shader_type canvas_item;

uniform float softness : hint_range(0.0, 0.2) = 0.02; // edge feather

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // UV is 0..1. Center circle at (0.5, 0.5)
    vec2 p = UV - vec2(0.5);
    float dist = length(p);

    // radius 0.5 fits inside the rect
    float radius = 0.5;

    // smooth edge
    float alpha = 1.0 - smoothstep(radius - softness, radius, dist);

    COLOR = vec4(tex.rgb, tex.a * alpha);
}
