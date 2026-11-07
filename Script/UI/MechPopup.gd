class_name MechPopup
extends CanvasLayer
const UIFeedback = preload("res://Script/UI/UISoundFeedback.gd")
## 固定控件在 MechPopup.tscn 中；升级消耗材料背包中的齿轮。

signal closed()

@export_range(1, 99, 1) var gear_base_cost: int = 1
@export_range(1, 100, 1) var gear_level_interval: int = 10
@onready var panel: Control = $Panel
@onready var mech_grid: GridContainer = $Panel/MechScroll/Grid
@onready var detail_name: Label = $Panel/Detail/Name
@onready var detail_level: Label = $Panel/Detail/Level
@onready var detail_stats: Label = $Panel/Detail/Stats
@onready var detail_next: Label = $Panel/Detail/Next
@onready var btn_upgrade: Button = $Panel/Detail/BtnUpgrade
@onready var btn_close: Button = $Panel/CloseBtn
@onready var _animation: WASAnimationPlayer = $Panel/Detail/Preview/Animation
@onready var _sprite: Sprite2D = $Panel/Detail/Preview/Sprite
@onready var _sound: AudioStreamPlayer = $Sound

var _selected: String = ""
var _preview_id: String = ""
var _feedback: String = ""

func _ready() -> void:
	set_meta("keyboard_modal", true)
	set_meta("keyboard_cancel", _on_close)
	set_meta("keyboard_region_order", ["mechs", "upgrade", "close"])
	btn_close.set_meta("keyboard_region", "close")
	btn_upgrade.set_meta("keyboard_region", "upgrade")
	btn_close.pressed.connect(_on_close)
	btn_upgrade.pressed.connect(_on_upgrade)
	hide()

func open() -> void:
	if not GameData.mech_team.has(_selected) or not GameData.mech_db.has(_selected):
		_selected = ""
		for pid in GameData.mech_team:
			if GameData.mech_db.has(pid):
				_selected = pid
				break
	_feedback = ""
	_refresh()
	show()
	_pop_in()

func _refresh() -> void:
	_sync_mech_list()
	for slot in mech_grid.get_children():
		var pid := str(slot.get_meta("mech_id", ""))
		var pet: Dictionary = GameData.mech_db.get(pid, {})
		var owned := GameData.mech_team.has(pid) and not pet.is_empty()
		slot.disabled = not owned
		slot.get_node("Name").text = str(pet.get("name", pid))
		slot.get_node("Level").text = "等级 %d" % int(pet.get("level", 1)) if owned else "尚未解锁"
		slot.get_node("Selection").visible = owned and pid == _selected
		slot.set_meta("keyboard_default", owned and pid == _selected)
		var portrait := slot.get_node("Portrait") as TextureRect
		portrait.texture = _portrait(str(pet.get("was_base_path", ""))) if owned else null
	_update_detail()

func _sync_mech_list() -> void:
	var ids: Array[String] = []
	for pid in GameData.mech_team:
		if GameData.mech_db.has(pid) and not GameData.mech_db[pid].is_empty() and pid not in ids:
			ids.append(pid)
	for slot in mech_grid.get_children():
		if str(slot.get_meta("mech_id", "")) not in ids:
			mech_grid.remove_child(slot)
			slot.queue_free()
	for i in ids.size():
		var pid := ids[i]
		var slot: Button = null
		for existing in mech_grid.get_children():
			if str(existing.get_meta("mech_id", "")) == pid:
				slot = existing
				break
		if slot == null:
			# 已解锁机关数量由存档数据决定，按需实例化可编辑的条目场景。
			slot = preload("res://scenes/UI/Mech/MechSelectionSlot.tscn").instantiate() as Button
			slot.set_meta("mech_id", pid)
			slot.pressed.connect(_keyboard_detail.bind(pid))
			slot.focus_entered.connect(_ensure_mech_focus.bind(slot))
			slot.resized.connect(_ensure_mech_focus.bind(slot))
			slot.set_meta("keyboard_detail", _keyboard_detail.bind(pid))
			slot.set_meta("keyboard_region", "mechs")
			mech_grid.add_child(slot)
		mech_grid.move_child(slot, i)
	if _selected not in ids:
		_selected = ids[0] if not ids.is_empty() else ""
		_feedback = ""
	$Panel/ChooseCaption.text = "选择机关（%d）" % ids.size()
	$Panel/ListEmpty.visible = ids.is_empty()

