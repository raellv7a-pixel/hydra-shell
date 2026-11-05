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
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D maskTexture;

float silhouette(vec2 uv) {
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0))))
        return 0.0;
    return texture(maskTexture, uv).a;
}

void main() {
    vec2 sampleUv = qt_TexCoord0;
    if (refractionAmount > 0.0) {
        vec2 local = (maskFromSource * vec4(sampleUv * sourceSize, 0.0, 1.0)).xy;
        vec2 uv = local / max(maskSize, vec2(1.0));
        vec2 dx = vec2(4.0 / max(maskSize.x, 1.0), 0.0);
        vec2 dy = vec2(0.0, 4.0 / max(maskSize.y, 1.0));
        vec2 gradient = vec2(silhouette(uv + dx) - silhouette(uv - dx),
                             silhouette(uv + dy) - silhouette(uv - dy));
        // Bend only the existing shared wallpaper texture, not the painted ink.
        // Local mask normals also work at holes and disconnected panel bodies.
        vec2 lens = sin(clamp(uv, vec2(0.0), vec2(1.0)) * 6.2831853) * 0.65;
        vec2 offset = (gradient * 7.0 + lens) * clamp(refractionAmount, 0.0, 1.0);
        vec2 sourceOffset = (sourceFromMask * vec4(offset, 0.0, 0.0)).xy;
        sampleUv = clamp(sampleUv + sourceOffset / max(sourceSize, vec2(1.0)), vec2(0.0), vec2(1.0));
    }
    vec4 pixel = texture(source, sampleUv);
    vec3 paper = pixel.rgb / max(pixel.a, 0.0001);
    float luminance = dot(paper, vec3(0.2126, 0.7152, 0.0722));
    paper = clamp(mix(vec3(luminance), paper, clamp(saturation, 0.0, 2.0)), vec3(0.0), vec3(1.0));
    // Apply contrast limits after refraction and saturation, preserving alpha.
    float peak = max(paper.r, max(paper.g, paper.b));
    paper *= min(1.0, toneBounds.y / max(peak, 0.0001));
    float trough = min(paper.r, min(paper.g, paper.b));
    paper = mix(paper, vec3(1.0), max(0.0, (toneBounds.x - trough) / max(1.0 - trough, 0.0001)));
    fragColor = vec4(paper * pixel.a, pixel.a) * qt_Opacity;
}
