#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// Set by the engine: size of the backdrop texture, in physical pixels.
uniform vec2 uSize;
uniform float uDpr;
// Shapes are rounded boxes: xy centre, zw half size, in global logical px.
uniform vec4 uBody;
uniform float uBodyRadius;
uniform vec4 uLens;
uniform float uLensRadius;
uniform vec4 uSatellite;
uniform float uSatelliteRadius;
uniform float uBlend;       // how far apart two shapes start to fuse
uniform float uThickness;   // width of the curved rim
uniform float uRefraction;  // how far the rim bends what is behind it
uniform float uDispersion;  // colour fringing, as a fraction of the bend
uniform float uBlur;        // frost radius
uniform float uLensPower;   // 0 resting pill, 1 full magnifier
uniform vec4 uTint;
uniform vec2 uLight;
uniform float uSaturation;
uniform float uShadow;
uniform sampler2D uTexture;

out vec4 fragColor;

float sdRoundBox(vec2 p, vec4 box, float r) {
  if (box.z <= 0.0) return 1.0e5;
  vec2 q = abs(p - box.xy) - box.zw + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float smin(float a, float b, float k) {
  if (k <= 0.0) return min(a, b);
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

float scene(vec2 p) {
  float d = sdRoundBox(p, uBody, uBodyRadius);
  d = smin(d, sdRoundBox(p, uSatellite, uSatelliteRadius), uBlend);
  d = smin(d, sdRoundBox(p, uLens, uLensRadius), uBlend);
  return d;
}

float lensOnly(vec2 p) { return sdRoundBox(p, uLens, uLensRadius); }

vec3 tap(vec2 q) { return texture(uTexture, q * uDpr / uSize).rgb; }

float grain(vec2 p) {
  return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

vec3 frost(vec2 q, float radius, float spin) {
  if (radius < 0.3) return tap(q);
  vec3 acc = vec3(0.0);
  for (int i = 0; i < 12; i++) {
    float fi = float(i);
    float r = sqrt((fi + 0.5) / 12.0) * radius;
    float a = fi * 2.39996 + spin;
    acc += tap(q + vec2(cos(a), sin(a)) * r);
  }
  return acc / 12.0;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = frag / uDpr;
  vec4 base = texture(uTexture, frag / uSize);

  float d = scene(p);

  // Soft contact shadow under the glass.
  float ds = scene(p - vec2(0.0, 7.0));
  float shadow = uShadow * (1.0 - smoothstep(-8.0, 26.0, ds));
  vec3 outside = base.rgb * (1.0 - shadow);

  if (d > 1.0) {
    fragColor = vec4(outside, base.a);
    return;
  }

  // Outward normal of the silhouette.
  vec2 e = vec2(1.0, 0.0);
  vec2 g = vec2(scene(p + e.xy) - scene(p - e.xy),
                scene(p + e.yx) - scene(p - e.yx));
  vec2 n = g / max(length(g), 1.0e-4);

  // 0 on the rim, 1 where the slab is flat.
  float t = clamp(-d / uThickness, 0.0, 1.0);
  float bend = pow(1.0 - t, 2.4);
  vec2 disp = -n * bend * uRefraction;

  // The inner lens: its own rim, and a magnifier while it is lifted.
  float dl = lensOnly(p);
  float inLens = 1.0 - smoothstep(-1.0, 1.0, dl);
  float tl = 1.0;
  vec2 nl = vec2(0.0);
  if (dl < 1.0) {
    vec2 gl = vec2(lensOnly(p + e.xy) - lensOnly(p - e.xy),
                   lensOnly(p + e.yx) - lensOnly(p - e.yx));
    nl = gl / max(length(gl), 1.0e-4);
    float lensRim = min(uThickness, min(uLens.z, uLens.w));
    tl = clamp(-dl / lensRim, 0.0, 1.0);
    float lbend = pow(1.0 - tl, 2.2);
    disp += -nl * lbend * uRefraction * 0.9 * uLensPower * inLens;
    disp += (uLens.xy - p) * 0.16 * uLensPower * smoothstep(0.0, 1.0, tl) * inLens;
  }

  float spin = grain(frag) * 6.2831853;
  float blur = uBlur * mix(1.0, 0.25, uLensPower * inLens);
  vec3 col = frost(p + disp, blur, spin);
  // Colour fringing only costs two more taps: shift red and blue apart.
  float fringe = uDispersion * (1.0 + 1.5 * uLensPower * inLens);
  vec3 mid = tap(p + disp);
  col.r += tap(p + disp * (1.0 + fringe)).r - mid.r;
  col.b += tap(p + disp * (1.0 - fringe)).b - mid.b;

  float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
  col = mix(vec3(lum), col, uSaturation);
  col = mix(col, uTint.rgb, uTint.a * mix(1.0, 0.35, uLensPower * inLens));

  // Light catching the rim: a strong edge facing the light, a softer one
  // opposite, the way a thick pane shows both.
  vec2 L = normalize(uLight);
  float facing = dot(n, L);
  float rim = pow(1.0 - t, 7.0);
  float spec = rim * (pow(max(facing, 0.0), 1.6) * 0.5 +
                      pow(max(-facing, 0.0), 2.2) * 0.24);
  float hair = smoothstep(1.3, 0.0, abs(d + 0.9));
  col += spec;
  col += hair * (0.08 + 0.34 * abs(facing));
  col += 0.03 * (1.0 - t);

  // The resting pill is a faint lighter capsule with its own hairline.
  float lfacing = dot(nl, L);
  float lhair = smoothstep(1.4, 0.0, abs(dl + 0.9));
  float lrim = pow(1.0 - tl, 5.0);
  col = mix(col, vec3(1.0), 0.11 * inLens * (1.0 - 0.6 * uLensPower));
  col += lhair * (0.07 + 0.30 * abs(lfacing)) * mix(0.55, 1.0, uLensPower);
  col += lrim * inLens * uLensPower *
         (pow(max(lfacing, 0.0), 1.6) * 0.7 + pow(max(-lfacing, 0.0), 2.2) * 0.35);

  float aa = 1.0 - smoothstep(-0.75, 0.75, d);
  fragColor = vec4(mix(outside, col, aa), base.a);
}
