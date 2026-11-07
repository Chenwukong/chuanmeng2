shader_type canvas_item;
render_mode unshaded;
uniform float pitch = 0.18;
uniform float roll = 0.25;
uniform float gleam = 0.0;
varying vec3 projected_uv;
varying vec4 vertex_tint;
void vertex() {
 // 剑尖位于局部原点：剑柄深入景深，接近时逐渐展开，而非整张图等比平移。
 float x = VERTEX.x * cos(roll);
 float z = -VERTEX.y * sin(pitch) + VERTEX.x * sin(roll);
 float perspective = 550.0 / max(180.0, 550.0 + z);
 // Sprite 的两个三角形默认线性插值 UV，会在对角线处把剑刃折弯。
 // 同步插值 UV / 深度与 1 / 深度，片元中还原完整的投影坐标。
 projected_uv = vec3(UV * perspective, perspective);
 vertex_tint = COLOR;
 VERTEX = vec2(x, VERTEX.y * cos(pitch)) * perspective;
}
void fragment() {
 vec2 sword_uv = projected_uv.xy / projected_uv.z;
 vec4 tex = texture(TEXTURE, sword_uv);
 float shine = exp(-pow((sword_uv.x - (0.22 + gleam * 0.58)) * 19.0, 2.0));
 float light = 0.76 + 0.24 * cos(roll) + shine * 0.65;
 COLOR = vertex_tint * vec4(tex.rgb * light, tex.a);
}
