#version 330 core

in vec2 v_TexCoords;
out vec4 FragColor;

uniform bool isSlider;
uniform float sliderPercentage;

vec3 hsv2rgb(vec3 color){
  vec3 rgb = clamp(abs(mod(color.r * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
  rgb = rgb * rgb * (3.0 - 2.0 * rgb);
  return color.b * mix(vec3(1.0), rgb, color.g);
}

void main() {
  if (isSlider) {
    vec3 color = hsv2rgb(vec3(v_TexCoords.y, 1.0, 1.0));
    FragColor = vec4(color, 1.0);
  } else {
    vec3 color = hsv2rgb(vec3(sliderPercentage, v_TexCoords.x, 1.0 - v_TexCoords.y));
    FragColor = vec4(color, 1.0);
  }
}
