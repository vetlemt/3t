const std = @import("std");

const _3t = @import("_3t");
const char = @import("chars");
const color = @import("colors");

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

const MAX_CHAR_SIZE: usize = 8;

const Char = struct {
    data: *const []const u8 = char.NONE,
    color: *const []const u8 = color.WHITE,

    fn init(character: *const []const u8, col: *const []const u8) Char {
        var c: Char = undefined;
        c.data = character;
        c.color = col;
        return c;
    }
};

const Screen = struct {
    chars: [SCREEN_HEIGHT][SCREEN_WIDTH]Char = blk: {
        const default_char = Char{};
        const default_row: [SCREEN_WIDTH]Char = .{default_char} ** SCREEN_WIDTH;
        const result: [SCREEN_HEIGHT][SCREEN_WIDTH]Char = .{default_row} ** SCREEN_HEIGHT;
        break :blk result;
    },

    fn print(self: *const Screen) void {
        std.debug.print("┌", .{});
        for (0..SCREEN_WIDTH) |_| {
            std.debug.print("─", .{});
        }
        std.debug.print("┐\n", .{});
        for (self.chars) |row| {
            std.debug.print("│", .{});
            for (row) |c| {
                std.debug.print("{s}{s}{s}", .{ c.color.*, c.data.*, color.RESET.* });
            }
            std.debug.print("│\n", .{});
        }
        std.debug.print("└", .{});
        for (0..SCREEN_WIDTH) |_| {
            std.debug.print("─", .{});
        }
        std.debug.print("┘\n", .{});
    }

    fn fill_y(self: *Screen, start: vec2i, length: usize, fill: Char) void {
        const y0: usize = @intCast(start.y);
        const xx: usize = @intCast(start.x);
        //std.debug.print("y0: {}, xx: {}, length: {}\n", .{ y0, xx, length });
        for (y0..(y0 + length + 1)) |yy| {
            if ((xx < SCREEN_WIDTH) and (yy < SCREEN_HEIGHT)) {
                self.chars[yy][xx] = fill;
            }
        }
    }

    fn draw_line_double(self: *Screen, start: vec2i, end: vec2i, col: *const []const u8) void {
        const fill = Char.init(char.FULL, col);
        // std.debug.print("<-- drawing line -->\n", .{});

        var _start: vec2i = vec2i{ .x = 0, .y = 0 };
        var _end: vec2i = vec2i{ .x = 0, .y = 0 };
        if (start.x == end.x) {
            const l = start.y - end.y;
            if (start.y < end.y) {
                self.fill_y(start, @abs(l), fill);
                self.fill_y(.{ .x = start.x + 1, .y = start.y }, @abs(l), fill);
            } else {
                self.fill_y(end, @abs(l), fill);
                self.fill_y(.{ .x = end.x + 1, .y = end.y }, @abs(l), fill);
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
                self.fill_y(p.to_int(), @intFromFloat(@abs(dydx)), fill);
            }
            p.x += 1;
            p.y += dydx;
        }
        self.fill_y(p.to_int(), @intFromFloat(@abs(dydx)), fill);
    }
};

pub fn main() !void {
    var screen = Screen{};
    screen.draw_line_double(.{ .x = 16, .y = 16 }, .{ .x = 32, .y = 32 }, color.RED);
    screen.draw_line_double(.{ .x = 25, .y = 0 }, .{ .x = 25, .y = 25 }, color.BLUE);
    screen.draw_line_double(.{ .x = 25, .y = 0 }, .{ .x = 50, .y = 0 }, color.GREEN);
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
