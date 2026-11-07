# PetPopup.gd
# 宠物管理弹窗 — 上面6个已上场格（WAS头像），下面翻页列表
class_name PetPopup
extends CanvasLayer
const UIFeedback = preload("res://Script/UI/UISoundFeedback.gd")

signal closed()

@onready var panel: Control = $Panel
@onready var deploy_grid: HBoxContainer = $Panel/DeployGrid
@onready var pet_grid: GridContainer = $Panel/PetGrid
@onready var detail_name: Label = $Panel/Name
@onready var detail_apt: Label = $Panel/Aptitude
@onready var detail_info: Label = $Panel/Info
@onready var detail_skills: Label = $Panel/Skills
@onready var btn_deploy: Button = $Panel/BtnDeploy
@onready var btn_release: Button = $Panel/BtnRelease
@onready var btn_devour: Button = $Panel/BtnDevour
@onready var devour_tip: Label = $Panel/DevourTip
@onready var devour_progress: Control = $Panel/DevourProgress
@onready var evolve_overlay: Label = $Panel/EvolveOverlay
@onready var page_label: Label = $Panel/PageLabel
@onready var btn_prev: Button = $Panel/BtnPrev
@onready var btn_next: Button = $Panel/BtnNext
@onready var btn_close: Button = $Panel/CloseBtn
@onready var btn_mech: Button = $Panel/BtnMech
@onready var preview_sprite: Sprite2D = $Panel/WASPreview/Sprite2D
@onready var preview_was: WASAnimationPlayer = $Panel/WASPreview/WASAnimationPlayer
@onready var _mech_popup: MechPopup = $MechPopup

const APT_COLORS := {
	PetData.Aptitude.丁: Color(0.6, 0.6, 0.6),
	PetData.Aptitude.丙: Color(0.3, 0.8, 0.3),
	PetData.Aptitude.乙: Color(0.3, 0.5, 1.0),
	PetData.Aptitude.甲: Color(1.0, 0.3, 0.3),
	PetData.Aptitude.特: Color(1.0, 0.85, 0.2),
}

var _pool_ids: Array = []
var _page: int = 0
var _selected_pid: String = ""
var _devour_pid: String = ""        # 吞噬者ID
var _devour_food_ids: Array = []    # 多选食物ID
@onready var btn_teach_book: Button = $Panel/BtnTeachBook
var _confirm_action: Callable
var _pending_food_pid: String = ""  # 甲级吞噬确认用
const PETS_PER_PAGE := 8


func open() -> void:
	_cancel_confirm()
	_pool_ids = _build_pool()
	_page = 0
	_selected_pid = str(_pool_ids[0]) if not _pool_ids.is_empty() else ""
	_devour_pid = ""
	_devour_food_ids.clear()
	_refresh()
	show()
	_pop_in()


func _build_pool() -> Array:
	var pool: Array = []
	for pid in GameData.pet_db:
		if pid not in GameData.pet_team:
			pool.append(pid)
	return pool


func _refresh() -> void:
	_refresh_deploy()
	_refresh_list()
	_update_detail()


func _portrait_texture(was_base: String, size: String) -> Texture2D:
	if was_base.is_empty(): return null
	var path = was_base + "/头像/%s.was" % size
	if not FileAccess.file_exists(path): return null
	var r_frame: Dictionary = preload("res://Script/Assets/AssetLoader.gd").was_frame(path)
	if r_frame.is_empty(): return null
	var d = r_frame
	if d.is_empty(): return null
	return d.get("texture", null)


# ── 上场格 ──

func _refresh_deploy() -> void:
	for i in deploy_grid.get_child_count():
		var slot := deploy_grid.get_child(i) as PanelContainer
		var pid := str(GameData.pet_team[i]) if i < GameData.pet_team.size() else ""
		var pet: PetData = GameData.pet_db.get(pid)
		_set_slot(slot, pet, true)

