#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 surfaceSize;
    vec2 toneBounds;
    vec4 surfaceColor;
    vec4 inkColor;
    vec4 primaryColor;
    vec4 tertiaryColor;
    float lightAmount;
    float chromeAmount;
    float textureAmount;
    float bloomAmount;
    float auroraAmount;
    float paperAmount;
    float pixelScale;
};
layout(binding = 1) uniform sampler2D maskTexture;

float silhouette(vec2 uv) {
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0))))
        return 0.0;
    return texture(maskTexture, uv).a;
}

float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float mask = silhouette(uv);
    if (mask <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 texel = max(pixelScale, 0.5) / max(surfaceSize, vec2(1.0));
    vec2 dx = vec2(texel.x, 0.0);
    vec2 dy = vec2(0.0, texel.y);
    vec2 gradient = vec2(silhouette(uv + dx) - silhouette(uv - dx),
                         silhouette(uv + dy) - silhouette(uv - dy));
    vec2 broadGradient = vec2(silhouette(uv + 5.0 * dx) - silhouette(uv - 5.0 * dx),
                              silhouette(uv + 5.0 * dy) - silhouette(uv - 5.0 * dy));
    float edge = clamp(length(gradient), 0.0, 1.0);
    float halo = clamp(length(broadGradient), 0.0, 1.0);
    vec2 normal = -gradient / max(length(gradient), 0.001);
    float facing = dot(normal, normalize(vec2(-0.55, -0.83)));
    float broadFacing = dot(-broadGradient / max(length(broadGradient), 0.001), normalize(vec2(-0.55, -0.83)));
    vec2 p = uv * surfaceSize / max(pixelScale, 0.5);

    // Spatial-only optics: no clock, noise texture, blur or persistent buffer.
    float grain = hash(floor(p)) - 0.5;
    float scanline = sin(p.y * 3.14159265);
    float band = sin(uv.y * 16.0 + uv.x * 3.0);
    float chrome = pow(max(0.0, band), 14.0) - 0.36 * pow(max(0.0, -band), 5.0);
    float ribbon = exp(-pow((uv.y - 0.35 - 0.16 * sin(uv.x * 5.0)) * 5.0, 2.0));

    // Short, sparsely distributed fibers have independent length and pigment.
    vec2 fiberCell = floor(p / vec2(11.0, 3.0));
    vec2 fiberPos = fract(p / vec2(11.0, 3.0));
    float fiberSeed = hash(fiberCell);
    float fiberLine = abs(fiberPos.y - 0.2 - 0.6 * fiberSeed - (fiberPos.x - 0.5) * (fiberSeed - 0.5) * 0.25);
    float fibers = (1.0 - smoothstep(0.025, 0.14, fiberLine)) * smoothstep(0.0, 0.16, fiberPos.x) * (1.0 - smoothstep(0.55 + 0.4 * fiberSeed, 1.0, fiberPos.x));
    float paper = grain * 0.11 + (fiberSeed - 0.5) * fibers * 0.20;

    float relief = lightAmount * (edge * facing * 0.14 + halo * broadFacing * 0.025);
    relief += chromeAmount * (chrome * 0.34 + edge * facing * 0.22);
    relief += textureAmount * (grain * 0.065 + scanline * chromeAmount * 0.03);
    relief += paperAmount * paper;
    float bloom = bloomAmount * (halo * 0.13 + max(chrome, 0.0) * 0.13);
    float aurora = auroraAmount * ribbon * 0.18;

    vec3 highlight = mix(mix(surfaceColor.rgb, vec3(1.0), 0.75), primaryColor.rgb, bloomAmount * 0.45);
    vec3 shade = mix(surfaceColor.rgb, vec3(0.0), 0.65);
    // The palette supplies pigment; physical shading supplies surface relief.
    vec3 pigment = mix(primaryColor.rgb, tertiaryColor.rgb, smoothstep(0.0, 1.0, uv.x));
    vec3 finish = relief >= 0.0 ? highlight : shade;
    float reliefAlpha = abs(relief) + bloom;
    float alpha = min(0.42, reliefAlpha + aurora);
    finish = mix(finish, pigment, aurora / max(reliefAlpha + aurora, 0.0001));
    finish = mix(finish, mix(surfaceColor.rgb, inkColor.rgb, 0.08), paperAmount * 0.18);
    // Limit even chrome and bloom to the current reading roles' safe tones.
    finish = clamp(finish, vec3(toneBounds.x), vec3(toneBounds.y));
    alpha *= mask;
    fragColor = vec4(finish * alpha, alpha) * qt_Opacity;
}
