extends Node2D
## 无纸底的原创符文笔画，以金色外光和白金笔芯绘制，不依赖角色或旧符纸素材。
var variant: int = 0
var tint := Color(1.0, 0.74, 0.18)

func _draw() -> void:
	var paths: Array[PackedVector2Array] = []
	var skew := float(variant % 3 - 1) * 1.5
	paths.append(PackedVector2Array([Vector2(-3,-22),Vector2(1,-25),Vector2(4,-21),Vector2(2,-18)]))
	paths.append(PackedVector2Array([Vector2(-8,-17),Vector2(0,-18),Vector2(8,-16)]))
	paths.append(PackedVector2Array([Vector2(-6,-12),Vector2(7,-13),Vector2(6,-5),Vector2(-6,-4),Vector2(-6,-12)]))
	paths.append(PackedVector2Array([Vector2(skew,-16),Vector2(-1,8),Vector2(1,24),Vector2(4,21)]))
	paths.append(PackedVector2Array([Vector2(-9,1),Vector2(8,0)]))
	paths.append(PackedVector2Array([Vector2(-7,6),Vector2(-8,17),Vector2(-5,22)]))
	paths.append(PackedVector2Array([Vector2(6,5),Vector2(8,16),Vector2(5,23)]))
	if variant % 2 == 0:
		paths.append(PackedVector2Array([Vector2(-9,10),Vector2(-3,11),Vector2(5,9),Vector2(10,11)]))
		paths.append(PackedVector2Array([Vector2(-5,-8),Vector2(5,-9)]))
	else:
		paths.append(PackedVector2Array([Vector2(-9,10),Vector2(-3,14),Vector2(5,11),Vector2(9,14)]))
		paths.append(PackedVector2Array([Vector2(-9,-8),Vector2(-10,-2),Vector2(-7,1)]))
	for path in paths:
		for width in [10.0, 6.0, 3.0]:
			draw_polyline(path, Color(tint, 0.035 if width > 6 else 0.085), width, true)
		draw_polyline(path, Color(tint, 0.85), 1.7, true)
		draw_polyline(path, Color(1, 0.97, 0.76, 0.98), 0.8, true)
