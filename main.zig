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
