package zephr

import "base:intrinsics"
import "core:fmt"
import "core:log"
import "core:math"
import m "core:math/linalg/glsl"
import "core:mem"
import "core:mem/virtual"
import "core:strings"
import "core:time"

import gl "vendor:OpenGL"
import "vendor:cgltf"

#assert(size_of(Vertex) == 96)
Vertex :: struct {
    position:   m.vec3,
    normal:     m.vec3,
    tex_coords: m.vec2,
    tangents:   m.vec4,
    joints:     [4]u32,
    weights:    m.vec4,
    color:      m.vec4,
}

@(private)
Mesh :: struct {
    primitive:             cgltf.primitive_type,
    vertices:              [dynamic]Vertex,
    indices:               []u32,
    parent: ^Node,
    material_id:           uintptr,
    weights:               []f32,
    morph_targets_tex:     TextureId,
    morph_normals_offset:  int,
    morph_tangents_offset: int,
    joint_matrices_buf:    u32,
    joint_matrices_tex:    TextureId,
    vao:                   u32,
    vbo:                   u32,
    ebo:                   u32,
    morph_weights_buf:     u32,
    morph_weights_tex:     TextureId,
    aabb: AABB,
}

Node :: struct {
    name:                  string,
    parent:                ^Node,
    is_bone:               bool,
    joints:                []^Node,
    skeleton:              ^Node,
    meshes:                []Mesh,
    transform:             m.mat4,
    has_transform:         bool,
    world_transform:       m.mat4,
    scale:                 m.vec3,
    translation:           m.vec3,
    rotation:              m.quat,
    children:              []^Node,
    inverse_bind_matrices: []m.mat4,
}

Model :: struct {
    nodes:            []^Node,
    materials:        map[uintptr]Material,
    arena:            virtual.Arena,
    animations:       []Animation,
    active_animation: ^Animation,
    aabb: AABB,
}

node_name_idx: ^int
bone_name_idx: ^int

// BUG: There seems to be a bug with how we're handling the hierarchy for skins/joints or something, a blender export doesn't move the skin/bones
// when we move the root node. The same model works fine in babylonjs, when I exported from babylon it works fine in the engine
// now, which makes me think there's a chance it's a blender export issue. But also means my importer should do a better job.
// Related: https://github.com/KhronosGroup/glTF-Blender-IO/issues/1626

@(private = "file")
process_sparse_accessor_vec2 :: proc(accessor: ^cgltf.accessor_sparse, data_out: []f32) {
    indices_byte_offset := accessor.indices_byte_offset + accessor.indices_buffer_view.offset
    values_byte_offset := accessor.values_byte_offset + accessor.values_buffer_view.offset

    sparse_values := intrinsics.ptr_offset(
        cast([^]f32)accessor.values_buffer_view.buffer.data,
        values_byte_offset / size_of(f32),
    )

    indices := make([]u32, accessor.count)
    defer delete(indices)

    process_indices(accessor.indices_buffer_view, accessor.indices_component_type, indices_byte_offset, indices)

    for idx, i in indices {
        data_out[idx * 2] = sparse_values[i * 2]
        data_out[idx * 2 + 1] = sparse_values[i * 2 + 1]
    }
}

@(private = "file")
process_sparse_accessor_vec3 :: proc(accessor: ^cgltf.accessor_sparse, data_out: []f32) {
    indices_byte_offset := accessor.indices_byte_offset + accessor.indices_buffer_view.offset
    values_byte_offset := accessor.values_byte_offset + accessor.values_buffer_view.offset

    sparse_values := intrinsics.ptr_offset(
        cast([^]f32)accessor.values_buffer_view.buffer.data,
        values_byte_offset / size_of(f32),
    )

    indices := make([]u32, accessor.count)
    defer delete(indices)

    process_indices(accessor.indices_buffer_view, accessor.indices_component_type, indices_byte_offset, indices)

    for idx, i in indices {
        data_out[idx * 3] = sparse_values[i * 3]
        data_out[idx * 3 + 1] = sparse_values[i * 3 + 1]
        data_out[idx * 3 + 2] = sparse_values[i * 3 + 2]
    }
}

@(private = "file")
process_sparse_accessor_vec4 :: proc(accessor: ^cgltf.accessor_sparse, data_out: []f32) {
    indices_byte_offset := accessor.indices_byte_offset + accessor.indices_buffer_view.offset
    values_byte_offset := accessor.values_byte_offset + accessor.values_buffer_view.offset

    sparse_values := intrinsics.ptr_offset(
        cast([^]f32)accessor.values_buffer_view.buffer.data,
        values_byte_offset / size_of(f32),
    )

    indices := make([]u32, accessor.count)
    defer delete(indices)

    process_indices(accessor.indices_buffer_view, accessor.indices_component_type, indices_byte_offset, indices)

    for idx, i in indices {
        data_out[idx * 4] = sparse_values[i * 4]
        data_out[idx * 4 + 1] = sparse_values[i * 4 + 1]
        data_out[idx * 4 + 2] = sparse_values[i * 4 + 2]
        data_out[idx * 4 + 3] = sparse_values[i * 4 + 3]
    }
}

