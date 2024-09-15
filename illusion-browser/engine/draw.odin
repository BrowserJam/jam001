package zephr

import "core:fmt"
import "core:log"
import m "core:math/linalg/glsl"
import "core:math"
import "core:slice"
import "core:strings"
import "core:path/filepath"
import "core:time"

import gl "vendor:OpenGL"
import "vendor:stb/image"

// We do 2^0, 2^2, 2^3, 2^4 to get 1, 4, 8, 16 for the corresponding MSAA samples
MSAA_SAMPLES :: enum i32 {
    NONE,
    MSAA_4 = 2,
    MSAA_8,
    MSAA_16,
}

ANTIALIASING :: enum {
    MSAA,
}

@(private = "file")
mesh_shader: ^Shader
@(private = "file")
missing_texture: TextureId
@(private = "file")
multisample_fb: u32
@(private = "file")
depth_texture: TextureId
@(private = "file")
color_texture: TextureId
@(private = "file")
msaa := MSAA_SAMPLES.MSAA_4

change_msaa :: proc(by: int) {
    msaa_int := int(msaa)

    defer {
        log.debug("Setting MSAA to", msaa)
        resize_multisample_fb(cast(i32)zephr_ctx.window.size.x, cast(i32)zephr_ctx.window.size.y)
    }

    msaa_int += by

    if msaa_int == 1 {
        msaa = MSAA_SAMPLES(msaa_int + by)
        return
    }

    if msaa_int < int(MSAA_SAMPLES.NONE) {
        msaa = .MSAA_16
        return
    }

    if msaa_int > int(MSAA_SAMPLES.MSAA_16) {
        msaa = .NONE
        return
    }

    msaa = MSAA_SAMPLES(msaa_int)
}

set_msaa :: proc(sampling: MSAA_SAMPLES) {
    msaa = sampling
}

// FIXME: I think we're doing something wrong when applying the transformation hierarchy
// and that causes the rotations to be "flipped" for entities. But I'm not 100% sure yet tbh

//@(private = "file")
//sort_by_transparency :: proc(i, j: Node) -> bool {
//    sort :: proc(node: Node) -> bool {
//        for mesh in node.meshes {
//            if mesh.material.alpha_mode == .blend {
//                return false
//            }
//        }
//
//        for child in node.children {
//            return sort(child)
//        }
//
//        return true
//    }
//
//    return sort(i)
//}

@(private)
init_renderer :: proc(window_size: m.vec2) {
    l_mesh_shader, success := create_shader(create_resource_path("shaders/mesh.vert"), create_resource_path("shaders/mesh.frag"))

    mesh_shader = l_mesh_shader

    if (!success) {
        log.error("Failed to load mesh shader")
    }

    missing_texture = load_texture(
        "res/textures/missing_texture.png",
        true,
        false,
        gl.REPEAT,
        gl.REPEAT,
        gl.NEAREST,
        gl.NEAREST,
    )

    max_tex_size: i32
    max_tex_arr_size: i32
    gl.GetIntegerv(gl.MAX_TEXTURE_SIZE, &max_tex_size)
    gl.GetIntegerv(gl.MAX_ARRAY_TEXTURE_LAYERS, &max_tex_arr_size)

    log.debugf("Max texture size: %d", max_tex_size)
    log.debugf("Max texture layers: %d", max_tex_arr_size)

    init_aabb()
    init_color_pass(window_size)
}

@(private)
resize_multisample_fb :: proc(width, height: i32) {
    gl.Viewport(0, 0, width, height)
    _msaa := math.pow2_f32(msaa)

    gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, color_texture)
    gl.TexImage2DMultisample(gl.TEXTURE_2D_MULTISAMPLE, i32(_msaa), gl.RGB8, width, height, gl.FALSE)

    gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, depth_texture)
    gl.TexImage2DMultisample(gl.TEXTURE_2D_MULTISAMPLE, i32(_msaa), gl.DEPTH24_STENCIL8, width, height, gl.FALSE)
}