func _refresh_list() -> void:
	var start := _page * PETS_PER_PAGE
	var total_pages := maxi(1, ceili(float(_pool_ids.size()) / PETS_PER_PAGE))
	_page = mini(_page, total_pages - 1)
	start = _page * PETS_PER_PAGE
	page_label.text = "%d / %d" % [_page + 1, total_pages]
	$Panel/ListCount.text = "共 %d 只" % _pool_ids.size()
	btn_prev.disabled = _page <= 0
	btn_next.disabled = _page >= total_pages - 1
	for i in pet_grid.get_child_count():
		var slot := pet_grid.get_child(i) as PanelContainer
		var pid := str(_pool_ids[start + i]) if start + i < _pool_ids.size() else ""
		var pet: PetData = GameData.pet_db.get(pid)
		_set_slot(slot, pet, false)
		var can_feed := true
		if pet and not _devour_pid.is_empty():
			var eater: PetData = GameData.pet_db.get(_devour_pid)
			if eater: can_feed = pet.aptitude >= _effective_apt(eater)
		slot.set_meta("can_feed", can_feed)
		slot.modulate = Color.WHITE if can_feed else Color(0.55, 0.62, 0.72, 0.65)
		slot.set_meta("keyboard_default", i == 0 and pet != null)
	_update_slot_highlights()

func _set_slot(slot: PanelContainer, pet: PetData, deployed: bool) -> void:
	slot.set_meta("pet_id", pet.pet_id if pet else "")
	slot.set_meta("keyboard_skip", pet == null)
	slot.get_node("Content/Empty").visible = pet == null
	slot.get_node("Content/Name").text = pet.character_name if pet else ""
	slot.get_node("Content/Level").text = "%s级资质 · Lv.%d" % [PetData.apt_name(pet.aptitude), pet.level] if pet else ""
	var portrait := slot.get_node("Content/Portrait") as TextureRect
	portrait.texture = _portrait_texture(pet.was_base_path, "头像" if deployed else "x32") if pet else null
	slot.get_node("Content/Fallback").text = PetData.apt_name(pet.aptitude) if pet and portrait.texture == null else ""
	var glow := slot.get_node("Content/Glow") as ColorRect
	_set_aptitude_aura(glow, pet)
	if pet:
		slot.tooltip_text = "%s · %s级资质 · 等级%d%s" % [pet.character_name, PetData.apt_name(pet.aptitude), pet.level, " · 点击召回" if deployed else ""]
	else:
		slot.tooltip_text = "空位" if deployed else "暂无宠物"

## 独立的场景材质保证每只宠物的资质光效互不影响。
func _set_aptitude_aura(aura: ColorRect, pet: PetData) -> void:
	var aptitude := int(pet.aptitude) if pet else int(PetData.Aptitude.丁)
	var intensity := [0.0, 0.44, 0.64, 0.84, 1.0]
	aura.visible = pet != null and aptitude > PetData.Aptitude.丁
	var material := aura.material as ShaderMaterial
	material.set_shader_parameter("strength", intensity[aptitude])
	material.set_shader_parameter("grade", float(aptitude))
	material.set_shader_parameter("aura_color", APT_COLORS.get(aptitude, Color.GRAY))

func _update_slot_highlights() -> void:
	for container in [deploy_grid, pet_grid]:
		for slot in container.get_children():
			var pid := str(slot.get_meta("pet_id", ""))
			var frame := slot.get_node("Content/Selection") as ReferenceRect
			frame.visible = not pid.is_empty() and (pid == _selected_pid or pid in _devour_food_ids)
			frame.border_color = Color(0.75, 0.3, 0.25) if pid in _devour_food_ids else Color(0.93, 0.73, 0.29)

func _preview_slot(slot: Control) -> void:
	var pid := str(slot.get_meta("pet_id", ""))
	if pid.is_empty() or not _devour_pid.is_empty() or _selected_pid == pid: return
	_selected_pid = pid
	_update_detail()
	_update_slot_highlights()

func _on_deploy_slot_input(event: InputEvent, slot: Control) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return
	var pid := str(slot.get_meta("pet_id", ""))
	if pid.is_empty() or not _devour_pid.is_empty(): return
	GameData.pet_team.erase(pid)
	_pool_ids = _build_pool()
	_selected_pid = pid
	_refresh()

func _on_warehouse_slot_input(event: InputEvent, slot: Control) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return
	var pid := str(slot.get_meta("pet_id", ""))
	if pid.is_empty(): return
	if not _devour_pid.is_empty():
		if not slot.get_meta("can_feed", true) and pid not in _devour_food_ids: return
		_toggle_devour_food(pid)
	else:
		_selected_pid = pid
		_refresh()


