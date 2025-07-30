const std = @import("std");

const _3t = @import("_3t");
const char = @import("chars");
const color = @import("colors");
const polygon = @import("polygon");
const Polygon = polygon.Polygon;
const quaternion = @import("quaternions");
const vectors = @import("vectors");
const vec2i = vectors.vec2i;
const vec2 = vectors.vec2;
const vec3 = vectors.vec3;

const SCREEN_WIDTH: u32 = 50;
const SCREEN_HEIGHT: u32 = 25;
const SCREEN_DEFAULT_CHAR: u8 = ' ';

const Edge = struct {
    atoms: std.ArrayList(vec2i),

    fn fill_y(self: *Edge, start: vec2i, length: usize) !void {
        const y0: usize =
            if (start.y < 0)
                0
            else if (start.y > SCREEN_HEIGHT)
                SCREEN_HEIGHT - 1
            else
                @intCast(start.y);
        const xx: i64 = start.x;
        //std.debug.print("y0: {}, xx: {}, length: {}\n", .{ y0, xx, length });
        for (y0..(y0 + length)) |y| {
            const yy: i64 = @intCast(y);
            try self.atoms.append(.{ .x = xx, .y = yy });
        }
    }

    fn deinit(self: *Edge) void {
        self.atoms.deinit();
    }

    fn init(start: vec2i, end: vec2i, allocator: std.mem.Allocator) !Edge {
        var edge: Edge = undefined;

        edge.atoms = std.ArrayList(vec2i).init(allocator);

        var _start: vec2i = vec2i{ .x = 0, .y = 0 };
        var _end: vec2i = vec2i{ .x = 0, .y = 0 };
        // HORIZONTAL LINE
        if (start.y == end.y) {
            try edge.atoms.append(start);
            try edge.atoms.append(end);
            return edge;
        }

        // VERTICAL LINE
        if (start.x == end.x) {
            const l = @abs(start.y - end.y);
            if (start.y < end.y) {
                try edge.fill_y(start, l);
            } else {
                try edge.fill_y(end, l);
            }
            return edge;
        }

        //  DIAGONAL LINE
        if (start.x > end.x) {
            _start = end;
            _end = start;
        } else {
            _start = start;
            _end = end;
        }

        const line = vec2i{ .x = _end.x - _start.x, .y = _end.y - _start.y };
        const dydx: f64 = @as(f64, @floatFromInt(line.y)) / @as(f64, @floatFromInt(line.x));
        var p = vec2.from(_start);

        const last_x: f64 = @floatFromInt(_end.x);
        var i: i32 = 0;
        var last_filled_y: usize = 0;
        while (p.x <= last_x) {
            i += 1;
            //std.debug.print("p.x {}\n", .{p.x});
            const xx: usize = @intFromFloat(@abs(std.math.round(p.x)));
            const yy: usize = @intFromFloat(@abs(std.math.round(p.y)));

            if ((xx < SCREEN_WIDTH) and (yy < SCREEN_HEIGHT)) {
                if (last_filled_y == 0) {
                    last_filled_y = yy;
                    try edge.fill_y(.{ .x = @intCast(xx), .y = @intCast(yy) }, 1);
                } else if (yy != last_filled_y) {
                    last_filled_y = yy;
                    const length: usize = @intFromFloat(@abs(dydx) + 1);
                    try edge.fill_y(.{ .x = @intCast(xx), .y = @intCast(yy) }, length);
                }
            }
            p.x += 1;
            p.y += dydx;
        }
        return edge;
    }

    fn intersects(self: *const Edge, y: i64) ?i64 {
        for (self.atoms.items) |atom| {
            if (atom.y == y) return atom.x;
        }
        return null;
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

    fn clear(self: *Screen) void {
        for (0..SCREEN_HEIGHT) |i| {
            for (0..SCREEN_WIDTH) |j| {
                self.chars[i][j].data = char.NONE;
            }
        }
    }

    fn print(self: *const Screen) void {
        std.debug.print("┌", .{});
        for (0..SCREEN_WIDTH) |_| {
            std.debug.print("─", .{});
        }
        std.debug.print("┐\n", .{});
        for (self.chars, 0..self.chars.len) |row, i| {
            std.debug.print("│", .{});
            for (row) |c| {
                std.debug.print("{s}{s}{s}", .{ c.color.*, c.data.*, color.RESET.* });
            }
            std.debug.print("│{d}\n", .{i});
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
        for (y0..(y0 + length)) |yy| {
            if ((xx < SCREEN_WIDTH) and (yy < SCREEN_HEIGHT)) {
                self.chars[yy][xx] = fill;
            }
        }
    }

    fn fill_x(self: *Screen, start: vec2i, length: usize, fill: Char) void {
        const yy: usize = @intCast(start.y);
        const x0: usize = @intCast(start.x);
        //std.debug.print("y0: {}, xx: {}, length: {}\n", .{ y0, xx, length });
        for (x0..(x0 + length)) |xx| {
            if ((xx < SCREEN_WIDTH) and (yy < SCREEN_HEIGHT)) {
                self.chars[yy][xx] = fill;
            }
        }
    }

    fn emplace(self: *Screen, items: std.ArrayList(vec2i), fill: Char) void {
        for (items.items) |*item| {
            if ((item.x < SCREEN_WIDTH) and (item.x > 0) and (item.y < SCREEN_HEIGHT) and (item.y > 0)) {
                const xx: usize = @intCast(item.x);
                const yy: usize = @intCast(item.y);
                self.chars[yy][xx] = fill;
            }
        }
    }

    fn draw_line_double(self: *Screen, start: vec2i, end: vec2i, col: color.Type) !void {
        //std.debug.print("<-- drawing line -->\n", .{});
        const fill = Char.init(char.FULL, col);

        const allocator = std.heap.page_allocator;
        var edge = try Edge.init(start, end, allocator);
        defer edge.deinit();

        self.emplace(edge.atoms, fill);
    }

    fn draw_surface(self: *Screen, vertecies: std.ArrayList(vec2i), col: color.Type) !void {
        //std.debug.print("<-- drawing surface -->\n", .{});
        const fill = Char.init(char.FULL, col);

        const allocator = std.heap.page_allocator;
        var edges = std.ArrayList(Edge).init(allocator);
        defer edges.deinit();

        for (1..vertecies.items.len) |i| {
            //std.debug.print("<-- drawing surface edge -->\n", .{});
            const e = try Edge.init(vertecies.items[i - 1], vertecies.items[i], allocator);
            try edges.append(e);
        }
        //std.debug.print("<-- drawing surface edge -->\n", .{});
        const e = try Edge.init(vertecies.items[vertecies.items.len - 1], vertecies.items[0], allocator);
        try edges.append(e);

        var max_y: i64 = std.math.minInt(i64);
        var min_y: i64 = std.math.maxInt(i64);
        for (vertecies.items) |*v| {
            if (v.y > max_y) max_y = v.y;
            if (v.y < min_y) min_y = v.y;
        }

        const first_y: usize =
            if (min_y < 0)
                0
            else if (min_y > SCREEN_HEIGHT)
                SCREEN_HEIGHT - 1
            else
                @intCast(min_y);
        const last_y: usize =
            if (max_y < 0)
                0
            else if (max_y > SCREEN_HEIGHT)
                SCREEN_HEIGHT - 1
            else
                @intCast(max_y);

        for (first_y..last_y) |y| {
            var intersections = std.ArrayList(i64).init(allocator);
            defer intersections.deinit();

            for (edges.items) |*edge| {
                if (edge.intersects(@intCast(y))) |intersection| {
                    var is_already_in_list = false;
                    for (intersections.items) |x| {
                        if (x == intersection) {
                            is_already_in_list = true;
                            break;
                        }
                    }
                    if (!is_already_in_list) {
                        try intersections.append(intersection);
                    }
                }
            }
            std.mem.sort(i64, intersections.items, {}, std.sort.asc(i64));

            if (y == 5) {
                std.debug.print("--> y5: ", .{});
                for (intersections.items) |*int| {
                    std.debug.print("{d}, ", .{int.*});
                }
                std.debug.print("\n", .{});
            }

            for (0..intersections.items.len / 2) |i| {
                const x0: i64 = intersections.items[i * 2];
                const x1: i64 = intersections.items[(i * 2) + 1];
                const length: usize = @intCast(x1 - x0);
                self.fill_x(.{ .x = x0, .y = @intCast(y) }, length, fill);
            }
        }

        // free edges
        for (edges.items) |*edge| {
            self.emplace(edge.atoms, Char.init(char.FULL, color.PURPLE));
            edge.deinit();
        }
        //self.emplace(vertecies, Char.init(char.FULL, color.RED));
    }
};

pub fn main() !void {
    var screen = Screen{};

    const allocator = std.heap.page_allocator;
    var surface = std.ArrayList(vec3).init(allocator);
    defer surface.deinit();
    try surface.append(.{ .x = 9, .y = 6, .z = 2 });
    try surface.append(.{ .x = 13, .y = 6, .z = 2 });
    try surface.append(.{ .x = 25, .y = 8, .z = 2 });
    try surface.append(.{ .x = 35, .y = 6, .z = 2 });
    try surface.append(.{ .x = 38, .y = 6, .z = 2 });
    try surface.append(.{ .x = 49, .y = 13, .z = 2 });
    try surface.append(.{ .x = 25, .y = 24, .z = 2 });
    try surface.append(.{ .x = 0, .y = 13, .z = 2 });

    var heart = Polygon.init(surface, color.RED, .{ .x = 50, .y = 0, .z = -100 }, quaternion.Quaternion{});

    while (true) {
        const t = std.time.microTimestamp();
        heart.transform(@floatFromInt(t));
        const vert = try heart.projection(allocator);
        defer vert.deinit();

        try screen.draw_surface(vert, heart.color);
        screen.print();
        screen.clear();
        std.time.sleep(1_000_000_000);
    }

    //try screen.draw_line_double(.{ .x = 16, .y = 16 }, .{ .x = 32, .y = 32 }, color.RED);
    //try screen.draw_line_double(.{ .x = 25, .y = 0 }, .{ .x = 25, .y = 25 }, color.BLUE);
    //try screen.draw_line_double(.{ .x = 25, .y = 0 }, .{ .x = 50, .y = 0 }, color.GREEN);

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
