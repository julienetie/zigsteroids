const std = @import("std");
const math = std.math;
const rand = std.rand;

const rl = @import("raylib");
const rlm = @import("raylib_math");
const Vector2 = rl.Vector2;

const THICKNESS = 2.5;
const SCALE = 38.0;
const SIZE = Vector2.init(640 * 2, 480 * 2);

const Ship = struct {
    pos: Vector2,
    vel: Vector2,
    rot: f32,
    deathTime: f32 = 0.0,

    fn isDead(self: @This()) bool {
        return self.deathTime != 0.0;
    }
};

const Asteroid = struct {
    pos: Vector2,
    vel: Vector2,
    size: AsteroidSize,
    seed: u64,
    remove: bool = false,
};

const AlienSize = enum {
    BIG,
    SMALL,

    fn collisionSize(self: @This()) f32 {
        return switch (self) {
            .BIG => SCALE * 0.8,
            .SMALL => SCALE * 0.5,
        };
    }

    fn dirChangeTime(self: @This()) f32 {
        return switch (self) {
            .BIG => 0.85,
            .SMALL => 0.35,
        };
    }

    fn shotTime(self: @This()) f32 {
        return switch (self) {
            .BIG => 1.25,
            .SMALL => 0.75,
        };
    }

    fn speed(self: @This()) f32 {
        return switch (self) {
            .BIG => 3,
            .SMALL => 6,
        };
    }
};

const Alien = struct {
    pos: Vector2,
    dir: Vector2,
    size: AlienSize,
    remove: bool = false,
    lastShot: f32 = 0,
    lastDir: f32 = 0,
};

const ParticleType = enum {
    LINE,
    DOT,
};

const Particle = struct {
    pos: Vector2,
    vel: Vector2,
    ttl: f32,

    values: union(ParticleType) {
        LINE: struct {
            rot: f32,
            length: f32,
        },
        DOT: struct {
            radius: f32,
        },
    },
};

const Projectile = struct {
    pos: Vector2,
    vel: Vector2,
    ttl: f32,
    spawn: f32,
    remove: bool = false,
};

const State = struct {
    now: f32 = 0,
    delta: f32 = 0,
    stageStart: f32 = 0,
    ship: Ship,
    asteroid: std.ArrayList(Asteroid),
    asteroid_queue: std.ArrayList(Asteroid),
    particles: std.ArrayList(Particle),
    projectiles: std.ArrayList(Projectile),
    aliens: std.ArrayList(Alien),
    rand: rand.Random,
    lives: usize = 0,
    lastScore: usize = 0,
    score: usize = 0,
    reset: bool = false,
    lastBloop: usize = 0,
    bloop: usize = 0,
    frame: usize = 0,
};

var state: State = undefined;

const Sound = struct {
    bloopLo: rl.Sound,
    bloopHi: rl.Sound,
    shoot: rl.Sound,
    thrust: rl.Sound,
    asteroid: rl.Sound,
    explode: rl.Sound,
};

var sound: Sound = undefined;

fn drawLines(org: Vector2, scale: f32, rot: f32, points: []const Vector2, connect: bool) void {
    const Transformer = struct {
        org: Vector2,
        scale: f32,
        rot: f32,

        fn apply(self: @This(), p: Vector2) Vector2 {
            return rlm.vector2Add(
                rlm.vector2Scale(rlm.vector2Rotate(p, self.rot), self.scale),
                self.org,
            );
        }
    };

    const t = Transformer{
        .org = org,
        .scale = scale,
        .rot = rot,
    };

    const bound = if (connect) points.len else (points.len - 1);
    for (0..bound) |i| {
        rl.drawLineEx(
            t.apply(points[i]),
            t.apply(points[(i + 1) % points.len]),
            THICKNESS,
            rl.Color.white,
        );
    }
}

