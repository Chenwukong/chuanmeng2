shader_type canvas_item;

uniform float blur_size : hint_range(0.0, 10.0) = 600.0;

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE * blur_size;
	vec4 col = texture(TEXTURE, UV);
	col += texture(TEXTURE, UV + vec2(ps.x, 0.0));
	col += texture(TEXTURE, UV - vec2(ps.x, 0.0));
	col += texture(TEXTURE, UV + vec2(0.0, ps.y));
	col += texture(TEXTURE, UV - vec2(0.0, ps.y));
	col += texture(TEXTURE, UV + vec2(ps.x, ps.y));
	col += texture(TEXTURE, UV - vec2(ps.x, ps.y));
	col += texture(TEXTURE, UV + vec2(ps.x, -ps.y));
	col += texture(TEXTURE, UV - vec2(ps.x, -ps.y));
	COLOR = col / 9.0;
}
