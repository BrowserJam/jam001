#version 330 core

in vec2 v_TexCoords;
out vec4 FragColor;

uniform vec4 aColor;
uniform float borderRadius;
uniform float uiWidth;
uniform float uiHeight;
uniform bool hasTexture;

uniform sampler2D tex;

const float smoothness = 0.7;

void main() {
  float alpha = aColor.a;

  if (borderRadius > 0.0) {
    vec2 dimensions = v_TexCoords * vec2(uiWidth, uiHeight);
    float xMax = uiWidth - borderRadius;
    float yMax = uiHeight - borderRadius;

    if (dimensions.x < borderRadius && dimensions.y < borderRadius) {
      alpha *= 1.0 - smoothstep(borderRadius - smoothness, borderRadius + smoothness, length(dimensions - vec2(borderRadius)));
    } else if (dimensions.x < borderRadius && dimensions.y > yMax) {
      alpha *= 1.0 - smoothstep(borderRadius - smoothness, borderRadius + smoothness, length(dimensions - vec2(borderRadius, yMax)));
    } else if (dimensions.x > xMax && dimensions.y < borderRadius) {
      alpha *= 1.0 - smoothstep(borderRadius - smoothness, borderRadius + smoothness, length(dimensions - vec2(xMax, borderRadius)));
    } else if (dimensions.x > xMax && dimensions.y > yMax) {
      alpha *= 1.0 - smoothstep(borderRadius - smoothness, borderRadius + smoothness, length(dimensions - vec2(xMax, yMax)));
    }
  }

  if (hasTexture) {
    FragColor = texture(tex, v_TexCoords) * vec4(aColor.rgb, alpha);
  } else {
    FragColor = vec4(aColor.rgb, alpha);
  }
}