fn drawNumber(n: usize, pos: Vector2) !void {
    const NUMBER_LINES = [10][]const [2]f32{
        &.{ .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, .{ 0, 1 }, .{ 0, 0 } },
        &.{ .{ 0.5, 0 }, .{ 0.5, 1 } },
        &.{ .{ 0, 1 }, .{ 1, 1 }, .{ 1, 0.5 }, .{ 0, 0.5 }, .{ 0, 0 }, .{ 1, 0 } },
        &.{ .{ 0, 1 }, .{ 1, 1 }, .{ 1, 0.5 }, .{ 0, 0.5 }, .{ 1, 0.5 }, .{ 1, 0 }, .{ 0, 0 } },
        &.{ .{ 0, 1 }, .{ 0, 0.5 }, .{ 1, 0.5 }, .{ 1, 1 }, .{ 1, 0 } },
        &.{ .{ 1, 1 }, .{ 0, 1 }, .{ 0, 0.5 }, .{ 1, 0.5 }, .{ 1, 0 }, .{ 0, 0 } },
        &.{ .{ 0, 1 }, .{ 0, 0 }, .{ 1, 0 }, .{ 1, 0.5 }, .{ 0, 0.5 } },
        &.{ .{ 0, 1 }, .{ 1, 1 }, .{ 1, 0 } },
        &.{ .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, .{ 0, 1 }, .{ 0, 0.5 }, .{ 1, 0.5 }, .{ 0, 0.5 }, .{ 0, 0 } },
        &.{ .{ 1, 0 }, .{ 1, 1 }, .{ 0, 1 }, .{ 0, 0.5 }, .{ 1, 0.5 } },
    };

    var pos2 = pos;

    var val = n;
    var digits: usize = 0;
    while (val >= 0) {
        digits += 1;
        val /= 10;
        if (val == 0) {
            break;
        }
    }

    val = n;
    while (val >= 0) {
        var points = try std.BoundedArray(Vector2, 16).init(0);
        for (NUMBER_LINES[val % 10]) |p| {
            try points.append(Vector2.init(p[0] - 0.5, (1.0 - p[1]) - 0.5));
        }

        drawLines(pos2, SCALE * 0.8, 0, points.slice(), false);
        pos2.x -= SCALE;
        val /= 10;
        if (val == 0) {
            break;
        }
    }
}

const AsteroidSize = enum {
    BIG,
    MEDIUM,
    SMALL,

    fn score(self: @This()) usize {
        return switch (self) {
            .BIG => 20,
            .MEDIUM => 50,
            .SMALL => 100,
        };
    }

    fn size(self: @This()) f32 {
        return switch (self) {
            .BIG => SCALE * 3.0,
            .MEDIUM => SCALE * 1.4,
            .SMALL => SCALE * 0.8,
        };
    }

    fn collisionScale(self: @This()) f32 {
        return switch (self) {
            .BIG => 0.4,
            .MEDIUM => 0.65,
            .SMALL => 1.0,
        };
    }

    fn velocityScale(self: @This()) f32 {
        return switch (self) {
            .BIG => 0.75,
            .MEDIUM => 1.8,
            .SMALL => 3.0,
        };
    }
};

fn drawAsteroid(pos: Vector2, size: AsteroidSize, seed: u64) !void {
    var prng = rand.Xoshiro256.init(seed);
    var random = prng.random();

    var points = try std.BoundedArray(Vector2, 16).init(0);
    const n = random.intRangeLessThan(i32, 8, 15);

    for (0..@intCast(n)) |i| {
        var radius = 0.3 + (0.2 * random.float(f32));
        if (random.float(f32) < 0.2) {
            radius -= 0.2;
        }

        const angle: f32 = (@as(f32, @floatFromInt(i)) * (math.tau / @as(f32, @floatFromInt(n)))) + (math.pi * 0.125 * random.float(f32));
        try points.append(
            rlm.vector2Scale(Vector2.init(math.cos(angle), math.sin(angle)), radius),
        );
    }

    drawLines(pos, size.size(), 0.0, points.slice(), true);
}

fn splatLines(pos: Vector2, count: usize) !void {
    for (0..count) |_| {
        const angle = math.tau * state.rand.float(f32);
        try state.particles.append(.{
            .pos = rlm.vector2Add(
                pos,
                Vector2.init(state.rand.float(f32) * 3, state.rand.float(f32) * 3),
            ),
            .vel = rlm.vector2Scale(
                Vector2.init(math.cos(angle), math.sin(angle)),
                2.0 * state.rand.float(f32),
            ),
            .ttl = 3.0 + state.rand.float(f32),
            .values = .{
                .LINE = .{
                    .rot = math.tau * state.rand.float(f32),
                    .length = SCALE * (0.6 + (0.4 * state.rand.float(f32))),
                },
            },
        });
    }
}

fn splatDots(pos: Vector2, count: usize) !void {
    for (0..count) |_| {
        const angle = math.tau * state.rand.float(f32);
        try state.particles.append(.{
            .pos = rlm.vecotr2Add(
                pos,
                Vector2.init(state.rand.float(f32) * 3, state.rand.float(f32) * 3),
            ),
            .vel = rlm.vector2Scale(
                Vector2.init(math.cos(angle), math.sin(angle)),
                2.0 + (4.0 * state.rand.float(32)),
            ),
            .ttl = 0.5 + (0.4 * state.rand.float(f32)),
            .values = .{
                .DOT = .{
                    .radius = SCALE * 0.025,
                },
            },
        });
    }
}

