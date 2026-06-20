shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float snow_amount : hint_range(0.0, 1.0) = 0.5;
uniform float time_shift : hint_range(0.0, 3600.0) = 0.0;

uniform vec2 camera_pos = vec2(0.0);
uniform vec2 viewport_size = vec2(1280.0, 720.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 4; i++) {
		val += amp * noise(p * freq);
		freq *= 2.3;
		amp *= 0.45;
	}
	return val;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 col = texture(screen_texture, uv);

	vec2 world_px = camera_pos + uv * viewport_size;
	vec2 world_uv = world_px / 300.0;

	float patch = fbm(world_uv * 1.0) + snow_amount * 0.2;
	vec3 snow = vec3(0.92, 0.94, 0.98);

	// 底部完全无雪
	float bottom_clamp = 1.0;

	// 主积雪
	float mask  = smoothstep(0.60, 0.75, patch);

	col.rgb = mix(col.rgb, snow, mask * 0.6);

	// 厚积雪
	float heavy = smoothstep(0.4, 0.7, patch) * bottom_clamp;
	
	col.rgb = mix(col.rgb, snow, heavy * 0.85);

	// 极纯白斑点
	float spot = step(2, patch) * bottom_clamp;
	col.rgb = mix(col.rgb, snow, spot * 1.0);

	// ── 飘雪 ──
	float t = time_shift * 0.75;

for(int i = 0; i < 20; i++)
{
	float fi = float(i);

	float seed = fi * 13.37;

	vec2 pos = vec2(
		fract(hash(vec2(seed, 1.0))),
		fract(hash(vec2(seed, 20.0)) + t * (0.05 + fract(seed)*0.1))
	);

	float d = distance(uv, pos);

	float flake = smoothstep(
		0.01,
		0.0,
		d
	);

	col.rgb += flake * 0.4;
}
	COLOR = col;
}
