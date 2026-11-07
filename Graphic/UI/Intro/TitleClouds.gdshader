shader_type canvas_item;
render_mode unshaded;

uniform sampler2D cloud_noise : filter_linear, repeat_enable;

float cloud_density(vec2 point) {
	float broad = texture(cloud_noise, point).r;
	float detail = texture(cloud_noise, point * 2.7 + vec2(0.34, 0.18)).r;
	return smoothstep(0.40, 0.74, broad * 0.80 + detail * 0.20);
}

void fragment() {
	vec2 uv = UV;
	float sky_band = 1.0 - smoothstep(0.0, 0.22, abs(uv.y - 0.21));
	float cliff_band = smoothstep(0.43, 0.97, uv.x) * (1.0 - smoothstep(0.04, 0.32, abs(uv.y - 0.58)));
	float foreground = smoothstep(0.54, 0.98, uv.y);
	float far_cloud = cloud_density(uv * vec2(1.3, 2.7) + vec2(-TIME * 0.017, 0.13));
	float near_cloud = cloud_density(uv * vec2(1.04, 2.15) + vec2(0.21 - TIME * 0.036, -TIME * 0.003));
	float far_alpha = far_cloud * (sky_band * 0.18 + cliff_band * 0.38);
	float near_alpha = near_cloud * foreground * 0.48;
	float opacity = 1.0 - (1.0 - far_alpha) * (1.0 - near_alpha);
	vec3 tint = mix(vec3(0.70, 0.84, 0.95), vec3(0.93, 0.98, 1.0), near_cloud);
	COLOR = vec4(tint, opacity);
}
