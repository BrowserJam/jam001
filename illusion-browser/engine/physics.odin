package zephr

import m "core:math/linalg/glsl"

// TODO: I can't into physics. Be into physics

PhysicsBody :: union {
    StaticBody,
    RigidBody,
}

StaticBody :: struct {
}

RigidBody :: struct {
    velocity: m.vec3,
    //mass:     f32,
    //force:    m.vec3,
}

Entity :: struct {
    physics_body: PhysicsBody,
    position: m.vec3,
    rotation: m.quat,
    rotation_euler: m.vec3,
    scale: m.vec3,
    model:       Model,
    // TODO: this is garbage I think
    type:       union {
        Player,
    },
    collision_shape: CollisionShape,
}

CollisionShape :: union {
    AABB,
    //Sphere,
    //Capsule,
    //Cylinder,
    //Cone,
    //ConvexHull,
    Mesh,
}

// TODO: Most of this stuff should probably be done by the game instead of the engine since it's so game-specific.
// But I'm conflicted because I feel like it can be reused between multiple games (although with slight differences maybe)
// which is why it initially landed in the engine, maybe an effort to generalize and abstract this would be good, if not, just move
// to the game code.

// ?? idk. I've never programmed a game before lol
EntityType :: enum {
    ENVIRONMENT,
    PLAYER,
}

PlayerAnimationState :: enum {
    IDLE,
    WALK,
    RUN,
}

Player :: struct {
    forward: m.vec3,
    animation_state: PlayerAnimationState,
}

entity_transform :: proc(entity: Entity) -> m.mat4 {
    mat := m.identity(m.mat4)
    mat = m.mat4Scale(entity.scale) * mat
    mat = m.mat4FromQuat(entity.rotation) * mat
    mat = m.mat4Translate(entity.position) * mat
    return mat
}