@(private = "file")
process_accessor_vec2 :: proc(accessor: ^cgltf.accessor, data_out: []f32) {
    byte_offset := accessor.offset

    if accessor.buffer_view != nil {
        byte_offset += accessor.buffer_view.offset

        buf := intrinsics.ptr_offset(cast([^]f32)accessor.buffer_view.buffer.data, byte_offset / size_of(f32))
        if accessor.buffer_view.stride == 0 {
            copy(data_out, buf[:accessor.count * 2])
        } else {
            for i in 0 ..< accessor.count {
                data_out[i * 2] = buf[i * accessor.buffer_view.stride / size_of(f32)]
                data_out[i * 2 + 1] = buf[i * (accessor.buffer_view.stride / size_of(f32)) + 1]
            }
        }

        if accessor.is_sparse {
            process_sparse_accessor_vec2(&accessor.sparse, data_out)
        }
    } else {
        if accessor.is_sparse {
            process_sparse_accessor_vec2(&accessor.sparse, data_out)
        } else {
            log.error("Got a buffer view that is nil and not sparse. Confused on what to do")
        }
    }
}

@(private = "file")
process_accessor_vec3 :: proc(accessor: ^cgltf.accessor, data_out: []f32) {
    byte_offset := accessor.offset

    if accessor.buffer_view != nil {
        byte_offset += accessor.buffer_view.offset

        buf := intrinsics.ptr_offset(cast([^]f32)accessor.buffer_view.buffer.data, byte_offset / size_of(f32))
        if accessor.buffer_view.stride == 0 {
            copy(data_out, buf[:accessor.count * 3])
        } else {
            for i in 0 ..< accessor.count {
                data_out[i * 3] = buf[i * accessor.buffer_view.stride / size_of(f32)]
                data_out[i * 3 + 1] = buf[i * (accessor.buffer_view.stride / size_of(f32)) + 1]
                data_out[i * 3 + 2] = buf[i * (accessor.buffer_view.stride / size_of(f32)) + 2]
            }
        }

        if accessor.is_sparse {
            process_sparse_accessor_vec3(&accessor.sparse, data_out)
        }
    } else {
        if accessor.is_sparse {
            process_sparse_accessor_vec3(&accessor.sparse, data_out)
        } else {
            log.error("Got a buffer view that is nil and not sparse. Confused on what to do")
        }
    }
}

@(private = "file")
process_accessor_vec4 :: proc(accessor: ^cgltf.accessor, data_out: []f32) {
    byte_offset := accessor.offset

    if accessor.buffer_view != nil {
        byte_offset += accessor.buffer_view.offset

        buf := intrinsics.ptr_offset(cast([^]f32)accessor.buffer_view.buffer.data, byte_offset / size_of(f32))
        if accessor.buffer_view.stride == 0 {
            copy(data_out, buf[:accessor.count * 4])
        } else {
            for i in 0 ..< accessor.count {
                data_out[i * 4] = buf[i * accessor.buffer_view.stride / size_of(f32)]
                data_out[i * 4 + 1] = buf[i * (accessor.buffer_view.stride / size_of(f32)) + 1]
                data_out[i * 4 + 2] = buf[i * (accessor.buffer_view.stride / size_of(f32)) + 2]
                data_out[i * 4 + 3] = buf[i * (accessor.buffer_view.stride / size_of(f32)) + 3]
            }
        }

        if accessor.is_sparse {
            process_sparse_accessor_vec4(&accessor.sparse, data_out)
        }
    } else {
        if accessor.is_sparse {
            process_sparse_accessor_vec4(&accessor.sparse, data_out)
        } else {
            log.error("Got a buffer view that is nil and not sparse. Confused on what to do")
        }
    }
}

@(private = "file")
process_joints :: proc(accessor: ^cgltf.accessor, data_out: []u32) {
    byte_offset := accessor.offset + accessor.buffer_view.offset

    if accessor.is_sparse {
        log.error("Sparse joints accessors are not supported yet.")
    }

    #partial switch accessor.component_type {
        case .r_8u:
            buf := intrinsics.ptr_offset(cast([^]u8)accessor.buffer_view.buffer.data, byte_offset / size_of(u8))

            for i in 0 ..< accessor.count {
                offset := accessor.buffer_view.stride == 0 ? i * 4 : i * (accessor.buffer_view.stride / size_of(u8))
                data_out[i * 4 + 0] = cast(u32)buf[offset + 0]
                data_out[i * 4 + 1] = cast(u32)buf[offset + 1]
                data_out[i * 4 + 2] = cast(u32)buf[offset + 2]
                data_out[i * 4 + 3] = cast(u32)buf[offset + 3]
            }
        case .r_16u:
            buf := intrinsics.ptr_offset(cast([^]u16)accessor.buffer_view.buffer.data, byte_offset / size_of(u16))

            for i in 0 ..< accessor.count {
                offset := accessor.buffer_view.stride == 0 ? i * 4 : i * (accessor.buffer_view.stride / size_of(u16))
                data_out[i * 4 + 0] = cast(u32)buf[offset + 0]
                data_out[i * 4 + 1] = cast(u32)buf[offset + 1]
                data_out[i * 4 + 2] = cast(u32)buf[offset + 2]
                data_out[i * 4 + 3] = cast(u32)buf[offset + 3]
            }
        case .r_32u:
            buf := intrinsics.ptr_offset(cast([^]u32)accessor.buffer_view.buffer.data, byte_offset / size_of(u32))

            for i in 0 ..< accessor.count {
                offset := accessor.buffer_view.stride == 0 ? i * 4 : i * (accessor.buffer_view.stride / size_of(u32))
                data_out[i * 4 + 0] = buf[offset + 0]
                data_out[i * 4 + 1] = buf[offset + 1]
                data_out[i * 4 + 2] = buf[offset + 2]
                data_out[i * 4 + 3] = buf[offset + 3]
            }
    }
}

