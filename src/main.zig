const std = @import("std");

const _3t = @import("_3t");
const ansi = @import("ansi");
const char = @import("chars");
const polygon = @import("polygon");
const Polygon = polygon.Polygon;
const AtomColor = polygon.AtomColor;
const quaternion = @import("quaternions");
const vectors = @import("vectors");
const vec1z = vectors.vec1z;
const vec2i = vectors.vec2i;
const vec2z = vectors.vec2z;
const vec2 = vectors.vec2;
const vec3 = vectors.vec3;

const SCREEN_WIDTH: u32 = 128;
const SCREEN_HEIGHT: u32 = 32;
const SCREEN_DEFAULT_CHAR: u8 = ' ';

const Edge = struct {
    start: vec2z,
    end: vec2z,
    atoms: std.ArrayList(vec2z),
    const z_bias = 0; // Small offset to make edges closer

    fn deinit(self: *Edge) void {
        self.atoms.deinit();
    }

    fn init(start: vec2z, end: vec2z, allocator: std.mem.Allocator) !Edge {
        var edge: Edge = undefined;
        edge.start = start;
        edge.end = end;
        edge.atoms = std.ArrayList(vec2z).init(allocator);
        var x0: i64 = start.x;
        var y0: i64 = start.y;
        var x1: i64 = end.x;
        var y1: i64 = end.y;
        var depth_start = start.z;
        var depth_end = end.z;
        const steep = @abs(y1 - y0) > @abs(x1 - x0);
        if (steep) {
            std.mem.swap(i64, &x0, &y0);
            std.mem.swap(i64, &x1, &y1);
        }
        if (x0 > x1) {
            std.mem.swap(i64, &x0, &x1);
            std.mem.swap(i64, &y0, &y1);
            std.mem.swap(f64, &depth_start, &depth_end); // Swap depths too!
        }
        const dx: i64 = x1 - x0;
        const dy: i64 = @intCast(@abs(y1 - y0));
        var err: i64 = @divTrunc(dx, 2);
        const ystep: i64 = if (y0 < y1) 1 else -1;
        var y: i64 = y0;
        const delta_depth = depth_end - depth_start;
        const num_steps = dx; // Additions between dx+1 points
        const depth_step = if (dx > 0) delta_depth / @as(f64, @floatFromInt(num_steps)) else 0.0;
        var x: i64 = x0;
        var n: f64 = 0;
        while (x <= x1) : (x += 1) {
            const px = if (steep) y else x;
            const py = if (steep) x else y;
            if (px >= 0 and px < SCREEN_WIDTH and py >= 0 and py < SCREEN_HEIGHT * 2) {
                try edge.atoms.append(.{ .x = px, .y = py, .z = (depth_start + (depth_step * n)) + z_bias });
            }
            n += 1.0;

            err -= dy;
            if (err < 0) {
                y += ystep;
                err += dx;
            }
        }
        // Force last atom to exact end depth (overrides FP drift)
        if (edge.atoms.items.len > 0) {
            //const last_interpolated = edge.atoms.items[edge.atoms.items.len - 1].z;
            //const depth_error = depth_end - last_interpolated;
            //std.debug.print("edge end z projected {}, interpolated {}, error {}, step {}\n", .{ depth_end, last_interpolated, depth_error, depth_step });

            edge.atoms.items[edge.atoms.items.len - 1].z = depth_end + z_bias;
        }
        std.sort.heap(vec2z, edge.atoms.items, {}, struct {
            pub fn lessThan(_: void, a: vec2z, b: vec2z) bool {
                if (a.y != b.y) return a.y < b.y;
                return a.x < b.x;
            }
        }.lessThan);
        return edge;
    }

    fn intersects(self: *const Edge, y: i64) ?vec1z {
        if (self.start.y == self.end.y) return null;
        for (self.atoms.items) |atom| {
            if (atom.y == y) return .{ .x = atom.x, .z = atom.z };
        }
        return null;
    }

    fn average_depth(self: *const Edge) f64 {
        return (self.start.z + self.end.z) / 2;
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
    const Atom = struct {
        color: AtomColor,
        z: f64,
    };

    chars: [SCREEN_HEIGHT][SCREEN_WIDTH]Char = blk: {
        const default_char = Char{};
        const default_row: [SCREEN_WIDTH]Char = .{default_char} ** SCREEN_WIDTH;
        const result: [SCREEN_HEIGHT][SCREEN_WIDTH]Char = .{default_row} ** SCREEN_HEIGHT;
        break :blk result;
    },

    atoms: [SCREEN_HEIGHT * 2][SCREEN_WIDTH]Atom = blk: {
        const default = Atom{ .color = AtomColor.NONE, .z = std.math.inf(f64) };
        const default_row: [SCREEN_WIDTH]Atom = .{default} ** SCREEN_WIDTH;
        const result: [SCREEN_HEIGHT * 2][SCREEN_WIDTH]Atom = .{default_row} ** (SCREEN_HEIGHT * 2);
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
                self.atoms[i][j] = .{ .color = AtomColor.NONE, .z = std.math.inf(f64) };
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
                const upper = self.atoms[yy * 2][xx].color;
                const lower = self.atoms[yy * 2 + 1][xx].color;
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
        //try writer.print("\x1B[2J\x1B[1;1H", .{});

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

    fn fill_x(self: *Screen, start: vec2z, end: vec1z, color: AtomColor) void {
        const length: usize = @intCast(end.x - start.x);
        if (length == 0) return;
        const d_depth = (end.z - start.z) / @as(f64, @floatFromInt(length));
        const curr_depth = start.z;
        const clamped_x0 = @max(0, start.x);
        const clamped_end = @min(@as(i64, @intCast(SCREEN_WIDTH - 1)), start.x + @as(i64, @intCast(length)));
        var offset: i64 = clamped_x0 - start.x;
        var x = clamped_x0;
        if (color == AtomColor.PURPLE) {
            std.debug.print("y{} ( {} => {})\n", .{ start.y, clamped_x0, clamped_end });
        }
        while (x <= clamped_end) : (x += 1) {
            const vy: usize = @intCast(start.y); // Virtual y
            const atom_depth = curr_depth + (d_depth * @as(f64, @floatFromInt(offset)));
            offset += 1;
            if (color == AtomColor.PURPLE) {
                std.debug.print("({},{}) {} vs {}\n", .{ x, vy, atom_depth, self.atoms[vy][x].z });
            }
            if (atom_depth < self.atoms[vy][x].z + 1e-10) { // Smaller depth = closer, overwrite
                if (color == AtomColor.PURPLE) {
                    std.debug.print("-painted-\n", .{});
                }
                self.atoms[vy][x].color = color;
                self.atoms[vy][x].z = atom_depth;
            }
        }
    }

    fn emplace(self: *Screen, items: []vec2z, fill: AtomColor) void {
        for (items) |*item| {
            if ((item.x < SCREEN_WIDTH) and (item.x >= 0) and (item.y < SCREEN_HEIGHT * 2) and (item.y >= 0)) {
                const xx: usize = @intCast(item.x);
                const yy: usize = @intCast(item.y);
                if (item.z <= self.atoms[yy][xx].z) {
                    self.atoms[yy][xx] = .{ .color = fill, .z = item.z };
                }
            }
        }
    }

    fn draw_surface(self: *Screen, vertecies: []vec2z, color: AtomColor) !void {
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
            var intersections = std.ArrayList(vec1z).init(allocator);
            defer intersections.deinit();

            for (edges.items) |*edge| {
                if (edge.intersects(@intCast(y))) |intersection| {
                    var is_already_in_list = false;
                    for (intersections.items) |x| {
                        if (x.x == intersection.x) {
                            is_already_in_list = true;
                            break;
                        }
                    }
                    if (!is_already_in_list) {
                        try intersections.append(intersection);
                    }
                }
            }

            std.sort.heap(vec1z, intersections.items, {}, struct {
                pub fn lessThan(_: void, a: vec1z, b: vec1z) bool {
                    return a.x < b.x;
                }
            }.lessThan);

            for (0..intersections.items.len / 2) |i| {
                const x0 = intersections.items[i * 2];
                const x1 = intersections.items[(i * 2) + 1];

                self.fill_x(x0.to_vec2z(@intCast(y)), x1, color);
            }
        }

        // free edges
        for (edges.items) |*edge| {
            //   self.emplace(edge.atoms.items, AtomColor.PURPLE);
            edge.deinit();
        }
        // self.emplace(vertecies, AtomColor.GREEN);
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

pub const Cube = struct {
    faces: [6]Polygon,
    pos: vec3 = .{ .x = 0, .y = 0, .z = 5.0 }, // Offset from camera for visibility

    pub fn init(side: f64, offset: vec3, allocator: std.mem.Allocator) !Cube {
        const q = quaternion.Quaternion.init(0, 1, 1, 1); // Identity start
        const h = side / 2.0; // Half-side for centering at origin
        const verts = [_]vec3{
            .{ .x = -h, .y = -h, .z = -h }, // 0: back-bottom-left
            .{ .x = h, .y = -h, .z = -h }, //- 1: back-bottom-right
            .{ .x = h, .y = h, .z = -h }, //-- 2: back-top-right
            .{ .x = -h, .y = h, .z = -h }, //- 3: back-top-left
            .{ .x = -h, .y = -h, .z = h }, //- 4: front-bottom-left
            .{ .x = h, .y = -h, .z = h }, //-- 5: front-bottom-right
            .{ .x = h, .y = h, .z = h }, //--- 6: front-top-right
            .{ .x = -h, .y = h, .z = h }, //-- 7: front-top-left
        };

        // Initialize each face as a Polygon
        var back_verts = std.ArrayList(vec3).init(allocator);
        try back_verts.ensureTotalCapacity(4);
        try back_verts.appendSlice(&[_]vec3{ verts[0], verts[1], verts[2], verts[3] });

        var front_verts = std.ArrayList(vec3).init(allocator);
        try front_verts.ensureTotalCapacity(4);
        try front_verts.appendSlice(&[_]vec3{ verts[4], verts[5], verts[6], verts[7] });

        var left_verts = std.ArrayList(vec3).init(allocator);
        try left_verts.ensureTotalCapacity(4);
        try left_verts.appendSlice(&[_]vec3{ verts[0], verts[3], verts[7], verts[4] });

        var right_verts = std.ArrayList(vec3).init(allocator);
        try right_verts.ensureTotalCapacity(4);
        try right_verts.appendSlice(&[_]vec3{ verts[1], verts[2], verts[6], verts[5] });

        var bottom_verts = std.ArrayList(vec3).init(allocator);
        try bottom_verts.ensureTotalCapacity(4);
        try bottom_verts.appendSlice(&[_]vec3{ verts[0], verts[1], verts[5], verts[4] });

        var top_verts = std.ArrayList(vec3).init(allocator);
        try top_verts.ensureTotalCapacity(4);
        try top_verts.appendSlice(&[_]vec3{ verts[3], verts[2], verts[6], verts[7] });

        return .{
            .faces = [_]Polygon{
                Polygon.init(back_verts, AtomColor.RED, offset, q),
                Polygon.init(front_verts, AtomColor.GREEN, offset, q),
                Polygon.init(left_verts, AtomColor.BLUE, offset, q),
                Polygon.init(right_verts, AtomColor.YELLOW, offset, q),
                Polygon.init(bottom_verts, AtomColor.PURPLE, offset, q),
                Polygon.init(top_verts, AtomColor.CYAN, offset, q),
            },
        };
    }
};
pub fn main() !void {
    var screen = Screen{};
    //try Screen.init_terminal();

    const allocator = std.heap.page_allocator;
    var surface = std.ArrayList(vec3).init(allocator);
    defer surface.deinit();
    try surface.append(.{ .x = -10, .y = -10, .z = 0 });
    try surface.append(.{ .x = -10, .y = 10, .z = 0 });
    try surface.append(.{ .x = 10, .y = 10, .z = 0 });
    try surface.append(.{ .x = 10, .y = -10, .z = 0 });

    var heart = Polygon.init(surface, AtomColor.RED, .{ .x = 35, .y = 15, .z = 50 }, quaternion.Quaternion{ .a = 0, .b = 1, .c = 1, .d = 0 });
    var paper = Polygon.init(surface, AtomColor.YELLOW, .{ .x = 45, .y = 35, .z = 100 }, quaternion.Quaternion{ .a = 0, .b = 0, .c = 1, .d = 0 });

    var cube = try Cube.init(20, .{ .x = 0, .y = 0, .z = 50 }, allocator);

    var itteration: u64 = 0;
    var running: bool = true;
    while (running) {
        const t = std.time.microTimestamp();
        heart.transform(50);
        paper.transform(10);

        for (&cube.faces) |*poly| {
            poly.transform(1740); //30
            const verts = try poly.projection(allocator);
            defer verts.deinit();
            try screen.draw_surface(verts.items, poly.color);
        }
        //heart.transform(@floatFromInt(10));
        // const vert = try heart.projection(allocator);
        // defer vert.deinit();
        // const vert2 = try paper.projection(allocator);
        // defer vert2.deinit();
        // try screen.draw_surface(vert.items, heart.color);
        // try screen.draw_surface(vert2.items, paper.color);
        try screen.print();
        screen.clear();
        const t2 = std.time.microTimestamp();
        std.debug.print("render time µs {}\n", .{t2 - t});
        std.debug.print("itteration {}\n", .{itteration});
        std.time.sleep(16_666_666);
        itteration += 1;
        running = false;
    }
    // try Screen.deinit_terminal();
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
