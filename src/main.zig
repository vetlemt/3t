const std = @import("std");

const _3t = @import("_3t");
const ansi = @import("ansi");
const char = @import("chars");
const inputs = @import("input");
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
    atoms: std.array_list.Managed(vec2z),
    const z_bias = 0; // Small offset to make edges closer

    fn deinit(self: *Edge) void {
        self.atoms.deinit();
    }

    fn init(start: vec2z, end: vec2z, allocator: std.mem.Allocator) !Edge {
        var edge: Edge = undefined;
        edge.start = start;
        edge.end = end;
        edge.atoms = std.array_list.Managed(vec2z).init(allocator);
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
            //if (px >= 0 and px < SCREEN_WIDTH and py >= 0 and py < SCREEN_HEIGHT * 2) {
            try edge.atoms.append(.{ .x = px, .y = py, .z = (depth_start + (depth_step * n)) + z_bias });
            //}
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
        // Fill any y gaps (rare, but for angles)
        return edge;
    }

    fn intersects(self: *const Edge, y: i64) ?vec1z {
        if (self.start.y == self.end.y) return null;
        for (self.atoms.items) |atom| {
            if (atom.y == y) return .{ .x = atom.x, .z = atom.z };
        }
        return null;
    }
};

const MAX_CHAR_SIZE: usize = 8;