func _ensure_mech_focus(slot: Control) -> void:
	if slot.has_focus(): $Panel/MechScroll.ensure_control_visible.call_deferred(slot)

func _upgrade_plan(pet: Dictionary) -> Dictionary:
	var start_level := maxi(1, int(pet.get("level", 1)))
	var needed := _exp_to_next(start_level)
	var level := start_level
	var experience := maxi(0, int(pet.get("exp", 0))) + needed
	while experience >= _exp_to_next(level):
		experience -= _exp_to_next(level)
		level += 1
	var steps := level - start_level
	return {
		"level": level, "exp": experience, "gold": needed * 10,
		"gears": gear_base_cost + int((start_level - 1) / maxi(1, gear_level_interval)),
		"atk": int(pet.get("atk", 0)) + int(pet.get("atk_g", 3)) * steps,
		"def_": int(pet.get("def_", 0)) + int(pet.get("def_g", 2)) * steps,
		"spd": int(pet.get("spd", 0)) + int(pet.get("spd_g", 1)) * steps,
	}

func _update_detail() -> void:
	var pet: Dictionary = GameData.mech_db.get(_selected, {})
	if pet.is_empty() or not GameData.mech_team.has(_selected):
		$Panel/Detail.hide()
		$Panel/EmptyDetail.show()
		$Panel/Status.text = ""
		_preview_id = ""
		_animation.stop()
		_sprite.texture = null
		detail_name.text = "暂无可强化机关"
		detail_level.text = ""
		detail_next.text = "解锁机关后可查看强化收益。"
		btn_upgrade.disabled = true
		return
	$Panel/Detail.show()
	$Panel/EmptyDetail.hide()
	var plan := _upgrade_plan(pet)
	detail_name.text = str(pet.get("name", _selected))
	detail_level.text = "等级 %d → %d" % [int(pet.level), int(plan.level)]
	$Panel/Detail/Role.text = str(pet.get("description", "机关伙伴 · 可使用齿轮强化"))
	for field in [["Attack", "atk"], ["Defense", "def_"], ["Speed", "spd"]]:
		var current := int(pet.get(field[1], 0))
		var after := int(plan[field[1]])
		get_node("Panel/Detail/" + field[0] + "Before").text = str(current)
		get_node("Panel/Detail/" + field[0] + "After").text = "%d (+%d)" % [after, after - current]
	var skills: Array = pet.get("skills", [])
	detail_next.text = "技能：" + (" / ".join(skills) if not skills.is_empty() else "无")
	var needed := _exp_to_next(int(pet.level))
	$Panel/Detail/Experience.text = "当前经验 %d / %d" % [int(pet.get("exp", 0)), needed]
	$Panel/Detail/ExperienceBar.max_value = needed
	$Panel/Detail/ExperienceBar.value = int(pet.get("exp", 0))
	var gears := _gear_count()
	$Panel/Detail/Gears.text = "持有 %d / 需要 %d" % [gears, int(plan.gears)]
	$Panel/Detail/Gold.text = "持有 %d / 需要 %d" % [GameData.player_gold, int(plan.gold)]
	$Panel/Detail/Gears.add_theme_color_override("font_color", Color(0.14, 0.25, 0.43) if gears >= plan.gears else Color(0.65, 0.24, 0.2))
	$Panel/Detail/Gold.add_theme_color_override("font_color", Color(0.14, 0.25, 0.43) if GameData.player_gold >= plan.gold else Color(0.65, 0.24, 0.2))
	btn_upgrade.disabled = gears < plan.gears or GameData.player_gold < plan.gold
	btn_upgrade.text = "强化至 %d 级" % int(plan.level)
	var shortage := ""
	if gears < plan.gears: shortage = "缺少 %d 个齿轮" % (int(plan.gears) - gears)
	if GameData.player_gold < plan.gold:
		shortage += (" · " if not shortage.is_empty() else "") + "金币不足"
	btn_upgrade.tooltip_text = shortage if not shortage.is_empty() else "消耗 %d 个齿轮和 %d 金币" % [int(plan.gears), int(plan.gold)]
	$Panel/Status.text = _feedback if not _feedback.is_empty() else (shortage if not shortage.is_empty() else "材料充足，可进行强化")
	$Panel/CostNote.text = "每次消耗齿轮 %d 个起\n每 %d 级增加 1 个" % [gear_base_cost, gear_level_interval]
	_load_preview(pet)

