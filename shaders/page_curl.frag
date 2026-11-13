#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform vec2 uFold;    // a point on the fold line, px
uniform vec2 uDir;     // unit vector across the fold, towards the lifted side
uniform float uRadius; // radius of the roll, px. Zero means lying flat.
uniform sampler2D uChild;

out vec4 fragColor;

const float PI = 3.14159265;

bool onPage(vec2 q) {
  return q.x >= 0.0 && q.y >= 0.0 && q.x <= uSize.x && q.y <= uSize.y;
}

// How far outside the page a point is, in px. Zero when on it.
float outside(vec2 q) {
  vec2 d = max(max(-q, q - uSize), 0.0);
  return length(d);
}

// The underside of the sheet: clean paper, a touch lighter than the face,
// with only a ghost of the print showing through.
vec4 back(vec2 q, float light) {
  vec4 c = texture(uChild, q / uSize);
  vec3 ink = c.a > 0.0 ? c.rgb / c.a : vec3(1.0);
  float ghost = dot(ink, vec3(0.3, 0.6, 0.1));
  vec3 paper = vec3(0.985, 0.975, 0.95) * mix(0.955, 1.0, ghost) * light;
  return vec4(paper * c.a, c.a);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  if (uRadius <= 0.0) {
    fragColor = texture(uChild, p / uSize);
    return;
  }
  float r = uRadius;
  float dist = dot(p - uFold, uDir);
  vec2 line = p - dist * uDir;

  if (dist > r) {
    // The sheet has lifted clear. Only its shadow falls here.
    float s = 0.38 * exp(-(dist - r) / (r * 1.1));
    fragColor = vec4(0.0, 0.0, 0.0, s);
    return;
  }

  if (dist >= 0.0) {
    // On the roll. The far side of the cylinder shows the underside.
    float th = asin(dist / r);
    float steep = pow(dist / r, 3.0);
    vec2 pb = line + uDir * (PI - th) * r;
    if (onPage(pb)) {
      fragColor = back(pb, mix(1.0, 0.62, steep));
      return;
    }
    vec2 pf = line + uDir * th * r;
    if (onPage(pf)) {
      vec4 c = texture(uChild, pf / uSize);
      fragColor = vec4(c.rgb * mix(1.0, 0.55, steep), c.a);
      return;
    }
    fragColor = vec4(0.0, 0.0, 0.0, 0.2);
    return;
  }

  // Still flat. The turned sheet may be lying over this spot.
  vec2 pb = line + uDir * (PI * r - dist);
  if (onPage(pb)) {
    // Brightest where it lies flat, shaded where it climbs into the roll.
    float lift = smoothstep(0.0, r * 2.2, -dist);
    fragColor = back(pb, mix(0.84, 1.0, lift));
    return;
  }
  vec4 c = texture(uChild, p / uSize);
  // The roll shades the page just ahead of it, and the turned sheet drops
  // a soft shadow round its own edge, which is what lifts it off the page.
  float shade = 0.22 * exp(dist / (r * 1.4));
  shade = max(shade, 0.30 * exp(-outside(pb) / 16.0));
  fragColor = vec4(c.rgb * (1.0 - shade), c.a);
}
