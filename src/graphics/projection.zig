const std = @import("std");
const cos = std.math.cos;
const sin = std.math.sin;

const vectors = @import("vectors");
const vec2 = vectors.vec2;
const vec3 = vectors.vec3;

pub fn project_point(a: vec3, e: vec3, t: vec3) vec3 {
    const c: vec3 = .{ .x = cos(t.x), .y = cos(t.y), .z = cos(t.z) }; //not to be confused with the position of the camera (cc)
    const s: vec3 = .{ .x = sin(t.x), .y = sin(t.y), .z = sin(t.z) };

    const cc = vec3{ .x = 0, .y = 0, .z = 0 }; // camera position

    const x = a.x - cc.x;
    const y = a.y - cc.y;
    const z = a.z - cc.z;

    const dx = c.y * ((s.z * y) + (c.z * x)) - (s.y * z);
    const dy = s.x * ((c.y * z) + s.y * ((s.z * y) + (c.z * x))) + c.x * ((c.z * y) - (s.z * x));
    const dz = c.x * ((c.y * z) + s.y * ((s.z * y) + (c.z * x))) - s.x * ((c.z * y) - (s.z * x));

    const bx = (e.z / dz) * dx + e.x;
    const by = (e.z / dz) * dy + e.y;

    return .{ .x = bx, .y = by, .z = dz };
}
