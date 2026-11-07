# MechSummonPopup.gd
# 战斗中选择召唤哪只铁甲兽
class_name MechSummonPopup
extends CanvasLayer

signal mech_selected(mech_name: String)
signal cancelled()

@onready var panel: Control = $Panel
@onready var grid: GridContainer = $Panel/VBox/Scroll/Grid

const ENTRY_SCENE = preload("res://scenes/UI/Mech/MechSummonEntry.tscn")

var _summoned_ids: Array[String] = []  # 战斗中已召唤的铁甲兽，本次打开时过滤掉


func open(summoned_ids: Array[String] = []) -> void:
	_closing = false
	_summoned_ids = summoned_ids
	_build_grid()
	_selected_idx = 0
	_update_highlight()
	show()
	_pop_in()
	_just_opened = true
	call_deferred(&"_clear_just_opened")


func _clear_just_opened() -> void:
	_just_opened = false


var _mech_names: Array[String] = []
var _selected_idx: int = 0
var _just_opened: bool = false
var _closing: bool = false


func _build_grid() -> void:
	for c in grid.get_children(): c.free()
	_mech_names.clear()
	for pid in GameData.mech_team:
		if pid in _summoned_ids:
			continue
		var pet = GameData.mech_db.get(pid)
		if pet == null: continue
		_mech_names.append(pid)
		var slot = ENTRY_SCENE.instantiate()
		slot.get_node("Content/Info/Name").text = pet.name
		slot.get_node("Content/Level").text = "Lv.%d" % pet.level
		slot.get_node("Content/Info/Stats").text = "物攻 %d   物防 %d   速度 %d" % [pet.get("atk", 0), pet.get("def_", 0), pet.get("spd", 0)]
		slot.get_node("Content/Icon").texture = _portrait(pet.get("was_base_path", ""))
		var sid = pid
		var index := _mech_names.size() - 1
		slot.mouse_entered.connect(func(): _selected_idx = index; _update_highlight())
		slot.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_pop_out()
				mech_selected.emit(sid)
		)
		grid.add_child(slot)
	$Panel/Empty.visible = _mech_names.is_empty()

func _portrait(base: String) -> Texture2D:
	var root_texture = preload("res://Script/Assets/AssetLoader.gd").root_portrait(base)
	if root_texture != null: return root_texture
	for filename in ["头像/头像.was", "头像/x44.was", "头像/x32.was"]:
		var path := base.path_join(filename)
		if not FileAccess.file_exists(path): continue
		var reader_frame: Dictionary = preload("res://Script/Assets/AssetLoader.gd").was_frame(path)
		if not reader_frame.is_empty():
			return reader_frame.get("texture")
	return null

func _update_highlight() -> void:
	for i in grid.get_child_count():
		grid.get_child(i).get_node("Selected").visible = i == _selected_idx
	if _selected_idx >= 0 and _selected_idx < grid.get_child_count():
		$Panel/VBox/Scroll.ensure_control_visible(grid.get_child(_selected_idx))


func _input(event: InputEvent) -> void:
	if not visible: return
	if PlatformControls.handle_fullscreen_shortcut(event): return
	# 模态窗口先于 GUI 焦点导航处理按键，避免被底下的战斗按钮吞掉。
	if not (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_accept")):
		return
	get_viewport().set_input_as_handled()
	if _just_opened or _closing: return
	if event.is_action_pressed("ui_cancel"):
		_pop_out(); cancelled.emit(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_selected_idx = maxi(0, _selected_idx - 1)
		_update_highlight(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_selected_idx = maxi(0, mini(_mech_names.size() - 1, _selected_idx + 1))
		_update_highlight(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _selected_idx >= 0 and _selected_idx < _mech_names.size():
			_pop_out(); mech_selected.emit(_mech_names[_selected_idx])
			get_viewport().set_input_as_handled()


func _ready() -> void:
	$Background.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_pop_out()
			cancelled.emit()
	)
	$Panel/Close.pressed.connect(func(): _pop_out(); cancelled.emit())
	hide()


func _pop_in() -> void:
	panel.modulate.a = 0; panel.scale = Vector2(0.85, 0.85)
	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(panel, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(panel, "scale", Vector2(1, 1), 0.2)


func _pop_out() -> void:
	_closing = true
	var t = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
	t.tween_property(panel, "modulate:a", 0.0, 0.1)
	t.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.1)
	t.tween_callback(hide)
