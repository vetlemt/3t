const std = @import("std");

const _3t = @import("_3t");
const ansi = @import("ansi");
const char = @import("chars");
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
    fg: ansi.Color = ansi.WHITE,
    bg: ansi.Color = ansi.NONE,

    fn init(character: *const []const u8, fg: ansi.Color, bg: ansi.Color) Char {
        var c: Char = undefined;
        c.data = character;
        c.fg = fg;
        c.bg = bg;
        return c;
    }
};

const Screen = struct {
    const AtomColor = enum {
        NONE,
        BLACK,
        RED,
        GREEN,
        YELLOW,
        BLUE,
        PURPLE,
        CYAN,
        WHITE,
    };

    chars: [SCREEN_HEIGHT][SCREEN_WIDTH]Char = blk: {
        const default_char = Char{};
        const default_row: [SCREEN_WIDTH]Char = .{default_char} ** SCREEN_WIDTH;
        const result: [SCREEN_HEIGHT][SCREEN_WIDTH]Char = .{default_row} ** SCREEN_HEIGHT;
        break :blk result;
    },

    atoms: [SCREEN_HEIGHT * 2][SCREEN_WIDTH]AtomColor = blk: {
        const default_char = AtomColor.NONE;
        const default_row: [SCREEN_WIDTH]AtomColor = .{default_char} ** SCREEN_WIDTH;
        const result: [SCREEN_HEIGHT * 2][SCREEN_WIDTH]AtomColor = .{default_row} ** (SCREEN_HEIGHT * 2);
        break :blk result;
    },

    fn clear(self: *Screen) void {
        for (0..SCREEN_HEIGHT) |i| {
            for (0..SCREEN_WIDTH) |j| {
                self.chars[i][j].data = char.NONE;
            }
        }
        for (0..SCREEN_HEIGHT * 2) |i| {
            for (0..SCREEN_WIDTH) |j| {
                self.atoms[i][j] = AtomColor.NONE;
            }
        }
    }

    fn get_ansi_color(color: AtomColor) ansi.Color {
        return switch (color) {
            AtomColor.NONE => ansi.NONE,
            AtomColor.BLACK => ansi.BLACK,
            AtomColor.RED => ansi.RED,
            AtomColor.GREEN => ansi.GREEN,
            AtomColor.YELLOW => ansi.YELLOW,
            AtomColor.BLUE => ansi.BLUE,
            AtomColor.PURPLE => ansi.PURPLE,
            AtomColor.CYAN => ansi.CYAN,
            AtomColor.WHITE => ansi.WHITE,
        };
    }

    fn get_ansi_bg_color(color: AtomColor) ansi.Color {
        return switch (color) {
            AtomColor.NONE => ansi.NONE,
            AtomColor.BLACK => ansi.BG_BLACK,
            AtomColor.RED => ansi.BG_RED,
            AtomColor.GREEN => ansi.BG_GREEN,
            AtomColor.YELLOW => ansi.BG_YELLOW,
            AtomColor.BLUE => ansi.BG_BLUE,
            AtomColor.PURPLE => ansi.BG_PURPLE,
            AtomColor.CYAN => ansi.BG_CYAN,
            AtomColor.WHITE => ansi.BG_WHITE,
        };
    }

    fn render_sub_pixels(self: *Screen) void {
        for (0..SCREEN_HEIGHT) |yy| {
            for (0..SCREEN_WIDTH) |xx| {
                const upper = self.atoms[yy * 2][xx];
                const lower = self.atoms[yy * 2 + 1][xx];
                const upper_fg = get_ansi_color(upper);
                const lower_fg = get_ansi_color(lower);
                const lower_bg = get_ansi_bg_color(lower);

                if ((upper == AtomColor.NONE) and (lower == AtomColor.NONE)) { // NOTHING
                    self.chars[yy][xx] = Char.init(char.NONE, ansi.NONE, ansi.NONE);
                } else if ((upper != AtomColor.NONE) and (lower == AtomColor.NONE)) { // UPPER ONLY
                    self.chars[yy][xx] = Char.init(char.UPPER, upper_fg, ansi.NONE);
                } else if ((upper == AtomColor.NONE) and (lower != AtomColor.NONE)) { // LOWER ONLY
                    self.chars[yy][xx] = Char.init(char.LOWER, lower_fg, ansi.NONE);
                } else if (upper == lower) { // UPPER AND LOWER THE SAME
                    self.chars[yy][xx] = Char.init(char.FULL, upper_fg, ansi.NONE);
                } else { // UPPER AND LOWER DIFFERENT
                    self.chars[yy][xx] = Char.init(char.UPPER, upper_fg, lower_bg);
                }
            }
        }
    }

    fn print(self: *Screen) !void {
        //std.debug.print(color.CLEAR.*, .{});
        self.render_sub_pixels();
        const stdout = std.io.getStdOut();
        var buffered = std.io.bufferedWriter(stdout.writer());
        const writer = buffered.writer();
        // Clear and home cursor each time (but stay in alt screen)
        try writer.print("\x1B[2J\x1B[1;1H", .{});

        try writer.print("┌", .{});
        for (0..SCREEN_WIDTH) |_| {
            try writer.print("─", .{});
        }
        try writer.print("┐\n", .{});
        for (self.chars, 0..self.chars.len) |row, i| {
            try writer.print("│", .{});
            for (row) |c| {
                try writer.print("{s}{s}{s}{s}", .{ c.fg.*, c.bg.*, c.data.*, ansi.RESET.* });
            }
            try writer.print("│{d}\n", .{i});
        }
        try writer.print("└", .{});
        for (0..SCREEN_WIDTH) |_| {
            try writer.print("─", .{});
        }
        try writer.print("┘\n", .{});
        try buffered.flush();
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

    fn fill_x(self: *Screen, start: vec2i, length: usize, fill: AtomColor) void {
        const yy: usize = @intCast(start.y);
        const x0: usize = @intCast(start.x);
        //std.debug.print("y0: {}, xx: {}, length: {}\n", .{ y0, xx, length });
        for (x0..(x0 + length)) |xx| {
            if ((xx < SCREEN_WIDTH) and (xx >= 0) and (yy < SCREEN_HEIGHT * 2) and (yy >= 0)) {
                self.atoms[yy][xx] = fill;
            }
        }
    }

    fn emplace(self: *Screen, items: []vec2i, fill: AtomColor) void {
        for (items) |*item| {
            if ((item.x < SCREEN_WIDTH) and (item.x >= 0) and (item.y < SCREEN_HEIGHT * 2) and (item.y >= 0)) {
                const xx: usize = @intCast(item.x);
                const yy: usize = @intCast(item.y);
                self.atoms[yy][xx] = fill;
            }
        }
    }

    fn draw_line_double(self: *Screen, start: vec2i, end: vec2i, col: ansi.Color) !void {
        _ = self; // autofix
        //std.debug.print("<-- drawing line -->\n", .{});
        const fill = Char.init(char.FULL, col);
        _ = fill; // autofix

        const allocator = std.heap.page_allocator;
        var edge = try Edge.init(start, end, allocator);
        defer edge.deinit();

        //self.emplace(edge.atoms.items, fill);
    }

    fn draw_surface(self: *Screen, vertecies: []vec2i, col: ansi.Color) !void {
        _ = col; // autofix
        //std.debug.print("<-- drawing surface -->\n", .{});

        const allocator = std.heap.page_allocator;
        var edges = std.ArrayList(Edge).init(allocator);
        defer edges.deinit();

        for (1..vertecies.len) |i| {
            //std.debug.print("<-- drawing surface edge -->\n", .{});
            const e = try Edge.init(vertecies[i - 1], vertecies[i], allocator);
            try edges.append(e);
        }
        //std.debug.print("<-- drawing surface edge -->\n", .{});
        const e = try Edge.init(vertecies[vertecies.len - 1], vertecies[0], allocator);
        try edges.append(e);

        var max_y: i64 = std.math.minInt(i64);
        var min_y: i64 = std.math.maxInt(i64);
        for (vertecies) |*v| {
            if (v.y > max_y) max_y = v.y;
            if (v.y < min_y) min_y = v.y;
        }

        const first_y: usize =
            if (min_y < 0)
                0
            else if (min_y > SCREEN_HEIGHT * 2)
                SCREEN_HEIGHT * 2 - 1
            else
                @intCast(min_y);
        const last_y: usize =
            if (max_y < 0)
                0
            else if (max_y > SCREEN_HEIGHT * 2)
                SCREEN_HEIGHT * 2 - 1
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
                self.fill_x(.{ .x = x0, .y = @intCast(y) }, length, AtomColor.RED);
            }
        }

        // free edges
        for (edges.items) |*edge| {
            self.emplace(edge.atoms.items, AtomColor.PURPLE);
            edge.deinit();
        }
        self.emplace(vertecies, AtomColor.GREEN);
    }

    fn init_terminal() !void {
        const stdout = std.io.getStdOut().writer();
        // Enter alternate screen and hide cursor
        try stdout.print("\x1B[?1049h\x1B[?25l", .{});
        // Optional: Initial clear and home
        try stdout.print("\x1B[2J\x1B[1;1H", .{});
    }

    fn deinit_terminal() !void {
        const stdout = std.io.getStdOut().writer();
        // Exit alternate screen, show cursor, reset colors
        try stdout.print("\x1B[?1049l\x1B[?25h\x1B[0m", .{});
        // Optional: Final clear if needed
        try stdout.print("\x1B[2J\x1B[1;1H", .{});
    }
};

pub fn main() !void {
    var screen = Screen{};
    try Screen.init_terminal();

    const allocator = std.heap.page_allocator;
    var surface = std.ArrayList(vec3).init(allocator);
    defer surface.deinit();
    try surface.append(.{ .x = -10, .y = -10, .z = 0 });
    try surface.append(.{ .x = -10, .y = 10, .z = 0 });
    try surface.append(.{ .x = 10, .y = 10, .z = 0 });
    try surface.append(.{ .x = 10, .y = -10, .z = 0 });

    var heart = Polygon.init(surface, ansi.RED, .{ .x = 35, .y = 15, .z = -50 }, quaternion.Quaternion{ .a = 0, .b = 1, .c = 1, .d = 0 });

    while (true) {
        const t = std.time.microTimestamp();
        heart.transform(50);
        //heart.transform(@floatFromInt(10));
        const vert = try heart.projection(allocator);
        defer vert.deinit();
        try screen.draw_surface(vert.items, heart.color);
        try screen.print();
        screen.clear();
        const t2 = std.time.microTimestamp();
        std.debug.print("render time µs {}\n", .{t2 - t});
        std.time.sleep(16_666_666);
    }
    Screen.deinit_terminal();
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
