extends PanelContainer

const LAYOUT_PATH := "user://ui_layout.cfg"
const LAYOUT_SECTION := "battle_stats"

@export var collapsed_width := 132.0
@export var expand_hint := "展开战局统计 · 按住标题拖动"
@export var collapse_hint := "收起战局统计 · 按住标题拖动"
@onready var expanded_width := custom_minimum_size.x

var _drag_pending := false
var _dragged := false
var _press_mouse := Vector2.ZERO
var _press_position := Vector2.ZERO

func _ready() -> void:
	%FoldButton.pressed.connect(_on_fold_pressed)
	%FoldButton.gui_input.connect(_on_header_input)
	%FoldButton.tooltip_text = collapse_hint
	resized.connect(_keep_on_screen)
	get_viewport().size_changed.connect(_keep_on_screen)
	visibility_changed.connect(_on_visibility_changed)
	_load_position()
	_keep_on_screen.call_deferred()
	set_process_input(false)

func _on_fold_pressed() -> void:
	if not _dragged:
		_toggle_details()

func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_drag_pending = true
		_dragged = false
		_press_mouse = %FoldButton.get_global_transform() * event.position
		_press_position = position
		set_process_input(true)

func _input(event: InputEvent) -> void:
	if not _drag_pending:
		return
	if event is InputEventMouseMotion:
		var delta: Vector2 = get_canvas_transform().affine_inverse() * event.position - _press_mouse
		if not _dragged and delta.length() >= 5.0:
			_dragged = true
			%FoldButton.set_pressed_no_signal(false)
		if _dragged:
			position = _press_position + delta
			_keep_on_screen()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag()
		if _dragged:
			get_viewport().set_input_as_handled()

func _finish_drag() -> void:
	_drag_pending = false
	set_process_input(false)
	if _dragged:
		%FoldButton.set_pressed_no_signal(false)
		_save_position()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _drag_pending:
		_finish_drag()

func _on_visibility_changed() -> void:
	if not visible and _drag_pending:
		_finish_drag()
	elif visible:
		_keep_on_screen.call_deferred()

func _keep_on_screen() -> void:
	if not is_inside_tree():
		return
	var viewport_size := get_viewport_rect().size
	position = position.clamp(Vector2.ZERO, (viewport_size - size).max(Vector2.ZERO))

func _load_position() -> void:
	var config := ConfigFile.new()
	if config.load(LAYOUT_PATH) != OK:
		return
	var saved: Variant = config.get_value(LAYOUT_SECTION, "position", position)
	if saved is Vector2 and saved.is_finite():
		position = saved

func _save_position() -> void:
	var config := ConfigFile.new()
	# 保留同一布局文件中其他界面的设置。
	config.load(LAYOUT_PATH)
	config.set_value(LAYOUT_SECTION, "position", position)
	var error := config.save(LAYOUT_PATH)
	if error != OK:
		push_warning("无法保存战局统计位置：%s" % error_string(error))

func _toggle_details() -> void:
	var expanded: bool = not %Details.visible
	%Details.visible = expanded
	custom_minimum_size.x = expanded_width if expanded else collapsed_width
	%Indicator.text = "▴" if expanded else "▾"
	%FoldButton.tooltip_text = collapse_hint if expanded else expand_hint
	reset_size.call_deferred()