@(private = "file")
process_accessor_mat4 :: proc(accessor: ^cgltf.accessor, data_out: []m.mat4) {
    byte_offset := accessor.offset + accessor.buffer_view.offset

    buf := intrinsics.ptr_offset(cast([^]f32)accessor.buffer_view.buffer.data, byte_offset / size_of(f32))
    stride := accessor.stride / size_of(f32) // 16 floats, 64 bytes always ??

    for i in 0 ..< accessor.count {
        data_out[i] = m.mat4 {
            buf[i * stride + 0],
            buf[i * stride + 4],
            buf[i * stride + 8],
            buf[i * stride + 12],
            buf[i * stride + 1],
            buf[i * stride + 5],
            buf[i * stride + 9],
            buf[i * stride + 13],
            buf[i * stride + 2],
            buf[i * stride + 6],
            buf[i * stride + 10],
            buf[i * stride + 14],
            buf[i * stride + 3],
            buf[i * stride + 7],
            buf[i * stride + 11],
            buf[i * stride + 15],
        }
    }

    if accessor.is_sparse {
        log.error("Sparse mat4 accessors are not supported yet.")
    }
}

@(private = "file")
process_accessor_scalar_float :: proc(accessor: ^cgltf.accessor, data_out: []f32) {
    byte_offset := accessor.offset + accessor.buffer_view.offset

    buf := intrinsics.ptr_offset(cast([^]f32)accessor.buffer_view.buffer.data, byte_offset / size_of(f32))

    if accessor.buffer_view.stride == 0 {
        copy(data_out, buf[:accessor.count])
    } else {
        for i in 0 ..< accessor.count {
            data_out[i] = buf[i * accessor.buffer_view.stride / size_of(f32)]
        }
    }

    if accessor.is_sparse {
        log.error("Sparse scalar float accessors are not supported yet.")
    }
    // TODO: sparse??
}

@(private = "file")
process_indices :: proc(
    buffer_view: ^cgltf.buffer_view,
    type: cgltf.component_type,
    byte_offset: uint,
    indices_out: []u32,
) {
    if buffer_view.stride != 0 {
        // TODO: support stride
        log.error("We don't support non zero stride for indices. Faces might not look correct")
    }

    #partial switch type {
        case .r_8u:
            start := byte_offset / size_of(u8)
            end := start + len(indices_out)
            ptr_arr := (cast([^]u8)buffer_view.buffer.data)[start:end]

            for i in 0 ..< len(ptr_arr) {
                indices_out[i] = cast(u32)ptr_arr[i]
            }
        case .r_16u:
            start := byte_offset / size_of(u16)
            end := start + len(indices_out)
            ptr_arr := (cast([^]u16)buffer_view.buffer.data)[start:end]

            for i in 0 ..< len(ptr_arr) {
                indices_out[i] = cast(u32)ptr_arr[i]
            }
        case .r_32u:
            start := byte_offset / size_of(u32)
            end := start + len(indices_out)
            copy(indices_out, (cast([^]u32)buffer_view.buffer.data)[start:end])
        case:
            log.error("Unsupported index type")
    }
}

