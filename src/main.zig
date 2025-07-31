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

const SCREEN_WIDTH: u32 = 64;
const SCREEN_HEIGHT: u32 = 32;
const SCREEN_DEFAULT_CHAR: u8 = ' ';

const Edge = struct {
    start: vec2i,
    end: vec2i,
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
        edge.start = start;
        edge.end = end;
        edge.atoms = std.ArrayList(vec2i).init(allocator);

        var x0: i64 = start.x;
        var y0: i64 = start.y;
        var x1: i64 = end.x;
        var y1: i64 = end.y;

        const steep = @abs(y1 - y0) > @abs(x1 - x0);
        if (steep) {
            std.mem.swap(i64, &x0, &y0);
            std.mem.swap(i64, &x1, &y1);
        }

        if (x0 > x1) {
            std.mem.swap(i64, &x0, &x1);
            std.mem.swap(i64, &y0, &y1);
        }

        const dx: i64 = x1 - x0;
        const dy: i64 = @intCast(@abs(y1 - y0));
        var err: i64 = @divTrunc(dx, 2);
        const ystep: i64 = if (y0 < y1) 1 else -1;
        var y: i64 = y0;

        var x: i64 = x0;
        while (x <= x1) : (x += 1) {
            const px = if (steep) y else x;
            const py = if (steep) x else y;
            if (px >= 0 and px < SCREEN_WIDTH and py >= 0 and py < SCREEN_HEIGHT) {
                try edge.atoms.append(.{ .x = px, .y = py });
            }
            err -= dy;
            if (err < 0) {
                y += ystep;
                err += dx;
            }
        }

        std.sort.heap(vec2i, edge.atoms.items, {}, struct {
            pub fn lessThan(_: void, a: vec2i, b: vec2i) bool {
                if (a.y != b.y) return a.y < b.y;
                return a.x < b.x;
            }
        }.lessThan);

        return edge;
    }

    fn intersects(self: *const Edge, y: i64) ?i64 {
        if (self.start.y == self.end.y) return null;
        //        std.sort.binarySearch(vec2i, self.atoms.items, {}, comptime compareFn: fn(@TypeOf(context), T)std.math.Order)
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
        //std.debug.print(color.CLEAR.*, .{});
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
        self.emplace(vertecies, Char.init(char.FULL, color.GREEN));
    }
};

pub fn main() !void {
    var screen = Screen{};

    const allocator = std.heap.page_allocator;
    var surface = std.ArrayList(vec3).init(allocator);
    defer surface.deinit();
    try surface.append(.{ .x = -10, .y = -10, .z = 0 });
    try surface.append(.{ .x = -10, .y = 10, .z = 0 });
    try surface.append(.{ .x = 10, .y = 10, .z = 0 });
    try surface.append(.{ .x = 10, .y = -10, .z = 0 });

    var heart = Polygon.init(surface, color.RED, .{ .x = 70, .y = 20, .z = -100 }, quaternion.Quaternion{ .a = 0, .b = 1, .c = 1, .d = 0 });

    while (true) {
        const t = std.time.microTimestamp();
        //heart.transform(@floatFromInt(t));
        heart.transform(500);
        const vert = try heart.projection(allocator);
        defer vert.deinit();
        try screen.draw_surface(vert, heart.color);
        screen.print();
        screen.clear();
        std.time.sleep(5_00_000_000);
        const t2 = std.time.microTimestamp();
        std.debug.print("render time {}\n", .{t2 - t});
    }

    //try screen.draw_line_double(.{ .x = 16, .y = 16 }, .{ .x = 32, .y = 32 }, color.RED);
    //try screen.draw_line_double(.{ .x = 25, .y = 0 }, .{ .x = 25, .y = 25 }, color.BLUE);
    //try screen.draw_line_double(.{ .x = 25, .y = 0 }, .{ .x = 50, .y = 0 }, color.GREEN);

}

test "simple test" {
    var list = std.ArrayList(i64).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i64, 42), list.pop());
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
