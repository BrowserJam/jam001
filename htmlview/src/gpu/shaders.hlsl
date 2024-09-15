cbuffer ViewConstants : register(b0) {
  row_major float4x4 cameraToClip;
}

struct ObjectConstants {};

cbuffer SurfaceConstants : register(b1) {}

cbuffer BatchConstants : register(b2) {}

struct VertexOut {
  float4 position : SV_POSITION;

  float2 uv : TEXCOORD0;
  float4 color0 : COLOR0;
};

SamplerState samplerBilinear : register(s0);

Texture2D texImage : register(t0);

static const float PI = 3.14159265359f;

VertexOut vs_main(float2 position: POSITION,
                  float2 texcoord0: TEXCOORD0,
                  float4 color0: COLOR0) {
  VertexOut ret;
  ret.position = mul(float4(position, 0, 1), cameraToClip);
  ret.uv = texcoord0;
  ret.color0 = color0;
  return ret;
}

// Pixel shaders

float4 ps_main(VertexOut input) : SV_TARGET {
  float mask = texImage.Sample(samplerBilinear, input.uv).r;
  return float4(input.color0.rgb, input.color0.a * mask);
}