@(private = "file")
process_vertex_colors :: proc(accessor: ^cgltf.accessor, color_out: ^[]f32) {
    // TODO: there can be multiple sets of vertex colors.
    // TODO: support when buffer_view is nil ?? (does this even happen for vert colors?)

    color_out := color_out
    color_out^ = make([]f32, accessor.count * 4)
    byte_offset := accessor.offset + accessor.buffer_view.offset

    if accessor.buffer_view == nil {
        log.error("Nil buffer views for vertex colors are not supported.")
    }

    if accessor.type == .vec3 {
        #partial switch accessor.component_type {
            case .r_32f:
                buf := intrinsics.ptr_offset(cast([^]f32)accessor.buffer_view.buffer.data, byte_offset / size_of(f32))
                stride := accessor.stride / size_of(f32)

                for i in 0..<accessor.count {
                    color_out[i * 4 + 0] = buf[i * stride + 0]
                    color_out[i * 4 + 1] = buf[i * stride + 1]
                    color_out[i * 4 + 2] = buf[i * stride + 2]
                    color_out[i * 4 + 3] = 1.0
                }
            case .r_8u:
                buf := intrinsics.ptr_offset(cast([^]u8)accessor.buffer_view.buffer.data, byte_offset / size_of(u8))
                stride := accessor.stride / size_of(u8)

                for i in 0..<accessor.count {
                    color_out[i * 4 + 0] = cast(f32)buf[i * stride + 0] / 255.0
                    color_out[i * 4 + 1] = cast(f32)buf[i * stride + 1] / 255.0
                    color_out[i * 4 + 2] = cast(f32)buf[i * stride + 2] / 255.0
                    color_out[i * 4 + 3] = 1.0
                }
            case .r_16u:
                buf := intrinsics.ptr_offset(cast([^]u16)accessor.buffer_view.buffer.data, byte_offset / size_of(u16))
                stride := accessor.stride / size_of(u16)

                for i in 0..<accessor.count {
                    color_out[i * 4 + 0] = cast(f32)buf[i * stride + 0] / 65535.0
                    color_out[i * 4 + 1] = cast(f32)buf[i * stride + 1] / 65535.0
                    color_out[i * 4 + 2] = cast(f32)buf[i * stride + 2] / 65535.0
                    color_out[i * 4 + 3] = 1.0
                }
            case:
                log.error("Unsupported vertex color type")
        }
    } else {
        #partial switch accessor.component_type {
            case .r_32f:
                buf := intrinsics.ptr_offset(cast([^]f32)accessor.buffer_view.buffer.data, byte_offset / size_of(f32))
                copy(color_out^, buf[:accessor.count * 4])
            case .r_8u:
                buf := intrinsics.ptr_offset(cast([^]u8)accessor.buffer_view.buffer.data, byte_offset / size_of(u8))
                stride := accessor.stride / size_of(u8)

                for i in 0..<accessor.count {
                    color_out[i * 4 + 0] = cast(f32)buf[i * stride + 0] / 255.0
                    color_out[i * 4 + 1] = cast(f32)buf[i * stride + 1] / 255.0
                    color_out[i * 4 + 2] = cast(f32)buf[i * stride + 2] / 255.0
                    color_out[i * 4 + 3] = cast(f32)buf[i * stride + 3] / 255.0
                }
            case .r_16u:
                buf := intrinsics.ptr_offset(cast([^]u16)accessor.buffer_view.buffer.data, byte_offset / size_of(u16))
                stride := accessor.stride / size_of(u16)

                for i in 0..<accessor.count {
                    color_out[i * 4 + 0] = cast(f32)buf[i * stride + 0] / 65535.0
                    color_out[i * 4 + 1] = cast(f32)buf[i * stride + 1] / 65535.0
                    color_out[i * 4 + 2] = cast(f32)buf[i * stride + 2] / 65535.0
                    color_out[i * 4 + 3] = cast(f32)buf[i * stride + 3] / 65535.0
                }
            case:
                log.error("Unsupported vertex color type")
        }
    }
}

