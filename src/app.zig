const std = @import("std");
const vaxis = @import("vaxis");
const build_options = @import("build_options");

const app_event = @import("ui/event.zig");
const menu = @import("ui/menu.zig");
const stats = @import("ui/stats.zig");
const connections = @import("games/connections/connections.zig");
const wordle = @import("games/wordle/wordle.zig");
const api_client = @import("api/client.zig");
const storage_db = @import("storage/db.zig");
const option = @import("option.zig");

pub const App = struct {
    allocator: std.mem.Allocator,
    args: []const [:0]const u8,
    io: std.Io,
    environ_map: *std.process.Environ.Map,

    pub fn init(
        allocator: std.mem.Allocator,
        args: []const [:0]const u8,
        io: std.Io,
        environ_map: *std.process.Environ.Map,
    ) !App {
        return .{ .allocator = allocator, .args = args, .io = io, .environ_map = environ_map };
    }

    pub fn deinit(self: *App) void {
        _ = self;
    }

    pub fn run(self: *App) !u8 {
        const action = try option.parse(self.args, build_options.version, self.io);
        return switch (action) {
            .exit => |code| code,
            .run => |cli| try runUi(self.allocator, cli, self.io, self.environ_map),
        };
    }

    fn runUi(
        allocator: std.mem.Allocator,
        cli: option.Cli,
        io: std.Io,
        environ_map: *std.process.Environ.Map,
    ) !u8 {
        try api_client.globalInit();
        defer api_client.globalDeinit();

        var buffer: [1024]u8 = undefined;
        var tty = try vaxis.Tty.init(io, &buffer);
        defer tty.deinit();

        var vx = try vaxis.init(io, allocator, environ_map, .{});
        defer vx.deinit(allocator, tty.writer());
        defer vx.resetState(tty.writer()) catch {};

        var loop: vaxis.Loop(app_event.Event) = .init(io, &tty, &vx);
        try loop.start();
        defer loop.stop();

        try vx.enterAltScreen(tty.writer());
        try vx.setMouseMode(tty.writer(), true);
        try vx.queryTerminal(tty.writer(), .fromSeconds(1));

        var storage = try storage_db.open(allocator, .{}, io, environ_map);
        defer storage.deinit();

        if (cli.direct_connections) {
            switch (try connections.run(allocator, &tty, &vx, &loop, &storage, cli.dev_mode, true, io, environ_map)) {
                .quit => {
                    try flashQuit(&tty, &vx, io);
                    return 0;
                },
                .back_to_menu => {},
            }
        }

        if (cli.direct_wordle) {
            const mode: wordle.Mode = if (cli.wordle_unlimited) .unlimited else .daily;
            switch (try wordle.run(allocator, &tty, &vx, &loop, &storage, mode, cli.dev_mode, true, io, environ_map)) {
                .quit => {
                    try flashQuit(&tty, &vx, io);
                    return 0;
                },
                .back_to_menu => {},
            }
        }

        while (true) {
            switch (try menu.run(allocator, &tty, &vx, &loop, &storage, cli.dev_mode)) {
                .quit => {
                    try flashQuit(&tty, &vx, io);
                    return 0;
                },
                .wordle => switch (try wordle.run(allocator, &tty, &vx, &loop, &storage, .daily, cli.dev_mode, false, io, environ_map)) {
                    .back_to_menu => continue,
                    .quit => {
                        try flashQuit(&tty, &vx, io);
                        return 0;
                    },
                },
                .wordle_unlimited => switch (try wordle.run(allocator, &tty, &vx, &loop, &storage, .unlimited, cli.dev_mode, false, io, environ_map)) {
                    .back_to_menu => continue,
                    .quit => {
                        try flashQuit(&tty, &vx, io);
                        return 0;
                    },
                },
                .connections => switch (try connections.run(allocator, &tty, &vx, &loop, &storage, cli.dev_mode, false, io, environ_map)) {
                    .back_to_menu => continue,
                    .quit => {
                        try flashQuit(&tty, &vx, io);
                        return 0;
                    },
                },
                .stats_wordle => switch (try stats.run(allocator, &tty, &vx, &loop, &storage, .wordle)) {
                    .back_to_menu => continue,
                    .quit => {
                        try flashQuit(&tty, &vx, io);
                        return 0;
                    },
                },
                .stats_wordle_unlimited => switch (try stats.run(allocator, &tty, &vx, &loop, &storage, .wordle_unlimited)) {
                    .back_to_menu => continue,
                    .quit => {
                        try flashQuit(&tty, &vx, io);
                        return 0;
                    },
                },
                .stats_connections => switch (try stats.run(allocator, &tty, &vx, &loop, &storage, .connections)) {
                    .back_to_menu => continue,
                    .quit => {
                        try flashQuit(&tty, &vx, io);
                        return 0;
                    },
                },
            }
        }
    }
};

fn flashQuit(tty: *vaxis.Tty, vx: *vaxis.Vaxis, io: std.Io) !void {
    const win = vx.window();
    win.clear();
    win.hideCursor();
    _ = win.print(&.{.{ .text = "Saving..." }}, .{ .row_offset = 0, .col_offset = 2, .wrap = .none });
    try vx.render(tty.writer());
    try std.Io.sleep(io, .fromMilliseconds(120), .awake);
}
