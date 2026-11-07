shader_type canvas_item;
render_mode unshaded;
uniform float strength = 1.0;
uniform float ring_radius = 0.32;
void fragment(){
 vec2 p=UV-0.5;
 float r=length(p);
 float ring=exp(-abs(r-ring_radius)*110.0);
 float glow=exp(-r*r*28.0)*0.32;
 float rays=pow(max(0.0,1.0-abs(p.x)*50.0),4.0)*exp(-abs(p.y)*8.0)*0.5;
 COLOR=vec4(0.65,0.87,1.0,(ring+glow+rays)*strength);
}
