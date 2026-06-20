extends Sprite2D

var _material: ShaderMaterial = null
@export var intensity = 0.5

func _ready() -> void:
	
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
	
	SeasonEffect.apply_to(self, 0.5)


func _process(delta: float) -> void:
	var cam = get_viewport().get_camera_2d()
	if cam == null:
		return

	var vp_size: Vector2 = get_viewport_rect().size

	# 注意这里必须是屏幕左上角世界坐标
	var top_left: Vector2 = (
		cam.get_screen_center_position()
		- vp_size * 0.5
	)

	material.set_shader_parameter("camera_pos", top_left)
	material.set_shader_parameter("viewport_size", vp_size)
	material.set_shader_parameter("time_shift", Time.get_ticks_msec() / 1000.0)
