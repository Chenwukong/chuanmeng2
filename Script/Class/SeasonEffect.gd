# SeasonEffect.gd
# 季节特效 — 挂在 CanvasLayer 下的 ColorRect 上
class_name SeasonEffect
extends ColorRect

@export var intensity: float = 0.5
@export var auto_update: bool = true

var _time: float = 0.0
var _material: ShaderMaterial = null


func _ready():
	material = null
	var shader = load("res://Shader/snow_season.gdshader")
	if shader == null:
		push_error("[SeasonEffect] 无法加载 shader")
		return
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("snow_amount", intensity)
	_material.set_shader_parameter("time_shift", 0.0)
	material = _material
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta):
	if not auto_update or _material == null:
		return
	_time += delta
	_material.set_shader_parameter("time_shift", _time)

	# 战斗中隐藏积雪
	if GameData.in_battle:
		if visible:
			hide()
		return
	else:
		if not visible:
			show()

	var cam = get_viewport().get_camera_2d()
	if cam == null:
		return

	# 视口世界范围（像素尺寸 ÷ zoom）
	var vp = get_viewport().get_visible_rect().size
	var world_size = Vector2(vp.x / cam.zoom.x, vp.y / cam.zoom.y)
	# 屏幕中心 → 左上角世界坐标
	var top_left = cam.get_screen_center_position() - world_size / 2.0
	_material.set_shader_parameter("camera_pos", top_left)
	_material.set_shader_parameter("viewport_size", world_size)
	# 每 60 帧打印一次确认
	if Engine.get_process_frames() % 60 == 0:
		print("[SeasonEffect] top_left=%s world_size=%s zoom=%s" % [top_left, world_size, cam.zoom])


func set_intensity(val: float):
	intensity = clamp(val, 0.0, 1.0)
	if _material:
		_material.set_shader_parameter("snow_amount", intensity)


static func apply_to(scene_root: Node, intensity: float = 0.5) -> SeasonEffect:
	var layer = CanvasLayer.new()
	layer.name = "SeasonLayer"
	layer.layer = 90
	scene_root.add_child(layer)
	var se = SeasonEffect.new()
	se.color = Color.WHITE
	se.set_anchors_preset(PRESET_FULL_RECT)
	se.intensity = intensity
	layer.add_child(se)
	return se
