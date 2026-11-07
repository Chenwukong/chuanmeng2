shader_type canvas_item;
render_mode unshaded;
void fragment() {
	float distance_from_center = length((UV - vec2(0.5)) * 2.0);
	COLOR *= vec4(0.015, 0.035, 0.07, (1.0 - smoothstep(0.1, 1.0, distance_from_center)) * 0.48);
}
