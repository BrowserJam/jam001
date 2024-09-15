#version 330 core
in vec2 v_TexCoords;
in vec4 textColor;
out vec4 FragColor;

uniform sampler2D text;

const float smoothness = 0.05;
const float outlineDistance = 0.50;
const vec4 outlineColor = vec4(0.0, 0.0, 0.0, 1.0);

void main() {
  //float distance = texture(text, v_TexCoords).r;
  //float outlineFactor = smoothstep(0.5 - smoothness, 0.5 + smoothness, distance);
  //vec4 color = mix(outlineColor, textColor, outlineFactor);
  //float alpha = smoothstep(outlineDistance - smoothness, outlineDistance + smoothness, distance);

  //FragColor = vec4(textColor.rgb, 1.0);

  vec4 sampled = vec4(1.0, 1.0, 1.0, texture(text, v_TexCoords).r);
  FragColor = textColor * sampled;
}