func _update_detail() -> void:
	var pet: PetData = GameData.pet_db.get(_selected_pid) if _selected_pid != "" else null
	_set_aptitude_aura($Panel/WASPreview/AptitudeAura, pet)
	devour_progress.hide()
	if pet == null:
		detail_name.text = "请选择宠物"
		detail_info.text = ""
		$Panel/ProgressSummary.text = ""
		detail_skills.text = ""
		detail_apt.text = "在下方仓库选择，查看属性与技能"
		btn_deploy.disabled = true
		btn_deploy.text = "上场"
		btn_release.visible = false
		btn_devour.visible = false
		btn_teach_book.visible = false
		preview_was.stop()
		preview_sprite.texture = null
		return

	detail_name.text = pet.character_name
	detail_apt.text = "资质：%s · 等级 %d" % [PetData.apt_name(pet.aptitude), pet.level]

	# 计算书技能加成后的等效属性（与 BattleCharacter 一致）
	var eff_hp = pet.max_hp; var eff_spd = pet.speed
	eff_hp = int(eff_hp * _pet_book_mul(pet, "hp_up"))
	eff_spd = int(eff_spd * _pet_book_mul(pet, "haste"))
	# 迟钝特殊处理
	for b in pet.book_skills:
		var db = SkillDB.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == "slow_tank":
			eff_hp = int(eff_hp * db.value.hp)
			eff_spd = int(eff_spd * db.value.speed)
	var eff_atk = int(pet.attack * _pet_book_mul(pet, "atk_up"))
	var eff_matk = int(pet.magic_attack * _pet_book_mul(pet, "matk_up"))
	var eff_def = int(pet.defense * _pet_book_mul(pet, "def_up"))
	var eff_mdef = int(pet.magic_defense * _pet_book_mul(pet, "mdef_up"))

	var base_info = "气血 %d    灵力 %d\n物攻 %d    法攻 %d\n物防 %d    法防 %d    速度 %d" % [
		eff_hp, pet.max_mp, eff_atk, eff_matk, eff_def, eff_mdef, eff_spd
	]
	if pet.aptitude != PetData.Aptitude.特:
		var needed = PetData.DEVOUR_REQUIRED.get(pet.aptitude, 0) - pet.devour_count
		$Panel/ProgressSummary.text = "吞噬成长：%d / %d" % [pet.devour_count, PetData.DEVOUR_REQUIRED.get(pet.aptitude, 0)]
	else:
		$Panel/ProgressSummary.text = "已达最高资质"
	detail_info.text = base_info
	$Panel/ProgressSummary.visible = _devour_pid.is_empty()
	detail_skills.visible = _devour_pid.is_empty()

	# 被动书显示（聚合同名数量）
	var book_display: String = "无"
	if not pet.book_skills.is_empty():
		var book_counts: Dictionary = {}
		for b in pet.book_skills:
			book_counts[b] = book_counts.get(b, 0) + 1
		var parts: Array[String] = []
		for b in book_counts:
			if book_counts[b] > 1:
				parts.append("%s x%d" % [b, book_counts[b]])
			else:
				parts.append(b)
		book_display = " / ".join(parts)
	detail_skills.text = "技能：%s\n被动：%s (%d/%d)" % [
		(" / ".join(pet.skill_ids) if not pet.skill_ids.is_empty() else "无"),
		book_display, pet.book_skills.size(), PetData.max_book_skills(pet.aptitude)
	]

	# 蓝色显示已有成长，金色只显示本次选择带来的增量。
	if _devour_pid == _selected_pid and pet.aptitude != PetData.Aptitude.特:
		_update_devour_progress(pet)

	btn_deploy.text = "已上场" if _selected_pid in GameData.pet_team else "上场"
	btn_deploy.disabled = _selected_pid in GameData.pet_team or GameData.pet_team.size() >= 6

	# 打书按钮
	btn_teach_book.visible = (_devour_pid == "")
	var max_books = PetData.max_book_skills(pet.aptitude)
	btn_teach_book.disabled = pet.book_skills.size() >= max_books
	if pet.book_skills.size() >= max_books:
		btn_teach_book.text = "技能已满"
	else:
		btn_teach_book.text = "打书"

	# 吞噬按钮（特级不可吞噬，吞噬模式中变取消）
	if pet.aptitude == PetData.Aptitude.特:
		btn_devour.visible = false
	else:
		btn_devour.visible = true
		if _devour_pid != "" and _devour_food_ids.size() > 0:
			btn_devour.text = "确认吞噬(%d)" % _devour_food_ids.size()
		elif _devour_pid != "":
			btn_devour.text = "取消吞噬"
		else:
			btn_devour.text = "吞噬"

	btn_release.visible = pet.aptitude != PetData.Aptitude.特 and _devour_pid == ""
	btn_release.disabled = _selected_pid in GameData.pet_team
	devour_tip.visible = (_devour_pid != "")
	if _devour_pid != "":
		devour_tip.text = "已选 %d 只饲料" % _devour_food_ids.size()
	# WAS 动画预览
	_load_preview(pet)


