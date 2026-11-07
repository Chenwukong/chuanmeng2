shader_type canvas_item;
render_mode unshaded;
uniform mat3 cube_basis;

float box_sdf(vec3 p) {
	vec3 q = abs(p) - vec3(0.86);
	return length(max(q, vec3(0.0))) + min(max(q.x, max(q.y,q.z)),0.0) - 0.14;
}
float dot_at(vec2 uv, vec2 at) { return 1.0-smoothstep(0.115,0.14,length(uv-at)); }
float pips(vec2 uv, int face) {
	float value = 0.0;
	if (face == 1 || face == 3 || face == 5) value += dot_at(uv,vec2(0.0));
	if (face >= 2) value += dot_at(uv,vec2(-0.44,-0.44))+dot_at(uv,vec2(0.44,0.44));
	if (face >= 4) value += dot_at(uv,vec2(-0.44,0.44))+dot_at(uv,vec2(0.44,-0.44));
	if (face == 6) value += dot_at(uv,vec2(-0.44,0.0))+dot_at(uv,vec2(0.44,0.0));
	return clamp(value,0.0,1.0);
}
void fragment() {
	vec2 screen = (UV-vec2(0.5))*vec2(2.0,-2.0);
	mat3 inv_basis = transpose(cube_basis);
	vec3 ro = inv_basis*vec3(0.0,0.0,5.0);
	vec3 rd = inv_basis*normalize(vec3(screen*2.0,-5.0));
	float t = 0.0;
	bool hit = false;
	vec3 p = ro;
	for(int i=0;i<64;i++) {
		p=ro+rd*t;
		float d=box_sdf(p);
		if(d<0.001) {hit=true;break;}
		t+=d;
		if(t>9.0) break;
	}
	vec4 color=vec4(0.0);
	if(hit) {
		vec2 e=vec2(0.002,0.0);
		vec3 n=normalize(vec3(box_sdf(p+e.xyy)-box_sdf(p-e.xyy),box_sdf(p+e.yxy)-box_sdf(p-e.yxy),box_sdf(p+e.yyx)-box_sdf(p-e.yyx)));
		vec3 wn=cube_basis*n;
		vec2 face_uv=p.xy;
		int face=p.z>0.0?1:6;
		if(abs(p.x)>abs(p.y)&&abs(p.x)>abs(p.z)) {face_uv=p.zy;face=p.x>0.0?3:4;}
		else if(abs(p.y)>abs(p.z)) {face_uv=p.xz;face=p.y>0.0?2:5;}
		float ink=pips(face_uv,face)*smoothstep(0.9,0.99,max(abs(n.x),max(abs(n.y),abs(n.z))));
		vec3 light=normalize(vec3(-0.6,0.9,1.4));
		float diffuse=0.45+0.55*max(0.0,dot(wn,light));
		vec3 ivory=vec3(0.88,0.94,1.0)*diffuse;
		float spec=pow(max(0.0,dot(reflect(-light,wn),vec3(0.0,0.0,1.0))),32.0)*0.28;
		vec3 surface=mix(ivory,vec3(0.035,0.10,0.20)*diffuse,ink);
		color=vec4(surface+spec*(1.0-ink),1.0);
	}
	COLOR=color;
}
