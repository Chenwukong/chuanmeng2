# MechPopup.gd
# 铁甲强化弹窗 — 专用于机关兽/机关鸟的养成
class_name MechPopup
extends CanvasLayer

signal closed()

@onready var panel: Control = $Panel
@onready var mech_grid: GridContainer = $Panel/Grid
@onready var detail_name: Label = $Panel/Detail/Name
@onready var detail_level: Label = $Panel/Detail/Level
@onready var detail_stats: Label = $Panel/Detail/Stats
@onready var detail_next: Label = $Panel/Detail/Next
@onready var btn_upgrade: Button = $Panel/Detail/BtnUpgrade
@onready var btn_close: Button = $Panel/CloseBtn

var _selected: String = ""

func open() -> void:
	_selected = ""
	_refresh()
	show()
	_pop_in()


func _refresh() -> void:
	for c in mech_grid.get_children(): c.queue_free()

	for pid in GameData.mech_team:
		var pet = GameData.mech_db.get(pid)
		if pet == null: continue
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(120, 80)
		var vbox = VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var name_lbl = Label.new()
		name_lbl.text = pet.name + "  Lv." + str(pet.level)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)

		var exp_lbl = Label.new()
		var needed = _exp_to_next(pet.level)
		exp_lbl.text = "EXP %d/%d" % [pet.exp, needed]
		exp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		exp_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(exp_lbl)

		var sid = pid
		slot.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_selected = sid
				_refresh()
		)
		slot.add_child(vbox)

		if pid == _selected:
			var hl = StyleBoxFlat.new()
			hl.bg_color = Color(0.2, 0.4, 0.7, 0.5)
			hl.border_color = Color(0.4, 0.7, 1.0, 0.8)
			hl.border_width_top = 2; hl.border_width_bottom = 2
			hl.border_width_left = 2; hl.border_width_right = 2
			slot.add_theme_stylebox_override("panel", hl)
		mech_grid.add_child(slot)

	_update_detail()


func _update_detail() -> void:
	var pet = GameData.mech_db.get(_selected)
	if pet == null:
		detail_name.text = ""
		detail_level.text = ""
		detail_stats.text = ""
		detail_next.text = ""
		btn_upgrade.disabled = true
		return
	detail_name.text = pet.name
	detail_level.text = "Lv.%d  下次升级需 %d 经验" % [pet.level, _exp_to_next(pet.level)]
	var atk_n = pet.get("atk_g", 3); var def_n = pet.get("def_g", 2); var spd_n = pet.get("spd_g", 1)
	detail_stats.text = "攻击 %d (+%d/级)  防御 %d (+%d/级)  速度 %d (+%d/级)" % [pet.atk, atk_n, pet.def_, def_n, pet.spd, spd_n]
	var skills = pet.get("skills", [])
	var skill_str = "技能：" + (" / ".join(skills) if skills.size() > 0 else "无")
	detail_next.text = skill_str
	btn_upgrade.disabled = false


func _on_upgrade() -> void:
	var pet = GameData.mech_db.get(_selected)
	if pet == null: return
	var needed = _exp_to_next(pet.level)
	var cost = needed * 10
	if GameData.player_gold >= cost:
		GameData.player_gold -= cost
		pet.exp += needed
		while pet.exp >= _exp_to_next(pet.level):
			pet.exp -= _exp_to_next(pet.level)
			pet.level += 1
			pet.atk += pet.get("atk_g", 3)
			pet.def_ += pet.get("def_g", 2)
			pet.spd += pet.get("spd_g", 1)
		_refresh()
	else:
		detail_next.text = "金币不足！需要 %d 金币" % cost


func _exp_to_next(lv: int) -> int:
	return 50 + lv * 30


func _on_close() -> void:
	_pop_out()
	closed.emit()


func _ready() -> void:
	btn_close.pressed.connect(_on_close)
	btn_upgrade.pressed.connect(_on_upgrade)
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
