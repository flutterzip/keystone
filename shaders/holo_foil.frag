#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform vec2 uTilt;      // -1..1 on each axis
uniform float uTime;
uniform float uFoil;     // overall strength
uniform float uPattern;  // 0 prism, 1 glitter, 2 engraved
uniform float uEmboss;
uniform sampler2D uChild;

out vec4 fragColor;

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

vec3 spectrum(float t) {
  return 0.5 + 0.5 * cos(6.2831853 * (t + vec3(0.0, 0.33, 0.67)));
}

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
  float n = hash21(p);
  return vec2(n, hash21(p + n + 17.17));
}

float childLuma(vec2 uv) {
  vec4 c = texture(uChild, uv);
  return luma(c.rgb);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  vec4 base = texture(uChild, uv);
  if (base.a < 0.003) {
    fragColor = vec4(0.0);
    return;
  }
  vec3 col = base.rgb / base.a;
  float l0 = luma(col);

  // Relief: treat brightness as height and light it from the tilt.
  vec2 px = 1.4 / uSize;
  vec2 grad = vec2(
    childLuma(uv + vec2(px.x, 0.0)) - childLuma(uv - vec2(px.x, 0.0)),
    childLuma(uv + vec2(0.0, px.y)) - childLuma(uv - vec2(0.0, px.y)));
  vec2 light = normalize(vec2(-0.35, -0.55) + uTilt * 1.4);
  float relief = dot(grad, -light);
  col += relief * uEmboss;

  // Foil. Work in square units so patterns do not stretch.
  vec2 p = frag / uSize.x;
  float aspect = uSize.y / uSize.x;
  float hue;
  float shine;

  if (uPattern < 0.5) {
    // Prism: broad diagonal bands cut by a fine ruled grating.
    hue = p.x * 0.85 + p.y * 0.55 + dot(uTilt, vec2(0.95, 0.75)) +
          0.05 * sin(p.y * 46.0 + uTilt.x * 7.0);
    float ruled = 0.5 + 0.5 * sin((p.x - p.y) * 260.0);
    float band = 0.5 + 0.5 * sin((p.x + p.y * 0.6) * 9.0 - dot(uTilt, vec2(5.0, 4.0)));
    shine = mix(0.45, 1.0, ruled) * mix(0.55, 1.0, band);
  } else if (uPattern < 1.5) {
    // Glitter: every flake has its own facing and flashes when the tilt
    // lines up with it.
    vec2 cell = floor(frag / 4.0);
    vec2 facing = hash22(cell) * 2.0 - 1.0;
    float catchLight = 1.0 - length(facing - uTilt * 1.15) * 1.25;
    float flake = pow(max(catchLight, 0.0), 3.0);
    float twinkle = 0.75 + 0.25 * sin(uTime * 3.0 + hash21(cell + 3.1) * 40.0);
    hue = hash21(cell + 9.7) * 0.6 + p.x * 0.5 + p.y * 0.4 + dot(uTilt, vec2(0.6, 0.5));
    shine = 0.16 + flake * 3.2 * twinkle;
  } else {
    // Engraved: rings of fine line work, like a banknote.
    vec2 c = vec2(0.5, aspect * 0.42);
    vec2 d = p - c;
    float r = length(d);
    float a = atan(d.y, d.x);
    float lines = 0.5 + 0.5 * sin(r * 420.0 + 7.0 * sin(a * 9.0) + 3.0 * sin(a * 4.0 - r * 30.0));
    hue = r * 2.2 - a * 0.159 + dot(uTilt, vec2(0.9, 0.7));
    float sweep = 0.5 + 0.5 * cos(a * 2.0 - atan(uTilt.y, uTilt.x) * 2.0);
    shine = mix(0.25, 1.0, lines) * mix(0.4, 1.0, sweep * min(length(uTilt) * 2.0, 1.0) + 0.3);
  }

  vec3 holo = spectrum(hue);
  // Bright parts of the artwork carry the foil; the dark ground only a sheen.
  float mask = uFoil * mix(0.30, 1.0, smoothstep(0.28, 0.78, l0));
  float k = clamp(mask * shine, 0.0, 1.0);
  col = mix(col, col * (0.35 + holo * 1.9) + holo * 0.20, k);

  // A soft hot spot that slides across as the card turns.
  vec2 hot = vec2(0.5) + uTilt * vec2(0.48, 0.42);
  vec2 hd = (uv - hot) * vec2(1.0, aspect);
  float glare = exp(-dot(hd, hd) * 5.5);
  col += glare * (0.10 + 0.22 * l0 + 0.10 * holo);
  col *= 1.0 - 0.14 * (1.0 - glare) * length(uTilt);

  fragColor = vec4(clamp(col, 0.0, 1.0) * base.a, base.a);
}