func _update_devour_progress(pet: PetData) -> void:
	var gained := 0
	for fid in _devour_food_ids:
		var food: PetData = GameData.pet_db.get(fid)
		if food: gained += PetData.devour_value(pet.aptitude, food.aptitude)
	var needed: int = PetData.DEVOUR_REQUIRED.get(pet.aptitude, 5)
	var current := pet.devour_count
	var projected := current + gained
	var stage := pet.aptitude
	var remaining := projected
	while stage < PetData.Aptitude.特 and remaining >= int(PetData.DEVOUR_REQUIRED.get(stage, 5)):
		remaining -= int(PetData.DEVOUR_REQUIRED.get(stage, 5))
		stage = stage + 1 as PetData.Aptitude
	devour_progress.get_node("Title").text = "%s → %s" % [PetData.apt_name(pet.aptitude), PetData.apt_name(pet.aptitude + 1 as PetData.Aptitude)]
	devour_progress.get_node("Count").text = "%d / %d" % [mini(projected, needed), needed]
	var existing := devour_progress.get_node("Current") as ProgressBar
	var preview := devour_progress.get_node("Preview") as ProgressBar
	existing.max_value = needed
	preview.max_value = needed
	existing.value = current
	preview.value = projected
	var hint := "蓝色：已积累 %d · 金色：本次 +%d" % [current, gained]
	if stage > pet.aptitude:
		hint += " · 可升至%s级" % PetData.apt_name(stage)
		if stage < PetData.Aptitude.特:
			hint += "（%d/%d）" % [remaining, PetData.DEVOUR_REQUIRED.get(stage, 5)]
	devour_progress.get_node("Hint").text = hint
	devour_progress.show()


func _load_preview(pet: PetData) -> void:
	preview_was.stop()
	if pet.was_base_path.is_empty():
		preview_sprite.texture = null
		return
	preview_was.anim_files.clear()
	preview_was.direction = 0  # 默认方向，避免单组 WAS 越界
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
	# 加载后读取 WAS 实际方向数，选右下方向（6），超过则用 0
	var r = preview_was._readers.get("idle")
	if r and r.group_count > 6:
		preview_was.direction = 6
	preview_was.play("idle")


func _on_deploy() -> void:
	if _selected_pid == "" or GameData.pet_team.size() >= 6: return
	var pet = GameData.pet_db.get(_selected_pid)
	if pet == null: return
	# 检查同名宠物不可重复上阵
	for pid in GameData.pet_team:
		var other = GameData.pet_db.get(pid)
		if other and other.character_name == pet.character_name:
			_show_flash_text("❌ 同名宠物 \"%s\" 已在队伍中！" % pet.character_name)
			return
	GameData.pet_team.append(_selected_pid)
	_pool_ids = _build_pool()
	_selected_pid = ""
	_refresh()


