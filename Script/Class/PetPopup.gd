# PetPopup.gd
# 宠物管理弹窗 — 上面6个已上场格（WAS头像），下面翻页列表
class_name PetPopup
extends CanvasLayer

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
@onready var devour_bar_label: Label = $Panel/DevourBarLabel
@onready var evolve_overlay: Label = $Panel/EvolveOverlay
@onready var page_label: Label = $Panel/PageLabel
@onready var btn_prev: Button = $Panel/BtnPrev
@onready var btn_next: Button = $Panel/BtnNext
@onready var btn_close: TextureButton = $Panel/CloseBtn
@onready var btn_mech: Button = $Panel/BtnMech
@onready var preview_sprite: Sprite2D = $Panel/WASPreview/Sprite2D
@onready var preview_was: WASAnimationPlayer = $Panel/WASPreview/WASAnimationPlayer
var _mech_popup: MechPopup = null

const APT_COLORS := {
	PetData.Aptitude.丁: Color(0.6, 0.6, 0.6),
	PetData.Aptitude.丙: Color(0.3, 0.8, 0.3),
	PetData.Aptitude.乙: Color(0.3, 0.5, 1.0),
	PetData.Aptitude.甲: Color(0.7, 0.3, 1.0),
	PetData.Aptitude.特: Color(1.0, 0.85, 0.2),
}

var _pool_ids: Array = []
var _page: int = 0
var _selected_pid: String = ""
var _devour_pid: String = ""        # 吞噬者ID
var _devour_food_ids: Array = []    # 多选食物ID
var _glow_tweens: Array = []
var btn_teach_book: Button
var _pending_food_pid: String = ""  # 甲级吞噬确认用
const PETS_PER_PAGE := 8


func open() -> void:
	_pool_ids = _build_pool()
	_page = 0
	_selected_pid = ""
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
	for t in _glow_tweens: if t: t.kill()
	_glow_tweens.clear()
	_refresh_deploy()
	_refresh_list()
	_update_detail()


func _portrait_texture(was_base: String, size: String) -> Texture2D:
	if was_base.is_empty(): return null
	var path = was_base + "/头像/%s.was" % size
	if not FileAccess.file_exists(path): return null
	var r = WASReader.new()
	if not r.load_from_file(path): return null
	var d = r.decode_frame(0, 0)
	if d.is_empty(): return null
	return d.get("texture", null)


# ── 上场格 ──

func _refresh_deploy() -> void:
	for c in deploy_grid.get_children(): c.queue_free()

	for i in 6:
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(90, 72)
		if i < GameData.pet_team.size():
			var pid = GameData.pet_team[i]
			var pet = GameData.pet_db.get(pid)
			if pet:
				var vbox = VBoxContainer.new()
				vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

				# 头像容器（光圈在下，头像在上）
				var av_cont = Control.new()
				av_cont.custom_minimum_size = Vector2(52, 52)
				av_cont.mouse_filter = Control.MOUSE_FILTER_IGNORE

				# 光圈层
				var glow = ColorRect.new()
				glow.color = APT_COLORS.get(pet.aptitude, Color.GRAY)
				glow.modulate.a = 0.0
				glow.offset_left = 0; glow.offset_top = -2
				glow.offset_right =0; glow.offset_bottom = 2
				glow.set_anchors_preset(Control.PRESET_FULL_RECT)
				glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
				av_cont.add_child(glow)

				# 头像层
				var tex = _portrait_texture(pet.was_base_path, "头像")
				if tex:
					var tr = TextureRect.new()
					tr.texture = tex
					tr.set_anchors_preset(Control.PRESET_FULL_RECT)
					tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					av_cont.add_child(tr)
				else:
					var bg = ColorRect.new()
					bg.color = APT_COLORS.get(pet.aptitude, Color.GRAY)
					bg.set_anchors_preset(Control.PRESET_FULL_RECT)
					av_cont.add_child(bg)
					var al = Label.new()
					al.text = PetData.apt_name(pet.aptitude)
					al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					al.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					al.set_anchors_preset(Control.PRESET_FULL_RECT)
					av_cont.add_child(al)
				vbox.add_child(av_cont)

				# 光圈闪烁
				var tw = create_tween().set_loops()
				tw.tween_property(glow, "modulate:a", 0.9, 0.7)
				tw.tween_property(glow, "modulate:a", 0.2, 0.7)
				_glow_tweens.append(tw)

				var name_lbl = Label.new()
				name_lbl.text = "%s %s" % [PetData.apt_name(pet.aptitude), pet.character_name]
				name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				name_lbl.add_theme_font_size_override("font_size", 10)
				vbox.add_child(name_lbl)

				var sid = pid
				slot.gui_input.connect(func(event):
					if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
						if _devour_pid != "": return  # 吞噬模式下忽略上场格的点击
						GameData.pet_team.erase(sid)
						_pool_ids = _build_pool()
						_selected_pid = ""
						_refresh()
				)
				slot.add_child(vbox)
		else:
			var lbl = Label.new()
			lbl.text = "空位"
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
			slot.add_child(lbl)
		deploy_grid.add_child(slot)


