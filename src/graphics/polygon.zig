const std = @import("std");

const colors = @import("colors");
const projecting = @import("projection");
const quaternions = @import("quaternions");
const Quaternion = quaternions.Quaternion;
const vectors = @import("vectors");
const vec2i = vectors.vec2i;
const vec2 = vectors.vec2;
const vec3 = vectors.vec3;

pub const Line = struct {
    start: vec3,
    end: vec3,
    center: vec3,
    color: colors.Type,
};

pub const Polygon = struct {
    color: colors.Type,
    vertices: std.ArrayList(vec3),
    offset: vec3,
    center: vec3,
    q: Quaternion,

    pub fn init(vertices: std.ArrayList(vec3), color: colors.Type, offset: vec3, q: Quaternion) Polygon {
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

    pub fn projection(self: *Polygon, allocator: std.mem.Allocator) !std.ArrayList(vec2i) {
        var projected = std.ArrayList(vec2i).init(allocator);

        const fov = 2.0 * std.math.pi / 5.0; //* 72 deg */ /* PI/2.0; // 90deg */
        const ez = std.math.tan(1.0 / (fov / 2.0));
        const e = vec3{ .x = 0, .y = 0, .z = ez };
        const t = vec3{ .x = 0, .y = 0, .z = 0 };
        for (self.vertices.items) |v| {
            const a = vec3{ .x = v.x + self.offset.x, .y = v.y + self.offset.y, .z = v.z + self.offset.z };
            var p = projecting.project_point(a, e, t);
            try projected.append(p.to_int());
        }
        return projected;
    }

    pub fn transform(self: *Polygon, time: f64) void {
        const w: f64 = time * std.math.pi / 5000.0;
        for (self.vertices.items) |*v| {
            const r = self.q.rotate_point(v.*, w);
            v.x = r.x + self.offset.x;
            v.y = r.y + self.offset.y;
            v.z = r.z + self.offset.z;
        }
    }
};
