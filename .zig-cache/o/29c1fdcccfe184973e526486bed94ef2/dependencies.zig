pub const packages = struct {
    pub const @"12207831bce7d4abce57b5a98e8f3635811cfefd160bca022eb91fe905d36a02cf25" = struct {
        pub const build_root = "/Users/dp/.cache/zig/p/12207831bce7d4abce57b5a98e8f3635811cfefd160bca022eb91fe905d36a02cf25";
        pub const build_zig = @import("12207831bce7d4abce57b5a98e8f3635811cfefd160bca022eb91fe905d36a02cf25");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"1220d78664322b50e31a99cfb004b6fa60c43098d95abf7ec60a21ebeaf1c914edaf" = struct {
        pub const build_root = "/Users/dp/.cache/zig/p/1220d78664322b50e31a99cfb004b6fa60c43098d95abf7ec60a21ebeaf1c914edaf";
        pub const build_zig = @import("1220d78664322b50e31a99cfb004b6fa60c43098d95abf7ec60a21ebeaf1c914edaf");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "mibu", "1220d78664322b50e31a99cfb004b6fa60c43098d95abf7ec60a21ebeaf1c914edaf" },
    .{ "ziglyph", "12207831bce7d4abce57b5a98e8f3635811cfefd160bca022eb91fe905d36a02cf25" },
};
