const std = @import("std");
const App = @import("app.zig").App;

pub fn main(init: std.process.Init) void {
    const allocator = init.gpa;

    const code: u8 = blk: {
        const args = init.minimal.args.toSlice(init.arena.allocator()) catch break :blk 1;
        var app = App.init(allocator, args, init.io, init.environ_map) catch break :blk 1;
        defer app.deinit();

        const code = app.run() catch |err| {
            std.debug.print("error: {s}\n", .{@errorName(err)});
            break :blk 1;
        };

        break :blk code;
    };

    std.process.exit(code);
}
