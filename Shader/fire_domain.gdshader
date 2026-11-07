shader_type canvas_item;
render_mode unshaded;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0)),f.x),f.y);
}
float fbm(vec2 p) { return noise(p)*0.57 + noise(p*2.03)*0.28 + noise(p*4.1)*0.15; }
void fragment() {
	vec2 p = UV;
	float x = (p.x - 0.5) * 2.0;
	float height = (0.77 - p.y) / 0.7;
	vec2 flow = vec2(x * 4.2, p.y * 4.0 + TIME * 1.65);
	float warp = fbm(flow + vec2(0.0, TIME*0.2));
	float detail = fbm(flow * 2.7 + vec2(warp * 2.0, TIME * 0.6));
	float curl = x + (warp - 0.5) * (0.18 + max(height,0.0)*0.32);
	// 两侧火舌升腾，内侧也有较矮火焰贴近角色，底部形成椭圆火床。
	float side = exp(-pow((abs(curl)-0.53)/0.25, 2.0));
	float ceiling = 0.28 + side * 0.57 + (warp-0.5)*0.43;
	float taper = smoothstep(0.97,0.66,abs(curl));
	float fire = smoothstep(0.0,0.21,ceiling-height) * taper;
	float underside = smoothstep(0.87,0.73,p.y + x*x*0.08);
	float holes = smoothstep(0.24,0.64,detail + (1.0-height)*0.19);
	float body = fire * underside * holes;
	float ground = exp(-pow((length(vec2(x, (p.y-0.76)*5.0))-0.65)/0.21,2.0))*0.16;
	float hot = clamp((1.0-height)*0.58 + detail*0.64,0.0,1.0);
	vec3 color = mix(vec3(0.88,0.055,0.008),vec3(1.0,0.42,0.035),smoothstep(0.2,0.63,hot));
	color = mix(color,vec3(1.0,0.88,0.36),smoothstep(0.72,1.0,hot));
	float alpha = clamp(body * 0.69 + ground,0.0,0.78);
	COLOR = vec4(color,alpha);
}