@(private)
init_color_pass :: proc(size: m.vec2) {
    _msaa := 1 << u32(msaa)
    {
        max_samples: i32
        gl.GetIntegerv(gl.MAX_SAMPLES, &max_samples)
        log.debug("MAX MSAA SAMPLES:", max_samples)
    }

    gl.GenTextures(1, &color_texture)
    gl.GenTextures(1, &depth_texture)
    gl.GenFramebuffers(1, &multisample_fb)

    gl.BindFramebuffer(gl.FRAMEBUFFER, multisample_fb)

    // Textures for both the color and depth attachments because renderbuffers just refuse to work
    gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, color_texture)
    gl.TexImage2DMultisample(gl.TEXTURE_2D_MULTISAMPLE, i32(_msaa), gl.RGB8, i32(size.x), i32(size.y), gl.FALSE)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D_MULTISAMPLE, color_texture, 0)

    // There's no need for stencil here but renderdoc crashes when loading a capture if it isn't there.
    gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, depth_texture)
    gl.TexImage2DMultisample(gl.TEXTURE_2D_MULTISAMPLE, i32(_msaa), gl.DEPTH24_STENCIL8, i32(size.x), i32(size.y), gl.FALSE)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.TEXTURE_2D_MULTISAMPLE, depth_texture, 0)

    status := gl.CheckFramebufferStatus(gl.FRAMEBUFFER)
    if status != gl.FRAMEBUFFER_COMPLETE {
        log.errorf("Multisampled color framebuffer is not complete: 0x%X", status)
    }

    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
}

// MUST be called every frame
draw :: proc(entities: []Entity, lights: []Light, camera: ^Camera) {
    color_pass(entities, lights, camera)
}

@(private = "file")
apply_transform_hierarchy :: proc(model: ^Model, model_transform: m.mat4) {
    apply_transform :: proc(node: ^Node) {
        node.world_transform = node_local_transform(node)
        if node.parent != nil {
            node.world_transform = node.parent.world_transform * node.world_transform
        }

        for child in node.children {
            apply_transform(child)
        }
    }

    for node in model.nodes {
        node.world_transform = model_transform * node_local_transform(node)
        if node.parent != nil {
            node.world_transform = node.parent.world_transform * node.world_transform
        }

        for child in node.children {
            apply_transform(child)
        }
    }
}

@(private = "file")
draw_model :: proc(model: ^Model) {
    use_shader(mesh_shader)

    if model.active_animation != nil && model.active_animation.timer.running {
        advance_animation(model.active_animation)
    }

    for node in &model.nodes {
        draw_node(node, &model.materials)
    }
}

@(private = "file")
draw_node :: proc(node: ^Node, materials: ^map[uintptr]Material) {
    joint_matrices: []m.mat4
    defer delete(joint_matrices)

    if len(node.joints) != 0 {
        joint_matrices = make([]m.mat4, len(node.joints))
        for joint, i in node.joints {
            j_transform := node_local_transform(joint)
            if joint.parent != nil {
                j_transform = joint.parent.world_transform * j_transform
            }
            // TODO: skeleton node ??

            joint_matrices[i] = j_transform * node.inverse_bind_matrices[i]
        }
    }

    for mesh in node.meshes {
        draw_mesh(mesh, node.world_transform, materials, joint_matrices)
        //draw_aabb(mesh.aabb, node.world_transform)
    }

    for child in node.children {
        draw_node(child, materials)
    }
}

@(private = "file", disabled = RELEASE_BUILD)
draw_aabb :: proc(aabb: AABB, transform: m.mat4) {
    set_mat4f(mesh_shader, "model", transform)
    set_bool(mesh_shader, "useSkinning", false)

    vertices := []m.vec3{
        aabb.min,
        {aabb.max.x, aabb.min.y, aabb.min.z},
        {aabb.max.x, aabb.max.y, aabb.min.z},
        {aabb.min.x, aabb.max.y, aabb.min.z},
        {aabb.min.x, aabb.min.y, aabb.max.z},
        {aabb.max.x, aabb.min.y, aabb.max.z},
        aabb.max,
        {aabb.min.x, aabb.max.y, aabb.max.z},
    }

    gl.LineWidth(4)
    gl.BindVertexArray(aabb_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, aabb_vbo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(m.vec3) * len(vertices), raw_data(vertices))
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
    gl.DrawElements(gl.TRIANGLES, 36, gl.UNSIGNED_INT, nil)

    gl.BindVertexArray(0)
    gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
    gl.LineWidth(1)
}

@(private = "file", disabled = RELEASE_BUILD)
draw_collision_shape :: proc() {
    // TODO:
}

