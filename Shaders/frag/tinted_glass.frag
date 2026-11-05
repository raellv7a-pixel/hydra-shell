#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 toneBounds;
    vec2 sourceSize;
    vec2 maskSize;
    mat4 maskFromSource;
    mat4 sourceFromMask;
    float refractionAmount;
    float saturation;
    float pixelScale;
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D maskTexture;

float silhouette(vec2 uv) {
    float reach = max(1.0, 8.0 * pixelScale);
    vec2 inset = min(uv, 1.0 - uv) * maskSize;
    float boundary = smoothstep(-reach, reach, min(inset.x, inset.y));
    return textureLod(maskTexture, clamp(uv, vec2(0.0), vec2(1.0)), log2(reach)).a * boundary;
}

void main() {
    vec2 sampleUv = qt_TexCoord0;
    if (refractionAmount > 0.0) {
        vec2 local = (maskFromSource * vec4(sampleUv * sourceSize, 0.0, 1.0)).xy;
        vec2 uv = local / max(maskSize, vec2(1.0));
        vec2 dx = vec2(16.0 * pixelScale / max(maskSize.x, 1.0), 0.0);
        vec2 dy = vec2(0.0, 16.0 * pixelScale / max(maskSize.y, 1.0));
        vec2 gradient = vec2(silhouette(uv + dx) - silhouette(uv - dx),
                             silhouette(uv + dy) - silhouette(uv - dy));
        // Bend only the existing shared wallpaper texture, not the painted ink.
        // Local mask normals also work at holes and disconnected panel bodies.
        vec2 centered = clamp(uv, vec2(0.0), vec2(1.0)) * 2.0 - 1.0;
        vec2 lens = centered * max(0.0, 1.0 - dot(centered, centered) * 0.5) * 8.0;
        vec2 offset = (gradient * 24.0 + lens) * pixelScale * clamp(refractionAmount, 0.0, 1.0);
        vec2 sourceOffset = (sourceFromMask * vec4(offset, 0.0, 0.0)).xy;
        sampleUv = clamp(sampleUv + sourceOffset / max(sourceSize, vec2(1.0)), vec2(0.0), vec2(1.0));
    }
    vec4 pixel = texture(source, sampleUv);
    vec3 paper = pixel.rgb / max(pixel.a, 0.0001);
    float luminance = dot(paper, vec3(0.2126, 0.7152, 0.0722));
    paper = clamp(mix(vec3(luminance), paper, clamp(saturation, 0.0, 2.0)), vec3(0.0), vec3(1.0));
    // Preserve spatial contrast even in bright scenes: clipping every highlight
    // to the same ceiling erased the signal that blur and refraction act on.
    // The affine map stays inside both reading bounds, after all optical changes.
    paper = mix(vec3(toneBounds.x), vec3(toneBounds.y), paper);
    fragColor = vec4(paper * pixel.a, pixel.a) * qt_Opacity;
}
