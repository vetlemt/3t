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

const errororo = error{to_big};

const Edge = struct {
    start: vec2z,
    end: vec2z,
    atoms: std.array_list.Managed(vec2z),
    const z_bias = 0.01; // Small offset to make edges closer

    fn deinit(self: *Edge) void {
        self.atoms.deinit();
    }

    fn x_crossing_point(start: vec2z, end: vec2z, c: i64) ?vec2z {
        const cf: f64 = @floatFromInt(c);
        const start_yf: f64 = @floatFromInt(start.y);
        const start_xf: f64 = @floatFromInt(start.x);
        const end_yf: f64 = @floatFromInt(end.y);
        const end_xf: f64 = @floatFromInt(end.x);

        if (start.y == end.y) return null;

        const crosses: bool = ((start.y - c) * (end.y - c)) < 0;
        if (!crosses) return null;

        const slope: f64 = (cf - start_yf) / (end_yf - start_yf);
        const intersects_line: bool = (slope >= 0) and (slope <= 1);

        if (!intersects_line) return null;

        const x_crossing = start_xf + (slope * (end_xf - start_xf));
        const z_crossing = start.z + (slope * (end.z - start.z));
        return .{ .x = @intFromFloat(x_crossing), .y = c, .z = z_crossing };
    }

    fn y_crossing_point(start: vec2z, end: vec2z, c: i64) ?vec2z {
        const cf: f64 = @floatFromInt(c);
        const start_xf: f64 = @floatFromInt(start.x);
        const start_yf: f64 = @floatFromInt(start.y);
        const end_xf: f64 = @floatFromInt(end.x);
        const end_yf: f64 = @floatFromInt(end.y);

        if (start.x == end.x) return null;

        // Strict straddle test
        const crosses: bool = ((start.x - c) * (end.x - c)) < 0;
        if (!crosses) return null;

        // Compute interpolation factor along x
        const t: f64 = (cf - start_xf) / (end_xf - start_xf);
        if (t < 0 or t > 1) return null;

        // Interpolate y and z
        const y_crossing_f: f64 = start_yf + t * (end_yf - start_yf);
        const z_crossing: f64 = start.z + t * (end.z - start.z);

        // x is exactly c (vertical line), convert y to integer
        const y_crossing: i64 = @intFromFloat(y_crossing_f);

        return .{ .x = c, .y = y_crossing, .z = z_crossing };
    }

    fn clip_point_to_bound(start: vec2z, point: *vec2z, axis: u8, bound_value: i64, crossing_fn: fn (vec2z, vec2z, i64) ?vec2z) void {
        const coord = if (axis == 0) point.*.x else point.*.y;

        if (coord < 0 or coord > bound_value) {
            if (crossing_fn(start, point.*, bound_value)) |v| {
                point.* = v;
            }
        }
    }

    fn clip_segment_to_bounds(start: *vec2z, end: *vec2z, x_max: i64, y_max: i64) ?void {
        //if ((start.x < 0 and end.x < 0) or (start.x > x_max and end.x > x_max) or (start.y < 0 and end.y < 0) or (start.y > y_max and end.y > y_max)) {
        //    return null;
        //}
        //
        // Clip start point
        clip_point_to_bound(end.*, start, 0, 0, y_crossing_point);
        clip_point_to_bound(end.*, start, 0, x_max, y_crossing_point);
        clip_point_to_bound(end.*, start, 1, 0, x_crossing_point);
        clip_point_to_bound(end.*, start, 1, y_max, x_crossing_point);

        // Clip end point
        clip_point_to_bound(start.*, end, 0, 0, y_crossing_point);
        clip_point_to_bound(start.*, end, 0, x_max, y_crossing_point);
        clip_point_to_bound(start.*, end, 1, 0, x_crossing_point);
        clip_point_to_bound(start.*, end, 1, y_max, x_crossing_point);
    }

    fn init(start: vec2z, end: vec2z, allocator: std.mem.Allocator) !?Edge {
        var edge: Edge = undefined;
        edge.start = start;
        edge.end = end;
        edge.atoms = std.array_list.Managed(vec2z).init(allocator);
        //if (clip_segment_to_bounds(&edge.start, &edge.end, SCREEN_WIDTH, SCREEN_HEIGHT * 2) == null) return null;

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
            var px = if (steep) y else x;
            var py = if (steep) x else y;
            if (px >= SCREEN_WIDTH) px = SCREEN_WIDTH;
            if (px < 0) px = -1;

            if (py >= SCREEN_HEIGHT * 2) py = SCREEN_HEIGHT * 2;
            if (py < 0) py = -1;

            const pz = (depth_start + (depth_step * n)) + z_bias;

            if (px >= 0 and px < SCREEN_WIDTH and py >= 0 and py < SCREEN_HEIGHT * 2) {
                try edge.atoms.append(.{ .x = px, .y = py, .z = pz });
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

        if (self.start.y == y) return .{ .x = self.start.x, .z = self.start.z };
        if (self.end.y == y) return .{ .x = self.end.x, .z = self.end.z };

        if (x_crossing_point(self.start, self.end, y)) |*crossing| {
            return .{ .x = crossing.x, .z = crossing.z };
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

    screen_buffer: [SCREEN_WIDTH * SCREEN_HEIGHT * 8]u8,
    color_buffer: [32]u8,
    stdout: std.fs.File.Writer,
    writer: *std.Io.Writer,

    fn init() !Screen {
        var screen: Screen = undefined;

        try format_ansi_color(&screen.color_buffer, AtomColor.WHITE, AtomColor.NONE);
        screen.stdout = std.fs.File.stdout().writer(&screen.screen_buffer); // bufferedgit git .writer();
        screen.writer = &screen.stdout.interface;

        try screen.init_terminal();
        return screen;
    }

    fn deinit(self: *Screen) !void {
        try self.deinit_terminal();
    }

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
        try format_ansi_color(&self.color_buffer, AtomColor.WHITE, AtomColor.NONE);
        self.render_sub_pixels();

        // Clear and home cursor each time (but stay in alt screen)
        try self.writer.print("\x1B[2J\x1B[1;1H{s}", .{self.color_buffer});

        _ = try self.writer.write("┌");
        for (0..SCREEN_WIDTH) |_| {
            _ = try self.writer.write("─");
        }
        _ = try self.writer.write("┐\n");

        var previous_fg: AtomColor = AtomColor.NONE;
        var previous_bg: AtomColor = AtomColor.NONE;
        var bg_has_changed: bool = true;
        var fg_has_changed: bool = true;

        for (self.chars, 0..self.chars.len) |row, i| {
            try format_ansi_color(&self.color_buffer, AtomColor.WHITE, AtomColor.NONE);
            try self.writer.print("{s}│", .{self.color_buffer});
            for (row) |c| {
                bg_has_changed = c.bg != previous_bg;
                fg_has_changed = c.fg != previous_fg;
                if (fg_has_changed or bg_has_changed) {
                    try format_ansi_color(&self.color_buffer, c.fg, c.bg);
                    try self.writer.print("{s}{s}", .{ self.color_buffer, c.data.* });
                } else {
                    try self.writer.print("{s}", .{c.data.*});
                }
                previous_bg = c.bg;
                previous_fg = c.fg;
            }
            try format_ansi_color(&self.color_buffer, AtomColor.WHITE, AtomColor.NONE);
            try self.writer.print("{s}│{d}\n", .{ self.color_buffer, i });
        }
        _ = try self.writer.write("└");
        for (0..SCREEN_WIDTH) |_| {
            _ = try self.writer.write("─");
        }
        try self.writer.print("┘{s}\n", .{ansi.RESET.*});
        try self.writer.flush();
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

            const atom: *Atom = &self.atoms[vy][x];
            const fill_atom = (atom_depth < atom.z and atom_depth > 0);
            if (fill_atom) {
                atom.color = color;
                atom.z = atom_depth;
            }
        }
    }

    fn emplace(self: *Screen, items: []vec2z, fill: AtomColor) void {
        for (items) |*item| {
            if ((item.x < SCREEN_WIDTH) and (item.x >= 0) and (item.y < SCREEN_HEIGHT * 2) and (item.y >= 0)) {
                const xx: usize = @intCast(item.x);
                const yy: usize = @intCast(item.y);
                if (item.z <= self.atoms[yy][xx].z and item.z > 0) {
                    self.atoms[yy][xx] = .{ .color = fill, .z = item.z };
                }
            }
        }
    }

    fn is_within_screen(vert: *vec2z) bool {
        return ((vert.x >= 0 and vert.x < SCREEN_WIDTH) and (vert.y >= 0 and vert.y < SCREEN_HEIGHT * 2));
    }

    fn draw_surface(self: *Screen, vertecies: []vec2z, color: AtomColor) !void {
        //std.debug.print("<-- drawing surface -->\n", .{});

        var part_of_surface_is_not_behind_camera: bool = false;
        for (vertecies) |*vert| {
            part_of_surface_is_not_behind_camera |= (vert.z > 0.000);
        }
        if (!part_of_surface_is_not_behind_camera) return;

        var part_of_surface_is_on_screen: bool = false;
        for (vertecies) |*vert| {
            part_of_surface_is_on_screen |= is_within_screen(vert);
        }
        //if (!part_of_surface_is_on_screen) return;

        var average_depth: f64 = 0;
        for (0..vertecies.len) |i| {
            average_depth += vertecies[i].z;
        }
        average_depth /= @floatFromInt(vertecies.len);

        const allocator = std.heap.page_allocator;
        var edges = std.ArrayList(Edge).empty;
        defer edges.deinit(allocator);

        for (1..vertecies.len) |i| {
            const e = try Edge.init(vertecies[i - 1], vertecies[i], allocator);
            if (e != null) try edges.append(allocator, e.?);
        }
        const e = try Edge.init(vertecies[vertecies.len - 1], vertecies[0], allocator);
        if (e != null) try edges.append(allocator, e.?);

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
            self.emplace(edge.atoms.items, AtomColor.BLACK);
            edge.deinit();
        }
        //self.emplace(vertecies, AtomColor.GREEN);
    }

    fn draw_lines(self: *Screen, vertecies: []vec2z, color: AtomColor) !void {
        var part_of_surface_is_not_behind_camera: bool = false;
        for (vertecies) |*vert| {
            part_of_surface_is_not_behind_camera |= (vert.z > 0.000);
        }
        if (!part_of_surface_is_not_behind_camera) return;

        var part_of_surface_is_on_screen: bool = false;
        for (vertecies) |*vert| {
            part_of_surface_is_on_screen |= is_within_screen(vert);
        }
        if (!part_of_surface_is_on_screen) return;

        var average_depth: f64 = 0;
        for (0..vertecies.len) |i| {
            average_depth += vertecies[i].z;
        }
        average_depth /= @floatFromInt(vertecies.len);

        const allocator = std.heap.page_allocator;
        var edges = std.ArrayList(Edge).empty;

        for (1..vertecies.len) |i| {
            const e = try Edge.init(vertecies[i - 1], vertecies[i], allocator);
            if (e != null) try edges.append(allocator, e.?);
        }
        const e = try Edge.init(vertecies[vertecies.len - 1], vertecies[0], allocator);
        if (e != null) try edges.append(allocator, e.?);

        // free edges
        for (edges.items) |*edge| {
            self.emplace(edge.atoms.items, color);
            edge.deinit();
        }
        //self.emplace(vertecies, AtomColor.GREEN);
    }

    fn init_terminal(self: *Screen) !void {
        _ = try self.writer.write("\x1B[?1049h\x1B[?25l");
        _ = try self.writer.write("\x1B[2J\x1B[1;1H");
    }

    fn deinit_terminal(self: *Screen) !void {
        _ = try self.writer.write("\x1B[?1049l\x1B[?25h\x1B[0m");
        _ = try self.writer.write("\x1B[2J\x1B[1;1H");
    }
};

