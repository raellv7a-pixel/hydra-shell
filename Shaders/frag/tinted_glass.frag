#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 toneBounds;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 pixel = texture(source, qt_TexCoord0);
    vec3 paper = pixel.rgb / max(pixel.a, 0.0001);
    // Compress only tones that would wash out the current palette's ink.
    // Scaling toward black/white retains wallpaper chroma without another blur.
    float peak = max(paper.r, max(paper.g, paper.b));
    paper *= min(1.0, toneBounds.y / max(peak, 0.0001));
    float trough = min(paper.r, min(paper.g, paper.b));
    paper = mix(paper, vec3(1.0), max(0.0, (toneBounds.x - trough) / max(1.0 - trough, 0.0001)));
    fragColor = vec4(paper * pixel.a, pixel.a) * qt_Opacity;
}
