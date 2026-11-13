#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform float uProgress;  // 0 the old page, 1 the new page
uniform float uMode;      // 0 ink, 1 burn, 2 liquid
uniform vec2 uOrigin;     // where an ink bleed starts, 0..1
uniform sampler2D uChild; // the incoming page

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 x) {
  vec2 i = floor(x);
  vec2 f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
  float a = 0.5;
  float s = 0.0;
  for (int i = 0; i < 4; i++) {
    s += a * noise(p);
    p = p * 2.03 + vec2(17.1, 3.7);
    a *= 0.5;
  }
  return s;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  float aspect = uSize.y / uSize.x;
  vec2 p = vec2(uv.x, uv.y * aspect);
  float prog = uProgress;
  vec4 page;
  float alpha;
  vec4 glow = vec4(0.0);

  if (uMode < 0.5) {
    // Ink soaking outwards through paper from where it was touched.
    vec2 o = vec2(uOrigin.x, uOrigin.y * aspect);
    float far = length(max(o, vec2(1.0, aspect) - o));
    float r = distance(p, o) / far;
    float edge = prog * 1.83 - 0.28 - r -
                 (fbm(p * 5.0 + 3.0) - 0.47) * 0.42 -
                 (fbm(p * 15.0) - 0.47) * 0.12;
    alpha = smoothstep(0.0, 0.03, edge);
    float wet = alpha * (1.0 - smoothstep(0.03, 0.17, edge));
    page = texture(uChild, uv);
    page.rgb = mix(page.rgb, vec3(0.02, 0.025, 0.05), wet * 0.9);
  } else if (uMode < 1.5) {
    // Paper burning away from the bottom edge.
    float n = fbm(p * 4.0) * 0.75 + fbm(p * 13.0) * 0.25;
    float thr = (1.0 - uv.y) * 0.55 + n * 0.45;
    float edge = prog * 1.25 - 0.12 - thr;
    alpha = smoothstep(0.0, 0.008, edge);
    float ember = 1.0 - smoothstep(0.0, 0.06, edge);
    float charred = 1.0 - smoothstep(0.04, 0.17, edge);
    page = texture(uChild, uv);
    page.rgb *= 1.0 - charred * 0.78;
    page.rgb += (vec3(1.0, 0.42, 0.06) * ember * 1.5 +
                 vec3(1.0, 0.86, 0.45) * pow(ember, 5.0)) * alpha;
    // Heat reaching ahead of the flame, onto the old page.
    float ahead = smoothstep(-0.07, 0.0, edge) * (1.0 - alpha);
    glow = vec4(vec3(1.0, 0.36, 0.05) * ahead, ahead) * 0.75;
  } else {
    // A sheet of liquid sliding across, bending the page behind its lip.
    float front = prog * 1.36 - 0.18 +
                  sin(uv.y * 8.0 + prog * 9.0) * 0.035 +
                  sin(uv.y * 21.0 - prog * 15.0) * 0.012;
    float d = front - uv.x;
    alpha = smoothstep(0.0, 0.006, d);
    float squeeze = exp(-max(d, 0.0) * 16.0);
    page = texture(uChild, vec2(min(uv.x + squeeze * 0.07, 1.0), uv.y));
    float lip = exp(-abs(d) * 95.0);
    page.rgb *= 1.0 - 0.28 * exp(-max(d, 0.0) * 30.0) * (1.0 - lip);
    page.rgb += lip * 0.55;
  }

  fragColor = vec4(page.rgb * alpha, page.a * alpha) + glow * (1.0 - alpha);
}
