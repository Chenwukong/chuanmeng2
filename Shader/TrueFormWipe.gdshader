shader_type canvas_item;
render_mode unshaded;
uniform float cut_y = 0.0;
uniform bool new_form = false;
varying float world_y;
void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}
void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	float revealed = smoothstep(cut_y - 1.0, cut_y + 1.0, world_y);
	float mask = new_form ? revealed : 1.0 - revealed;
	float edge = exp(-abs(world_y - cut_y) * 0.4);
	color.rgb = mix(color.rgb, vec3(1.0, 0.83, 0.36) * 1.6, edge * 0.85);
	color.a *= mask;
	COLOR = color;
}
