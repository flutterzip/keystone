#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform float uTime;
uniform float uAmplitude;   // how far a crest pushes pixels
uniform float uSpeed;       // how fast a ring travels, px per second
uniform float uWavelength;
// Each ripple: where it started and when. A negative time means unused.
uniform vec3 uR0;
uniform vec3 uR1;
uniform vec3 uR2;
uniform vec3 uR3;
uniform vec3 uR4;
uniform vec3 uR5;
uniform sampler2D uChild;

out vec4 fragColor;

// Adds one ring's push to xy and its glint to z.
vec3 ring(vec2 frag, vec3 r) {
  if (r.z < 0.0) return vec3(0.0);
  float age = uTime - r.z;
  vec2 d = frag - r.xy;
  float dist = length(d) + 0.001;
  float x = dist - age * uSpeed;
  float width = uWavelength * 0.95;
  float envelope = exp(-x * x / (2.0 * width * width));
  float life = exp(-age * 1.5) * smoothstep(0.0, 0.07, age);
  float phase = x / uWavelength * 6.2831853;
  return vec3(d / dist * sin(phase), cos(phase)) * envelope * life;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec3 sum = ring(frag, uR0) + ring(frag, uR1) + ring(frag, uR2) +
             ring(frag, uR3) + ring(frag, uR4) + ring(frag, uR5);
  vec2 uv = clamp((frag + sum.xy * uAmplitude) / uSize, 0.0, 1.0);
  vec4 c = texture(uChild, uv);
  // Crests catch the light, troughs fall into shade.
  c.rgb += sum.z * 0.11 * c.a * min(uAmplitude / 12.0, 1.5);
  fragColor = c;
}
