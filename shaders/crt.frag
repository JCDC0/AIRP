#version 460 core
#include <flutter/runtime_effect.glsl>

// Subtle CRT treatment for the chat background layer.
//
// Applied to the background image only, never to chat text: barrel distortion
// on glyphs bows the baseline and softens stems, which hurts long-form reading.
//
// uIntensity scales every artifact together so a single slider moves the whole
// look from "barely there" to "old monitor" without any stage running away.

// Uniform order is load-bearing: setFloat() indices are assigned in declaration
// order, so uSize occupies 0-1, uTexScale 2-3, uTexOffset 4-5, and so on.
uniform vec2 uSize;       // Layer size in pixels.
uniform vec2 uTexScale;   // Screen UV -> texture UV, BoxFit.cover.
uniform vec2 uTexOffset;  // Centring offset for the same mapping.
uniform float uIntensity; // 0..1 master strength.
uniform float uTime;      // Seconds, for the drifting scanline roll.
uniform sampler2D uTexture;

out vec4 fragColor;

const float kMaxBarrel = 0.28;
const float kMaxAberration = 0.0042;
const float kMaxScanline = 0.13;
const float kMaxVignette = 0.55;

// Barrel (fisheye) warp about the centre of the layer.
vec2 barrel(vec2 uv, float amount) {
    vec2 centred = uv * 2.0 - 1.0;
    float r2 = dot(centred, centred);
    centred *= 1.0 + amount * r2;
    return centred * 0.5 + 0.5;
}

// Screen-space UV to texture-space UV, preserving the image aspect ratio.
vec2 toTexture(vec2 uv) {
    return uv * uTexScale + uTexOffset;
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

    // Chromatic aberration: the colour channels miss convergence further from
    // the centre, exactly as a real shadow mask does. The offset is applied in
    // screen space, then mapped, so it stays uniform across aspect ratios.
    vec2 fromCentre = warped - 0.5;
    vec2 offset = fromCentre * kMaxAberration * k;
    vec3 color = vec3(
        texture(uTexture, toTexture(warped + offset)).r,
        texture(uTexture, toTexture(warped)).g,
        texture(uTexture, toTexture(warped - offset)).b
    );

    // Scanlines in physical pixels so the pitch does not change with layer
    // size, plus a slow vertical roll to keep it from looking like a static
    // texture overlay.
    float linePhase = (warped.y * uSize.y) * 3.14159265 + uTime * 0.6;
    float scan = 1.0 - kMaxScanline * k * (0.5 + 0.5 * sin(linePhase));
    color *= scan;

    // Aperture grille: dim every third subpixel column very slightly.
    float grille = 1.0 - 0.04 * k * step(1.5, mod(FlutterFragCoord().x, 3.0));
    color *= grille;

    // Vignette toward the corners of the tube.
    float vig = 1.0 - kMaxVignette * k * dot(fromCentre, fromCentre) * 1.6;
    color *= clamp(vig, 0.0, 1.0);

    // A trace of lift, because phosphor never reaches true black.
    color += 0.012 * k;

    fragColor = vec4(color, 1.0);
}
