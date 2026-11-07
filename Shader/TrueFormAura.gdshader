shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float gather = smoothstep(0.0, 0.22, progress);
	float fade = 1.0 - smoothstep(0.55, 1.0, progress);
	float spiral = pow(max(0.0, sin(a * 3.0 + r * 13.0 + progress * 22.0)), 12.0);
	float veil = exp(-pow((r - mix(0.72, 0.30, smoothstep(0.0, 0.43, progress))) * 5.5, 2.0));
	float spokes = pow(max(0.0, sin(a * 9.0 - progress * 7.0)), 22.0);
	float reveal = exp(-pow((progress - 0.414) * 24.0, 2.0));
	float shock_radius = mix(0.14, 0.94, smoothstep(0.40, 0.78, progress));
	float ring = exp(-abs(r - shock_radius) * 65.0) * smoothstep(0.38, 0.44, progress);
	float edge = 1.0 - smoothstep(0.86, 1.0, r);
	float energy = ((spiral * 0.65 + 0.055) * veil * gather + spokes * reveal * 0.45 + ring * 0.70) * fade * edge;
	vec3 color = mix(vec3(1.0, 0.15, 0.035), vec3(1.0, 0.81, 0.32), clamp(spiral + reveal, 0.0, 1.0));
	COLOR = vec4(color, energy);
}