func _on_devour() -> void:
	var pet: PetData = GameData.pet_db.get(_selected_pid) if _selected_pid != "" else null
	if pet == null: return

	# 吞噬会永久消耗饲料，执行前统一确认。
	if _devour_pid != "" and _devour_food_ids.size() > 0:
		_show_confirm_popup("确定让【%s】吞噬所选的 %d 只宠物吗？\n饲料宠物将永久消失，无法找回。" % [pet.character_name, _devour_food_ids.size()], _confirm_devour)
		return

	# 取消吞噬模式
	if _devour_pid != "":
		_devour_pid = ""
		_devour_food_ids.clear()
		_refresh()
		return

	# 进入吞噬模式
	if pet.aptitude == PetData.Aptitude.特: return
	_devour_pid = _selected_pid
	_devour_food_ids.clear()
	_refresh()


func _toggle_devour_food(food_pid: String) -> void:
	if _devour_pid == "" or _devour_pid == food_pid: return
	var food = GameData.pet_db.get(food_pid)
	if food == null: return

	# 取消已选中的 → 直接移除
	if food_pid in _devour_food_ids:
		_devour_food_ids.erase(food_pid)
		_refresh()
		return

	# 添加前检查限制：特级不可，低于等效资质不可
	if food.aptitude == PetData.Aptitude.特:
		return

	var eater = GameData.pet_db.get(_devour_pid)
	if eater == null: return

	var eff_apt = _effective_apt(eater)
	if food.aptitude < eff_apt:
		return

	# 甲级饲料：首次选中需二次确认
	if food.aptitude == PetData.Aptitude.甲 and food_pid not in _devour_food_ids:
		_pending_food_pid = food_pid
		_show_confirm_popup("⚠️ %s 是甲级宠物，确定要当作饲料吗？" % food.character_name, func():
			_devour_food_ids.append(_pending_food_pid)
			_pending_food_pid = ""
			_refresh()
		)
		return

	_devour_food_ids.append(food_pid)
	_refresh()


## 根据当前 devour_count + 预览选中的饲料，算出等效资质
func _effective_apt(eater: PetData) -> PetData.Aptitude:
	var apt = eater.aptitude
	var cur = eater.devour_count
	for fid in _devour_food_ids:
		if fid == _devour_pid: continue
		var f = GameData.pet_db.get(fid)
		if f: cur += PetData.devour_value(apt, f.aptitude)
	while apt != PetData.Aptitude.特:
		var need = PetData.DEVOUR_REQUIRED.get(apt, 1)
		if cur >= need:
			cur -= need
			apt = apt + 1 as PetData.Aptitude
		else:
			break
	return apt


func _confirm_devour() -> void:
	if _devour_pid == "" or _devour_food_ids.is_empty(): return
	var eater = GameData.pet_db.get(_devour_pid)
	if eater == null: return

	# 锁定吃的列表（_refresh 会清空 _devour_food_ids）
	var food_list = _devour_food_ids.duplicate()
	var total_val = 0

	for food_pid in food_list:
		var food = GameData.pet_db.get(food_pid)
		if food == null: continue
		var val = PetData.devour_value(eater.aptitude, food.aptitude)
		total_val += val
		GameData.pet_db.erase(food_pid)
		GameData.pet_team.erase(food_pid)

	eater.devour_count += total_val

	# 检查升级（支持连升/溢出继承）
	var evolved := false
	while eater.devour_count >= PetData.DEVOUR_REQUIRED.get(eater.aptitude, 1) and eater.aptitude != PetData.Aptitude.特:
		var needed = PetData.DEVOUR_REQUIRED.get(eater.aptitude, 1)
		eater.devour_count -= needed
		var old_name = PetData.apt_name(eater.aptitude)
		var old_enum = eater.aptitude
		eater.aptitude = old_enum + 1 as PetData.Aptitude
		var ratio = PetData.APT_GROWTH_MUL[eater.aptitude] / PetData.APT_GROWTH_MUL[old_enum]
		eater.max_hp = maxi(1, int(eater.max_hp * ratio))
		eater.max_mp = maxi(1, int(eater.max_mp * ratio))
		eater.attack = maxi(1, int(eater.attack * ratio))
		eater.magic_attack = maxi(1, int(eater.magic_attack * ratio))
		eater.defense = maxi(1, int(eater.defense * ratio))
		eater.magic_defense = maxi(1, int(eater.magic_defense * ratio))
		eater.speed = maxi(1, int(eater.speed * ratio))
		_show_evolve_popup("✦ 资质提升 ✦\n%s → %s\n%s" % [old_name, PetData.apt_name(eater.aptitude), eater.character_name])
		evolved = true
		# 等待弹窗消失再继续
		await get_tree().create_timer(2.8).timeout

	_devour_pid = ""
	_devour_food_ids.clear()
	_pool_ids = _build_pool()
	_selected_pid = ""
	_refresh()