const Char = struct {
    data: *const []const u8 = char.NONE,
    fg: AtomColor = AtomColor.NONE,
    bg: AtomColor = AtomColor.NONE,

    fn init(character: *const []const u8, fg: AtomColor, bg: AtomColor) Char {
        return Char{
            .data = character,
            .fg = fg,
            .bg = bg,
        };
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

    fn get_fg_color_number(color: AtomColor) []const u8 {
        return switch (color) {
            AtomColor.NONE => "0",
            AtomColor.BLACK => "30",
            AtomColor.RED => "31",
            AtomColor.GREEN => "32",
            AtomColor.YELLOW => "33",
            AtomColor.BLUE => "34",
            AtomColor.PURPLE => "35",
            AtomColor.CYAN => "36",
            AtomColor.WHITE => "37",
        };
    }

    fn get_bg_color_number(color: AtomColor) []const u8 {
        return switch (color) {
            AtomColor.NONE => "0",
            AtomColor.BLACK => "40",
            AtomColor.RED => "41",
            AtomColor.GREEN => "42",
            AtomColor.YELLOW => "43",
            AtomColor.BLUE => "44",
            AtomColor.PURPLE => "45",
            AtomColor.CYAN => "46",
            AtomColor.WHITE => "47",
        };
    }

    fn format_ansi_color(out: *[32]u8, fg: AtomColor, bg: AtomColor) !void {
        const background_code = get_bg_color_number(bg);
        const foreground_code = get_fg_color_number(fg);
        _ = try std.fmt.bufPrint(out, "\x1B[{s};{s}m\x00\x00", .{ background_code, foreground_code });
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

                if ((upper == AtomColor.NONE) and (lower == AtomColor.NONE)) { // NOTHING
                    self.chars[yy][xx] = Char.init(char.NONE, AtomColor.NONE, AtomColor.NONE);
                } else if ((upper != AtomColor.NONE) and (lower == AtomColor.NONE)) { // UPPER ONLY
                    self.chars[yy][xx] = Char.init(char.UPPER, upper, AtomColor.NONE);
                } else if ((upper == AtomColor.NONE) and (lower != AtomColor.NONE)) { // LOWER ONLY
                    self.chars[yy][xx] = Char.init(char.LOWER, lower, AtomColor.NONE);
                } else if (upper == lower) { // UPPER AND LOWER THE SAME
                    self.chars[yy][xx] = Char.init(char.FULL, upper, AtomColor.NONE);
                } else { // UPPER AND LOWER DIFFERENT
                    self.chars[yy][xx] = Char.init(char.UPPER, upper, lower);
                }
            }
        }
    }

    fn print(self: *Screen) !void {
        var screen_buffer: [SCREEN_WIDTH * SCREEN_HEIGHT * 8]u8 = undefined;
        var color_buffer: [32]u8 = undefined;
        try format_ansi_color(&color_buffer, AtomColor.WHITE, AtomColor.NONE);
        //std.debug.print(color.CLEAR.*, .{});
        self.render_sub_pixels();
        var stdout = std.fs.File.stdout().writer(&screen_buffer); // bufferedgit git .writer();
        const writer = &stdout.interface;

        // Clear and home cursor each time (but stay in alt screen)
        try writer.print("\x1B[2J\x1B[1;1H{s}", .{color_buffer});

        try writer.print("┌", .{});
        for (0..SCREEN_WIDTH) |_| {
            try writer.print("─", .{});
        }
        try writer.print("┐\n", .{});

        var previous_fg: AtomColor = AtomColor.NONE;
        var previous_bg: AtomColor = AtomColor.NONE;
        var bg_has_changed: bool = true;
        var fg_has_changed: bool = true;

        for (self.chars, 0..self.chars.len) |row, i| {
            try format_ansi_color(&color_buffer, AtomColor.WHITE, AtomColor.NONE);
            try writer.print("{s}│", .{color_buffer});
            for (row) |c| {
                bg_has_changed = c.bg != previous_bg;
                fg_has_changed = c.fg != previous_fg;
                if (fg_has_changed or bg_has_changed) {
                    try format_ansi_color(&color_buffer, c.fg, c.bg);
                    try writer.print("{s}{s}", .{ color_buffer, c.data.* });
                } else {
                    try writer.print("{s}", .{c.data.*});
                }
                previous_bg = c.bg;
                previous_fg = c.fg;
            }
            try format_ansi_color(&color_buffer, AtomColor.WHITE, AtomColor.NONE);
            try writer.print("{s}│{d}\n", .{ color_buffer, i });
        }
        try writer.print("└", .{});
        for (0..SCREEN_WIDTH) |_| {
            try writer.print("─", .{});
        }
        try writer.print("┘{s}\n", .{ansi.RESET.*});
        try writer.flush();
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

        while (x <= clamped_end) : (x += 1) {
            const vy: usize = @intCast(start.y); // Virtual y
            const atom_depth = curr_depth + (d_depth * @as(f64, @floatFromInt(offset)));
            offset += 1;

            var fill_atom = false;
            if (atom_depth < self.atoms[vy][x].z) { // Smaller depth = closer, overwrite
                fill_atom = true;
            }
            if (fill_atom) {
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

        var average_depth: f64 = 0;
        for (0..vertecies.len) |i| {
            average_depth += vertecies[i].z;
        }
        average_depth /= @floatFromInt(vertecies.len);

        const allocator = std.heap.page_allocator;
        var edges = std.ArrayList(Edge).empty;
        defer edges.deinit(allocator);

        for (1..vertecies.len) |i| {
            //std.debug.print("<-- drawing surface edge -->\n", .{});
            const e = try Edge.init(vertecies[i - 1], vertecies[i], allocator);
            try edges.append(allocator, e);
        }
        //std.debug.print("<-- drawing surface edge -->\n", .{});
        const e = try Edge.init(vertecies[vertecies.len - 1], vertecies[0], allocator);
        try edges.append(allocator, e);

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

        for (first_y..last_y + 1) |y| {
            var intersections = std.array_list.Managed(vec1z).init(allocator);
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
                        try intersections.append(vec1z{ .x = intersection.x, .z = intersection.z });
                    }
                }
            }

            if (intersections.items.len < 2) continue;
            if (intersections.items.len % 2 == 1) {
                try intersections.append(intersections.items[intersections.items.len - 2]);
            }

            std.sort.heap(vec1z, intersections.items, {}, struct {
                pub fn lessThan(_: void, a: vec1z, b: vec1z) bool {
                    return a.x < b.x;
                }
            }.lessThan);

            for (0..intersections.items.len / 2) |i| {
                const n = i * 2;
                const x0 = intersections.items[n];
                const x1 = intersections.items[n + 1];

                self.fill_x(x0.to_vec2z(@intCast(y)), x1, color);
            }
        }

        // free edges
        for (edges.items) |*edge| {
            //self.emplace(edge.atoms.items, colors[i]);
            edge.deinit();
        }
        //self.emplace(vertecies, AtomColor.GREEN);
    }

    fn init_terminal() !void {
        const stdout = std.fs.File.stdout();
        // Enter alternate screen and hide cursor
        _ = try stdout.write("\x1B[?1049h\x1B[?25l");
        // Optional: Initial clear and home
        _ = try stdout.write("\x1B[2J\x1B[1;1H");
    }

    fn deinit_terminal() !void {
        const stdout = std.fs.File.stdout();
        // Exit alternate screen, show cursor, reset colors
        _ = try stdout.write("\x1B[?1049l\x1B[?25h\x1B[0m");
        // Optional: Final clear if needed
        _ = try stdout.write("\x1B[2J\x1B[1;1H");
    }
};

