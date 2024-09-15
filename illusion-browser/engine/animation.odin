package zephr

import "core:log"
import "core:math"
import m "core:math/linalg/glsl"
import "core:time"

import "vendor:cgltf"

@(private)
AnimationTrack :: struct {
    node:          ^Node,
    property:      cgltf.animation_path_type,
    time:          []f32,
    data:          []f32,
    interpolation: cgltf.interpolation_type,
    prev_t:        f32,
    prev_keyframe: int,
}

Animation :: struct {
    name:        string,
    tracks:      []AnimationTrack,
    max_time:    f32,
    timer:       time.Stopwatch,
    root_motion: bool,
}

@(private = "file")
interpolate_rotation :: proc(track: ^AnimationTrack, t, td: f32) -> m.quat #no_bounds_check {
    prev_val := cast(m.quat)quaternion(
        x = track.data[track.prev_keyframe * 4],
        y = track.data[track.prev_keyframe * 4 + 1],
        z = track.data[track.prev_keyframe * 4 + 2],
        w = track.data[track.prev_keyframe * 4 + 3],
    )
    next_val := cast(m.quat)quaternion(
        x = track.data[track.prev_keyframe * 4 + 4],
        y = track.data[track.prev_keyframe * 4 + 5],
        z = track.data[track.prev_keyframe * 4 + 6],
        w = track.data[track.prev_keyframe * 4 + 7],
    )

    rot := cast(m.quat)quaternion(x = 0, y = 0, z = 0, w = 1)

    switch track.interpolation {
        case .linear:
            rot = m.slerp(prev_val, next_val, t)
        case .step:
            rot = prev_val
        case .cubic_spline:
            stride := 12
            prev_val = quaternion(
                x = track.data[track.prev_keyframe * stride + 4],
                y = track.data[track.prev_keyframe * stride + 5],
                z = track.data[track.prev_keyframe * stride + 6],
                w = track.data[track.prev_keyframe * stride + 7],
            )
            bk := quaternion(
                x = track.data[track.prev_keyframe * stride + 8],
                y = track.data[track.prev_keyframe * stride + 9],
                z = track.data[track.prev_keyframe * stride + 10],
                w = track.data[track.prev_keyframe * stride + 11],
            )

            ak1 := quaternion(
                x = track.data[track.prev_keyframe * stride + 12],
                y = track.data[track.prev_keyframe * stride + 13],
                z = track.data[track.prev_keyframe * stride + 14],
                w = track.data[track.prev_keyframe * stride + 15],
            )
            next_val = quaternion(
                x = track.data[track.prev_keyframe * stride + 16],
                y = track.data[track.prev_keyframe * stride + 17],
                z = track.data[track.prev_keyframe * stride + 18],
                w = track.data[track.prev_keyframe * stride + 19],
            )

            t1 := (2 * m.pow(t, 3) - 3 * m.pow(t, 2) + 1)
            p1 := quaternion(x = prev_val.x * t1, y = prev_val.y * t1, z = prev_val.z * t1, w = prev_val.w * t1)

            t2 := td * (m.pow(t, 3) - 2 * m.pow(t, 2) + t)
            p2 := quaternion(x = bk.x * t2, y = bk.y * t2, z = bk.z * t2, w = bk.w * t2)

            t3 := (-2 * m.pow(t, 3) + 3 * m.pow(t, 2))
            p3 := quaternion(x = next_val.x * t3, y = next_val.y * t3, z = next_val.z * t3, w = next_val.w * t3)

            t4 := td * (m.pow(t, 3) - m.pow(t, 2))
            p4 := quaternion(x = ak1.x * t4, y = ak1.y * t4, z = ak1.z * t4, w = ak1.w * t4)

            rot = m.normalize(cast(m.quat)(p1 + p2 + p3 + p4))
    }

    return rot
}