func _is_gear(item: Dictionary) -> bool:
	return str(item.get("id", "")) == "gear" or str(item.get("name", "")) == "齿轮"

func _gear_count() -> int:
	if GameData.debug_cheats_enabled: return GameData.DEBUG_GOLD
	var amount := 0
	for item in GameData.material_bag:
		if _is_gear(item): amount += maxi(0, int(item.get("count", 1)))
	return amount

func _consume_gears(amount: int) -> bool:
	if GameData.debug_cheats_enabled: return amount > 0
	if amount <= 0 or _gear_count() < amount: return false
	var remaining := amount
	for i in range(GameData.material_bag.size() - 1, -1, -1):
		var item: Dictionary = GameData.material_bag[i]
		if not _is_gear(item): continue
		var count := maxi(0, int(item.get("count", 1)))
		var taken := mini(count, remaining)
		if count == taken: GameData.material_bag.remove_at(i)
		else: item["count"] = count - taken
		remaining -= taken
		if remaining == 0: return true
	return false

func _on_upgrade() -> void:
	var pet: Dictionary = GameData.mech_db.get(_selected, {})
	if pet.is_empty() or not GameData.mech_team.has(_selected): return
	var plan := _upgrade_plan(pet)
	# 先校验全部费用，失败时不扣材料、不扣金币，也不改变机关属性。
	if GameData.player_gold < plan.gold or _gear_count() < plan.gears:
		UIFeedback.play_ui(&"error")
		_feedback = "齿轮或金币不足，无法强化"
		_update_detail()
		return
	if not _consume_gears(int(plan.gears)): return
	GameData.player_gold -= int(plan.gold)
	for key in ["level", "exp", "atk", "def_", "spd"]: pet[key] = plan[key]
	_feedback = "强化成功 · 已提升至 %d 级" % int(plan.level)
	_refresh()
	_sound.stream = preload("res://Audio/SE/001-System01.ogg")
	_sound.play()

func _exp_to_next(lv: int) -> int:
	return 50 + lv * 30

func _portrait(base: String) -> Texture2D:
	var root_texture = preload("res://Script/Assets/AssetLoader.gd").root_portrait(base)
	if root_texture != null: return root_texture
	for filename in ["头像/x44.was", "头像/x32.was", "头像/头像.was"]:
		var path := base.path_join(filename)
		if not FileAccess.file_exists(path): continue
		var reader_frame: Dictionary = preload("res://Script/Assets/AssetLoader.gd").was_frame(path)
		if not reader_frame.is_empty():
			var frame := reader_frame
			if not frame.is_empty(): return frame.get("texture", null)
	return null

func _load_preview(pet: Dictionary) -> void:
	if _preview_id == _selected: return
	_preview_id = _selected
	_animation.stop()
	_animation.anim_files.clear()
	_sprite.texture = null
	var base := str(pet.get("was_base_path", ""))
	for filename in ["待机.was", "站立.was", "idle.was"]:
		var path := base.path_join(filename)
		if not FileAccess.file_exists(path): continue
		_animation.direction = 0
		_animation.add_anim("idle", path)
		_animation.load_all()
		var reader = _animation._readers.get("idle")
		if reader and reader.group_count > 6: _animation.direction = 6
		_animation.play("idle")
		break

func _on_close() -> void:
	hide()
	closed.emit()

func _pop_in() -> void:
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.96, 0.96)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.18)

func _keyboard_detail(pid: String) -> void:
	if not GameData.mech_team.has(pid) or not GameData.mech_db.has(pid): return
	if _selected != pid: _feedback = ""
	_selected = pid
	_refresh()
