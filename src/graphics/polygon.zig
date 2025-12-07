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

    pub fn projection(self: *Polygon, translation: vec3, pitch: f64, yaw: f64, allocator: std.mem.Allocator) !std.ArrayList(vec2z) {
        var projected = std.ArrayList(vec2z).empty;

        const fov = 2.0 * std.math.pi / 5.0; //* 72 deg */
        const ez = 64.0 / std.math.tan(fov / 2.0);
        const e = vec3{ .x = 64, .y = 32, .z = ez };
        const t = vec3{ .x = pitch, .y = yaw, .z = 0 };
        for (self.vertices.items) |v| {
            const a = vec3{ .x = v.x + self.offset.x, .y = v.y + self.offset.y, .z = v.z + self.offset.z };
            const p = projecting.project_point(a, e, t, translation);
            try projected.append(allocator, .{
                .x = @intFromFloat(p.x),
                .y = @intFromFloat(p.y),
                .z = p.z,
            });
        }
        return projected;
    }

    pub fn transform(self: *Polygon, time: f64) void {
        const w: f64 = time * std.math.pi / 5000.0;
        for (self.vertices.items) |*v| {
            v.* = self.q.rotate_point(v.*, w);
        }
    }
};