@(private = "file")
interpolate_vec3 :: proc(track: ^AnimationTrack, t, td: f32) -> m.vec3 #no_bounds_check {
    prev_val := m.vec3 {
        track.data[track.prev_keyframe * 3],
        track.data[track.prev_keyframe * 3 + 1],
        track.data[track.prev_keyframe * 3 + 2],
    }
    next_val := m.vec3 {
        track.data[track.prev_keyframe * 3 + 3],
        track.data[track.prev_keyframe * 3 + 4],
        track.data[track.prev_keyframe * 3 + 5],
    }
    val := m.vec3{0, 0, 0}

    switch track.interpolation {
        case .linear:
            val = m.lerp(prev_val, next_val, t)
        case .step:
            val = prev_val
        case .cubic_spline:
            stride := 9
            prev_val = m.vec3 {
                track.data[track.prev_keyframe * stride + 3],
                track.data[track.prev_keyframe * stride + 4],
                track.data[track.prev_keyframe * stride + 5],
            }
            bk := m.vec3 {
                track.data[track.prev_keyframe * stride + 6],
                track.data[track.prev_keyframe * stride + 7],
                track.data[track.prev_keyframe * stride + 8],
            }

            ak1 := m.vec3 {
                track.data[track.prev_keyframe * stride + 9],
                track.data[track.prev_keyframe * stride + 10],
                track.data[track.prev_keyframe * stride + 11],
            }
            next_val = m.vec3 {
                track.data[track.prev_keyframe * stride + 12],
                track.data[track.prev_keyframe * stride + 13],
                track.data[track.prev_keyframe * stride + 14],
            }

            p1 := (2 * m.pow(t, 3) - 3 * m.pow(t, 2) + 1) * prev_val
            p2 := td * (m.pow(t, 3) - 2 * m.pow(t, 2) + t) * bk
            p3 := (-2 * m.pow(t, 3) + 3 * m.pow(t, 2)) * next_val
            p4 := td * (m.pow(t, 3) - m.pow(t, 2)) * ak1
            val = p1 + p2 + p3 + p4
    }

    return val
}

interpolate_weights :: proc(track: ^AnimationTrack, t, td: f32, weights_len: int) -> []f32 {
    prev_val := track.data[(track.prev_keyframe * weights_len):(track.prev_keyframe * weights_len) + weights_len]
    next_val := track.data[(track.prev_keyframe * weights_len) +
    weights_len:(track.prev_keyframe * weights_len) +
    (weights_len * 2)]

    val := make([]f32, weights_len)

    switch track.interpolation {
        case .linear:
            for i in 0 ..< weights_len {
                val[i] = m.lerp(prev_val[i], next_val[i], t)
            }
        case .step:
            val = prev_val
        case .cubic_spline:
                    //odinfmt: disable
        // TODO: Does any of this make any sense. This needs to be tested with a model
        prev_val := track.data[(track.prev_keyframe * weights_len) + weights_len:(track.prev_keyframe * weights_len) + (weights_len * 2)]
        bk := track.data[(track.prev_keyframe * weights_len) + (weights_len * 2):(track.prev_keyframe * weights_len) + (weights_len * 3)]

        ak1 := track.data[(track.prev_keyframe * weights_len) + (weights_len * 3):(track.prev_keyframe * weights_len) + (weights_len * 4)]
        next_val := track.data[(track.prev_keyframe * weights_len) + (weights_len * 4):(track.prev_keyframe * weights_len) + (weights_len * 5)]

        t1 := (2 * m.pow(t, 3) - 3 * m.pow(t, 2) + 1)
        t2 := td * (m.pow(t, 3) - 2 * m.pow(t, 2) + t)
        t3 := (-2 * m.pow(t, 3) + 3 * m.pow(t, 2))
        t4 := td * (m.pow(t, 3) - m.pow(t, 2))

        val = make([]f32, weights_len)

        for i in 0..<weights_len {
            p1 := (t1 * prev_val[i])
            p2 := (t2 * bk[i])
            p3 := (t3 * next_val[i])
            p4 := (t4 * ak1[i])

            val[i] = p1 + p2 + p3 + p4
        }
        //odinfmt: enable


    }

    return val
}

