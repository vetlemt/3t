const std = @import("std");
const cos = std.math.cos;
const sin = std.math.sin;

const vectors = @import("vectors");
const vec2 = vectors.vec2;
const vec3 = vectors.vec3;

pub fn view_space_projection(a: vec3, t: vec3, cc: vec3) vec3 {
    const c: vec3 = .{ .x = cos(t.x), .y = cos(t.y), .z = cos(t.z) }; //not to be confused with the position of the camera (cc)
    const s: vec3 = .{ .x = sin(t.x), .y = sin(t.y), .z = sin(t.z) };

    const x = a.x - cc.x;
    const y = a.y - cc.y;
    const z = a.z - cc.z;

    const dx = c.y * ((s.z * y) + (c.z * x)) - (s.y * z);
    const dy = s.x * ((c.y * z) + s.y * ((s.z * y) + (c.z * x))) + c.x * ((c.z * y) - (s.z * x));
    const dz = c.x * ((c.y * z) + s.y * ((s.z * y) + (c.z * x))) - s.x * ((c.z * y) - (s.z * x));

    return .{ .x = dx, .y = dy, .z = dz };
}

pub fn project_point(d: vec3, e: vec3) ?vec3 {
    const MIN_Z = 0.01;
    if (d.z < MIN_Z) return null;
    const scale: f64 = e.z / d.z;
    const bx = scale * d.x + e.x;
    const by = scale * d.y + e.y;

    return .{ .x = bx, .y = by, .z = d.z };
}
