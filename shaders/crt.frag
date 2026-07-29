#version 460 core
#include <flutter/runtime_effect.glsl>

// CRT treatment applied to the whole chat surface: background, particles and
// text alike.
//
// The dominant artifact is analog fuzz, not geometry. A composite signal loses
// horizontal bandwidth, so detail smears along the scan direction, bright areas
// bloom into their neighbours, and colour separates slightly. Curvature is only
// a faint hint here: cranking barrel distortion is what makes an effect read as
// a fisheye wallpaper rather than a screen, so it is capped low on purpose and
// every other stage carries the look.

// Uniform order is load-bearing: setFloat() indices follow declaration order,
// so uSize occupies 0-1, uIntensity 2, uTime 3.
uniform vec2 uSize;       // Layer size in logical pixels.
uniform float uIntensity; // 0..1 master strength.
uniform float uTime;      // Seconds, for the scanline roll and noise.
uniform sampler2D uTexture;

out vec4 fragColor;

// Deliberately small. Curvature should be felt, not seen.
const float kMaxBarrel = 0.045;

const float kMaxSmear = 2.6;      // Horizontal bandwidth loss, in pixels.
const float kMaxAberration = 1.7; // Colour separation, in pixels.
const float kMaxBloom = 0.42;     // Glow bleed from bright areas.
const float kMaxScanline = 0.16;
const float kMaxGrille = 0.10;
const float kMaxVignette = 0.85;
const float kMaxNoise = 0.045;

vec2 barrel(vec2 uv, float amount) {
    vec2 centred = uv * 2.0 - 1.0;
    float r2 = dot(centred, centred);
    centred *= 1.0 + amount * r2;
    return centred * 0.5 + 0.5;
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Seven-tap horizontal blur. Weights sum to 1, so flat areas keep their value
// and only detail is lost, which is what limited bandwidth actually does.
vec4 smear(vec2 uv, float px) {
    vec2 d = vec2(px / uSize.x, 0.0);
    vec4 c = vec4(0.0);
    c += texture(uTexture, uv - 3.0 * d) * 0.06;
    c += texture(uTexture, uv - 2.0 * d) * 0.12;
    c += texture(uTexture, uv - 1.0 * d) * 0.20;
    c += texture(uTexture, uv) * 0.24;
    c += texture(uTexture, uv + 1.0 * d) * 0.20;
    c += texture(uTexture, uv + 2.0 * d) * 0.12;
    c += texture(uTexture, uv + 3.0 * d) * 0.06;
    return c;
}

// Wide four-tap sample used as the bloom source.
vec3 haze(vec2 uv, float r) {
    vec2 dx = vec2(r / uSize.x, 0.0);
    vec2 dy = vec2(0.0, r / uSize.y);
    vec3 c = texture(uTexture, uv + dx).rgb;
    c += texture(uTexture, uv - dx).rgb;
    c += texture(uTexture, uv + dy).rgb;
    c += texture(uTexture, uv - dy).rgb;
    return c * 0.25;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    float k = clamp(uIntensity, 0.0, 1.0);

    vec2 warped = barrel(uv, kMaxBarrel * k);

    // Outside the tube the glass is black rather than a smeared edge clamp.
    if (warped.x < 0.0 || warped.x > 1.0 || warped.y < 0.0 || warped.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec4 base = smear(warped, kMaxSmear * k);
    float alpha = base.a;

    // Colour separation grows toward the edges, as convergence error does.
    vec2 fromCentre = warped - 0.5;
    vec2 ca = fromCentre * (kMaxAberration * k) / uSize.x * 2.0;
    vec3 color = vec3(
        texture(uTexture, warped + ca).r,
        base.g,
        texture(uTexture, warped - ca).b
    );

    // Bloom: only what is already bright bleeds outward.
    vec3 glow = haze(warped, 2.0 + 4.0 * k);
    color += max(glow - 0.32, 0.0) * kMaxBloom * k;

    // Scanlines in physical pixels, so the pitch does not change with layer
    // size, plus a slow roll so it does not read as a static texture.
    float linePhase = warped.y * uSize.y * 3.14159265 + uTime * 0.6;
    color *= 1.0 - kMaxScanline * k * (0.5 + 0.5 * sin(linePhase));

    // Aperture grille: every third subpixel column sits slightly darker.
    color *= 1.0 - kMaxGrille * k * step(1.5, mod(FlutterFragCoord().x, 3.0));

    // Analog grain, resampled every frame.
    float n = hash(warped * uSize + vec2(uTime * 60.0, uTime * 37.0));
    color += (n - 0.5) * kMaxNoise * k;

    // Vignette toward the corners of the tube.
    float vig = 1.0 - kMaxVignette * k * dot(fromCentre, fromCentre) * 1.5;
    color *= clamp(vig, 0.0, 1.0);

    // A trace of lift, because phosphor never reaches true black.
    color += 0.014 * k;

    // Source is premultiplied, so keep the invariant rgb <= a after bloom.
    color = clamp(color, vec3(0.0), vec3(alpha));
    fragColor = vec4(color, alpha);
}