# ── 列表 ──

func _refresh_list() -> void:
	for c in pet_grid.get_children(): c.queue_free()

	var start = _page * PETS_PER_PAGE
	var items = _pool_ids.slice(start, start + PETS_PER_PAGE)
	var total_pages = maxi(1, ceili(float(_pool_ids.size()) / PETS_PER_PAGE))
	page_label.text = "%d / %d" % [_page + 1, total_pages]
	btn_prev.disabled = _page <= 0
	btn_next.disabled = _page >= total_pages - 1

	for i in PETS_PER_PAGE:
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(130, 46)
		if i < items.size():
			var pid = items[i]
			var pet = GameData.pet_db[pid]

			var can_feed = true
			if _devour_pid != "":
				var eater = GameData.pet_db.get(_devour_pid)
				if eater:
					var eff_apt = _effective_apt(eater)
					if pet.aptitude < eff_apt:
						can_feed = false

			var hbox = HBoxContainer.new()
			hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var tex = _portrait_texture(pet.was_base_path, "x32")
			if tex:
				var tr = TextureRect.new()
				tr.texture = tex
				tr.custom_minimum_size = Vector2(32, 32)
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				hbox.add_child(tr)

			var lbl = Label.new()
			lbl.text = "%s  %s" % [PetData.apt_name(pet.aptitude), pet.character_name]
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hbox.add_child(lbl)

			if pid == _selected_pid:
				var hl = StyleBoxFlat.new()
				hl.bg_color = Color(0.15, 0.3, 0.55, 0.5)
				hl.border_color = Color(0.3, 0.6, 0.9, 0.7)
				hl.border_width_top = 1; hl.border_width_bottom = 1
				hl.border_width_left = 1; hl.border_width_right = 1
				slot.add_theme_stylebox_override("panel", hl)
			elif pid in _devour_food_ids:
				var hl = StyleBoxFlat.new()
				hl.bg_color = Color(0.5, 0.15, 0.15, 0.5)
				hl.border_color = Color(0.9, 0.3, 0.3, 0.7)
				hl.border_width_top = 1; hl.border_width_bottom = 1
				hl.border_width_left = 1; hl.border_width_right = 1
				slot.add_theme_stylebox_override("panel", hl)
			elif _devour_pid != "" and not can_feed:
				slot.modulate = Color(0.4, 0.4, 0.4, 0.5)

			slot.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					if _devour_pid != "":
						if not can_feed and pid not in _devour_food_ids: return
						_toggle_devour_food(pid)
					else:
						_selected_pid = pid
						_refresh()
			)
			slot.add_child(hbox)
		pet_grid.add_child(slot)


