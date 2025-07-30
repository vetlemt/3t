const std = @import("std");
const cos = std.math.cos;
const sin = std.math.sin;

const vectors = @import("vectors");
const vec3 = vectors.vec3;

pub const Quaternion = struct {
    a: f64 = 0,
    b: f64 = 1,
    c: f64 = 1,
    d: f64 = 1,

    pub fn init(a: f64, b: f64, c: f64, d: f64) Quaternion {
        return .{ .a = a, .b = b, .c = c, .d = d };
    }

    pub fn conjugate(self: *Quaternion) Quaternion {
        return Quaternion.init(self.a, -self.b, -self.c, -self.d);
    }

    pub fn len(self: *Quaternion) f64 {
        return std.math.sqrt(((self.a * self.a) + (self.b * self.b) + (self.c * self.c) + (self.d * self.d)));
    }

    pub fn unitize(self: *Quaternion) Quaternion {
        const l = self.len();
        return scale(self.*, (1.0 / l));
    }

    pub fn inverse(self: *Quaternion) Quaternion {
        const qi = self.conjugate();
        const l = self.len();
        const l2 = l * l;
        return scale(qi, (1.0 / l2));
    }
    pub fn rotatation(self: *Quaternion, theta: f64) Quaternion {
        const s: f64 = sin(theta / 2.0);
        const c: f64 = cos(theta / 2.0);
        const u = self.unitize();
        return add(scale(u, s), c);
    }

    pub fn rotate_point(self: *Quaternion, a: vec3, theta: f64) vec3 {
        const p = from_vec3(a);
        var q = self.rotatation(theta);
        const qi = q.inverse();
        const lp = product(product(q, p), qi);
        return to_vec3(lp);
    }
};

pub fn add(q: Quaternion, offset: f64) Quaternion {
    var qq = q;
    qq.a += offset;
    return qq;
}

pub fn sum(q: Quaternion, p: Quaternion) Quaternion {
    return Quaternion.init(q.a + p.a, q.b + p.b, q.c + p.c, q.d + p.d);
}

pub fn product(q: Quaternion, p: Quaternion) Quaternion {
    return Quaternion.init((q.a * p.a) - (q.b * p.b) - (q.c * p.c) - (q.d * p.d), (q.a * p.b) + (q.b * p.a) + (q.c * p.d) - (q.d * p.c), (q.a * p.c) - (q.b * p.d) + (q.c * p.a) + (q.d * p.b), (q.a * p.d) + (q.b * p.c) - (q.c * p.b) - (q.d * p.a));
}

pub fn scale(q: Quaternion, alpha: f64) Quaternion {
    return Quaternion.init(q.a * alpha, q.b * alpha, q.c * alpha, q.d * alpha);
}

fn to_vec3(q: Quaternion) vec3 {
    return .{ .x = q.b, .y = q.c, .z = q.d };
}

fn from_vec3(v: vec3) Quaternion {
    return .{ .a = 0.0, .b = v.x, .c = v.y, .d = v.z };
}
