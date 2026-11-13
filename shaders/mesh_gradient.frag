#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform float uTime;
uniform vec3 uTouch;   // xy position (0..1), z strength
uniform vec3 uC0;
uniform vec3 uC1;
uniform vec3 uC2;
uniform vec3 uC3;
uniform float uGrain;

out vec4 fragColor;

float hash(vec2 p) {
  return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

mat2 rot(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat2(c, -s, s, c);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float aspect = uSize.x / uSize.y;
  vec2 q = vec2(frag.x / uSize.x * aspect, frag.y / uSize.y);
  float t = uTime;

  // A finger stirs the field like a spoon in paint.
  vec2 touch = vec2(uTouch.x * aspect, uTouch.y);
  vec2 d = q - touch;
  float pull = uTouch.z * exp(-dot(d, d) * 7.0);
  q = touch + rot(pull * 2.4) * d * (1.0 - 0.25 * pull);

  // Slow folds, two scales.
  q += 0.13 * vec2(sin(q.y * 2.3 + t * 0.70), cos(q.x * 2.1 - t * 0.60));
  q += 0.05 * vec2(sin(q.y * 5.1 - t * 1.10), cos(q.x * 4.7 + t * 0.90));

  // Four colour sources drifting on their own orbits.
  vec2 p0 = vec2(0.20 * aspect + 0.16 * sin(t * 0.31), 0.18 + 0.12 * cos(t * 0.27));
  vec2 p1 = vec2(0.82 * aspect + 0.14 * cos(t * 0.23), 0.30 + 0.16 * sin(t * 0.36));
  vec2 p2 = vec2(0.30 * aspect + 0.18 * cos(t * 0.29 + 2.0), 0.78 + 0.12 * sin(t * 0.22));
  vec2 p3 = vec2(0.78 * aspect + 0.15 * sin(t * 0.26 + 1.0), 0.84 + 0.10 * cos(t * 0.33));

  float w0 = 1.0 / pow(dot(q - p0, q - p0) + 0.02, 1.4);
  float w1 = 1.0 / pow(dot(q - p1, q - p1) + 0.02, 1.4);
  float w2 = 1.0 / pow(dot(q - p2, q - p2) + 0.02, 1.4);
  float w3 = 1.0 / pow(dot(q - p3, q - p3) + 0.02, 1.4);
  vec3 col = (uC0 * w0 + uC1 * w1 + uC2 * w2 + uC3 * w3) / (w0 + w1 + w2 + w3);

  col += pull * 0.10;
  col += (hash(frag) - 0.5) * uGrain;
  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