pub const Floor = struct {
    faces: [6]Polygon,
    pos: vec3 = .{ .x = 0, .y = 0, .z = 5.0 }, // Offset from camera for visibility

    pub fn init(side: f64, offset: vec3, allocator: std.mem.Allocator) !Cube {
        const q = quaternion.Quaternion.init(0, 1, 1, 0); // Identity start
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

pub const Cube = struct {
    faces: [6]Polygon,
    pos: vec3 = .{ .x = 0, .y = 0, .z = 5.0 }, // Offset from camera for visibility

    pub fn init(side: f64, offset: vec3, allocator: std.mem.Allocator) !Cube {
        const q = quaternion.Quaternion.init(0, 1, 1, 0); // Identity start
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
        var back_verts = std.ArrayList(vec3).empty;
        try back_verts.ensureTotalCapacity(allocator, 4);
        try back_verts.appendSlice(allocator, &[_]vec3{ verts[0], verts[1], verts[2], verts[3] });

        var front_verts = std.ArrayList(vec3).empty;
        try front_verts.ensureTotalCapacity(allocator, 4);
        try front_verts.appendSlice(allocator, &[_]vec3{ verts[4], verts[5], verts[6], verts[7] });

        var left_verts = std.ArrayList(vec3).empty;
        try left_verts.ensureTotalCapacity(allocator, 4);
        try left_verts.appendSlice(allocator, &[_]vec3{ verts[0], verts[3], verts[7], verts[4] });

        var right_verts = std.ArrayList(vec3).empty;
        try right_verts.ensureTotalCapacity(allocator, 4);
        try right_verts.appendSlice(allocator, &[_]vec3{ verts[1], verts[2], verts[6], verts[5] });

        var bottom_verts = std.ArrayList(vec3).empty;
        try bottom_verts.ensureTotalCapacity(allocator, 4);
        try bottom_verts.appendSlice(allocator, &[_]vec3{ verts[0], verts[1], verts[5], verts[4] });

        var top_verts = std.ArrayList(vec3).empty;
        try top_verts.ensureTotalCapacity(allocator, 4);
        try top_verts.appendSlice(allocator, &[_]vec3{ verts[3], verts[2], verts[6], verts[7] });

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

const World = struct {
    const MAX_PITCH: f64 = std.math.pi / 2.0;
    const MIN_PITCH: f64 = -std.math.pi / 2.0;
    const GRAVITY = 0.1;
    const FRICTION = 0.4;

    translation: vec3 = vec3{},
    pitch: f64 = 0,
    yaw: f64 = 0,
    inertia: vec3 = .{ .x = 0, .y = 0, .z = 0 },

    fn tick(self: *World) void {
        self.translation.y += self.inertia.y;
        if (self.translation.y > 0) self.translation.y = 0;
        self.translation.x += self.inertia.x;
        self.translation.z += self.inertia.z;

        self.inertia.y += GRAVITY;
        if (self.inertia.y > 10 * GRAVITY) self.inertia.y = 10 * GRAVITY;
        if (self.translation.y != 0) return;
        self.inertia.x *= FRICTION;
        if (@abs(self.inertia.x) < 0.01) self.inertia.x = 0;
        self.inertia.z *= FRICTION;
        if (@abs(self.inertia.z) < 0.01) self.inertia.z = 0;
    }

    fn move(self: *World, distance: vec3) void {
        var q = quaternion.Quaternion.init(0, 0, 1, 0);
        const b = q.rotate_point(distance, self.yaw);
        self.inertia.x += b.x;
        self.inertia.y += b.y;
        self.inertia.z += b.z;
    }

    fn look(self: *World, pitch: f64, yaw: f64) void {
        self.yaw += yaw;
        self.pitch += pitch;
        if (self.pitch > MAX_PITCH) {
            self.pitch = MAX_PITCH;
        } else if (self.pitch < MIN_PITCH) {
            self.pitch = MIN_PITCH;
        }
    }
};

const TARGET_FRAME_RATE: i64 = 60;
const TARGET_PERIOD_US: i64 = @truncate(1_000_000 / TARGET_FRAME_RATE);

pub fn main() !void {
    var screen = Screen{};
    try Screen.init_terminal();
    defer Screen.deinit_terminal() catch |err| {
        std.debug.print("Failed to restore terminal: {}\n", .{err});
    };

    var world = World{};

    const allocator = std.heap.page_allocator;

    // Initialize shared state
    var state = inputs.InputState.init();

    // Enable raw mode
    const original_term = try inputs.enableRawMode();
    defer inputs.restoreTerminal(original_term) catch |err| {
        std.debug.print("Failed to restore terminal: {}\n", .{err});
    };

    // Spawn input reading thread
    const thread = try std.Thread.spawn(.{}, inputs.readInput, .{&state});
    defer thread.join();

    std.debug.print("Exiting...\n", .{});

    var surface = std.ArrayList(vec3).empty;
    defer surface.deinit(allocator);
    const surf_size = 2;
    try surface.append(allocator, .{ .x = -surf_size, .y = 0, .z = -surf_size });
    try surface.append(allocator, .{ .x = surf_size, .y = 0, .z = -surf_size });
    try surface.append(allocator, .{ .x = surf_size, .y = 0, .z = surf_size });
    try surface.append(allocator, .{ .x = -surf_size, .y = 0, .z = surf_size });

    var floor = Polygon.init(surface, AtomColor.WHITE, .{ .x = 0, .y = 2, .z = 1 }, quaternion.Quaternion{ .a = 0, .b = 1, .c = 1, .d = 1 });

    var cube = try Cube.init(5, .{ .x = 0, .y = 0, .z = 15 }, allocator);

    var itteration: u64 = 0;
    while (!state.isDone()) {
        const t = std.time.microTimestamp();
        world.tick();
        const Verts = struct { verts: std.ArrayList(vec2z), z: f64, color: AtomColor };
        var vert_order = std.ArrayList(Verts).empty;
        defer vert_order.deinit(allocator);
        {
            const verts = try floor.projection(world.translation, world.pitch, world.yaw, allocator);
            var z: f64 = 0;
            for (verts.items) |*v| {
                z += v.z;
            }
            z /= @floatFromInt(verts.items.len);
            try vert_order.append(allocator, .{ .verts = verts, .z = z, .color = floor.color });
        }

        for (&cube.faces) |*poly| {
            poly.*.transform(60); //30
            const verts = try poly.*.projection(world.translation, world.pitch, world.yaw, allocator);
            var z: f64 = 0;
            for (verts.items) |*v| {
                z += v.z;
            }
            z /= @floatFromInt(verts.items.len);
            if (z > 0) {
                try vert_order.append(allocator, .{ .verts = verts, .z = z, .color = poly.color });
            }
        }

        std.sort.heap(Verts, vert_order.items, {}, struct {
            pub fn lessThan(_: void, a: Verts, b: Verts) bool {
                return a.z < b.z;
            }
        }.lessThan);

        for (vert_order.items) |*v| {
            try screen.draw_surface(v.verts.items, v.color);
        }

        try screen.print();
        screen.clear();
        const t_loop = std.time.microTimestamp() - t;
        std.debug.print("render time µs {}\n", .{t_loop});
        std.debug.print("itteration {}\n", .{itteration});
        if (state.input_len > 0) {
            const input = try state.getInput(allocator);
            defer allocator.free(input);

            var move_left = false;
            var move_right = false;
            var move_forward = false;
            var move_backward = false;
            var look_up = false;
            var look_down = false;
            var look_left = false;
            var look_right = false;
            var jump = false;
            for (input) |c| {
                std.debug.print("Received: {c}\n", .{c});
                switch (c) {
                    'w' => {
                        move_forward = true;
                    },
                    'a' => {
                        move_left = true;
                    },
                    's' => {
                        move_backward = true;
                    },
                    'd' => {
                        move_right = true;
                    },
                    'i' => {
                        look_up = true;
                    },
                    'k' => {
                        look_down = true;
                    },
                    'j' => {
                        look_left = true;
                    },
                    'l' => {
                        look_right = true;
                    },
                    ' ' => {
                        jump = true;
                    },
                    else => {},
                }
            }
            var movement = vec3{};
            if (move_left) movement.x -= 1;
            if (move_right) movement.x += 1;
            if (move_forward) movement.z += 1;
            if (move_backward) movement.z -= 1;
            if (jump and world.translation.y == 0) movement.y += -2;

            var yaw: f64 = 0;
            var pitch: f64 = 0;
            const LOOK_SPEED = std.math.pi / 32.0;
            if (look_right) yaw += LOOK_SPEED;
            if (look_left) yaw -= LOOK_SPEED;
            if (look_up) pitch += LOOK_SPEED;
            if (look_down) pitch -= LOOK_SPEED;
            world.look(pitch, yaw);
            world.move(movement);
        }
        std.debug.print("pos {}, {}, {}\n", .{ world.translation.x, world.translation.y, world.translation.z });
        std.debug.print("inertia {}, {}, {}\n", .{ world.inertia.x, world.inertia.y, world.inertia.z });
        std.debug.print("pitch {}\n", .{world.pitch});
        std.debug.print("yaw {}\n", .{world.yaw});

        const t_sleep_us = TARGET_PERIOD_US - t_loop;
        if (t_sleep_us > 0) {
            const t_sleep_ns: u64 = @as(u64, @intCast(t_sleep_us)) * 1000;
            std.Thread.sleep(t_sleep_ns);
        }
        itteration += 1;
    }
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
