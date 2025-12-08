const std = @import("std");

const ansi = @import("ansi");
const projecting = @import("projection");
const quaternions = @import("quaternions");
const Quaternion = quaternions.Quaternion;
const vectors = @import("vectors");
const vec2i = vectors.vec2i;
const vec2 = vectors.vec2;
const vec3 = vectors.vec3;
const vec2z = vectors.vec2z;

pub const AtomColor = enum {
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

pub const Polygon = struct {
    color: AtomColor,
    vertices: std.ArrayList(vec3),
    offset: vec3,
    center: vec3,
    q: Quaternion,

    pub fn init(vertices: std.ArrayList(vec3), color: AtomColor, offset: vec3, q: Quaternion) Polygon {
        var polygon: Polygon = undefined;
        polygon.vertices = vertices;
        polygon.color = color;
        polygon.offset = offset;
        polygon.q = q;
        polygon.center = .{ .x = 0, .y = 0, .z = 0 };
        const n_vert = vertices.items.len;
        for (vertices.items) |*v| {
            polygon.center.x += v.x;
            polygon.center.y += v.y;
            polygon.center.z += v.z;
        }
        polygon.center.x /= @floatFromInt(n_vert);
        polygon.center.y /= @floatFromInt(n_vert);
        polygon.center.z /= @floatFromInt(n_vert);
        return polygon;
    }

    fn clip_to_plane(input: []const vec3, a: f64, b: f64, c: f64, d: f64, allocator: std.mem.Allocator) !std.array_list.Managed(vec3) {
        var output = std.array_list.Managed(vec3).init(allocator);
        const n = input.len;
        if (n == 0) return output;

        var prev = input[n - 1];
        var prev_dist = a * prev.x + b * prev.y + c * prev.z + d;
        var prev_inside = prev_dist >= 0.0;

        const EPS: f64 = 1e-6;

        for (input) |curr| {
            const curr_dist = a * curr.x + b * curr.y + c * curr.z + d;
            const curr_inside = curr_dist >= 0.0;

            if (curr_inside) {
                if (!prev_inside) {
                    // Entering
                    const denom = (a * (curr.x - prev.x)) + (b * (curr.y - prev.y)) + (c * (curr.z - prev.z));
                    if (@abs(denom) < EPS) continue;
                    const t = -prev_dist / denom;
                    if (t >= -EPS and t <= 1.0 + EPS) {
                        const clamped_t = std.math.clamp(t, 0.0, 1.0);
                        const intersect = vec3{
                            .x = prev.x + clamped_t * (curr.x - prev.x),
                            .y = prev.y + clamped_t * (curr.y - prev.y),
                            .z = prev.z + clamped_t * (curr.z - prev.z),
                        };
                        try output.append(intersect);
                    }
                }
                try output.append(curr);
            } else if (prev_inside) {
                // Exiting
                const denom = (a * (curr.x - prev.x)) + (b * (curr.y - prev.y)) + (c * (curr.z - prev.z));
                if (@abs(denom) < EPS) continue;
                const t = -prev_dist / denom;
                if (t >= -EPS and t <= 1.0 + EPS) {
                    const clamped_t = std.math.clamp(t, 0.0, 1.0);
                    const intersect = vec3{
                        .x = prev.x + clamped_t * (curr.x - prev.x),
                        .y = prev.y + clamped_t * (curr.y - prev.y),
                        .z = prev.z + clamped_t * (curr.z - prev.z),
                    };
                    try output.append(intersect);
                }
            }

            prev = curr;
            prev_dist = curr_dist;
            prev_inside = curr_inside;
        }

        // Post-process: Remove nearly duplicate consecutive points
        var cleaned = std.array_list.Managed(vec3).init(allocator);
        for (output.items, 0..) |pt, i| {
            if (i == 0) {
                try cleaned.append(pt);
                continue;
            }
            const last = cleaned.items[cleaned.items.len - 1];
            if (@abs(pt.x - last.x) > EPS or @abs(pt.y - last.y) > EPS or @abs(pt.z - last.z) > EPS) {
                try cleaned.append(pt);
            }
        }

        output.deinit();
        return cleaned;
    }

    pub fn projection(self: *Polygon, translation: vec3, pitch: f64, yaw: f64, allocator: std.mem.Allocator) !std.ArrayList(vec2z) {
        var view_space = std.ArrayList(vec3).empty;
        var projected = std.ArrayList(vec2z).empty;

        const fov = 2.0 * std.math.pi / 5.0; //* 72 deg */
        const ez = 64.0 / std.math.tan(fov / 2.0);
        const e = vec3{ .x = 64, .y = 32, .z = ez };
        const t = vec3{ .x = pitch, .y = yaw, .z = 0 };

        for (self.vertices.items) |v| {
            const a = vec3{ .x = v.x + self.offset.x, .y = v.y + self.offset.y, .z = v.z + self.offset.z };
            const p = projecting.view_space_projection(a, t, translation);
            // std.debug.print("vs ({},{},{})\n", .{ p.x, p.y, p.z });
            try view_space.append(allocator, p);
        }

        const MIN_Z = 0.01;
        const MIN_BX = 0;
        const MAX_BX = 129;
        const MIN_BY = 0;
        const MAX_BY = 65;

        const left_slope = (MIN_BX - e.x) / e.z;
        const right_slope = (MAX_BX - e.x) / e.z;
        const bottom_slope = (MIN_BY - e.y) / e.z;
        const top_slope = (MAX_BY - e.y) / e.z;

        var clipped = try clip_to_plane(view_space.items, 0, 0, 1, -MIN_Z, allocator);
        var temp = try clip_to_plane(clipped.items, 1, 0, -left_slope, 0, allocator); // Left
        clipped.deinit();
        clipped = temp;
        temp = try clip_to_plane(clipped.items, -1, 0, right_slope, 0, allocator); // Right
        clipped.deinit();
        clipped = temp;
        temp = try clip_to_plane(clipped.items, 0, 1, -bottom_slope, 0, allocator); // Bottom
        clipped.deinit();
        clipped = temp;
        temp = try clip_to_plane(clipped.items, 0, -1, top_slope, 0, allocator); // Top
        clipped.deinit();
        clipped = temp;

        view_space.deinit(allocator);
        for (clipped.items) |v| {
            if (projecting.project_point(v, e)) |p| {
                try projected.append(allocator, .{
                    .x = @intFromFloat(p.x),
                    .y = @intFromFloat(p.y),
                    .z = p.z,
                });
            }
        }
        clipped.deinit();
        return projected;
    }

    pub fn transform(self: *Polygon, time: f64) void {
        const w: f64 = time * std.math.pi / 5000.0;
        for (self.vertices.items) |*v| {
            v.* = self.q.rotate_point(v.*, w);
        }
    }
};
