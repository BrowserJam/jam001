#version 330 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec2 texCoords;
layout (location = 3) in vec4 tangent;
layout (location = 4) in uvec4 joint;
layout (location = 5) in vec4 weight;
layout (location = 6) in vec4 color;

out vec3 fragPos;
out vec3 fragNormal;
out vec2 fragTexCoords;
out vec4 vertColor;
out mat3 TBN;

uniform mediump sampler2DArray morphTargets;
uniform mediump samplerBuffer morphTargetWeights;
uniform mediump samplerBuffer jointMatrices;
uniform mat4 model;
uniform mat4 projectionView;
uniform bool useMorphing;
uniform bool useSkinning;
uniform int morphTargetNormalsOffset;
uniform int morphTargetTangentsOffset;
uniform int morphTargetsCount;

mat4 getSkinMat() {
    int xIdx = int(joint.x) * 4;
    int yIdx = int(joint.y) * 4;
    int zIdx = int(joint.z) * 4;
    int wIdx = int(joint.w) * 4;

    vec4 xRow0 = texelFetch(jointMatrices, xIdx);
    vec4 xRow1 = texelFetch(jointMatrices, xIdx + 1);
    vec4 xRow2 = texelFetch(jointMatrices, xIdx + 2);
    vec4 xRow3 = texelFetch(jointMatrices, xIdx + 3);
    mat4 xMat = mat4(xRow0, xRow1, xRow2, xRow3);

    vec4 yRow0 = texelFetch(jointMatrices, yIdx);
    vec4 yRow1 = texelFetch(jointMatrices, yIdx + 1);
    vec4 yRow2 = texelFetch(jointMatrices, yIdx + 2);
    vec4 yRow3 = texelFetch(jointMatrices, yIdx + 3);
    mat4 yMat = mat4(yRow0, yRow1, yRow2, yRow3);

    vec4 zRow0 = texelFetch(jointMatrices, zIdx);
    vec4 zRow1 = texelFetch(jointMatrices, zIdx + 1);
    vec4 zRow2 = texelFetch(jointMatrices, zIdx + 2);
    vec4 zRow3 = texelFetch(jointMatrices, zIdx + 3);
    mat4 zMat = mat4(zRow0, zRow1, zRow2, zRow3);

    vec4 wRow0 = texelFetch(jointMatrices, wIdx);
    vec4 wRow1 = texelFetch(jointMatrices, wIdx + 1);
    vec4 wRow2 = texelFetch(jointMatrices, wIdx + 2);
    vec4 wRow3 = texelFetch(jointMatrices, wIdx + 3);
    mat4 wMat = mat4(wRow0, wRow1, wRow2, wRow3);

    mat4 skinMat = weight.x * xMat +
               weight.y * yMat +
               weight.z * zMat +
               weight.w * wMat;

    return skinMat;
}

void main() {
    vec3 pos = position;
    vec3 norm = normal;
    vec4 tan = tangent;

    if (useMorphing) {
        int texSize = textureSize(morphTargets, 0)[0];
        int x = gl_VertexID % texSize;
        int y = (gl_VertexID - x) / texSize;
        for (int i = 0; i < morphTargetsCount; i++) {
            float weight = texelFetch(morphTargetWeights, i).x;
            if (weight == 0.0f) {
                continue;
            }

            vec3 morphedPos = texelFetch(morphTargets, ivec3(x, y, i), 0).xyz;
            pos += morphedPos * weight;

            if (morphTargetNormalsOffset != 0) {
                vec3 morphedNorm = texelFetch(morphTargets, ivec3(x, y, i + morphTargetNormalsOffset), 0).xyz;
                norm += morphedNorm * weight;
            }

            if (morphTargetTangentsOffset != 0) {
                vec3 morphedTan = texelFetch(morphTargets, ivec3(x, y, i + morphTargetTangentsOffset), 0).xyz;
                tan.xyz += morphedTan * weight;
            }
        }
    }

    mat4 modelMat = model;

    if (useSkinning) {
        modelMat = getSkinMat();
        // TODO: apparently normals have their own skinning matrix, fix that.
        //fragNormal = mat3(transpose(inverse(skinMat))) * norm;
    }

    gl_Position = projectionView * modelMat * vec4(pos, 1.0f);
    fragNormal = mat3(transpose(inverse(modelMat))) * norm;
    fragPos = vec3(modelMat * vec4(pos, 1.0));
    fragTexCoords = texCoords;
    vertColor = color;

    // TODO: More efficient way of calculating the normal maps by moving most of the processing from the frag shader
    // to the vert shader, check learnopengl.com
    vec3 T = normalize(vec3(modelMat * vec4(tan.xyz, 0.0)));
    vec3 N = normalize(vec3(modelMat * vec4(norm, 0.0)));
    // re-orthogonalize T with respect to N
    T = normalize(T - dot(T, N) * N);
    vec3 B = cross(N, T) * tan.w;
    TBN = mat3(T, B, N);
}
