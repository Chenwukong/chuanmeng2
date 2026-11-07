extends Control
@export_range(0.0, 0.5) var dead_zone := 0.15
var _finger := -1
var _mouse := false

func _ready() -> void:
	PlatformControls.mode_changed.connect(_update_visibility)
	_update_visibility()

func _allowed() -> bool:
	return PlatformControls.android_mode and GameData.difficulty_locked and not GameData.in_battle and not GameData.ui_blocked and not GameData.is_dialogue_active() and not get_tree().paused

func _process(_delta: float) -> void:
	_update_visibility()

func _update_visibility() -> void:
	visible = _allowed()
	if not visible: reset()

func reset() -> void:
	_finger = -1
	_mouse = false
	PlatformControls.move_vector = Vector2.ZERO
	$Knob.position = (size - $Knob.size) * 0.5
	$Base.modulate.a = 0.72
	$Knob.modulate.a = 0.82

func _update_direction(point: Vector2) -> void:
	var local_point := get_global_transform_with_canvas().affine_inverse() * point
	var radius := size.x * 0.36
	var offset := (local_point - size * 0.5).limit_length(radius)
	$Knob.position = (size - $Knob.size) * 0.5 + offset
	$Base.modulate.a = 1.0
	$Knob.modulate.a = 1.0
	var amount := offset.length() / radius
	PlatformControls.move_vector = offset.normalized() * inverse_lerp(dead_zone, 1.0, amount) if amount > dead_zone else Vector2.ZERO

func _input(event: InputEvent) -> void:
	if not _allowed():
		reset()
		return
	if event is InputEventScreenTouch:
		if event.index == _finger:
			if not event.pressed or event.canceled: reset()
			get_viewport().set_input_as_handled()
		elif event.pressed and not event.canceled and _finger == -1 and not _mouse and get_global_rect().has_point(event.position):
			_finger = event.index
			_update_direction(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _finger:
		_update_direction(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# 电脑预览可拖动摇杆；触屏的模拟鼠标事件不能夺取手指控制权。
		if _finger >= 0:
			if get_global_rect().has_point(event.position): get_viewport().set_input_as_handled()
			return
		if event.pressed and get_global_rect().has_point(event.position):
			_mouse = true
			_update_direction(event.position)
			get_viewport().set_input_as_handled()
		elif _mouse and not event.pressed:
			reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mouse:
		_update_direction(event.position)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: reset()

func _exit_tree() -> void:
	PlatformControls.move_vector = Vector2.ZERO