func _update_detail() -> void:
	var pet: PetData = GameData.pet_db.get(_selected_pid) if _selected_pid != "" else null
	if pet == null:
		detail_name.text = ""
		detail_info.text = ""
		detail_skills.text = ""
		detail_apt.text = ""
		btn_deploy.disabled = true
		btn_deploy.text = "上场"
		btn_release.visible = false
		btn_devour.visible = false
		btn_teach_book.visible = false
		preview_was.stop()
		preview_sprite.texture = null
		return

	detail_name.text = pet.character_name
	detail_apt.text = "资质：%s" % PetData.apt_name(pet.aptitude)

	# 计算书技能加成后的等效属性（与 BattleCharacter 一致）
	var eff_hp = pet.max_hp; var eff_spd = pet.speed
	eff_hp = int(eff_hp * _pet_book_mul(pet, "hp_up"))
	eff_spd = int(eff_spd * _pet_book_mul(pet, "haste"))
	# 迟钝特殊处理
	for b in pet.book_skills:
		var db = GameData.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == "slow_tank":
			eff_hp = int(eff_hp * db.value.hp)
			eff_spd = int(eff_spd * db.value.speed)
	var eff_atk = int(pet.attack * _pet_book_mul(pet, "atk_up"))
	var eff_matk = int(pet.magic_attack * _pet_book_mul(pet, "matk_up"))
	var eff_def = int(pet.defense * _pet_book_mul(pet, "def_up"))
	var eff_mdef = int(pet.magic_defense * _pet_book_mul(pet, "mdef_up"))

	var base_info = "等级 %d\n气血 %d  灵力 %d\n攻击 %d  法攻 %d\n防御 %d  法防 %d  速度 %d" % [
		pet.level, eff_hp, pet.max_mp, eff_atk, eff_matk, eff_def, eff_mdef, eff_spd
	]
	if pet.aptitude != PetData.Aptitude.特:
		var needed = PetData.DEVOUR_REQUIRED.get(pet.aptitude, 0) - pet.devour_count
		base_info += "\n吞噬进度：%d/%d" % [pet.devour_count, PetData.DEVOUR_REQUIRED.get(pet.aptitude, 0)]
	detail_info.text = base_info

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

	# 吞噬进度条预览
	devour_bar_label.visible = false
	if _devour_pid == _selected_pid and pet.aptitude != PetData.Aptitude.特:
		var cur = pet.devour_count
		var prev = 0
		for fid in _devour_food_ids:
			var f = GameData.pet_db.get(fid)
			if f: prev += PetData.devour_value(pet.aptitude, f.aptitude)

		# 生成多阶段进度条渲染
		var orig_apt_name = PetData.apt_name(pet.aptitude)
		var stage_apt = pet.aptitude
		var stage_cur = cur
		var remaining_gain = prev
		var bar_text := ""

		while stage_apt != PetData.Aptitude.特:
			var needed = PetData.DEVOUR_REQUIRED.get(stage_apt, 1)
			var next_name = PetData.apt_name(stage_apt + 1 as PetData.Aptitude)
			var bar = ""
			for j in 12:
				var t = float(j) / 12.0 * needed
				if t < stage_cur:
					bar += "■"
				elif t < min(stage_cur + remaining_gain, needed):
					bar += "▣"
				else:
					bar += "□"
			var after_stage = stage_cur + remaining_gain
			if after_stage >= needed:
				remaining_gain -= (needed - stage_cur)
				stage_cur = 0
				stage_apt = stage_apt + 1 as PetData.Aptitude
				# 不追加，直接覆盖到下一阶段
				continue
			bar_text = "%s→%s %s" % [orig_apt_name, next_name, bar]
			if remaining_gain > 0:
				bar_text += "  %d/%d" % [min(after_stage, needed), needed]
			else:
				bar_text += "  %d/%d" % [stage_cur, needed]
			break
		if bar_text.is_empty():
			bar_text = "%s→%s ■■■■■■■■■■■■" % [orig_apt_name, PetData.apt_name(stage_apt)]
		devour_bar_label.text = bar_text
		devour_bar_label.visible = true

	btn_deploy.text = "上场"
	btn_deploy.disabled = GameData.pet_team.size() >= 6

	# 打书按钮
	btn_teach_book.visible = (_devour_pid == "")
	var max_books = PetData.max_book_skills(pet.aptitude)
	btn_teach_book.disabled = pet.book_skills.size() >= max_books
	if pet.book_skills.size() >= max_books:
		btn_teach_book.text = "📖 已满"
	else:
		btn_teach_book.text = "📖 打书"

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

	# 如果已有食物选中 → 先检查是否有甲级需要确认
	if _devour_pid != "" and _devour_food_ids.size() > 0:
		var has_jia = false
		for fid in _devour_food_ids:
			var f = GameData.pet_db.get(fid)
			if f and f.aptitude == PetData.Aptitude.甲:
				has_jia = true; break
		if has_jia:
			_show_confirm_popup("⚠️ 饲料中包含甲级宠物！\n确认吞噬吗？", func():
				_confirm_devour()
			)
			return
		_confirm_devour()
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
	if _selected_pid == "": return
	if _selected_pid in GameData.pet_team: return
	var pet = GameData.pet_db.get(_selected_pid)
	if pet and pet.aptitude == PetData.Aptitude.特: return
	GameData.pet_db.erase(_selected_pid)
	GameData.pet_team.erase(_selected_pid)
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
	_pop_out()
	closed.emit()


