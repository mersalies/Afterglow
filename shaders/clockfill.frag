#version 440
// Afterglow clock digits: the digits arrive as white text; this paints them
// with a colour or a gradient and draws an outline of any thickness around
// them (the text's coverage widened in 24 directions), also plain or graded.
// Colours come premultiplied, as ShaderEffect passes them.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // item size, px
    vec4 fill1;
    vec4 fill2;
    vec4 line1;
    vec4 line2;
    vec2 dir;         // gradient direction (unit vector)
    float lineWidth;  // outline thickness, px (0 = none)
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    float a = texture(source, uv).a;
    float t = clamp(dot(uv - 0.5, dir) + 0.5, 0.0, 1.0);
    vec4 col = mix(fill1, fill2, t) * a;
    if (lineWidth > 0.0) {
        vec2 px = lineWidth / size;
        float d = a;
        for (int i = 0; i < 24; i++) {
            float ang = float(i) * 0.2617994;
            vec2 o = vec2(cos(ang), sin(ang)) * px;
            d = max(d, texture(source, uv + o).a);
            d = max(d, texture(source, uv + o * 0.5).a);
        }
        col += mix(line1, line2, t) * d * (1.0 - a);
    }
    fragColor = col * qt_Opacity;
}
