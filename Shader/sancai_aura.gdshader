shader_type canvas_item;
render_mode unshaded;
uniform float stroke_scale = 1.0;
float segment(vec2 p,vec2 a,vec2 b) {
	vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0));
}
float ink(float distance) {return 1.0-smoothstep(0.002,0.0055,max(distance,0.0));}
float circle(float r,float at,float width) {return 1.0-smoothstep(width,width+0.003,abs(r-at));}
void fragment() {
	vec4 tint=COLOR;
	vec2 p=(UV-vec2(0.5))*2.0;
	float r=length(p),a=atan(p.y,p.x);
	float pulse=0.9+0.1*sin(TIME*1.3);
	float rim=circle(r,0.83,0.0025)+circle(r,0.805,0.001)+circle(r,0.975,0.001);
	float glow=exp(-pow((r-0.83)/0.028,2.0))*0.25;
	float inner=circle(r,0.665,0.0015);
	float tracers=pow(max(0.0,cos(a-TIME*0.48)),50.0)+pow(max(0.0,cos(a-TIME*0.48-3.14159)),50.0);
	float flow=tracers*exp(-pow((r-0.83)/0.018,2.0));
	// 外圈三十六枚符箓刻痕，缓慢逆行，与主光轨形成层次。
	float sector=(a+3.14159+TIME*0.025)/TAU*36.0;
	float cell=floor(sector);
	vec2 q=vec2((fract(sector)-0.5)*0.15,r-0.91);
	float strokes=segment(q,vec2(-0.022,-0.023),vec2(0.022,-0.023));
	strokes=min(strokes,segment(q,vec2(-0.022,0.023),vec2(0.022,0.023)));
	strokes=min(strokes,segment(q,vec2(0.0,-0.023),vec2(0.0,0.023)));
	if(mod(cell,3.0)<1.0) strokes=min(strokes,segment(q,vec2(-0.026,0.0),vec2(0.026,0.0)));
	else strokes=min(strokes,segment(q,vec2(-0.02,-0.004),vec2(0.02,0.01)));
	float runes=ink(strokes)*0.68;
	vec2 v0=vec2(0.0,-0.59),v1=vec2(0.511,0.295),v2=vec2(-0.511,0.295);
	float path=min(segment(p,v0,v1),min(segment(p,v1,v2),segment(p,v2,v0)));
	float triangle=ink(path)*0.6;
	float seals=0.0;
	for(int i=0;i<3;i++) {
		float angle=-1.570796+float(i)*TAU/3.0;
		vec2 center=vec2(cos(angle),sin(angle))*0.59;
		vec2 local=p-center;
		float dr=length(local);
		seals+=circle(dr,0.071,0.0015)+circle(dr,0.092,0.001);
		float petals=abs(sin(atan(local.y,local.x)*3.0+TIME*0.2));
		seals+=ink(abs(dr-(0.098+0.026*petals)))*0.65;
	}
	float stars=0.0;
	for(int i=0;i<9;i++) {
		float angle=float(i)*TAU/9.0+TIME*0.10;
		vec2 spot=vec2(cos(angle),sin(angle))*0.75;
		vec2 d=abs(p-spot);
		stars+=exp(-length(d)*170.0)*0.8;
	}
	float center_seal=circle(r,0.115,0.0015)+circle(r,0.14,0.001);
	float haze=(1.0-smoothstep(0.3,0.83,r))*0.035;
	float cyan_light=rim*0.72+inner*0.35+glow+flow+stars;
	float gold_light=runes+triangle+seals*0.72+center_seal*0.6;
	float alpha=clamp((cyan_light+gold_light)*pulse+haze,0.0,1.0);
	vec3 color=mix(vec3(0.22,0.76,1.0),vec3(1.0,0.82,0.43),clamp(gold_light/(cyan_light+gold_light+0.001),0.0,1.0));
	COLOR=vec4(color,alpha)*tint;
}