func _ready() -> void:
	btn_deploy.pressed.connect(_on_deploy)
	btn_release.pressed.connect(_on_release)
	btn_devour.pressed.connect(_on_devour)
	btn_prev.pressed.connect(_on_prev)
	btn_next.pressed.connect(_on_next)
	btn_close.pressed.connect(_on_close)
	evolve_overlay.add_theme_font_size_override("font_size", 22)
	evolve_overlay.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	evolve_overlay.hide()
	devour_bar_label.visible = false
	# 铁甲强化按钮
	var mech_btn = Button.new()
	mech_btn.text = "⚙ 铁甲强化"
	mech_btn.position = Vector2(690, 120)
	mech_btn.custom_minimum_size = Vector2(100, 30)
	panel.add_child(mech_btn)
	mech_btn.pressed.connect(_open_mech_upgrade)
	# 打书按钮
	btn_teach_book = Button.new()
	btn_teach_book.text = "📖 打书"
	btn_teach_book.position = Vector2(717, 206)
	btn_teach_book.custom_minimum_size = Vector2(85, 38)
	panel.add_child(btn_teach_book)
	btn_teach_book.pressed.connect(_on_teach_book)
	btn_teach_book.visible = false
	# 预加载 MechPopup
	var mp_res = load("res://Component/MechPopup.tscn")
	if mp_res:
		_mech_popup = mp_res.instantiate()
		add_child(_mech_popup)
		_mech_popup.hide()
		_mech_popup.closed.connect(func(): _mech_popup.hide())
	hide()
	await get_tree().process_frame
	open()


func _pet_book_mul(pet: PetData, book_type: String) -> float:
	var mul = 1.0
	for b in pet.book_skills:
		var db = GameData.BOOK_SKILL_DB.get(b, {})
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
	var popup = PanelContainer.new()
	popup.name = "BookSelectPopup"
	popup.anchor_left = 0.5; popup.anchor_top = 0.5
	popup.anchor_right = 0.5; popup.anchor_bottom = 0.5
	popup.offset_left = -170; popup.offset_top = -140
	popup.offset_right = 170; popup.offset_bottom = 140
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.15, 0.95)
	style.border_color = Color(0.8, 0.65, 0.2, 0.8)
	style.border_width_top = 2; style.border_width_bottom = 2
	style.border_width_left = 2; style.border_width_right = 2
	popup.add_theme_stylebox_override("panel", style)
	add_child(popup)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	popup.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var title = Label.new()
	title.text = "选择技能书  (%d格空位)" % (PetData.max_book_skills(pet.aptitude) - pet.book_skills.size())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	vbox.add_child(title)

	for book in books:
		var btn = Button.new()
		var bname: String = book.name
		var bcount: int = book.count
		btn.text = "%s\n%s — x%d" % [bname, book.desc, bcount]
		btn.custom_minimum_size = Vector2(305, 44)
		var bid = book.book_id; var iid = book.item_id
		btn.pressed.connect(func():
			_do_teach_book(pet, bid, iid)
			popup.queue_free()
		)
		vbox.add_child(btn)

	var cancel = Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(305, 32)
	cancel.pressed.connect(popup.queue_free)
	vbox.add_child(cancel)

func _do_teach_book(pet: PetData, book_id: String, item_id: String) -> void:
	if pet.book_skills.size() >= PetData.max_book_skills(pet.aptitude): return
	if book_id in pet.book_skills: return  # 同名不可叠加
	if not GameData.player_inventory.remove_item(item_id, 1): return
	pet.book_skills.append(book_id)
	_refresh()
	_show_flash_text("✓ %s 学会了 %s！" % [pet.character_name, book_id])

func _show_flash_text(msg: String) -> void:
	var lbl = Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.position = Vector2(270, 180)
	lbl.size = Vector2(300, 30)
	panel.add_child(lbl)
	var tw = create_tween().set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", lbl.position.y - 60, 1.5)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.5)
	tw.tween_callback(lbl.queue_free)


func _show_confirm_popup(msg: String, on_yes: Callable) -> void:
	var popup = PanelContainer.new()
	popup.name = "ConfirmPopup"
	popup.anchor_left = 0.5; popup.anchor_top = 0.5
	popup.anchor_right = 0.5; popup.anchor_bottom = 0.5
	popup.offset_left = -140; popup.offset_top = -60
	popup.offset_right = 140; popup.offset_bottom = 60
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.04, 0.04, 0.95)
	style.border_color = Color(0.9, 0.3, 0.3, 0.8)
	style.border_width_top = 2; style.border_width_bottom = 2
	style.border_width_left = 2; style.border_width_right = 2
	popup.add_theme_stylebox_override("panel", style)
	add_child(popup)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	popup.add_child(vbox)

	var lbl = Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(1, 0.6, 0.4))
	vbox.add_child(lbl)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)

	var yes = Button.new()
	yes.text = "确认吞噬"
	yes.custom_minimum_size = Vector2(90, 30)
	yes.pressed.connect(func(): popup.queue_free(); on_yes.call())
	hbox.add_child(yes)

	var no = Button.new()
	no.text = "取消"
	no.custom_minimum_size = Vector2(60, 30)
	no.pressed.connect(popup.queue_free)
	hbox.add_child(no)


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