@(private = "file")
draw_mesh :: proc(mesh: Mesh, transform: m.mat4, materials: ^map[uintptr]Material, joint_matrices: []m.mat4) {
    // TODO: calling set_int a shitton of times is apparently slow according to callgrind
    set_int(mesh_shader, "morphTargets", 0)
    set_int(mesh_shader, "morphTargetWeights", 1)
    set_int(mesh_shader, "jointMatrices", 2)
    set_int(mesh_shader, "material.texture_diffuse", 3)
    set_int(mesh_shader, "material.texture_normal", 4)
    set_int(mesh_shader, "material.texture_metallic_roughness", 5)
    set_int(mesh_shader, "material.texture_emissive", 6)
    // TODO: group all uniforms into a UBO so that we don't have to set a lot of them every frame.
    // No idea if this will have any impact on performance.
    // All these uniforms are baaaaad for performance. Especially conditionals
    // What I see a lot of projects do is set the conditionals as ifdefs in the shader and basically modifying the
    // shader during runtime afaik.
    if mesh.morph_targets_tex != 0 {
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D_ARRAY, mesh.morph_targets_tex)
        set_bool(mesh_shader, "useMorphing", true)
        set_int(mesh_shader, "morphTargetNormalsOffset", cast(i32)mesh.morph_normals_offset)
        set_int(mesh_shader, "morphTargetTangentsOffset", cast(i32)mesh.morph_tangents_offset)
        set_int(mesh_shader, "morphTargetsCount", cast(i32)len(mesh.weights))
        gl.ActiveTexture(gl.TEXTURE1)
        gl.BindTexture(gl.TEXTURE_BUFFER, mesh.morph_weights_tex)
        gl.BindBuffer(gl.ARRAY_BUFFER, mesh.morph_weights_buf)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, len(mesh.weights) * size_of(f32), raw_data(mesh.weights))
    } else {
        set_bool(mesh_shader, "useMorphing", false)
    }

    material := &materials[mesh.material_id]

    if material.double_sided {
        gl.Disable(gl.CULL_FACE)
    } else {
        gl.Enable(gl.CULL_FACE)
    }

    if material.alpha_mode == .blend {
        gl.Enable(gl.BLEND)
        gl.BlendFuncSeparate(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA, gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
        gl.BlendEquation(gl.FUNC_ADD)
    } else {
        gl.Disable(gl.BLEND)
    }

    set_mat4f(mesh_shader, "model", transform)

    set_bool(mesh_shader, "useTextures", len(material.textures) != 0)
    set_vec4fv(mesh_shader, "material.diffuse", material.diffuse)
    set_vec3fv(mesh_shader, "material.specular", material.specular)
    set_vec3fv(mesh_shader, "material.emissive", material.emissive)
    set_float(mesh_shader, "material.shininess", material.shininess)
    set_float(mesh_shader, "material.metallic", material.metallic)
    set_float(mesh_shader, "material.roughness", material.roughness)
    set_bool(mesh_shader, "doubleSided", material.double_sided)
    set_bool(mesh_shader, "unlit", material.unlit)
    set_float(mesh_shader, "alphaCutoff", material.alpha_cutoff)
    set_int(mesh_shader, "alphaMode", cast(i32)material.alpha_mode)
    if len(joint_matrices) != 0 {
        set_bool(mesh_shader, "useSkinning", true)
        gl.ActiveTexture(gl.TEXTURE2)
        gl.BindTexture(gl.TEXTURE_BUFFER, mesh.joint_matrices_tex)
        gl.BindBuffer(gl.ARRAY_BUFFER, mesh.joint_matrices_buf)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(m.mat4) * len(joint_matrices), raw_data(joint_matrices))
    } else {
        set_bool(mesh_shader, "useSkinning", false)
    }

    set_bool(mesh_shader, "hasDiffuseTexture", false)
    set_bool(mesh_shader, "hasNormalTexture", false)
    set_bool(mesh_shader, "hasEmissiveTexture", false)
    set_bool(mesh_shader, "hasMetallicRoughnessTexture", false)

    for texture in material.textures {
        texture_id := texture.id != 0 ? texture.id : missing_texture

        #partial switch texture.type {
            case .DIFFUSE:
                gl.ActiveTexture(gl.TEXTURE3)
                set_bool(mesh_shader, "hasDiffuseTexture", true)
            case .NORMAL:
                gl.ActiveTexture(gl.TEXTURE4)
                set_bool(mesh_shader, "hasNormalTexture", true)
            case .METALLIC_ROUGHNESS:
                gl.ActiveTexture(gl.TEXTURE5)
                set_bool(mesh_shader, "hasMetallicRoughnessTexture", true)
            case .EMISSIVE:
                gl.ActiveTexture(gl.TEXTURE6)
                set_bool(mesh_shader, "hasEmissiveTexture", true)
        }

        gl.BindTexture(gl.TEXTURE_2D, texture_id)
    }

    gl.BindVertexArray(mesh.vao)
    gl.DrawElements(gl.TRIANGLES, cast(i32)len(mesh.indices), gl.UNSIGNED_INT, nil)

    set_bool(mesh_shader, "useTextures", false)

    gl.BindVertexArray(0)
}

