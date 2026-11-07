shader_type canvas_item;
render_mode unshaded;

uniform vec4 aura_color : source_color = vec4(0.3, 0.8, 0.3, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float spread : hint_range(0.5, 2.0) = 1.0;
uniform float grade : hint_range(0.0, 4.0) = 0.0;
uniform float breathing : hint_range(0.0, 0.15) = 0.06;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float pulse = 1.0 + breathing * sin(TIME * 1.8);
	float drift = 0.06 * sin(angle * 3.0 + TIME * 0.5) + 0.04 * sin(angle * 5.0 - TIME * 0.35);
	float haze = exp(-pow(radius / ((0.62 + drift) * spread), 2.0) * 1.3);
	float soft_light = exp(-pow(radius / (0.48 * spread), 2.0) * 1.6);
	float high_grade = smoothstep(1.0, 4.0, grade);
	float rays = pow(max(0.0, cos(angle * 7.0 + TIME * 0.7)), 10.0);
	rays *= smoothstep(0.2, 0.5, radius) * (1.0 - smoothstep(0.55, 0.95, radius));
	float spark_radius = 0.58 + 0.10 * sin(angle * 3.0 + TIME * 0.6);
	float sparks = pow(max(0.0, cos(angle * 5.0 - TIME * 1.2)), 70.0);
	sparks *= exp(-pow((radius - spark_radius) / 0.045, 2.0)) * high_grade;
	float alpha = (haze * 1.15 + soft_light * 0.25 + rays * high_grade * 0.42 + sparks * 0.75) * strength * pulse;
	alpha *= 1.0 - smoothstep(0.75, 1.0, radius);
	vec3 saturated = max(aura_color.rgb - vec3(0.1), vec3(0.0));
	vec3 light = mix(saturated, vec3(1.0, 0.99, 0.94), clamp((soft_light * 0.45 + sparks) * strength, 0.0, 0.9));
	COLOR = vec4(light, clamp(alpha, 0.0, 0.95));
}
