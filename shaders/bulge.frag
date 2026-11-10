#version 440
// Afterglow "ball" lyrics: a lens that bulges the text block as if it were
// printed on a ball. Inside the ellipse around `center` the picture is
// magnified towards the middle and squeezed towards the rim; outside it is
// left alone. `strength` 0..1 sets how round the ball is.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;       // item size, px
    vec2 center;     // ball centre, px
    vec2 radius;     // ball half-extents, px
    float strength;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 px = qt_TexCoord0 * size;
    vec2 p = (px - center) / radius;          // -1..1 inside the ball
    float r = length(p);
    vec2 uv = qt_TexCoord0;
    if (r < 1.0) {
        // Sample closer to the centre in the middle (magnify) and catch up at the
        // rim, like a sphere seen from the front: r' = r^(1 + strength).
        float rr = pow(r, 1.0 + strength);
        vec2 q = r > 0.0001 ? p * (rr / r) : p;
        uv = (center + q * radius) / size;
    }
    fragColor = texture(source, uv) * qt_Opacity;
}
