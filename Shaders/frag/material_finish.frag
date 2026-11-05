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
    vec4 cornerRadii;
    float maskPadding;
    float strength;
    float edgeAmount;
    float lightAmount;
    float chromeAmount;
    float textureAmount;
    float bloomAmount;
    float auroraAmount;
    float paperAmount;
    float pixelScale;
};
layout(binding = 1) uniform sampler2D maskTexture;

float silhouette(vec2 uv, float lod) {
    vec2 size = max(surfaceSize, vec2(1.0));
    vec2 paddedUv = (uv * size + maskPadding) / (size + 2.0 * maskPadding);
    return textureLod(maskTexture, paddedUv, lod).a;
}

// The same per-corner geometry as the native rounded surface, in logical pixels.
float roundedDistance(vec2 p) {
    vec2 halfSize = surfaceSize * 0.5;
    float r = p.y < 0.0 ? (p.x < 0.0 ? cornerRadii.x : cornerRadii.y)
                       : (p.x < 0.0 ? cornerRadii.z : cornerRadii.w);
    r = clamp(r, 0.0, min(halfSize.x, halfSize.y));
    vec2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float scale = max(pixelScale, 0.5);
    vec2 texel = scale / max(surfaceSize, vec2(1.0));
    vec2 normal;
    float rim;
    float diffusion;
    float mask;
    if (cornerRadii.x >= 0.0) {
        vec2 position = (uv - 0.5) * surfaceSize;
        float distance = roundedDistance(position);
        float antialias = max(0.0001, fwidth(distance) * 0.5);
        mask = 1.0 - smoothstep(-antialias, antialias, distance);
        // A wider normal field avoids a crease along a rounded box's medial axis.
        vec2 grad = vec2(roundedDistance(position + vec2(scale, 0.0)) - roundedDistance(position - vec2(scale, 0.0)),
                         roundedDistance(position + vec2(0.0, scale)) - roundedDistance(position - vec2(0.0, scale)));
        normal = grad / max(length(grad), 0.001);
        float depth = max(0.0, -distance) / scale;
        rim = exp(-depth / 3.5);
        diffusion = exp(-depth / 18.0);
        float core = 1.0 - smoothstep(min(surfaceSize.x, surfaceSize.y) * 0.2 / scale,
                                    min(surfaceSize.x, surfaceSize.y) * 0.5 / scale, depth);
        rim *= core;
        diffusion *= core;
    } else {
        mask = silhouette(uv, 0.0);
        // A padded mip pyramid diffuses the actual path, including concave corners
        // and holes. No replacement rectangle or repeated horizontal bands.
        float lod = max(0.0, log2(12.0 * scale));
        vec2 dx = vec2(texel.x * 4.0, 0.0);
        vec2 dy = vec2(0.0, texel.y * 4.0);
        vec2 grad = vec2(silhouette(uv + dx, lod) - silhouette(uv - dx, lod),
                         silhouette(uv + dy, lod) - silhouette(uv - dy, lod));
        normal = -grad / max(length(grad), 0.001);
        rim = clamp(2.0 * (mask - silhouette(uv, max(0.0, log2(3.5 * scale)))), 0.0, 1.0);
        diffusion = clamp(2.0 * (mask - silhouette(uv, lod)), 0.0, 1.0);
    }
    if (mask <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    float facing = dot(normal, normalize(vec2(-0.42, -0.91)));
    vec2 p = uv * surfaceSize / max(pixelScale, 0.5);

    // Static optics: distance from the silhouette, not elevation across the card.
    float grain = hash(floor(p)) - 0.5;
    vec2 keyPosition = (uv - vec2(0.12, 0.08)) * vec2(1.6, 2.0);
    float key = exp(-dot(keyPosition, keyPosition) * 2.0);
    vec2 atmosphereA = (uv - vec2(0.12, 0.12)) * vec2(1.6, 2.4);
    vec2 atmosphereB = (uv - vec2(0.88, 0.78)) * vec2(2.2, 1.6);
    float atmosphere = exp(-dot(atmosphereA, atmosphereA) * 1.8)
                     + 0.7 * exp(-dot(atmosphereB, atmosphereB) * 2.0);
    float chrome = rim * (0.3 + 0.7 * max(facing, 0.0))
                 - diffusion * max(-facing, 0.0) * 0.24;

    // Short, sparsely distributed fibers have independent length and pigment.
    vec2 fiberCell = floor(p / vec2(11.0, 3.0));
    vec2 fiberPos = fract(p / vec2(11.0, 3.0));
    float fiberSeed = hash(fiberCell);
    float fiberLine = abs(fiberPos.y - 0.2 - 0.6 * fiberSeed - (fiberPos.x - 0.5) * (fiberSeed - 0.5) * 0.25);
    float fibers = (1.0 - smoothstep(0.025, 0.14, fiberLine)) * smoothstep(0.0, 0.16, fiberPos.x) * (1.0 - smoothstep(0.55 + 0.4 * fiberSeed, 1.0, fiberPos.x));
    float paper = grain * 0.11 + (fiberSeed - 0.5) * fibers * 0.20;

    float relief = edgeAmount * (rim * facing * 0.35 + diffusion * max(facing, 0.0) * 0.55);
    relief += lightAmount * (key * 0.4 + diffusion * facing * 0.2);
    relief += chromeAmount * chrome * 0.52;
    relief += textureAmount * grain * 0.24;
    relief += paperAmount * paper;
    float bloom = bloomAmount * (diffusion * 0.24 + key * 0.25);
    float aurora = auroraAmount * atmosphere * 0.65;

    vec3 highlight = mix(mix(surfaceColor.rgb, vec3(1.0), 0.8), primaryColor.rgb, bloomAmount * 0.55);
    vec3 shade = mix(surfaceColor.rgb, vec3(0.0), 0.75);
    vec3 pigment = mix(primaryColor.rgb, tertiaryColor.rgb, smoothstep(0.1, 0.9, uv.x + uv.y * 0.25));
    vec3 finish = relief >= 0.0 ? highlight : shade;
    float reliefAlpha = abs(relief) + bloom;
    float alpha = min(0.58, (reliefAlpha + aurora) * strength);
    finish = mix(finish, pigment, aurora / max(reliefAlpha + aurora, 0.0001));
    finish = mix(finish, mix(surfaceColor.rgb, inkColor.rgb, 0.08), paperAmount * 0.18);
    // Compress safe tones without clipping every bright pigment channel to grey.
    float peak = max(finish.r, max(finish.g, finish.b));
    finish *= min(1.0, toneBounds.y / max(peak, 0.0001));
    float trough = min(finish.r, min(finish.g, finish.b));
    finish = mix(finish, vec3(1.0), max(0.0, (toneBounds.x - trough) / max(1.0 - trough, 0.0001)));
    finish = clamp(finish, vec3(toneBounds.x), vec3(toneBounds.y));
    alpha *= mask;
    fragColor = vec4(finish * alpha, alpha) * qt_Opacity;
}