pub const Floor = struct {
    faces: std.ArrayList(Polygon),
    tile: std.ArrayList(vec3),

    pub fn init(tile_size: f64, width: u32, height: u32, offset: vec3, allocator: std.mem.Allocator) !Floor {
        const q = quaternion.Quaternion.init(1, 0, 0, 0); // Identity start

        // Initialize each face as a Polygon
        const h = tile_size / 2.0;
        var floor: Floor = undefined;
        floor.tile = std.ArrayList(vec3).empty;
        try floor.tile.append(allocator, .{ .x = -h, .y = 0, .z = -h });
        try floor.tile.append(allocator, .{ .x = h, .y = 0, .z = -h });
        try floor.tile.append(allocator, .{ .x = h, .y = 0, .z = h });
        try floor.tile.append(allocator, .{ .x = -h, .y = 0, .z = h });

        floor.faces = std.ArrayList(Polygon).empty;
        var oz: f64 = 0.0;
        var ox: f64 = 0.0;
        for (0..height) |_| {
            oz += tile_size;
            ox = 0;
            for (0..width) |_| {
                ox += tile_size;
                try floor.faces.append(allocator, Polygon.init(floor.tile, AtomColor.WHITE, .{ .x = offset.x + ox, .y = offset.y, .z = offset.z + oz }, q));
            }
        }
        return floor;
    }
};