draw_lights :: proc(lights: []Light) {
    point_light_idx := 0

    for light in lights {
        if light.type == .DIRECTIONAL {
            use_shader(mesh_shader)
            set_vec3fv(mesh_shader, "dirLight.direction", light.direction)
            set_vec3fv(mesh_shader, "dirLight.diffuse", light.diffuse)
        } else if light.type == .POINT {
            use_shader(mesh_shader)
            pos_c_str := strings.clone_to_cstring(
                fmt.tprintf("pointLights[%d].position", point_light_idx),
                context.temp_allocator,
            )
            set_vec3fv(mesh_shader, pos_c_str, light.position)

            constant_c_str := strings.clone_to_cstring(
                fmt.tprintf("pointLights[%d].constant", point_light_idx),
                context.temp_allocator,
            )
            set_float(mesh_shader, constant_c_str, light.point.constant)
            linear_c_str := strings.clone_to_cstring(
                fmt.tprintf("pointLights[%d].linear", point_light_idx),
                context.temp_allocator,
            )
            set_float(mesh_shader, linear_c_str, light.point.linear)
            quadratic_c_str := strings.clone_to_cstring(
                fmt.tprintf("pointLights[%d].quadratic", point_light_idx),
                context.temp_allocator,
            )
            set_float(mesh_shader, quadratic_c_str, light.point.quadratic)

            diffuse_c_str := strings.clone_to_cstring(
                fmt.tprintf("pointLights[%d].diffuse", point_light_idx),
                context.temp_allocator,
            )
            set_vec3fv(mesh_shader, diffuse_c_str, light.diffuse)

            point_light_idx += 1
        }
    }
}

color_pass :: proc(entities: []Entity, lights: []Light, camera: ^Camera) {
    context.logger = logger

    gl.BindFramebuffer(gl.FRAMEBUFFER, multisample_fb)
    gl.Viewport(0, 0, cast(i32)zephr_ctx.window.size.x, cast(i32)zephr_ctx.window.size.y)
    gl.ClearColor(zephr_ctx.clear_color.r, zephr_ctx.clear_color.g, zephr_ctx.clear_color.b, zephr_ctx.clear_color.a)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    use_shader(mesh_shader)
    set_vec3fv(mesh_shader, "viewPos", camera.position)
    set_mat4f(mesh_shader, "projectionView", camera.proj_mat * camera.view_mat)
    set_bool(mesh_shader, "useTextures", false)

    // sort meshes by transparency for proper alpha blending
    // TODO: also sort by distance for transparent meshes
    // TODO: also sort ALL models first
    if len(entities) > 0 {
        //slice.sort_by(models[0].nodes[:], sort_by_transparency)
        //slice.sort_by(game.models[0].nodes[:], sort_by_distance)
    }

    draw_lights(lights)

    entities := entities

    for &entity in entities {
        model_mat := m.identity(m.mat4)
        model_mat = m.mat4Scale(entity.scale) * model_mat
        model_mat = m.mat4FromQuat(entity.rotation) * model_mat
        model_mat = m.mat4Translate(entity.position) * model_mat

        apply_transform_hierarchy(&entity.model, model_mat)
        draw_model(&entity.model)
        //draw_aabb(entity.model.aabb, entity.model.nodes[0].world_transform)
        //draw_collision_shape()
    }

    size_x := cast(i32)zephr_ctx.window.size.x
    size_y := cast(i32)zephr_ctx.window.size.y

    gl.BindFramebuffer(gl.READ_FRAMEBUFFER, multisample_fb)
    gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0)
    gl.DrawBuffer(gl.BACK)
    gl.BlitFramebuffer(0, 0, size_x, size_y, 0, 0, size_x, size_y, gl.COLOR_BUFFER_BIT, gl.NEAREST)

    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
}

// MUST be called after drawing and before swapping buffers, otherwise you only get the clear color
save_default_framebuffer_to_image :: proc(dir: string = ".", filename: string = "") -> bool {
    filename := filename
    w := i32(zephr_ctx.window.size.x)
    h := i32(zephr_ctx.window.size.y)

    if filename == "" {
        now := time.now()
        year, month, day := time.date(now)
        hour, mins, secs := time.clock_from_time(now)
        filename = fmt.tprintf("%d-%02d-%02d %02d:%02d:%02d.png", year, cast(i32)month, day, hour, mins, secs)
    } else {
        filename = strings.concatenate({filename, ".png"}, context.temp_allocator)
    }

    pixels := make([]u8, w * h * 3)
    defer delete(pixels)
    gl.PixelStorei(gl.PACK_ALIGNMENT, 1)
    gl.ReadPixels(0, 0, w, h, gl.RGB, gl.UNSIGNED_BYTE, raw_data(pixels))
    gl.PixelStorei(gl.PACK_ALIGNMENT, 4)

    final_path := filepath.join({dir, filename})
    cstr := strings.clone_to_cstring(final_path, context.temp_allocator)
    image.flip_vertically_on_write(true)
    return image.write_png(cstr, w, h, 3, raw_data(pixels), w * 3) != 0
}

