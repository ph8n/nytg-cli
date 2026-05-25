const std = @import("std");
const App = @import("app.zig").App;

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const code: u8 = blk: {
        var app = App.init(gpa.allocator()) catch break :blk 1;
        defer app.deinit();

        const code = app.run() catch |err| {
            std.debug.print("error: {s}\n", .{@errorName(err)});
            break :blk 1;
        };

        break :blk code;
    };

    if (gpa.deinit() == .leak) {
        std.debug.print("error: memory leak detected\n", .{});
        std.process.exit(1);
    }

    std.process.exit(code);
}
