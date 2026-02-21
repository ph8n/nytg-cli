const std = @import("std");
const curl = @import("curl");

const models = @import("models.zig");
const storage_db = @import("../storage/db.zig");

pub const Error = error{
    UnexpectedStatusCode,
};

const request_timeout_ms: usize = 8_000;
const max_retries: u8 = 2;
const max_cache_file_bytes: usize = 256 * 1024;

var curl_initialized = false;

const PuzzleKind = enum {
    wordle,
    connections,
};

const FetchResponse = struct {
    status_code: i32,
    body: []u8,
};

pub fn globalInit() !void {
    if (curl_initialized) return;
    try curl.globalInit();
    curl_initialized = true;
}

pub fn globalDeinit() void {
    if (!curl_initialized) return;
    curl.globalDeinit();
    curl_initialized = false;
}

pub fn fetchWordle(allocator: std.mem.Allocator, date: []const u8) !std.json.Parsed(models.WordleData) {
    return fetchPuzzle(models.WordleData, allocator, .wordle, date);
}

pub fn fetchConnections(allocator: std.mem.Allocator, date: []const u8) !std.json.Parsed(models.ConnectionsData) {
    return fetchPuzzle(models.ConnectionsData, allocator, .connections, date);
}

fn fetchPuzzle(
    comptime T: type,
    allocator: std.mem.Allocator,
    kind: PuzzleKind,
    date: []const u8,
) !std.json.Parsed(T) {
    try globalInit();

    const url = try buildUrl(allocator, kind, date);
    defer allocator.free(url);

    const network = fetchWithRetry(allocator, url) catch |network_err| {
        if (try loadCachedPuzzle(T, allocator, kind, date)) |cached| return cached;
        return network_err;
    };
    defer allocator.free(network.body);

    if (network.status_code != 200) {
        if (try loadCachedPuzzle(T, allocator, kind, date)) |cached| return cached;
        return error.UnexpectedStatusCode;
    }

    const parsed = std.json.parseFromSlice(T, allocator, network.body, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    }) catch |parse_err| {
        if (try loadCachedPuzzle(T, allocator, kind, date)) |cached| return cached;
        return parse_err;
    };

    saveCachedPuzzle(allocator, kind, date, network.body) catch {};
    return parsed;
}

fn buildUrl(allocator: std.mem.Allocator, kind: PuzzleKind, date: []const u8) ![]u8 {
    return switch (kind) {
        .wordle => std.fmt.allocPrint(
            allocator,
            "https://www.nytimes.com/svc/wordle/v2/{s}.json",
            .{date},
        ),
        .connections => std.fmt.allocPrint(
            allocator,
            "https://www.nytimes.com/svc/connections/v2/{s}.json",
            .{date},
        ),
    };
}

fn fetchWithRetry(allocator: std.mem.Allocator, url: []const u8) !FetchResponse {
    var attempt: u8 = 0;
    while (attempt <= max_retries) : (attempt += 1) {
        const response = performFetch(allocator, url) catch |err| {
            if (attempt == max_retries) return err;
            sleepBeforeRetry(attempt);
            continue;
        };

        if (response.status_code == 200) return response;
        if (attempt < max_retries and isRetryableStatus(response.status_code)) {
            allocator.free(response.body);
            sleepBeforeRetry(attempt);
            continue;
        }
        return response;
    }
    unreachable;
}

fn performFetch(allocator: std.mem.Allocator, url: []const u8) !FetchResponse {
    var ca_bundle = try curl.allocCABundle(allocator);
    defer ca_bundle.deinit();

    var easy = try curl.Easy.init(.{
        .ca_bundle = ca_bundle,
        .default_user_agent = "nytg-cli",
        .default_timeout_ms = request_timeout_ms,
    });
    defer easy.deinit();

    try easy.setFollowLocation(true);
    try easy.setMaxRedirects(3);

    const url_z = try allocator.dupeZ(u8, url);
    defer allocator.free(url_z);

    var body = std.Io.Writer.Allocating.init(allocator);
    defer body.deinit();

    const resp = try easy.fetch(url_z, .{
        .method = .GET,
        .writer = &body.writer,
    });

    return .{
        .status_code = resp.status_code,
        .body = try body.toOwnedSlice(),
    };
}

fn sleepBeforeRetry(attempt: u8) void {
    const delay_ms: u64 = 150 * (@as(u64, attempt) + 1);
    std.Thread.sleep(delay_ms * std.time.ns_per_ms);
}

fn isRetryableStatus(status_code: i32) bool {
    return switch (status_code) {
        408, 429, 500, 502, 503, 504 => true,
        else => false,
    };
}

fn loadCachedPuzzle(
    comptime T: type,
    allocator: std.mem.Allocator,
    kind: PuzzleKind,
    date: []const u8,
) !?std.json.Parsed(T) {
    const path = try cachePath(allocator, kind, date);
    defer allocator.free(path);

    var file = std.fs.openFileAbsolute(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close();

    const body = file.readToEndAlloc(allocator, max_cache_file_bytes) catch |err| switch (err) {
        error.FileTooBig => return null,
        else => return err,
    };
    defer allocator.free(body);

    return std.json.parseFromSlice(T, allocator, body, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    }) catch null;
}

fn saveCachedPuzzle(
    allocator: std.mem.Allocator,
    kind: PuzzleKind,
    date: []const u8,
    body: []const u8,
) !void {
    const path = try cachePath(allocator, kind, date);
    defer allocator.free(path);

    const parent = std.fs.path.dirname(path) orelse return;
    try std.fs.cwd().makePath(parent);

    var file = try std.fs.createFileAbsolute(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(body);
}

fn cachePath(allocator: std.mem.Allocator, kind: PuzzleKind, date: []const u8) ![]u8 {
    const app_dir = try std.fs.getAppDataDir(allocator, storage_db.AppName);
    defer allocator.free(app_dir);

    const filename = try std.fmt.allocPrint(allocator, "{s}.json", .{date});
    defer allocator.free(filename);

    return std.fs.path.join(allocator, &.{ app_dir, "cache", puzzleKindName(kind), filename });
}

fn puzzleKindName(kind: PuzzleKind) []const u8 {
    return switch (kind) {
        .wordle => "wordle",
        .connections => "connections",
    };
}

test "retryable status coverage" {
    try std.testing.expect(isRetryableStatus(500));
    try std.testing.expect(isRetryableStatus(429));
    try std.testing.expect(!isRetryableStatus(404));
}

test {
    std.testing.refAllDecls(@This());
}