// TODO: GARBAGE
get_current_animation_value :: proc(anim: ^Animation, track: ^AnimationTrack) -> m.vec3 {
    n := len(track.time)

    tc := cast(f32)time.duration_seconds(time.stopwatch_duration(anim.timer))

    tc = math.mod(tc, anim.max_time)
    tc = clamp(tc, track.time[0], track.time[n - 1])
    if track.prev_t > tc {
        track.prev_keyframe = 0
    }

    track.prev_t = tc

    next_key := 0
    for i in track.prev_keyframe + 1 ..< n {
        if tc <= track.time[i] {
            next_key = clamp(i, 1, n - 1)
            break
        }
    }
    track.prev_keyframe = clamp(next_key - 1, 0, next_key)
    tk_prev := track.time[track.prev_keyframe]
    tk_next := track.time[next_key]

    td := tk_next - tk_prev
    t := (tc - tk_prev) / td

    prev_val := m.vec3 {
        track.data[track.prev_keyframe * 3],
        track.data[track.prev_keyframe * 3 + 1],
        track.data[track.prev_keyframe * 3 + 2],
    }
    next_val := m.vec3 {
        track.data[track.prev_keyframe * 3 + 3],
        track.data[track.prev_keyframe * 3 + 4],
        track.data[track.prev_keyframe * 3 + 5],
    }

    return m.lerp(prev_val, next_val, t)
}

advance_animation :: proc(anim: ^Animation) #no_bounds_check {
    context.logger = logger

    for &track, t in anim.tracks {
        // TODO: this is some BS that I wrote to quickly get something that resembles root motion.
        // Needs to be removed.
        if anim.root_motion && t == 0 {
            continue
        }
        n := len(track.time)

        if n == 1 {
            #partial switch track.property {
                case .translation:
                    track.node.translation = {track.data[0], track.data[1], track.data[2]}
                case .scale:
                    track.node.scale = {track.data[0], track.data[1], track.data[2]}
                case .rotation:
                    track.node.rotation =
                    cast(m.quat)quaternion(x = track.data[0], y = track.data[1], z = track.data[2], w = track.data[3])
                case .weights:
                    for &mesh in track.node.meshes {
                        copy(mesh.weights, track.data[:len(track.node.meshes[0].weights)])
                    }
            }
            continue
        }

        tc := cast(f32)time.duration_seconds(time.stopwatch_duration(anim.timer))
        // TODO: if loop_animation {
        //if tc > anim.max_time {
        //    time.stopwatch_reset(&anim.timer)
        //    time.stopwatch_start(&anim.timer)
        //    tc = 0
        //}
        tc = math.mod(tc, anim.max_time)
        //}
        tc = clamp(tc, track.time[0], track.time[n - 1])

        if track.prev_t > tc {
            track.prev_keyframe = 0
        }

        track.prev_t = tc

        next_key := 0
        for i in track.prev_keyframe ..< n {
            if tc <= track.time[i] {
                next_key = clamp(i, 1, n - 1)
                break
            }
        }
        track.prev_keyframe = clamp(next_key - 1, 0, next_key)
        tk_prev := track.time[track.prev_keyframe]
        tk_next := track.time[next_key]

        td := tk_next - tk_prev
        t := (tc - tk_prev) / td

        #partial switch track.property {
            case .translation:
                position := interpolate_vec3(&track, t, td)
                track.node.translation = position
            case .rotation:
                rotation := interpolate_rotation(&track, t, td)
                track.node.rotation = rotation
            case .scale:
                scale := interpolate_vec3(&track, t, td)
                track.node.scale = scale
            case .weights:
                weights := interpolate_weights(&track, t, td, len(track.node.meshes[0].weights))
                defer delete(weights)
                for &mesh in track.node.meshes {
                    copy(mesh.weights, weights)
                }
        }
    }
}

