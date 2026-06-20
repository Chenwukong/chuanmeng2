// battle_transition.gdshader
// 战斗转场 — 采样真实屏幕画面做特效
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;

uniform int mode = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 src = texture(screen, uv);

	if (mode == 0) {
		// 0 — CRT故障：RGB错位 + 扫描线撕裂 + 噪点
		float shift = progress * intensity * 0.06;
		float r = texture(screen, uv + vec2(shift, 0.0)).r;
		float g = texture(screen, uv).g;
		float b = texture(screen, uv - vec2(shift * 0.7, 0.0)).b;
		float row_id = floor(uv.y * 60.0);
		float tear = step(0.92, hash(vec2(row_id, 0.0))) * progress * 0.4;
		vec2 tear_uv = uv + vec2(tear * (hash(vec2(row_id, 1.0)) - 0.5) * 0.15, 0.0);
		vec4 tear_color = texture(screen, tear_uv);
		float noise = (hash(vec2(uv.x * 800.0, uv.y * 600.0 + progress * 100.0)) - 0.5) * progress * 0.15;
		COLOR.rgb = vec3(r, g, b) * (1.0 - tear) + tear_color.rgb * tear + noise;
		COLOR.a = 1.0;
	}
	else if (mode == 1) {
		// 1 — 水波扭曲：环形涟漪 + 漩涡拉伸
		float dist = length(uv - center);
		float wave = sin(dist * 30.0 - progress * 12.0) * progress * intensity * 0.04;
		float swirl = cos(dist * 15.0 - progress * 8.0) * progress * intensity * 0.03;
		float d = max(dist, 0.001);
		vec2 w_uv = uv + vec2(
			wave * (uv.x - center.x) / d + swirl * (uv.y - center.y) / d,
			wave * (uv.y - center.y) / d - swirl * (uv.x - center.x) / d
		);
		COLOR = texture(screen, w_uv);
		COLOR.a = 1.0;
	}
	else if (mode == 2) {
		// 2 — 碎片炸裂：三角块各向飞散
		float scale = mix(40.0, 8.0, progress);
		vec2 grid_uv = floor(uv * scale) / scale;
		vec2 local = fract(uv * scale);
		float h = hash(grid_uv);
		float angle = h * 6.283;
		float speed = (0.5 + h * 0.5) * intensity;
		vec2 offset = vec2(cos(angle), sin(angle)) * progress * speed * 0.15;
		bool upper = local.x > local.y;
		float delay = (upper ? h : hash(grid_uv + 0.5)) * 0.3;
		float p = clamp((progress - delay) / max(1.0 - delay, 0.01), 0.0, 1.0);
		vec2 f_uv = uv + offset * p;
		COLOR = texture(screen, f_uv);
		COLOR.a = 1.0;
	}
	else if (mode == 3) {
		// 3 — 暗角吞噬：四角向内收拢
		vec2 dd = abs(uv - 0.5) * 2.0;
		float vignette = smoothstep(1.0 - progress, 1.0 - progress + 0.3, max(dd.x, dd.y));
		COLOR.rgb = mix(src.rgb, vec3(0.0), vignette);
		COLOR.a = 1.0;
	}
	else if (mode == 4) {
		// 4 — 像素溶解：随机像素块消失
		float ps = mix(800.0, 40.0, progress);
		vec2 g_uv = floor(uv * ps) / ps;
		float h = hash(g_uv + center * 10.0);
		float threshold = mix(-0.2, 1.1, progress);
		if (h > threshold) {
			COLOR = src;
		} else {
			vec2 d_uv = uv + vec2((h - 0.5) * progress * 0.03, (hash(g_uv + 1.0) - 0.5) * progress * 0.03);
			COLOR.rgb = texture(screen, d_uv).rgb * (1.0 - progress * 0.8);
		}
		COLOR.a = 1.0;
	}
	else if (mode == 5) {
		// 5 — 菱形收缩：菱形遮罩推进
		vec2 dd = abs(uv - 0.5) * 2.0;
		float diamond = dd.x + dd.y;
		float wipe = smoothstep(2.0 - progress * 2.5, 2.0 - progress * 2.5 + 0.3, diamond);
		COLOR.rgb = mix(src.rgb, vec3(0.0), wipe);
		COLOR.a = 1.0;
	}
	else if (mode == 6) {
		// 6 — 螺旋扭曲：旋转吸入
		float dist = length(uv - center);
		float angle = atan(uv.y - center.y, uv.x - center.x);
		float twist = angle + dist * progress * intensity * 12.0;
		float pull = dist * (1.0 + progress * intensity * 0.6);
		vec2 s_uv = center + vec2(cos(twist), sin(twist)) * pull;
		COLOR = texture(screen, s_uv);
		float dark = smoothstep(0.3, 0.0, dist) * progress;
		COLOR.rgb = mix(COLOR.rgb, vec3(0.0), dark);
		COLOR.a = 1.0;
	}
	else if (mode == 7) {
		// 7 — 百叶窗：横向黑条从顶部向下拉，progress 越大黑条越宽
		float bar_w = progress;
		float row = fract(uv.y * 16.0);
		float blind = step(row, bar_w);
		COLOR.rgb = mix(src.rgb, vec3(0.0), blind);
		COLOR.a = 1.0;
	}
	else if (mode == 8) {
		// 8 — 波浪冲刷：正弦波层层推过，波峰处画面扭曲+暗化
		float wave = sin(uv.x * 15.0 + uv.y * 3.0 - progress * 20.0) * 0.5 + 0.5;
		float sweep = smoothstep(progress - 0.15, progress, wave);
		vec2 w_uv = uv + vec2(
			sin(uv.y * 40.0 + progress * 15.0) * sweep * 0.03,
			cos(uv.x * 40.0 + progress * 15.0) * sweep * 0.02
		);
		COLOR.rgb = mix(texture(screen, w_uv).rgb, vec3(0.03, 0.02, 0.08), sweep);
		COLOR.a = 1.0;
	}
	else if (mode == 9) {
		// 9 — 万花筒：多重镜像扇形从中心扩散
		float dist = length(uv - center);
		float angle = atan(uv.y - center.y, uv.x - center.x);
		float segs = mix(2.0, 12.0, progress);
		float seg_angle = floor(angle / (6.283 / segs)) * (6.283 / segs);
		float mirror = mod(floor(angle / (3.1415 / segs)), 2.0);
		float m_angle = mirror > 0.5 ? seg_angle + (seg_angle + 6.283 / segs - angle) : angle;
		vec2 k_uv = center + vec2(cos(m_angle), sin(m_angle)) * dist;
		// 扇区边界线
		float edge = abs(fract(angle / (6.283 / segs)) - 0.5) * 2.0;
		float line = 1.0 - smoothstep(0.92, 1.0, edge) * progress;
		COLOR.rgb = texture(screen, k_uv).rgb * line;
		COLOR.a = 1.0;
	}
	else if (mode == 10) {
		// 10 — 墨滴晕染：随机圆斑从各处扩散融合
		float ink = 0.0;
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			vec2 spot = vec2(
				hash(vec2(fi, 0.33)) * 0.6 + 0.2,
				hash(vec2(fi, 0.67)) * 0.6 + 0.2
			);
			float radius = mix(0.0, 0.7, progress);
			float d = length(uv - spot);
			ink += smoothstep(radius, radius - 0.05, d);
		}
		ink = clamp(ink, 0.0, 1.0);
		COLOR.rgb = mix(src.rgb, vec3(0.0), ink);
		COLOR.a = 1.0;
	}
	else if (mode == 11) {
		// 11 — 马赛克崩塌：像素块越来越大，同时随机下沉
		float ms = mix(120.0, 6.0, progress);
		vec2 m_uv = floor(uv * ms) / ms;
		float h = hash(m_uv);
		float fall = h * progress * progress * 0.3;
		vec2 f_uv = uv + vec2(0.0, fall);
		COLOR = texture(screen, f_uv);
		// 块间裂缝
		float crack = abs(fract(uv.x * ms) - 0.5) + abs(fract(uv.y * ms) - 0.5);
		float crack_alpha = smoothstep(0.96, 1.0, crack) * progress;
		COLOR.rgb = mix(COLOR.rgb, vec3(0.0), crack_alpha);
		COLOR.a = 1.0;
	}
	else if (mode == 12) {
		// 12 — 多边形炸裂：随机 Voronoi 块各向飞离
		float vor_scale = mix(50.0, 12.0, progress);
		vec2 vor_uv = uv * vor_scale;
		vec2 cell = floor(vor_uv);
		vec2 frac = fract(vor_uv);
		float best = 1.0;
		vec2 best_cell = cell;
		for (int fy = -1; fy <= 1; fy++) {
			for (int fx = -1; fx <= 1; fx++) {
				vec2 n = cell + vec2(float(fx), float(fy));
				vec2 point = vec2(hash(n), hash(n + 0.5));
				float d = length(frac - point);
				if (d < best) {
					best = d;
					best_cell = n;
				}
			}
		}
		float h = hash(best_cell);
		float angle = h * 6.283;
		float speed = (0.5 + hash(best_cell + 0.3) * 0.5) * intensity;
		vec2 voff = vec2(cos(angle), sin(angle)) * progress * speed * 0.2;
		COLOR = texture(screen, uv + voff);
		COLOR.a = 1.0;
	}
	else if (mode == 13) {
		// 13 — 时钟扫灭：指针从中心顺时针旋转扫过
		float angle = atan(uv.y - center.y, uv.x - center.x) + 3.14159;
		float sweep_angle = progress * 6.283;
		float wipe = 1.0 - smoothstep(sweep_angle - 0.15, sweep_angle + 0.15, angle);
		COLOR.rgb = mix(src.rgb, vec3(0.0), wipe);
		COLOR.a = 1.0;
	}
	else if (mode == 14) {
		// 14 — 帷幕闭合：上下黑幕向中间合拢
		float curtain = smoothstep(0.5 - progress * 0.55, 0.5 - progress * 0.55 + 0.05, abs(uv.y - 0.5));
		COLOR.rgb = mix(src.rgb, vec3(0.0), curtain);
		COLOR.a = 1.0;
	}
	else if (mode == 15) {
		// 15 — 圆环扩散：空心圆从中心外扩，环外变黑
		float dist = length(uv - center);
		float inner_r = progress * 0.8;
		float ring = 1.0 - smoothstep(inner_r, inner_r + 0.08, dist);
		COLOR.rgb = mix(src.rgb, vec3(0.0), ring);
		// 环内保留原画面
		COLOR.a = 1.0;
	}
	else if (mode == 16) {
		// 16 — 雪花噪点吞噬
		float noise = hash(uv * 800.0 + progress * 200.0);
		float threshold = 1.0 - progress;
		float black = step(threshold, noise);
		COLOR.rgb = mix(src.rgb, vec3(0.0), black);
		COLOR.a = 1.0;
	}
	else if (mode == 17) {
		// 17 — 网格透底：格子逐个变黑
		float gs = mix(60.0, 20.0, progress);
		vec2 g_uv = floor(uv * gs) / gs;
		float h = hash(g_uv);
		float dissolve = step(h, progress);
		COLOR.rgb = mix(src.rgb, vec3(0.0), dissolve);
		COLOR.a = 1.0;
	}
	else if (mode == 18) {
		// 18 — 光柱扫过：亮白色竖条从右扫左
		float bar_x = 1.0 - progress;
		float bar = 1.0 - smoothstep(0.0, 0.06, abs(uv.x - bar_x));
		COLOR.rgb = mix(src.rgb, vec3(1.0), bar * 0.8);
		// 扫过区域变黑
		float swept = step(uv.x, bar_x + 0.02);
		COLOR.rgb = mix(COLOR.rgb, vec3(0.0), swept);
		COLOR.a = 1.0;
	}
	else if (mode == 19) {
		// 19 — 方片飘落：矩形碎片从天而降堆积
		float flake_size = 0.06;
		vec2 flake_uv = floor(uv / flake_size);
		float h = hash(flake_uv);
		float speed = 0.5 + h * 1.5;
		float y = fract(uv.y / flake_size);
		float pile = step(y, progress * speed);
		COLOR.rgb = mix(src.rgb, vec3(0.02, 0.01, 0.06), pile);
		// 已堆满区域加暗
		float full = step(1.0, progress * speed);
		COLOR.rgb = mix(COLOR.rgb, vec3(0.0), full * 0.5);
		COLOR.a = 1.0;
	}
}
