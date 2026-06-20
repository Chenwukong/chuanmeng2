# SummonPopup.gd
# 战斗召唤弹窗 — 从6只出战宠物选一个召唤
class_name SummonPopup
extends CanvasLayer

signal pet_selected(pet: PetData)
signal cancelled()

@onready var panel: Control = $Panel
@onready var pet_grid: GridContainer = $Panel/VBox/PetGrid
@onready var detail_name: Label = $Panel/VBox/Detail/VBoxLeft/Name
@onready var detail_info: Label = $Panel/VBox/Detail/VBoxLeft/Info
@onready var btn_confirm: Button = $Panel/VBox/Detail/VBoxRight/BtnConfirm
@onready var close_btn: Button = $Panel/VBox/TopBar/CloseBtn
@onready var preview_sprite: Sprite2D = $Panel/VBox/Detail/VBoxLeft/WASPreview/Sprite2D
@onready var preview_was: WASAnimationPlayer = $Panel/VBox/Detail/VBoxLeft/WASPreview/WASAnimationPlayer

const APT_COLORS := {
	PetData.Aptitude.丁: Color(0.6, 0.6, 0.6),
	PetData.Aptitude.丙: Color(0.3, 0.8, 0.3),
	PetData.Aptitude.乙: Color(0.3, 0.5, 1.0),
	PetData.Aptitude.甲: Color(0.7, 0.3, 1.0),
	PetData.Aptitude.特: Color(1.0, 0.85, 0.2),
}

var _team_pets: Array = []     # [{pet, id}]
var _selected_idx: int = -1
var _summoned_ids: Array[String] = []


func open(summoned_ids: Array[String] = []) -> void:
	_summoned_ids = summoned_ids
	_team_pets.clear()
	for pid in GameData.pet_team:
		var pet = GameData.pet_db.get(pid)
		if pet and pid not in _summoned_ids:  # 过滤已召唤的宠物
			_team_pets.append({"pet": pet, "id": pid})

	_build_grid()
	_selected_idx = -1
	_update_detail(null)
	show()
	_pop_in()
	# 键盘导航：自动选第一只宠物
	if _team_pets.size() > 0:
		await get_tree().process_frame
		_select_pet(0)


func _build_grid() -> void:
	for c in pet_grid.get_children(): c.queue_free()

	for i in range(6):
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(100, 120)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		if i < _team_pets.size():
			var pet = _team_pets[i].pet as PetData
			var vbox = VBoxContainer.new()
			vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var av = Control.new()
			av.custom_minimum_size = Vector2(50, 50)
			av.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# 头像纹理
			var tex = _portrait_texture(pet.was_base_path, "x44")
			if tex:
				var tr = TextureRect.new()
				tr.texture = tex
				tr.set_anchors_preset(Control.PRESET_FULL_RECT)
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				av.add_child(tr)
			else:
				# 无头像时用资质颜色方块
				var av_bg = ColorRect.new()
				av_bg.color = APT_COLORS.get(pet.aptitude, Color.GRAY)
				av_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
				av_bg.modulate.a = 0.4
				av.add_child(av_bg)
			vbox.add_child(av)

			var name_lbl = Label.new()
			name_lbl.text = "[%s]%s" % [PetData.apt_name(pet.aptitude), pet.character_name]
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(name_lbl)

			var sidx = i
			slot.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_selected_idx = sidx
					_build_grid()
					_update_detail(_team_pets[sidx].pet)
					btn_confirm.grab_focus()
			)
			slot.add_child(vbox)

			if i == _selected_idx:
				var hl = StyleBoxFlat.new()
				hl.bg_color = Color(0.2, 0.4, 0.7, 0.5)
				hl.border_color = Color(0.4, 0.7, 1.0, 0.8)
				hl.border_width_top = 2; hl.border_width_bottom = 2
				hl.border_width_left = 2; hl.border_width_right = 2
				slot.add_theme_stylebox_override("panel", hl)
		else:
			var lbl = Label.new()
			lbl.text = "空位"
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
			slot.add_child(lbl)
		pet_grid.add_child(slot)


func _update_detail(pet: PetData) -> void:
	if pet == null:
		detail_name.text = ""
		detail_info.text = ""
		btn_confirm.disabled = true
		preview_was.stop()
		preview_sprite.texture = null
		return

	detail_name.text = "[%s] %s" % [PetData.apt_name(pet.aptitude), pet.character_name]
	detail_info.text = "Lv.%d  HP%d  ATK%d" % [pet.level, pet.max_hp, pet.attack]
	btn_confirm.disabled = false
	_load_preview(pet)


func _load_preview(pet: PetData) -> void:
	preview_was.stop()
	if pet.was_base_path.is_empty():
		preview_sprite.texture = null
		return
	preview_was.anim_files.clear()
	preview_was.direction = 0
	var idle_path = ""
	for candidate in ["待机.was", "idle.was", "站立.was"]:
		var p = pet.was_base_path.path_join(candidate)
		if FileAccess.file_exists(p):
			idle_path = p
			break
	if idle_path.is_empty():
		preview_sprite.texture = null
		return
	preview_was.add_anim("idle", idle_path)
	preview_was.load_all()
	preview_sprite.centered = true
	var r = preview_was._readers.get("idle")
	if r and r.group_count > 6:
		preview_was.direction = 6
	preview_was.play("idle")


## 提取 WAS 头像的静态纹理（参考 PetPopup）
func _portrait_texture(was_base: String, size: String) -> Texture2D:
	if was_base.is_empty(): return null
	var path = was_base + "/头像/%s.was" % size
	if not FileAccess.file_exists(path): return null
	var r = WASReader.new()
	if not r.load_from_file(path): return null
	var d = r.decode_frame(0, 0)
	if d.is_empty(): return null
	return d.get("texture", null)


func _on_confirm() -> void:
	if _selected_idx < 0 or _selected_idx >= _team_pets.size(): return
	_pop_out()
	pet_selected.emit(_team_pets[_selected_idx].pet)


func _on_cancel() -> void:
	_pop_out()
	cancelled.emit()


func _ready() -> void:
	btn_confirm.pressed.connect(_on_confirm)
	close_btn.pressed.connect(_on_cancel)
	$Background.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_cancel()
	)
	hide()
	


func _unhandled_input(event: InputEvent) -> void:
	if not visible: return

	if event.is_action_pressed("ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept"):
		if btn_confirm.disabled: return
		_on_confirm()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		if _team_pets.is_empty(): return
		if _selected_idx < 0:
			_select_pet(0)
			return
		var cols = 6  # GridContainer columns
		var row = _selected_idx / cols
		var col = _selected_idx % cols
		if event.is_action_pressed("ui_left"):
			col = maxi(0, col - 1)
		else:
			col = mini(cols - 1, col + 1)
		_select_pet(row * cols + col)

	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		if _team_pets.is_empty(): return
		if _selected_idx < 0:
			_select_pet(0)
			return
		var cols = 6
		var row = _selected_idx / cols
		var col = _selected_idx % cols
		if event.is_action_pressed("ui_up"):
			row = maxi(0, row - 1)
		else:
			row = mini(1, row + 1)  # 最多2行(6格)
		_select_pet(row * cols + col)


func _select_pet(idx: int) -> void:
	if idx < 0 or idx >= _team_pets.size(): return
	_selected_idx = idx
	_build_grid()
	_update_detail(_team_pets[idx].pet)
	btn_confirm.grab_focus()


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