move_to_next_keyframe :: proc(anim: ^Animation) {
    for &track in anim.tracks {
        n := len(track.time)

        track.prev_keyframe = clamp(track.prev_keyframe + 1, 0, n - 1)

        #partial switch track.property {
            case .translation:
                val := m.vec3 {
                    track.data[track.prev_keyframe * 3],
                    track.data[track.prev_keyframe * 3 + 1],
                    track.data[track.prev_keyframe * 3 + 2],
                }
                track.node.translation = val
            case .rotation:
                val := cast(m.quat)quaternion(
                    x = track.data[track.prev_keyframe * 4],
                    y = track.data[track.prev_keyframe * 4 + 1],
                    z = track.data[track.prev_keyframe * 4 + 2],
                    w = track.data[track.prev_keyframe * 4 + 3],
                )
                track.node.rotation = val
            case .scale:
                val := m.vec3 {
                    track.data[track.prev_keyframe * 3],
                    track.data[track.prev_keyframe * 3 + 1],
                    track.data[track.prev_keyframe * 3 + 2],
                }
                track.node.scale = val
            case .weights:
                weights_len := len(track.node.meshes[0].weights)
                val := track.data[(track.prev_keyframe * weights_len):(track.prev_keyframe * weights_len) + weights_len]
                for &mesh in track.node.meshes {
                    copy(mesh.weights, val)
                }
        }
    }
}

move_to_prev_keyframe :: proc(anim: ^Animation) {
    for &track in anim.tracks {
        n := len(track.time)

        track.prev_keyframe = clamp(track.prev_keyframe - 1, 0, n - 1)

        #partial switch track.property {
            case .translation:
                val := m.vec3 {
                    track.data[track.prev_keyframe * 3],
                    track.data[track.prev_keyframe * 3 + 1],
                    track.data[track.prev_keyframe * 3 + 2],
                }
                track.node.translation = val
            case .rotation:
                val := cast(m.quat)quaternion(
                    x = track.data[track.prev_keyframe * 4],
                    y = track.data[track.prev_keyframe * 4 + 1],
                    z = track.data[track.prev_keyframe * 4 + 2],
                    w = track.data[track.prev_keyframe * 4 + 3],
                )
                track.node.rotation = val
            case .scale:
                val := m.vec3 {
                    track.data[track.prev_keyframe * 3],
                    track.data[track.prev_keyframe * 3 + 1],
                    track.data[track.prev_keyframe * 3 + 2],
                }
                track.node.scale = val
            case .weights:
                weights_len := len(track.node.meshes[0].weights)
                val := track.data[(track.prev_keyframe * weights_len):(track.prev_keyframe * weights_len) + weights_len]
                for &mesh in track.node.meshes {
                    copy(mesh.weights, val)
                }
        }
    }
}

pause_animation :: proc(anim: ^Animation) {
    time.stopwatch_stop(&anim.timer)
}

resume_animation :: proc(anim: ^Animation) {
    time.stopwatch_start(&anim.timer)
}

play_animation_with_name :: proc(model: ^Model, name: string) {
    log.assert(len(model.animations) > 0, "Tried playing animation on model with no animations")

    if model.active_animation != nil {
        time.stopwatch_reset(&model.active_animation.timer)
    }

    for &anim in model.animations {
        if anim.name == name {
            model.active_animation = &anim
            time.stopwatch_start(&anim.timer)
            return
        }
    }

    log.errorf("Animation with name \"%s\" not found on model %s", name, model.nodes[0].name)
}

reset_animation :: proc(anim: ^Animation) {
    // TODO: resetting animation doesn't reset skinned vertices. fix that
    time.stopwatch_reset(&anim.timer)

    reset_node_animation :: proc(anim: ^Animation) {
        for &track in anim.tracks {
            track.prev_keyframe = 0
            track.prev_t = 0

            #partial switch track.property {
                case .translation:
                    track.node.translation = m.vec3{track.data[0], track.data[1], track.data[2]}
                case .rotation:
                    track.node.rotation = quaternion(
                        x = track.data[0],
                        y = track.data[1],
                        z = track.data[2],
                        w = track.data[3],
                    )
                case .scale:
                    track.node.scale = m.vec3{track.data[0], track.data[1], track.data[2]}
                case .weights:
                    for &mesh in track.node.meshes {
                        copy(mesh.weights, track.data[:len(mesh.weights)])
                    }
            }
        }
    }

    reset_node_animation(anim)
}
