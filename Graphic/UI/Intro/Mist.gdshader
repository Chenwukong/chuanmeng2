shader_type canvas_item;
render_mode unshaded;
uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float fbm(vec2 p) {
 float v=0.0, a=0.5;
 for(int i=0;i<5;i++){v+=a*noise(p); p=mat2(vec2(1.6,1.2),vec2(-1.2,1.6))*p+4.1; a*=0.5;}
 return v;
}
void fragment(){
 vec2 p=UV*vec2(5.8,3.6);
 vec2 drift=vec2(phase*0.14,-phase*0.09);
 float n=fbm(p+vec2(fbm(p+drift),fbm(p-drift))*2.5+drift);
 float edge=pow(abs(UV.x-0.5)*2.0,0.7)*0.32 + pow(abs(UV.y-0.5)*2.0,1.4)*0.18;
 float alpha=smoothstep(0.28,0.77,n*0.55+edge+coverage*1.25-0.48);
 alpha*=smoothstep(0.0,0.12,coverage);
 // 满屏时完全遮住场景切换，但保留流动的雾纹，不转为纯白色块。
 alpha=mix(alpha,1.0,smoothstep(0.86,1.0,coverage));
 vec3 tint=mix(vec3(0.71,0.85,0.97),vec3(1.0),n*0.75+0.15);
 COLOR=vec4(tint,alpha);
}
