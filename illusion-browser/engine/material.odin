// +private
package zephr

import m "core:math/linalg/glsl"
import "vendor:cgltf"

Material :: struct {
    name:         string,
    diffuse:      m.vec4,
    specular:     m.vec3,
    emissive:     m.vec3,
    shininess:    f32,
    metallic:     f32,
    roughness:    f32,
    textures:     [dynamic]Texture,
    double_sided: bool,
    unlit:        bool,
    alpha_mode:   cgltf.alpha_mode,
    alpha_cutoff: f32,
}

DEFAULT_MATERIAL :: Material {
    name         = "default_material",
    diffuse      = m.vec4{1.0, 0.5, 0.2, 1.0},
    specular     = m.vec3{0.2, 0.2, 0.2},
    emissive     = m.vec3{0.0, 0.0, 0.0},
    shininess    = 32.0,
    metallic     = 1,
    roughness    = 1,
    textures     = nil,
    double_sided = false,
    unlit        = true,
    alpha_mode   = .opaque,
    alpha_cutoff = 0.5,
}