@(private = "file")
process_mesh :: proc(
    primitive: ^cgltf.primitive,
    materials: ^map[uintptr]Material,
    model_path: string,
    parent: ^Node,
    textures: ^map[cstring]TextureId,
    weights_len: int,
    joints_len: int,
    allocator: ^mem.Allocator,
) -> (
    Mesh,
    bool,
) {
    if primitive.indices == nil {
        log.error("No indices found")
        return Mesh{}, false
    }

    vertices := make([dynamic]Vertex, 0, 256, allocator^)
    material_id: uintptr = 0

    primitive_type := primitive.type
    if primitive.type != .triangles {
        log.warn("Got a primitive that isn't triangles")
    }
    if primitive.material != nil {
        material_id = transmute(uintptr)primitive.material
        if !(material_id in materials) {
            materials[material_id] = process_material(primitive.material, model_path, textures, allocator)
        }
    }
    positions: []f32
    defer delete(positions)
    normals: []f32
    defer delete(normals)
    texcoords: []f32
    defer delete(texcoords)
    tangents: []f32
    defer delete(tangents)
    joints: []u32
    defer delete(joints)
    weights: []f32
    defer delete(weights)
    colors: []f32
    defer delete(colors)
    has_aabb := false
    mesh_aabb := AABB{
        min = {math.INF_F32, math.INF_F32, math.INF_F32},
        max = {math.NEG_INF_F32, math.NEG_INF_F32, math.NEG_INF_F32},
    }

    for a in 0 ..< len(primitive.attributes) {
        attribute := primitive.attributes[a]
        accessor := attribute.data

        #partial switch attribute.type {
            case .position:
                positions = make([]f32, accessor.count * 3)
                if accessor.has_min && accessor.has_max {
                    mesh_aabb.min = m.min(mesh_aabb.min, m.vec3{accessor.min[0], accessor.min[1], accessor.min[2]})
                    mesh_aabb.max = m.max(mesh_aabb.max, m.vec3{accessor.max[0], accessor.max[1], accessor.max[2]})
                    has_aabb = true
                }
                process_accessor_vec3(accessor, positions)
            case .normal:
                normals = make([]f32, accessor.count * 3)
                process_accessor_vec3(accessor, normals)
            case .texcoord:
                // BUG: we leak memory here for models that have mutiple texcoords.
                // Same with the joints and weights attributes.
                texcoords = make([]f32, accessor.count * 2)
                process_accessor_vec2(accessor, texcoords)
            case .tangent:
                // This is explicitly defined as a vec4 in the spec
                tangents = make([]f32, accessor.count * 4)
                process_accessor_vec4(accessor, tangents)
            case .joints:
                joints = make([]u32, accessor.count * 4)
                process_joints(accessor, joints)
            case .weights:
                weights = make([]f32, accessor.count * 4)
                process_accessor_vec4(accessor, weights)
            case .color:
                process_vertex_colors(accessor, &colors)
        }
    }

    if len(normals) == 0 {
        log.warn("No normals found. Falling back to flat shading")
    }

    if len(tangents) == 0 {
        // TODO: calculate tangents using mikkTSpace??
        // Not sure if worth because I can just export with tangents from blender.
        log.warn("No tangents found. Normal mapping will not be applied")
    }

    // TODO: different pipeline and mesh shader for static meshes to reduce GPU memory usage
    // Instead of a different shader or pipeline we can use preprocessor directives to remove
    // any attribute that is not used for the specific mesh. This requires that we implement some sort of
    // runtime shader modification stuff or something.
    for i in 0 ..< len(positions) / 3 {
        pos := m.vec3{positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2]}
        tex_coords := len(texcoords) != 0 ? m.vec2{texcoords[i * 2], texcoords[i * 2 + 1]} : m.vec2{0, 0}
        normal := len(normals) != 0 ? m.vec3{normals[i * 3], normals[i * 3 + 1], normals[i * 3 + 2]} : m.vec3{0, 0, 0}
        tangents :=
            len(tangents) != 0 \
            ? m.vec4{tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2], tangents[i * 4 + 3]} \
            : m.vec4{0, 0, 0, 0}
        joints :=
            len(joints) != 0 \
            ? [4]u32{joints[i * 4], joints[i * 4 + 1], joints[i * 4 + 2], joints[i * 4 + 3]} \
            : [4]u32{0, 0, 0, 0}
        weights :=
            len(weights) != 0 \
            ? m.vec4{weights[i * 4], weights[i * 4 + 1], weights[i * 4 + 2], weights[i * 4 + 3]} \
            : m.vec4{0, 0, 0, 0}
        color :=
            len(colors) != 0 \
            ? m.vec4{colors[i * 4], colors[i * 4 + 1], colors[i * 4 + 2], colors[i * 4 + 3]} \
            : m.vec4{0, 0, 0, 0}

        if !has_aabb {
            mesh_aabb.min = m.min(mesh_aabb.min, pos)
            mesh_aabb.max = m.max(mesh_aabb.max, pos)
        }

        append(
            &vertices,
            Vertex {
                position = pos,
                normal = normal,
                tex_coords = tex_coords,
                tangents = tangents,
                joints = joints,
                weights = weights,
                color = color,
            },
        )
    }

    morph_attribute_count := 0
    found_pos := false
    found_norm := false
    found_tan := false

    tex_width := math.ceil(math.sqrt(cast(f32)len(vertices)))
    single_texture_size := cast(int)math.pow(tex_width, 2) * 3 // 3 for vec3

    for target in primitive.targets {
        for attr in target.attributes {
            if attr.type == .position && !found_pos {
                morph_attribute_count += 1
                found_pos = true
            } else if attr.type == .normal && !found_norm {
                morph_attribute_count += 1
                found_norm = true
            } else if attr.type == .tangent && !found_tan {
                morph_attribute_count += 1
                found_tan = true
            }
        }
    }

    morph_normals_offset := found_pos ? len(primitive.targets) * single_texture_size : 0
    // Breaks if there're no positions but there is normals
    morph_tangents_offset := found_pos ? len(primitive.targets) * single_texture_size + morph_normals_offset : 0

    morph_targets := make([]f32, single_texture_size * len(primitive.targets) * morph_attribute_count)
    defer delete(morph_targets)

    // The layout for morph_targets is POS, NORM, TAN
    for target, i in primitive.targets {

        for attr in target.attributes {
            accessor := attr.data

            #partial switch attr.type {
                case .position:
                    offset := i * single_texture_size
                    process_accessor_vec3(accessor, morph_targets[offset:cast(uint)offset + accessor.count * 3])
                case .normal:
                    offset := i * single_texture_size + morph_normals_offset
                    process_accessor_vec3(accessor, morph_targets[offset:cast(uint)offset + accessor.count * 3])
                case .tangent:
                    offset := i * single_texture_size + morph_tangents_offset
                    // Morph tangents are explicitly defined as a vec3 in the spec
                    process_accessor_vec3(accessor, morph_targets[offset:cast(uint)offset + accessor.count * 3])
            }
        }
    }

    indices := make([]u32, primitive.indices.count, allocator^)
    offset_into_buffer := primitive.indices.buffer_view.offset
    offset_into_buf_view := primitive.indices.offset

    process_indices(
        primitive.indices.buffer_view,
        primitive.indices.component_type,
        offset_into_buffer + offset_into_buf_view,
        indices,
    )

    return new_mesh(
            primitive_type,
            vertices,
            indices,
            parent,
            material_id,
            weights_len,
            joints_len,
            morph_targets,
            morph_attribute_count,
            morph_normals_offset,
            morph_tangents_offset,
            mesh_aabb,
            allocator,
        ),
        true
}

