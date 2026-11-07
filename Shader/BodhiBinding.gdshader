shader_type canvas_item;
render_mode unshaded, blend_add;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float rings = exp(-abs(r - 0.70) * 70.0) + exp(-abs(r - 0.85) * 85.0) * 0.6;
	float runes = pow(max(0.0, cos(a * 12.0 + TIME * 0.6)), 18.0) * exp(-abs(r - 0.77) * 65.0);
	float cross = exp(-abs(p.x) * 22.0) * smoothstep(0.87, 0.3, abs(p.y)) * 0.25;
	float band_mask = 1.0 - smoothstep(0.68, 0.9, abs(p.y));
	float helix = exp(-abs(p.x - sin(p.y * 9.0 + TIME * 0.9) * 0.6) * 45.0) * band_mask;
	float reverse = exp(-abs(p.x + sin(p.y * 9.0 + TIME * 0.9) * 0.6) * 45.0) * band_mask;
	float mask = (rings + runes + cross + (helix + reverse) * 0.55) * (0.85 + sin(TIME * 4.0) * 0.15);
	COLOR = vec4(0.45, 0.85, 1.0, mask);
}
