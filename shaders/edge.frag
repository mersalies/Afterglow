#version 440
// Afterglow edge light: a thin line along a rounded rectangle just inside the
// screen edge, with a narrow halo inwards. Two colours share the perimeter; where
// they meet the light dims softly. `phase` turns the split around the screen and
// sends three bright streaks running along the line; `pulse` (bass) and `flash`
// (beats) brighten the line, and only slightly widen the halo.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float radius;
    float inset;
    float lineWidth;
    float halo;
    float pulse;
    float flash;
    float phase;
    float gain;
    vec4 colorA;
    vec4 colorB;
};

const float TAU = 6.28318530718;

float sdRoundRect(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 c = size * 0.5;
    vec2 p = qt_TexCoord0 * size - c;
    float d = sdRoundRect(p, c - vec2(inset), radius);   // < 0 inside

    float w = lineWidth * (1.0 + 0.35 * pulse + 0.3 * flash);
    float core = exp(-(d * d) / (w * w));
    float h = halo * (1.0 + 0.25 * pulse + 0.2 * flash);
    float inner = exp(min(d, 0.0) / h) * smoothstep(w * 2.0, 0.0, d);

    // Position along the perimeter, 0..1, aspect-corrected so corners sit near 1/8 steps.
    float t0 = atan(p.y / size.y, p.x / size.x) / TAU + 0.5;
    float t = fract(t0 + phase);
    float s = sin(TAU * t);
    vec3 col = mix(colorB.rgb, colorA.rgb, smoothstep(-0.25, 0.25, s));
    float dim = mix(0.2, 1.0, smoothstep(0.0, 0.35, abs(s)));

    // Streaks: a bright head with a fading tail, running twice as fast as the colours.
    float sc = fract(3.0 * t0 + 6.0 * phase);
    float streak = smoothstep(0.0, 0.015, sc) * exp(-sc * 12.0);

    float glow = core * (0.9 + 0.4 * pulse + 0.45 * flash + 0.9 * streak)
               + inner * (0.24 + 0.22 * pulse + 0.18 * flash + 0.25 * streak);
    glow *= mix(dim, 1.0, 0.5 * streak);

    vec3 rgb = mix(col, vec3(1.0), (0.3 + 0.4 * streak) * core * dim);
    float a = clamp(glow * gain, 0.0, 1.0);
    fragColor = vec4(rgb * a, a) * qt_Opacity;
}