@(private = "file")
process_node :: proc(
    node: ^cgltf.node,
    parent: ^Node,
    materials: ^map[uintptr]Material,
    model_path: string,
    textures: ^map[cstring]TextureId,
    bones: ^map[uintptr]bool,
    nodes_map: ^map[uintptr]^Node,
    allocator: ^mem.Allocator,
) -> ^Node {
    id := transmute(uintptr)node
    if id in nodes_map {
        return nodes_map[id]
    }

    new_node := new(Node, allocator^)

    name := strings.clone_from_cstring(node.name, allocator^)
    is_bone := id in bones
    if node.name == nil {
        if is_bone {
            name = fmt.aprintf("Bone %d", bone_name_idx^, allocator = allocator^)
            bone_name_idx^ += 1
        } else {
            name = fmt.aprintf("Node %d", node_name_idx^, allocator = allocator^)
            node_name_idx^ += 1
        }
    }
    transform := m.identity(m.mat4)
    translation := m.vec3{0, 0, 0}
    rotation := cast(m.quat)quaternion(x = 0, y = 0, z = 0, w = 1)
    scale := m.vec3{1, 1, 1}

    if node.has_matrix {
        transform = m.mat4 {
            node.matrix_[0],
            node.matrix_[4],
            node.matrix_[8],
            node.matrix_[12],
            node.matrix_[1],
            node.matrix_[5],
            node.matrix_[9],
            node.matrix_[13],
            node.matrix_[2],
            node.matrix_[6],
            node.matrix_[10],
            node.matrix_[14],
            node.matrix_[3],
            node.matrix_[7],
            node.matrix_[11],
            node.matrix_[15],
        }
    } else {
        if node.has_scale {
            scale = m.vec3(node.scale)
        }
        if node.has_rotation {
            rotation =
            cast(m.quat)quaternion(w = node.rotation.w, x = node.rotation.x, y = node.rotation.y, z = node.rotation.z)
        }
        if node.has_translation {
            translation = m.vec3(node.translation)
        }
    }

    inverse_bind_matrices: []m.mat4
    joints: []^Node
    skeleton: ^Node = nil
    if node.skin != nil {
        if node.skin.inverse_bind_matrices != nil {
            inverse_bind_matrices = make([]m.mat4, len(node.skin.joints), allocator^)
            process_accessor_mat4(node.skin.inverse_bind_matrices, inverse_bind_matrices)
        } else {
            log.warn(
                "Found a skin with no inverse bind matrices. We don't support generating the matrices ourselves yet.",
            )
            // TODO: calculate the inverse bind matrices ourselves
        }

        joints = make([]^Node, len(node.skin.joints), allocator^)

        for joint, i in node.skin.joints {
            joints[i] = process_node(joint, nil, materials, model_path, textures, bones, nodes_map, allocator)
        }

        if node.skin.skeleton != nil {
            skeleton = process_node(
                node.skin.skeleton,
                nil,
                materials,
                model_path,
                textures,
                bones,
                nodes_map,
                allocator,
            )
        }
    }

    meshes: []Mesh
    if node.mesh != nil {
        meshes = make([]Mesh, len(node.mesh.primitives), allocator^)
        // we consider primitives to be different meshes
        for idx in 0 ..< len(node.mesh.primitives) {
            mesh, ok := process_mesh(
                &node.mesh.primitives[idx],
                materials,
                model_path,
                new_node,
                textures,
                len(node.mesh.weights),
                len(joints),
                allocator,
            )
            if ok {
                copy(mesh.weights, node.mesh.weights)
                meshes[idx] = mesh
            }
        }
    }


    children := make([]^Node, len(node.children), allocator^)

    for idx in 0 ..< len(node.children) {
        child := node.children[idx]
        children[idx] = process_node(child, new_node, materials, model_path, textures, bones, nodes_map, allocator)
    }

    new_node.name = name
    new_node.parent = parent
    new_node.is_bone = is_bone
    new_node.joints = joints
    new_node.skeleton = skeleton
    new_node.meshes = meshes
    new_node.transform = transform
    new_node.has_transform = cast(bool)node.has_matrix
    new_node.world_transform = m.identity(m.mat4)
    new_node.scale = scale
    new_node.translation = translation
    new_node.rotation = rotation
    new_node.children = children
    new_node.inverse_bind_matrices = inverse_bind_matrices

    nodes_map[id] = new_node

    return new_node
}

