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

const PET_CARD = preload("res://scenes/UI/SummonPetCard.tscn")
@onready var _pet_tooltip: Control = $PetTooltip

func _show_pet_tooltip(pet: PetData) -> void:
	$PetTooltip/Text.text = "%s  Lv.%d  [%s]\n生命 %d   灵力 %d\n攻击 %d   防御 %d\n法防 %d   速度 %d" % [pet.character_name, pet.level, PetData.apt_name(pet.aptitude), pet.max_hp, pet.max_mp, pet.attack, pet.defense, pet.magic_defense, pet.speed]
	_pet_tooltip.reset_size()
	_pet_tooltip.show()

func _hide_pet_tooltip() -> void:
	if _pet_tooltip:
		_pet_tooltip.visible = false

func _process(_delta: float) -> void:
	if _pet_tooltip and _pet_tooltip.visible:
		_pet_tooltip.position = (panel.get_global_mouse_position() + Vector2(16, 16)).clamp(Vector2.ZERO, panel.get_viewport_rect().size - _pet_tooltip.size)

const APT_COLORS := {
	PetData.Aptitude.丁: Color("#455b73"),
	PetData.Aptitude.丙: Color("#256445"),
	PetData.Aptitude.乙: Color("#234f91"),
	PetData.Aptitude.甲: Color(1.0, 0.3, 0.3),
	PetData.Aptitude.特: Color("#80551b"),
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
	set_process(true)
	# 键盘导航：自动选第一只宠物
	if _team_pets.size() > 0:
		await get_tree().process_frame
		_select_pet(0)


func _build_grid() -> void:
	_hide_pet_tooltip()
	for c in pet_grid.get_children():
		pet_grid.remove_child(c)
		c.queue_free()
	for i in range(6):
		var slot = PET_CARD.instantiate() as PanelContainer
		pet_grid.add_child(slot)
		if i < _team_pets.size():
			var pet = _team_pets[i].pet as PetData
			slot.get_node("VBox/Portrait").texture = _portrait_texture(pet.was_base_path, "x44")
			slot.get_node("VBox/Name").text = pet.character_name
			slot.get_node("VBox/Level").text = "%s阶  ·  Lv.%d" % [PetData.apt_name(pet.aptitude), pet.level]
			slot.get_node("VBox/Level").add_theme_color_override("font_color", APT_COLORS[pet.aptitude])
			slot.theme_type_variation = &"SelectedCard" if i == _selected_idx else &"PanelContainer"
			slot.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_select_pet(i)
			)
			slot.mouse_entered.connect(func(): _show_pet_tooltip(pet))
			slot.mouse_exited.connect(_hide_pet_tooltip)
		else:
			slot.get_node("VBox/Name").text = "— 空位 —"
			slot.get_node("VBox/Name").self_modulate.a = 0.75
			slot.get_node("VBox/Level").text = "暂无可召唤灵宠"
			slot.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _update_detail(pet: PetData) -> void:
	if pet == null:
		detail_name.text = "暂无可召唤灵宠"
		detail_info.text = "已出战的灵宠不会显示在列表中"
		btn_confirm.disabled = true
		preview_was.stop()
		preview_sprite.texture = null
		return

	detail_name.text = "[%s] %s" % [PetData.apt_name(pet.aptitude), pet.character_name]
	detail_info.text = "等级 %d    生命 %d    灵力 %d\n攻击 %d    防御 %d    速度 %d" % [pet.level, pet.max_hp, pet.max_mp, pet.attack, pet.defense, pet.speed]
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
	var r_frame: Dictionary = preload("res://Script/Assets/AssetLoader.gd").was_frame(path)
	if r_frame.is_empty(): return null
	var d = r_frame
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
	panel.pivot_offset = panel.size / 2.0
	panel.modulate.a = 0; panel.scale = Vector2(0.85, 0.85)
	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(panel, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(panel, "scale", Vector2(1, 1), 0.2)


func _pop_out() -> void:
	var t = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
	t.tween_property(panel, "modulate:a", 0.0, 0.1)
	t.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.1)
	t.tween_callback(hide)
	t.tween_callback(func(): set_process(false); _hide_pet_tooltip())
