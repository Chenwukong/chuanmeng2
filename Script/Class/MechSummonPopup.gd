# MechSummonPopup.gd
# 战斗中选择召唤哪只铁甲兽
class_name MechSummonPopup
extends CanvasLayer

signal mech_selected(mech_name: String)
signal cancelled()

@onready var panel: Control = $Panel
@onready var grid: GridContainer = $Panel/VBox/Grid

func open() -> void:
	_build_grid()
	_selected_idx = 0
	_update_highlight()
	show()
	_pop_in()


var _mech_names: Array[String] = []
var _selected_idx: int = 0


func _build_grid() -> void:
	for c in grid.get_children(): c.queue_free()
	_mech_names.clear()
	for pid in GameData.mech_team:
		var pet = GameData.mech_db.get(pid)
		if pet == null: continue
		_mech_names.append(pid)
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(150, 60)
		var hbox = HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var name_lbl = Label.new()
		name_lbl.text = "%s  Lv.%d" % [pet.name, pet.level]
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(name_lbl)

		var sid = pid
		slot.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_pop_out()
				mech_selected.emit(sid)
		)
		slot.add_child(hbox)
		grid.add_child(slot)


func _update_highlight() -> void:
	for i in grid.get_child_count():
		var slot = grid.get_child(i) as PanelContainer
		if slot == null: continue
		# 彻底清除旧样式
		slot.add_theme_stylebox_override("panel", null)
		var hl = StyleBoxFlat.new()
		hl.bg_color = Color(0.2, 0.4, 0.7, 0.5) if i == _selected_idx else Color.TRANSPARENT
		hl.border_color = Color(0.4, 0.7, 1.0, 0.8) if i == _selected_idx else Color.TRANSPARENT
		hl.border_width_top = 2; hl.border_width_bottom = 2
		hl.border_width_left = 2; hl.border_width_right = 2
		slot.add_theme_stylebox_override("panel", hl)


func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_cancel"):
		_pop_out(); cancelled.emit(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_selected_idx = maxi(0, _selected_idx - 1)
		_update_highlight(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_selected_idx = mini(_mech_names.size() - 1, _selected_idx + 1)
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
	hide()


func _pop_in() -> void:
	panel.modulate.a = 0; panel.scale = Vector2(0.85, 0.85)
	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(panel, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(panel, "scale", Vector2(1, 1), 0.2)


func _pop_out() -> void:
	var t = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
	t.tween_property(panel, "modulate:a", 0.0, 0.1)
	t.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.1)
	t.tween_callback(hide)
