shader_type canvas_item;
render_mode unshaded;

uniform vec4 mist_color : source_color = vec4(0.88, 0.94, 1.0, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.24;
uniform float drift_speed = 1.0;
varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
float cloud(vec2 p) {
	return noise(p) * 0.57 + noise(p * 2.03 + 7.4) * 0.28 + noise(p * 4.07 + 19.1) * 0.15;
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	float t = TIME * drift_speed;
	vec2 p = world_pos / vec2(560.0, 155.0);
	vec2 drift = vec2(t * 0.045, -t * 0.012);
	float curl = noise(p * 0.7 + drift * 0.4);
	float near_mist = cloud(p + drift + vec2(curl * 1.5, curl * 0.6));
	float far_mist = cloud(p * vec2(0.55, 1.3) - drift * 0.55 + 32.0);
	float wisps = smoothstep(0.36, 0.68, near_mist) * 0.9
		+ smoothstep(0.4, 0.72, far_mist) * 0.35;
	// 柔边防止地图边界出现矩形截断。
	vec2 map_uv = world_pos / vec2(3760.0, 3360.0);
	vec2 edge = smoothstep(vec2(0.0), vec2(0.035), map_uv)
		* smoothstep(vec2(0.0), vec2(0.035), vec2(1.0) - map_uv);
	COLOR = vec4(mist_color.rgb, wisps * density * edge.x * edge.y);
}
