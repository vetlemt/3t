const std = @import("std");

const _3t = @import("_3t");

const SCREEN_WIDTH: u32 = 50;
const SCREEN_HEIGHT: u32 = 25;
const SCREEN_DEFAULT_CHAR: u8 = ' ';

const vec2i = struct {
    x: i64,
    y: i64,
};

const vec2 = struct {
    x: f64,
    y: f64,

    fn from(v2i: vec2i) vec2 {
        return vec2{
            .x = @as(f64, @floatFromInt(v2i.x)),
            .y = @as(f64, @floatFromInt(v2i.y)),
        };
    }

    fn to_int(self: *vec2) vec2i {
        return vec2i{
            .x = @as(i64, @intFromFloat(self.x)),
            .y = @as(i64, @intFromFloat(self.y)),
        };
    }
};

const Screen = struct {
    chars: [SCREEN_HEIGHT][SCREEN_WIDTH]u8 = blk: {
        var result: [SCREEN_HEIGHT][SCREEN_WIDTH]u8 = undefined;
        for (&result) |*row| {
            @memset(row, SCREEN_DEFAULT_CHAR);
        }
        break :blk result;
    },

    fn print(self: *const Screen) void {
        std.debug.print("┌", .{});
        for (0..SCREEN_WIDTH) |_| {
            std.debug.print("─", .{});
        }
        std.debug.print("┐\n", .{});
        for (self.chars) |row| {
            std.debug.print("│{s}│\n", .{row});
        }
        std.debug.print("└", .{});
        for (0..SCREEN_WIDTH) |_| {
            std.debug.print("─", .{});
        }
        std.debug.print("┘\n", .{});
    }

    fn fill_y(self: *Screen, start: vec2i, length: usize, fill: comptime_int) void {
        const y0: usize = @intCast(start.y);
        const xx: usize = @intCast(start.x);
        //std.debug.print("y0: {}, xx: {}, length: {}\n", .{ y0, xx, length });
        for (y0..(y0 + length + 1)) |yy| {
            if ((xx < SCREEN_WIDTH) and (yy < SCREEN_HEIGHT)) {
                self.chars[yy][xx] = fill;
            }
        }
    }

    fn draw_line(self: *Screen, start: vec2i, end: vec2i) void {
        // std.debug.print("<-- drawing line -->\n", .{});

        var _start: vec2i = vec2i{ .x = 0, .y = 0 };
        var _end: vec2i = vec2i{ .x = 0, .y = 0 };
        if (start.x == end.x) {
            const l = start.y - end.y;
            if (start.y < end.y) {
                self.fill_y(start, @abs(l), 'X');
            } else {
                self.fill_y(end, @abs(l), 'X');
            }
            return;
        } else if (start.x > end.x) {
            _start = end;
            _end = start;
        } else {
            _start = start;
            _end = end;
        }
        const line = vec2i{ .x = _end.x - _start.x, .y = _end.y - _start.y };
        const dydx: f64 = @as(f64, @floatFromInt(line.y)) / @as(f64, @floatFromInt(line.x));
        const dxdy: f64 = @as(f64, @floatFromInt(line.x)) / @as(f64, @floatFromInt(line.y));
        var p = vec2.from(_start);
        std.debug.print("dydx: {}, dxdy: {}\n", .{ dydx, dxdy });

        const last_x: f64 = @floatFromInt(_end.x);
        var i: i32 = 0;
        while (p.x < last_x) {
            i += 1;
            const xx: usize = @intFromFloat(std.math.floor(p.x));
            const yy: usize = @intFromFloat(std.math.floor(p.y));

            //std.debug.print("{}: ({},{})\n", .{ i, xx, yy });
            if ((xx < SCREEN_WIDTH) and (yy < SCREEN_HEIGHT)) {
                //  std.debug.print("setting ({},{})\n", .{ xx, yy });
                //self.chars[yy][xx] = 'x';
                self.fill_y(p.to_int(), @intFromFloat(@abs(dydx)), 'X');
            }
            p.x += 1;
            p.y += dydx;
        }
        self.fill_y(p.to_int(), @intFromFloat(@abs(dydx)), 'X');
    }
};

pub fn main() !void {
    var screen = Screen{};
    screen.draw_line(vec2i{ .x = 16, .y = 16 }, vec2i{ .x = 32, .y = 32 });
    screen.draw_line(vec2i{ .x = 25, .y = 0 }, vec2i{ .x = 25, .y = 25 });
    screen.draw_line(vec2i{ .x = 25, .y = 0 }, vec2i{ .x = 50, .y = 0 });
    screen.print();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
