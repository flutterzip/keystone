#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform vec4 uBody;   // xy centre, zw half size
uniform float uBodyRadius;
uniform vec3 uSat;    // xy centre, z radius
uniform float uBlend;

out vec4 fragColor;

float sdRoundBox(vec2 p, vec4 box, float r) {
  vec2 q = abs(p - box.xy) - box.zw + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float smin(float a, float b, float k) {
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

float scene(vec2 p) {
  float d = sdRoundBox(p, uBody, uBodyRadius);
  if (uSat.z > 0.5) d = smin(d, length(p - uSat.xy) - uSat.z, uBlend);
  return d;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float d = scene(p);
  float body = 1.0 - smoothstep(-0.75, 0.75, d);
  // A soft shadow, so it lifts off whatever is behind.
  float shadow = 0.30 * (1.0 - smoothstep(0.0, 26.0, scene(p - vec2(0.0, 6.0))));
  // The faintest lit edge.
  float rim = smoothstep(1.6, 0.0, abs(d + 1.0)) * 0.11;
  vec3 col = vec3(rim) * body;
  float a = max(body, shadow * (1.0 - body));
  fragColor = vec4(col, a);
}