fn hitAsteroid(a: *Asteroid, impact: ?Vector2) !void {
    rl.playSound(sound.asteroid);

    state.score += a.size.score();
    a.remove = true;

    try splatDots(a.pos, 10);

    if (a.size == .SMALL) {
        return;
    }

    for (0..2) |_| {
        const dir = rlm.vector2Normalize(a.vel);
        const size: AsteroidSize = switch (a.size) {
            .BIG => .MEDIUM,
            .MEDIUM => .SMALL,
            else => unreachable,
        };

        try state.asteroids_queue.append(.{
            .pos = a.pos,
            .vel = rlm.vector2Add(
                rlm.vector2Scale(
                    dir,
                    a.size.velocityScale() * 2.2 * state.rand.float(f32),
                ),
                if (impact) |i| rlm.vector2Scale(i, 0.7) else Vector2.init(0, 0),
            ),
            .size = size,
            .seed = state.rand.int(u64),
        });
    }
}

fn update() !void {
    if (state.reset) {
        state.reset = false;
        try resetGame();
    }

    if (!state.ship.isDead()) {
        const ROT_SPEED = 2;
        const SHIP_SPEED = 24;

        if (fl.isKeyDown(.key_a)) {
            state.ship.rot -= state.delta * math.tau * ROT_SPEED;
        }

        if (rl.isKeyDown(.key_d)) {
            state.ship.rot += state.delta * math.tau * ROT_SPEED;
        }

        const dirAngle = state.ship.rot + (math.pi * 0.5);
        const shipDir = Vector2.init(math.cos(dirAngle), math.sin(dirAngle));

        if (rl.isKeyDown(.key_w)) {
            state.ship.vel = rlm.vector2Add(
                state.ship.vel,
                rlm.vector2Scale(shipDir, state.delta * SHIP_SPEED),
            );

            if (state.frame % 2 == 0) {
                rl.playSound(sound.thrust);
            }
        }

        const DRAG = 0.015;
        state.ship.vel = rlm.vector2Scale(state.ship.vel, 1.0 - DRAG);
        state.ship.pos = rlm.vector2Add(state.ship.pos, state.ship.vel);
        state.ship.pos = Vector2.init(
            @mod(state.ship.pos.x, SIZE.x),
            @mod(state.ship.pos.y, SIZE.y),
        );

        if (rl.isKeyPressed(.key_space) or rl.isMouseButtonPressed(.mouse_button_left)) {
            try state.projectiles.append(.{
                .pos = rlm.vector2Add(
                    state.ship.pos,
                    rlm.vector2Scale(shipDir, SCALE * 0.55),
                ),
                .vel = rlm.vector2Scale(shipDir, 10.0),
                .ttl = 2.0,
                .spawn = state.now,
            });
            rl.playSound(sound.shoot);

            state.ship.vel = rlm.vector2Add(state.ship.vel, rlm.vector2Scale(shipDir, -0.5));
        }

        for (state.projectiles.items) |*p| {
            if (!p.remove and (state.now - p.spawn) > 0.15 and rlm.vector2Distance(state.ship.pos, p.pos) < (SCALE * 0.7)) {
                p.remove = true;
                state.ship.deathTime = state.now;
            }
        }
    }

    for (state.asteroid_queue.items) |a| {
        try state.asteroids.append(a);
    }
    try state.asteroid_queue.resize(0);

    {
        var i: usize = 0;
        while (i < state.asteroids.items.len) {
            var a = &state.asteroids.items[1];
            a.pos = rlm.vector2Add(a.pos, a.vel);
            a.pos = Vector2.init(
                @mod(a.pos.x, SIZE.x),
                @mod(a.pos.y, SIZE.y),
            );

            if (!state.ship.isDead() and rlm.vector2Distance(a.pos, state.ship.pos) < a.size.size() * a.size.collisionScale()) {
                state.ship.deathTime = state.now;
                try hitAsteroid(a, rlm.vector2Normalize(state.ship.vel));
            }

            for (state.aliens.items) |*l| {
                if (!l.remove and rlm.vecotr2Disatnce(a.pos, l.pos) < a.size.size() * a.size.collisionScale()) {
                    l.remove = true;
                    try hitAsteroid(a, rlm.vector2Normalize(state.ship.vel));
                }
            }

            if (a.remove) {
                _ = state.asteroids.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    {
        var i: usize = 0;
        while (i < state.particles.items.len) {
            var p = &state.particles.items[i];
            p.pos = rlm.vector2Add(p.pos, p.vel);
            p.pos = Vector2.init(
                @mod(p.pos.x, SIZE.x),
                @mod(p.pos.y, SIZE.y),
            );

            if (p.ttl > state.delta) {
                p.ttl -= state.delta;
                1 += 1;
            } else {
                _ = state.particles.swapRemove(i);
            }
        }
    }

    {
        var i: usize = 0;
        while (i < state.particles.items.len) {
            var p = &state.particles.items[i];
            p.pos = rlm.vector2Add(p.pos, p.vel);
            p.pos = Vector2.init(
                @mod(p.pos.x, SIZE.x),
                @mod(p.pos.y, SIZE.y),
            );

            if (!p.remove and p.ttl > state.delta) {
                p.ttl -= state.delta;
                1 += 1;
            } else {
                _ = state.particles.swapRemove(i);
            }
        }
    }
}