func _show_evolve_popup(text: String) -> void:
	evolve_overlay.text = text
	evolve_overlay.modulate.a = 0.0
	evolve_overlay.visible = true
	var t = create_tween()
	t.tween_property(evolve_overlay, "modulate:a", 1.0, 0.3)
	t.tween_interval(2.0)
	t.tween_property(evolve_overlay, "modulate:a", 0.0, 0.5)
	t.tween_callback(func(): evolve_overlay.visible = false)

func _on_release() -> void:
	var pid := _selected_pid
	var pet: PetData = GameData.pet_db.get(pid)
	if pet == null or pid in GameData.pet_team or pet.aptitude == PetData.Aptitude.特: return
	_show_confirm_popup("确定放生【%s】（%s级 · Lv.%d）吗？\n宠物及其已学技能将永久失去，无法找回。" % [pet.character_name, PetData.apt_name(pet.aptitude), pet.level], _confirm_release.bind(pid), "确认放生")


func _confirm_release(pid: String) -> void:
	var pet: PetData = GameData.pet_db.get(pid)
	if pet == null or pid in GameData.pet_team or pet.aptitude == PetData.Aptitude.特: return
	GameData.pet_db.erase(pid)
	_pool_ids = _build_pool()
	_selected_pid = ""
	_refresh()


func _on_prev() -> void:
	if _page > 0:
		_page -= 1
		_selected_pid = ""
		_refresh()


func _on_next() -> void:
	var total_pages = maxi(1, ceili(float(_pool_ids.size()) / PETS_PER_PAGE))
	if _page < total_pages - 1:
		_page += 1
		_selected_pid = ""
		_refresh()


func _on_close() -> void:
	_cancel_confirm()
	# 关闭音效
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://Audio/SE/003-System03.ogg")
	snd.bus = "SFX"
	get_tree().root.add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)
	_pop_out()
	closed.emit()


func _ready() -> void:
	$ConfirmPopup/Card/Yes.pressed.connect(_accept_confirm)
	$ConfirmPopup/Card/Cancel.pressed.connect(_cancel_confirm)
	$ConfirmPopup.set_meta("keyboard_cancel", _cancel_confirm)
	$BookSelectPopup/Card/Cancel.pressed.connect($BookSelectPopup.hide)
	$BookSelectPopup.set_meta("keyboard_cancel", $BookSelectPopup.hide)
	btn_deploy.pressed.connect(_on_deploy)
	btn_release.pressed.connect(_on_release)
	btn_devour.pressed.connect(_on_devour)
	btn_prev.pressed.connect(_on_prev)
	btn_next.pressed.connect(_on_next)
	btn_close.pressed.connect(_on_close)
	evolve_overlay.hide()
	devour_progress.visible = false
	btn_mech.pressed.connect(_open_mech_upgrade)
	btn_teach_book.pressed.connect(_on_teach_book)
	btn_teach_book.visible = false
	_mech_popup.hide()
	_mech_popup.closed.connect(func(): _mech_popup.hide())
	for slot in deploy_grid.get_children():
		slot.gui_input.connect(_on_deploy_slot_input.bind(slot))
		slot.mouse_entered.connect(_preview_slot.bind(slot))
		slot.set_meta("keyboard_detail", _preview_slot.bind(slot))
		slot.set_meta("keyboard_region", "deployed")
	for slot in pet_grid.get_children():
		slot.gui_input.connect(_on_warehouse_slot_input.bind(slot))
		slot.mouse_entered.connect(_preview_slot.bind(slot))
		slot.set_meta("keyboard_detail", _preview_slot.bind(slot))
		slot.set_meta("keyboard_region", "warehouse")
	set_meta("keyboard_region_order", ["deployed", "warehouse", "actions", "paging", "close"])
	for button in [btn_deploy, btn_release, btn_devour, btn_teach_book, btn_mech]: button.set_meta("keyboard_region", "actions")
	for button in [btn_prev, btn_next]: button.set_meta("keyboard_region", "paging")
	btn_close.set_meta("keyboard_region", "close")
	hide()
	await get_tree().process_frame
	open()