pub const Cube = struct {
    faces: [6]Polygon,

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
    const GRAVITY = 0.015;
    const FRICTION = 0.2;
    const CAMERA_RESISTANCE = 0.5;

    translation: vec3 = vec3{},
    pitch: f64 = 0,
    yaw: f64 = 0,
    inertia: vec3 = .{ .x = 0, .y = 0, .z = 0 },
    pitch_inertia: f64 = 0,
    yaw_inertia: f64 = 0,

    fn standing(self: *World) bool {
        return self.translation.y == 0;
    }

    fn tick(self: *World) void {
        self.pitch += self.pitch_inertia;
        self.yaw += self.yaw_inertia;
        if (self.pitch > MAX_PITCH) {
            self.pitch = MAX_PITCH;
        } else if (self.pitch < MIN_PITCH) {
            self.pitch = MIN_PITCH;
        }

        self.translation.y += self.inertia.y;
        if (self.translation.y > 0) self.translation.y = 0;
        self.translation.x += self.inertia.x;
        self.translation.z += self.inertia.z;

        self.yaw_inertia *= CAMERA_RESISTANCE;
        if (@abs(self.yaw_inertia) < 0.01) self.yaw_inertia = 0;

        self.pitch_inertia *= CAMERA_RESISTANCE;
        if (@abs(self.pitch_inertia) < 0.01) self.pitch_inertia = 0;

        self.inertia.y += GRAVITY;
        if (self.inertia.y > 8 * GRAVITY) self.inertia.y = 8 * GRAVITY;

        if (self.standing()) {
            self.inertia.x *= FRICTION;
            if (@abs(self.inertia.x) < 0.01) self.inertia.x = 0;
            self.inertia.z *= FRICTION;
            if (@abs(self.inertia.z) < 0.01) self.inertia.z = 0;
        } else {
            self.inertia.x *= FRICTION;
            if (@abs(self.inertia.x) < 0.01) self.inertia.x = 0;
            self.inertia.z *= FRICTION;
            if (@abs(self.inertia.z) < 0.01) self.inertia.z = 0;
        }
    }

    fn move(self: *World, distance: vec3) void {
        var q = quaternion.Quaternion.init(0, 0, 1, 0);
        const b = q.rotate_point(distance, self.yaw);
        self.inertia.x += b.x;
        self.inertia.y += b.y;
        self.inertia.z += b.z;
    }

    fn look(self: *World, pitch: f64, yaw: f64) void {
        self.yaw_inertia += yaw;
        self.pitch_inertia += pitch;
    }
};

