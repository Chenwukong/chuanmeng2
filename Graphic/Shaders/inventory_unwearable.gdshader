shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(gray * 0.8), tex.a * 0.72) * COLOR;
}