func _pet_book_mul(pet: PetData, book_type: String) -> float:
	var mul = 1.0
	for b in pet.book_skills:
		var db = SkillDB.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == book_type:
			var v = db.get("value", 1.0)
			if v is float or v is int:
				mul *= v
	return mul


func _on_teach_book() -> void:
	if _selected_pid == "" or _devour_pid != "": return
	var pet = GameData.pet_db.get(_selected_pid)
	if pet == null: return
	if pet.book_skills.size() >= PetData.max_book_skills(pet.aptitude): return

	# 收集背包中的技能书（同名聚合数量，已学的同名书不显示）
	var book_counts: Dictionary = {}
	for slot in GameData.player_inventory._slots.values():
		var item: ItemData = slot.get("data", null)
		if item == null or item.item_type != ItemData.ItemType.SKILL_BOOK: continue
		var count: int = slot.get("count", 0)
		if count <= 0: continue
		var bid = item.book_skill_id
		if bid in pet.book_skills: continue  # 同名不可叠加
		if book_counts.has(bid):
			book_counts[bid].count += count
		else:
			book_counts[bid] = {"book_id": bid, "item_id": item.item_id, "name": item.book_skill_id, "desc": item.description, "count": count}

	if book_counts.is_empty():
		_show_flash_text("没有可用的技能书！")
		return

	_show_book_select_popup(book_counts.values(), pet)




func _show_book_select_popup(books: Array, pet: PetData) -> void:
	var popup := $BookSelectPopup as Control
	var list := $BookSelectPopup/Card/Scroll/Books as VBoxContainer
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	$BookSelectPopup/Card/Message.text = "选择技能书 · 剩余 %d 格" % (PetData.max_book_skills(pet.aptitude) - pet.book_skills.size())
	for book in books:
		# 技能书条目数量由背包数据决定，复用编辑器中的条目场景。
		var button := preload("res://scenes/UI/Pets/PetBookChoice.tscn").instantiate() as Button
		button.text = "%s ×%d\n%s" % [book.name, book.count, book.desc]
		var bid: String = book.book_id
		var iid: String = book.item_id
		button.pressed.connect(func():
			_do_teach_book(pet, bid, iid)
			popup.hide()
		)
		list.add_child(button)
	popup.show()


func _do_teach_book(pet: PetData, book_id: String, item_id: String) -> void:
	if pet.book_skills.size() >= PetData.max_book_skills(pet.aptitude): return
	if book_id in pet.book_skills: return  # 同名不可叠加
	if not GameData.player_inventory.remove_item(item_id, 1): return
	pet.book_skills.append(book_id)
	_refresh()
	_show_flash_text("✓ %s 学会了 %s！" % [pet.character_name, book_id])

func _show_flash_text(msg: String) -> void:
	UIFeedback.play_ui(&"success" if msg.begins_with("✓") else &"error")
	var label := $Panel/FlashMessage as Label
	label.text = msg
	label.show()
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(label.hide)


func _show_confirm_popup(msg: String, on_yes: Callable, yes_text: String = "确认吞噬") -> void:
	_confirm_action = on_yes
	$ConfirmPopup/Card/Message.text = msg
	$ConfirmPopup/Card/Yes.text = yes_text
	$ConfirmPopup.show()
	$ConfirmPopup/Card/Cancel.grab_focus()

func _accept_confirm() -> void:
	$ConfirmPopup.hide()
	var action := _confirm_action
	_confirm_action = Callable()
	if action.is_valid(): action.call()


func _cancel_confirm() -> void:
	$ConfirmPopup.hide()
	_confirm_action = Callable()


func _open_mech_upgrade() -> void:
	if _mech_popup:
		_mech_popup.open()


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


func keyboard_page(direction: int) -> void:
	if direction < 0: _on_prev()
	else: _on_next()

func _keyboard_pet_detail(pid: String) -> void:
	if _devour_pid != "": return
	_selected_pid = pid
	_update_detail()