@(private = "file")
new_mesh :: proc(
    primitive: cgltf.primitive_type,
    vertices: [dynamic]Vertex,
    indices: []u32,
    parent: ^Node,
    material_id: uintptr,
    weights_len: int,
    joints_len: int,
    morph_targets: []f32,
    morph_attribute_count: int,
    morph_normals_offset: int,
    morph_tangents_offset: int,
    aabb: AABB,
    allocator: ^mem.Allocator,
) -> Mesh {
    vao, vbo, ebo: u32
    morph_texture, morph_weights_texture, morph_weights_buf: u32
    joint_matrices_buf, joint_matrices_texture: u32
    usage: u32 = gl.STATIC_DRAW

    if len(morph_targets) != 0 {
        temp_max_tex_size, temp_max_tex_array_size: i32
        gl.GetIntegerv(gl.MAX_TEXTURE_SIZE, &temp_max_tex_size)
        gl.GetIntegerv(gl.MAX_ARRAY_TEXTURE_LAYERS, &temp_max_tex_array_size)
        max_tex_size := cast(u32)math.pow(cast(f32)temp_max_tex_size, 2)
        max_tex_array_size := cast(u32)temp_max_tex_array_size

        if weights_len * morph_attribute_count > cast(int)max_tex_array_size {
            log.warn("Morph targets exceed the maximum texture size limit")
        }

        width := cast(i32)math.ceil(math.sqrt(cast(f32)len(vertices)))

        gl.GenTextures(1, &morph_texture)
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D_ARRAY, morph_texture)
        gl.TexImage3D(
            gl.TEXTURE_2D_ARRAY,
            0,
            gl.RGB32F,
            width,
            width,
            cast(i32)weights_len,
            0,
            gl.RGB,
            gl.FLOAT,
            raw_data(morph_targets),
        )

        gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
        gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

        // Morph weights buffer texture's backing buffer
        gl.GenBuffers(1, &morph_weights_buf)
        gl.BindBuffer(gl.ARRAY_BUFFER, morph_weights_buf)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(f32) * weights_len, nil, gl.DYNAMIC_DRAW)

        // Morph weights buffer texture
        gl.GenTextures(1, &morph_weights_texture)
        gl.ActiveTexture(gl.TEXTURE1)
        gl.BindTexture(gl.TEXTURE_BUFFER, morph_weights_texture)
        gl.TexBuffer(gl.TEXTURE_BUFFER, gl.R32F, morph_weights_buf)

        gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
        gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

        usage = gl.DYNAMIC_DRAW
    }

    if joints_len != 0 {
        gl.GenBuffers(1, &joint_matrices_buf)
        gl.BindBuffer(gl.ARRAY_BUFFER, joint_matrices_buf)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(m.mat4) * joints_len, nil, gl.DYNAMIC_DRAW)

        gl.GenTextures(1, &joint_matrices_texture)
        gl.ActiveTexture(gl.TEXTURE2)
        gl.BindTexture(gl.TEXTURE_BUFFER, joint_matrices_texture)
        gl.TexBuffer(gl.TEXTURE_BUFFER, gl.RGBA32F, joint_matrices_buf)

        gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
        gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    }

    gl.GenVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)
    gl.GenBuffers(1, &ebo)

    gl.BindVertexArray(vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(Vertex) * len(vertices), raw_data(vertices), usage)

    // positions
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), 0)

    // normals
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), 3 * size_of(f32))

    // texcoords
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, size_of(Vertex), 6 * size_of(f32))

    // tangents
    gl.EnableVertexAttribArray(3)
    gl.VertexAttribPointer(3, 4, gl.FLOAT, gl.FALSE, size_of(Vertex), 8 * size_of(f32))

    // joints
    gl.EnableVertexAttribArray(4)
    gl.VertexAttribIPointer(4, 4, gl.UNSIGNED_INT, size_of(Vertex), 12 * size_of(f32))

    // weights
    gl.EnableVertexAttribArray(5)
    gl.VertexAttribPointer(5, 4, gl.FLOAT, gl.FALSE, size_of(Vertex), 16 * size_of(u32))

    // color
    gl.EnableVertexAttribArray(6)
    gl.VertexAttribPointer(6, 4, gl.FLOAT, gl.FALSE, size_of(Vertex), 20 * size_of(u32))

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(u32) * len(indices), raw_data(indices), gl.STATIC_DRAW)

    return(
        Mesh {
            primitive,
            vertices,
            indices,
            parent,
            material_id,
            make([]f32, weights_len, allocator^),
            morph_texture,
            morph_normals_offset,
            morph_tangents_offset,
            joint_matrices_buf,
            joint_matrices_texture,
            vao,
            vbo,
            ebo,
            morph_weights_buf,
            morph_weights_texture,
            aabb,
        } \
    )
}

@(private = "file")
process_material :: proc(
    material: ^cgltf.material,
    model_path: string,
    textures_map: ^map[cstring]TextureId,
    allocator: ^mem.Allocator,
) -> Material {
    textures := make([dynamic]Texture, 0, 8, allocator^)

    name := strings.clone_from_cstring(material.name, allocator^)
    if material.name == nil {
        delete(name)
        name = fmt.aprintf("Material", allocator = allocator^)
    }
    diffuse := m.vec4(material.pbr_metallic_roughness.base_color_factor)
    specular := m.vec3(material.specular.specular_color_factor)
    emissive := m.vec3(material.emissive_factor)
    shininess := material.specular.specular_factor != 0 ? material.specular.specular_factor : 32.0
    metallic := material.pbr_metallic_roughness.metallic_factor
    roughness := material.pbr_metallic_roughness.roughness_factor

    if material.has_emissive_strength {
        emissive *= material.emissive_strength.emissive_strength
    }

    // TODO: use ior if available to calculate the specular, otherwise default F0 to 0.04
    // TODO: specularGlossiness
    //ior := material.ior.ior

    if material.has_ior {
        log.debugf("ior: %f", material.ior.ior)
    }

    if material.has_specular {
        log.debugf("specular: %f", material.specular.specular_factor)
    }

    diffuse_tex := material.pbr_metallic_roughness.base_color_texture
    normal_tex := material.normal_texture
    emissive_tex := material.emissive_texture
    metallic_roughness_tex := material.pbr_metallic_roughness.metallic_roughness_texture

    if diffuse_tex.texture != nil {
        append(&textures, process_texture(diffuse_tex.texture, .DIFFUSE, model_path, textures_map))
    }

    if normal_tex.texture != nil {
        append(&textures, process_texture(normal_tex.texture, .NORMAL, model_path, textures_map))
    }

    if emissive_tex.texture != nil {
        append(&textures, process_texture(emissive_tex.texture, .EMISSIVE, model_path, textures_map))
    }

    if metallic_roughness_tex.texture != nil {
        append(
            &textures,
            process_texture(metallic_roughness_tex.texture, .METALLIC_ROUGHNESS, model_path, textures_map),
        )
    }

    return(
        Material {
            name,
            diffuse,
            specular,
            emissive,
            shininess,
            metallic,
            roughness,
            textures,
            cast(bool)material.double_sided,
            cast(bool)material.unlit,
            material.alpha_mode,
            material.alpha_cutoff,
        } \
    )
}

