#version 330 core
layout (location = 0) in vec2 vertex;

// per instance
layout (location = 1) in vec4 offset; // x,y = position, z,w = size
layout (location = 2) in vec4 tex_coords1; // Coords for vertex 0 and 1
layout (location = 3) in vec4 tex_coords2; // Coords for vertex 2 and 3
layout (location = 4) in vec4 color;
layout (location = 5) in mat4 model; // this takes locations 5,6,7,8

out vec2 v_TexCoords;
out vec4 textColor;
uniform mat4 projection;

void main() {
  vec2 pos = vec2((vertex.x) * offset.z, (vertex.y) * offset.w);
  gl_Position = projection * model * vec4(pos + offset.xy, 0.0, 1.0);

  if (gl_VertexID == 0) {
    v_TexCoords = tex_coords1.xy;
  } else if (gl_VertexID == 1) {
    v_TexCoords = tex_coords1.zw;
  } else if (gl_VertexID == 2) {
    v_TexCoords = tex_coords2.xy;
  } else if (gl_VertexID == 3) {
    v_TexCoords = tex_coords2.zw;
  }

  textColor = color;
}
