package zephr

import "core:container/queue"
import "core:log"
import m "core:math/linalg/glsl"
import "core:path/filepath"
import "core:os"
import "core:strings"

import gl "vendor:OpenGL"

Shader :: struct {
    program:       u32,
    vertex_path:   string,
    geometry_path: string,
    has_geometry: bool,
    fragment_path: string,
}

create_shader :: proc(vertex_path: string, fragment_path: string) -> (^Shader, bool) {
    shader := new(Shader)

    program, ok := gl.load_shaders(vertex_path, fragment_path)
    shader.program = program
    shader.vertex_path = vertex_path
    shader.fragment_path = fragment_path
    shader.has_geometry = false

    append(&zephr_ctx.shaders, shader)

    return shader, ok
}

create_shader_with_geometry :: proc(vs_path, fs_path, geom_path: string) -> (shader: ^Shader, ok: bool) {
    shader = new(Shader)

    // Don't or_return when compiling because we want to be able to hot-reload these shaders if any of them fail to compile.
    // We don't care about hot-reloading if we fail to read the shader file though.

    vs_data := os.read_entire_file(vs_path) or_return
    defer delete(vs_data)

    fs_data := os.read_entire_file(fs_path) or_return
    defer delete(fs_data)

    geom_data := os.read_entire_file(geom_path) or_return
    defer delete(geom_data)

    vs_id, vs_ok := gl.compile_shader_from_source(string(vs_data), gl.Shader_Type.VERTEX_SHADER)
    defer gl.DeleteShader(vs_id)

    fs_id, fs_ok := gl.compile_shader_from_source(string(fs_data), gl.Shader_Type.FRAGMENT_SHADER)
    defer gl.DeleteShader(fs_id)

    geom_id, geom_ok := gl.compile_shader_from_source(string(geom_data), gl.Shader_Type.GEOMETRY_SHADER)
    defer gl.DeleteShader(geom_id)

    program_id := gl.create_and_link_program({vs_id, geom_id, fs_id}) or_return

    shader.program = program_id
    shader.vertex_path = vs_path
    shader.fragment_path = fs_path
    shader.geometry_path = geom_path
    shader.has_geometry = true

    append(&zephr_ctx.shaders, shader)

    return shader, vs_ok && fs_ok && geom_ok
}

@(private, disabled = RELEASE_BUILD)
update_shaders_if_changed :: proc() {
    context.logger = logger

    if queue.len(zephr_ctx.changed_shaders_queue) == 0 {
        return
    }

    file := queue.front_ptr(&zephr_ctx.changed_shaders_queue)
    queue.pop_front(&zephr_ctx.changed_shaders_queue)

    if file != nil {
        for shader in &zephr_ctx.shaders {
            if filepath.base(shader.vertex_path) == file^ || filepath.base(shader.fragment_path) == file^ || filepath.base(shader.geometry_path) == file^ {
                log.debugf("Hot-reloading shaders that depend on \"%s\"", file^)

                program: u32
                ok: bool
                if shader.has_geometry {
                    new_shader, new_shader_ok := create_shader_with_geometry(shader.vertex_path, shader.fragment_path, shader.geometry_path) 
                    ok = new_shader_ok
                    program = new_shader.program
                } else {
                    program, ok = gl.load_shaders(shader.vertex_path, shader.fragment_path)
                }

                if !ok {
                    log.errorf(
                        "Failed to hot-reload shader %d. Vert: %s, Frag: %s",
                        shader.program,
                        shader.vertex_path,
                        shader.fragment_path,
                    )
                }

                gl.DeleteProgram(shader.program)

                shader.program = program
            }
        }
    }
}

use_shader :: proc(shader: ^Shader) {
    gl.UseProgram(shader.program)
}

set_mat4f :: proc(shader: ^Shader, name: cstring, mat4: m.mat4, transpose: bool = false) {
    mat4 := mat4
    loc := gl.GetUniformLocation(shader.program, name)
    gl.UniformMatrix4fv(loc, 1, transpose, raw_data(&mat4))
}

set_mat4fv :: proc(shader: ^Shader, name: cstring, mat4: []m.mat4, transpose: bool = false) {
    mat4 := mat4
    loc := gl.GetUniformLocation(shader.program, name)
    gl.UniformMatrix4fv(loc, cast(i32)len(mat4), transpose, raw_data(&mat4[0]))
}

set_float :: proc(shader: ^Shader, name: cstring, val: f32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform1f(loc, val)
}

set_float_array :: proc(shader: ^Shader, name: cstring, val: []f32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform1fv(loc, cast(i32)len(val), raw_data(val))
}

set_int :: proc(shader: ^Shader, name: cstring, val: i32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform1i(loc, val)
}

set_bool :: proc(shader: ^Shader, name: cstring, val: bool) {
    set_int(shader, name, cast(i32)val)
}

set_vec2f :: proc(shader: ^Shader, name: cstring, val1: f32, val2: f32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform2f(loc, val1, val2)
}

set_vec3f :: proc(shader: ^Shader, name: cstring, val1: f32, val2: f32, val3: f32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform3f(loc, val1, val2, val3)
}

set_vec3fv :: proc(shader: ^Shader, name: cstring, vec: m.vec3) {
    vec := vec
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform3fv(loc, 1, raw_data(&vec))
}

set_vec4f :: proc(shader: ^Shader, name: cstring, val1: f32, val2: f32, val3: f32, val4: f32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform4f(loc, val1, val2, val3, val4)
}

set_vec4fv :: proc(shader: ^Shader, name: cstring, vec: m.vec4) {
    vec := vec
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform4fv(loc, 1, raw_data(&vec))
}
