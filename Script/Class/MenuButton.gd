# MenuButton.gd
# UI 按钮 — 挂在 AnimatedSprite2D 上，管理 default/hover/pressed/lock 四种状态
class_name MenuButton
extends AnimatedSprite2D

signal clicked

enum State { DEFAULT, HOVER, PRESSED, LOCK }
var current_state = State.DEFAULT
var _area: Area2D


func _ready():
	# 给自身加 Area2D + CollisionShape2D 以便检测鼠标
	_area = Area2D.new()
	_area.name = "ClickArea"
	add_child(_area)

	var col = CollisionShape2D.new()
	col.shape = RectangleShape2D.new()
	# 用 sprite_frames 第一帧的纹理大小
	if sprite_frames and sprite_frames.get_frame_count("default") > 0:
		var tex = sprite_frames.get_frame_texture("default", 0)
		if tex:
			col.shape.size = tex.get_size()
	_area.add_child(col)

	_area.mouse_entered.connect(_on_mouse_enter)
	_area.mouse_exited.connect(_on_mouse_exit)
	_area.input_event.connect(_on_input_event)

	set_state(State.DEFAULT)


func set_state(st: State):
	if current_state == State.LOCK and st != State.LOCK:
		return  # 锁定态不切出
	current_state = st
	match st:
		State.DEFAULT: _play("default")
		State.HOVER:   _play("hover")
		State.PRESSED: _play("pressed")
		State.LOCK:    _play("lock")


func _play(anim: String):
	if sprite_frames and sprite_frames.has_animation(anim):
		play(anim)


func _on_mouse_enter():
	if current_state != State.LOCK:
		set_state(State.HOVER)


func _on_mouse_exit():
	if current_state != State.LOCK:
		set_state(State.DEFAULT)


func _on_input_event(_viewport, event: InputEvent, _shape_idx: int):
	if current_state == State.LOCK: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_state(State.PRESSED)
		clicked.emit()
		# 短暂延迟后回到 DEFAULT
		await get_tree().create_timer(0.15).timeout
		if current_state == State.PRESSED:
			set_state(State.DEFAULT)
