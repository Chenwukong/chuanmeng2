extends Node2D
## 依据当前动画帧的真实边界适配卡片，兼容 WAS 锚点和大尺寸角色。
@export var preview_size := Vector2(152, 168)
@export var maximum_scale: float = 1.2

func _process(_delta: float) -> void:
	fit_preview()

func fit_preview() -> void:
	var sprite: Sprite2D = $Visual/sprite
	if not sprite.texture: return
	var bounds := sprite.get_rect()
	if bounds.size.x <= 0 or bounds.size.y <= 0: return
	var ratio := minf(maximum_scale, minf((preview_size.x - 12) / bounds.size.x, (preview_size.y - 12) / bounds.size.y))
	sprite.scale = Vector2.ONE * ratio
	sprite.position = preview_size * 0.5 - bounds.get_center() * ratio