const TARGET_FRAME_RATE: i64 = 60;
const TARGET_PERIOD_US: i64 = @truncate(1_000_000 / TARGET_FRAME_RATE);

pub fn main() !void {
    var screen = try Screen.init();
    defer screen.deinit() catch |err| {
        std.debug.print("Failed to restore terminal: {}\n", .{err});
    };

    var world = World{};

    const allocator = std.heap.page_allocator;
    // Initialize shared state
    var state = inputs.InputState.init();

    // Spawn input reading thread
    const kbd_thread = try std.Thread.spawn(.{}, inputs.read_keyboard_input_thread, .{&state});
    defer kbd_thread.join();
    const mouse_thread = try std.Thread.spawn(.{}, inputs.read_mouse_input_thread, .{&state});
    defer mouse_thread.join();

    std.debug.print("Exiting...\n", .{});
    const floor = try Floor.init(2, 1, 1, .{ .x = -5, .y = 1, .z = 0 }, allocator);
    var cube = try Cube.init(0.7, .{ .x = 0, .y = 0, .z = 3 }, allocator);

    var itteration: u64 = 0;
    while (!state.isDone()) {
        const t = std.time.microTimestamp();
        world.tick();
        const Verts = struct { verts: std.ArrayList(vec2z), z: f64, color: AtomColor };
        var vert_order = std.ArrayList(Verts).empty;
        defer {
            for (vert_order.items) |*verts| {
                verts.verts.deinit(allocator);
            }
            vert_order.deinit(allocator);
        }
        for (floor.faces.items) |*poly| {
            const verts = try poly.*.projection(world.translation, world.pitch, world.yaw, allocator);
            var z: f64 = 0;
            for (verts.items) |*v| {
                z += v.z;
            }
            z /= @floatFromInt(verts.items.len);
            try vert_order.append(allocator, .{ .verts = verts, .z = z, .color = poly.color });
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
        //for (vert_order.items) |*v| {
        //    try screen.draw_lines(v.verts.items, AtomColor.WHITE);
        //}
        const t_draw = std.time.microTimestamp() - t;

        try screen.print();
        screen.clear();
        const t_loop = std.time.microTimestamp() - t;
        std.debug.print("draw time µs {}\n", .{t_draw});
        std.debug.print("render time µs {}\n", .{t_loop});

        {
            const keys = state.get_keys();

            const move_left = keys.a;
            const move_right = keys.d;
            const move_forward = keys.w;
            const move_backward = keys.s;

            const jump = keys.space;

            const MOVE_FORCE = 0.1;
            const JUMP_FORCE = 0.3;
            var movement = vec3{};

            if (move_left) movement.x -= MOVE_FORCE;
            if (move_right) movement.x += MOVE_FORCE;
            if (move_forward) movement.z += MOVE_FORCE;
            if (move_backward) movement.z -= MOVE_FORCE;

            if ((move_forward ^ move_backward) & (move_left ^ move_right)) {
                const r2 = 1.0 / std.math.sqrt(2);
                movement.x *= r2;
                movement.z *= r2;
            }

            if (jump and world.translation.y == 0) movement.y -= JUMP_FORCE;

            const mouse_movement = state.get_mouse_movement();
            const LOOK_SPEED = 0.001;
            const yaw: f64 = LOOK_SPEED * mouse_movement.x;
            const pitch: f64 = LOOK_SPEED * -mouse_movement.y;
            world.look(pitch, yaw);
            world.move(movement);
        }

        std.debug.print("pos {}, {}, {}\n", .{ world.translation.x, world.translation.y, world.translation.z });
        std.debug.print("inertia {}, {}, {}\n", .{ world.inertia.x, world.inertia.y, world.inertia.z });
        std.debug.print("pitch {}\n", .{world.pitch});
        std.debug.print("yaw {}\n", .{world.yaw});
        std.debug.print("itteration {}\n", .{itteration});
        const t_frame = std.time.microTimestamp() - t;
        std.debug.print("itteration time {}\n", .{t_frame});

        //for (&cube.faces) |*poly| {
        //    const verts = try poly.*.projection(world.translation, world.pitch, world.yaw, allocator);
        //    for (verts.items) |*vert| {
        //        std.debug.print("({},{},{})\n", .{ vert.x, vert.y, vert.z });
        //    }
        //}
        if (t_loop > 20_000) return;

        const t_sleep_us = TARGET_PERIOD_US - t_frame;
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