load_gltf_model :: proc(
    file_path: string,
) -> (
    Model,
    bool,
) {
    context.logger = logger

    file_path_cstr := strings.clone_to_cstring(file_path)
    defer delete(file_path_cstr)
    node_name_idx = new(int)
    defer free(node_name_idx)
    bone_name_idx = new(int)
    defer free(bone_name_idx)

    start := time.now()
    data, res := cgltf.parse_file(cgltf.options{}, file_path_cstr)
    defer cgltf.free(data)

    if res != .success {
        log.errorf("Failed to load gltf file: \"%s\": %s", file_path, res)
        return Model{}, false
    }

    res = cgltf.load_buffers(cgltf.options{}, data, file_path_cstr)
    if res != .success {
        log.error("Failed to load gltf buffers")
        return Model{}, false
    }

    model, err := virtual.arena_growing_bootstrap_new_by_name(Model, "arena")
    log.assert(err == nil)
    arena_allocator := virtual.arena_allocator(&model.arena)

    nodes := make([]^Node, len(data.scene.nodes), arena_allocator)
    nodes_map := make(map[uintptr]^Node)
    defer delete(nodes_map)
    materials := make(map[uintptr]Material, allocator = arena_allocator)
    textures_map := make(map[cstring]TextureId)
    defer delete(textures_map)
    aabb := AABB{
        min = {math.INF_F32, math.INF_F32, math.INF_F32},
        max = {math.NEG_INF_F32, math.NEG_INF_F32, math.NEG_INF_F32},
    }

    materials[0] = DEFAULT_MATERIAL

    bones := make(map[uintptr]bool)
    defer delete(bones)

    for skin in data.skins {
        for joint in skin.joints {
            node_id := transmute(uintptr)joint
            bones[node_id] = true
        }
    }

    for idx in 0 ..< len(data.scene.nodes) {
        nodes[idx] = process_node(
            data.scene.nodes[idx],
            nil,
            &materials,
            file_path,
            &textures_map,
            &bones,
            &nodes_map,
            &arena_allocator,
        )
    }

    animations := make([]Animation, len(data.animations), arena_allocator)
    for anim, a in data.animations {
        name := strings.clone_from_cstring(anim.name, arena_allocator)
        if anim.name == nil {
            name = fmt.aprintf("Animation %d", a, allocator = arena_allocator)
        }

        animation := Animation {
            name   = name,
            tracks = make([]AnimationTrack, len(anim.channels), arena_allocator),
            timer  = time.Stopwatch{},
        }

        for channel, t in anim.channels {
            if channel.target_node == nil {
                continue
            }

            animation.tracks[t].interpolation = channel.sampler.interpolation

            input := channel.sampler.input
            output := channel.sampler.output

            anim_time := make([]f32, input.count, arena_allocator)
            anim_data: []f32

            // input is always scalar
            process_accessor_scalar_float(input, anim_time)

            animation.max_time = max(anim_time[input.count - 1], animation.max_time)

            #partial switch output.type {
                case .vec4:
                    anim_data = make([]f32, output.count * 4, arena_allocator)
                    process_accessor_vec4(output, anim_data)
                case .vec3:
                    anim_data = make([]f32, output.count * 3, arena_allocator)
                    process_accessor_vec3(output, anim_data)
                case .scalar:
                    anim_data = make([]f32, output.count, arena_allocator)
                    process_accessor_scalar_float(output, anim_data)
                case:
                    log.warnf("Unsupported animation sampler output type: %s", output.type)
            }

            animation.tracks[t].time = anim_time
            animation.tracks[t].data = anim_data
            animation.tracks[t].node = nodes_map[transmute(uintptr)channel.target_node]
            animation.tracks[t].property = channel.target_path
        }

        animations[a] = animation
    }

    log.debugf("Loading model took: %s", time.diff(start, time.now()))

    create_model_aabb(nodes, &aabb)

    model.nodes = nodes
    model.materials = materials
    model.animations = animations
    model.aabb = aabb

    return model^, true
}

create_model_aabb :: proc(nodes: []^Node, aabb: ^AABB) {
    calc_transform_and_aabb :: proc(node: ^Node, aabb: ^AABB, parent_world_transform: m.mat4) {
        transform: m.mat4
        if node.parent != nil {
            transform = parent_world_transform * node_local_transform(node)
        } else {
            transform = node_local_transform(node)
        }

        for mesh in node.meshes {
            for vert in mesh.vertices {
                aabb.min = m.min(aabb.min, vert.position + m.vec3{transform[3][0], transform[3][1], transform[3][2]})
                aabb.max = m.max(aabb.max, vert.position + m.vec3{transform[3][0], transform[3][1], transform[3][2]})
            }
        }

        for child in node.children {
            calc_transform_and_aabb(child, aabb, transform)
        }
    }

    for node in nodes {
        calc_transform_and_aabb(node, aabb, m.identity(m.mat4))
    }
}

@(private)
node_local_transform :: proc(node: ^Node) -> m.mat4 {
    if node.has_transform {
        return node.transform
    } else {
        mat := m.identity(m.mat4)
        mat = m.mat4Scale(node.scale) * mat
        mat = m.mat4FromQuat(node.rotation) * mat
        mat = m.mat4Translate(node.translation) * mat
        return mat
    }
}

node_world_transform :: proc(node: ^Node) -> m.mat4 {
    return node.world_transform
}
