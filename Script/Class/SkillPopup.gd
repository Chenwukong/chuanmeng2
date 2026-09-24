# SkillPopup.gd
# 技能选择弹窗 — 战斗中选择仙术时弹出
# 上方显示当前选中技能的详情，下方是技能网格
# 鼠标点击 / 键盘上下左右均可操作
class_name SkillPopup
extends CanvasLayer

signal skill_selected(skill_id: String)
signal item_selected(item_id: String)
signal cancelled()

# ── 枚举 ──
enum Mode { SKILL, ITEM }
var _mode: Mode = Mode.SKILL

# ── 节点 ──
@onready var background:    ColorRect       = $Background
@onready var panel_window:  Control         = $PanelWindow
@onready var skill_name_lb: Label           = $PanelWindow/SkillName
@onready var skill_meta_lb: Label           = $PanelWindow/SkillMeta
@onready var skill_desc_lb: Label           = $PanelWindow/SkillDesc
@onready var skill_grid:    GridContainer   = $PanelWindow/ScrollContainer/SkillGrid
@onready var close_btn:      Button         = $PanelWindow/CloseBtn
@onready var title_label:   Label           = $PanelWindow/TitleLabel

# ── 数据 ──
var _actor: BattleCharacter = null
var _get_cooldown: Callable = Callable()
var _inventory: Inventory = null
var _item_entries: Array = []
var _buttons: Array = []           # SkillButton | ItemButton
var _skill_datas: Array[SkillData] = []   # 仅法术模式有值

# ── 按钮样式（在 _build_skill_list 中应用） ──
var _btn_style_normal: StyleBoxFlat
var _btn_style_hover:  StyleBoxFlat

# ── 类型标签映射 ──
const TYPE_LABELS := {
	SkillData.SkillType.PHYSICAL: "物理攻击",
	SkillData.SkillType.MAGIC:    "法术攻击",
	SkillData.SkillType.HEAL:     "治疗",
	SkillData.SkillType.BUFF:     "增益",
	SkillData.SkillType.DEBUFF:   "减益",
	SkillData.SkillType.MULTI_HIT: "多段攻击",
	SkillData.SkillType.AOE:      "群体攻击",
}
const TARGET_LABELS := {
	SkillData.TargetType.SINGLE_ENEMY: "敌方单体",
	SkillData.TargetType.SINGLE_ALLY:  "己方单体",
	SkillData.TargetType.SELF:         "自身",
	SkillData.TargetType.ALL_ENEMIES:  "敌方全体",
	SkillData.TargetType.ALL_ALLIES:   "己方全体",
}

# ══════════════════════════════════════════════

var _selected_idx: int = -1  # 当前选中按钮索引

func _ready() -> void:
	close_btn.pressed.connect(_on_cancel)
	background.gui_input.connect(_on_bg_click)
	# 设置简单按钮样式
	_setup_button_style()


func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	# 注意：ui_up/ui_down 会被 ScrollContainer 吞掉，所以改用 _input
	# 这里只用 ui_cancel / ui_accept
	if event.is_action_pressed("ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()
		return

	if _buttons.is_empty(): return
	if event.is_action_pressed("ui_accept"):
		if _selected_idx >= 0 and _selected_idx < _buttons.size():
			if not _buttons[_selected_idx].disabled:
				_buttons[_selected_idx].pressed.emit()
				get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible: return
	if _buttons.is_empty(): return
	var cols = 3
	var handled = false

	if event.is_action_pressed("ui_right"):
		if _selected_idx + 1 < _buttons.size():
			_selected_idx += 1
			handled = true
	elif event.is_action_pressed("ui_left"):
		if _selected_idx > 0:
			_selected_idx -= 1
			handled = true
	elif event.is_action_pressed("ui_down"):
		var target = _selected_idx + cols
		if target < _buttons.size():
			_selected_idx = target
			handled = true
	elif event.is_action_pressed("ui_up"):
		var target = _selected_idx - cols
		if target >= 0:
			_selected_idx = target
			handled = true

	if handled:
		_update_highlight()
		_update_detail(_selected_idx)
		get_viewport().set_input_as_handled()
		get_viewport().set_input_as_handled()


## 让弹窗居中
func center_panel() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	panel_window.position = (vp_size - Vector2(700, 540)) * 0.5


## 打开弹窗（法术模式）
func open(actor: BattleCharacter, get_cd_func: Callable) -> void:
	_mode = Mode.SKILL
	_actor = actor
	_get_cooldown = get_cd_func
	title_label.text = GameData._T("POPUP_SELECT_SKILL")
	_build_skill_list()
	_selected_idx = 0
	show()
	center_panel()
	if _buttons.size() > 0:
		_update_detail(0)
		_update_highlight()
	_pop_in()


## 打开弹窗（道具模式）
func open_for_items(actor: BattleCharacter, inventory: Inventory) -> void:
	# 先清空旧信息
	skill_name_lb.text = ""
	skill_meta_lb.text = ""
	skill_desc_lb.text = ""

	_mode = Mode.ITEM
	_actor = actor
	_inventory = inventory
	_get_cooldown = Callable()
	title_label.text = GameData._T("POPUP_SELECT_ITEM")
	_build_item_list()
	_selected_idx = 0
	show()
	center_panel()
	if _buttons.size() > 0:
		_update_detail(0)
		_update_highlight()
	_pop_in()


## 技能按钮内部结构
class SkillButton:
	extends Button

	var skill_data: SkillData
	var index: int = 0

	func setup(data: SkillData, idx: int, disabled: bool, cd: int, mp_ok: bool) -> void:
		skill_data = data
		index = idx
		self.disabled = disabled
		custom_minimum_size = Vector2(220, 65)

		# 第一行：名字
		text = data.skill_name

		# 副行：冷却 / MP
		var sub = ""
		if cd > 0:
			sub = GameData._T("SKILL_STATUS_CD") % cd
		elif data.mp_cost > 0:
			sub = GameData._T("SKILL_STATUS_MP") % data.mp_cost
			if not mp_ok:
				sub += GameData._T("SKILL_STATUS_NOT_ENOUGH")

		# 显示双行
		text = "%s\n%s" % [text, sub]
		clip_text = true

## 道具按钮
class ItemButton:
	extends Button

	var item_data: ItemData
	var item_count: int
	var index: int = 0
	var _icon_rect: TextureRect
	var _name_lb: Label
	var _count_lb: Label

	func setup(data: ItemData, count: int, idx: int, disabled: bool) -> void:
		item_data = data
		item_count = count
		index = idx
		self.disabled = disabled
		custom_minimum_size = Vector2(220, 65)
		text = ""
		clip_text = false

		# 三分布局：[图标] [名字·居中] [数量·靠右]
		var margin = MarginContainer.new()
		margin.name = "Row"
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		add_child(margin)

		var row = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 6)
		margin.add_child(row)

		# 左：图标
		_icon_rect = TextureRect.new()
		_icon_rect.custom_minimum_size = Vector2(36, 36)
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_rect.visible = false
		row.add_child(_icon_rect)

		# 中：名字（居中，占据中间伸缩区）
		_name_lb = Label.new()
		_name_lb.text = data.item_name
		_name_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_name_lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_name_lb.clip_text = true
		_name_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_name_lb.add_theme_font_size_override("font_size", 14)
		_name_lb.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
		row.add_child(_name_lb)

		# 右：数量
		_count_lb = Label.new()
		_count_lb.text = "×%d" % count
		_count_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_count_lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_count_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_count_lb.add_theme_font_size_override("font_size", 14)
		_count_lb.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
		row.add_child(_count_lb)

	## 设置左侧图标；传 null 则隐藏图标占位
	func set_icon_texture(tex: Texture2D) -> void:
		if _icon_rect == null:
			return
		if tex == null:
			_icon_rect.visible = false
			return
		_icon_rect.texture = tex
		_icon_rect.visible = true


# ══════════════════════════════════════════════
# 内部 — 法术
# ══════════════════════════════════════════════

func _build_skill_list() -> void:
	# 清空旧按钮
	for c in skill_grid.get_children(): c.queue_free()
	_buttons.clear()
	_skill_datas.clear()

	if _actor == null or _actor.stats.skill_ids.is_empty():
		return

	var idx = 0
	for skill_id in _actor.stats.skill_ids:
		var data: SkillData = SkillManager.get_skill(skill_id)
		if data == null: continue
		if skill_id == "普通攻击": continue  # 有独立按钮

		var cd    = _get_cooldown.call(_actor, skill_id) as int
		var mp_ok = _actor.current_mp >= data.mp_cost

		var btn = SkillButton.new()
		btn.setup(data, idx, cd > 0 or not mp_ok, cd, mp_ok)
		btn.focus_mode = Control.FOCUS_NONE
		_buttons.append(btn)
		_skill_datas.append(data)

		# 鼠标点击
		var sid = skill_id
		btn.pressed.connect(func(): _on_skill_click(sid))

		# 鼠标悬停 → 更新 _selected_idx
		btn.mouse_entered.connect(func(): _selected_idx = btn.index; _update_highlight(); _update_detail(btn.index))

		skill_grid.add_child(btn)

		# 应用按钮主题
		if _btn_style_normal:
			btn.add_theme_stylebox_override("normal", _btn_style_normal)
			btn.add_theme_stylebox_override("hover", _btn_style_hover)
			btn.add_theme_stylebox_override("focus", _btn_style_hover)
			btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
			btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.45, 1.0))
			btn.add_theme_font_size_override("font_size", 14)
		idx += 1


# ══════════════════════════════════════════════
# 内部 — 道具
# ══════════════════════════════════════════════

# 道具 tcp 图标缓存（避免每次打开弹窗重复解析）
var _icon_cache: Dictionary = {}

## 把 tcp 文件第 0 帧解码成 Texture2D；失败返回 null
func _tcp_icon(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _icon_cache.has(path):
		return _icon_cache[path]
	var tex: Texture2D = null
	if FileAccess.file_exists(path):
		var reader = WASReader.new()
		if reader.load_from_file(path):
			var decoded = reader.decode_frame(0, 0)
			if decoded != null and not decoded.is_empty():
				tex = decoded.get("texture")
	_icon_cache[path] = tex
	return tex

func _build_item_list() -> void:
	# 清空旧按钮
	for c in skill_grid.get_children(): c.queue_free()
	_buttons.clear()
	_skill_datas.clear()

	if _inventory == null: return
	_item_entries = _inventory.get_all_items()

	if _item_entries.is_empty():
		skill_name_lb.text = GameData._T("POPUP_BAG_EMPTY")
		skill_meta_lb.text = ""
		skill_desc_lb.text = ""
		return

	var idx = 0
	for entry in _item_entries:
		var data: ItemData = entry["data"]
		var count: int     = entry["count"]
		var iid = data.item_id
		# 过滤：不显示技能书和符咒
		if data.item_type == ItemData.ItemType.SKILL_BOOK or data.item_type == ItemData.ItemType.SPECIAL:
			continue

		var btn = ItemButton.new()
		btn.setup(data, count, idx, count <= 0)
		# 道具 tcp 图片：解析 icon_path 并显示在按钮最左侧
		btn.set_icon_texture(_tcp_icon(data.icon_path))
		btn.focus_mode = Control.FOCUS_NONE
		_buttons.append(btn)
		_skill_datas.append(null)

		# 鼠标点击
		btn.pressed.connect(func(): _on_item_click(iid))

		# 鼠标悬停 → 更新 _selected_idx
		btn.mouse_entered.connect(func(): _selected_idx = btn.index; _update_highlight(); _update_detail(btn.index))

		skill_grid.add_child(btn)

		# 应用按钮主题
		if _btn_style_normal:
			btn.add_theme_stylebox_override("normal", _btn_style_normal)
			btn.add_theme_stylebox_override("hover", _btn_style_hover)
			btn.add_theme_stylebox_override("focus", _btn_style_hover)
			btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
			btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.45, 1.0))
			btn.add_theme_font_size_override("font_size", 14)
		idx += 1


func _update_detail(index: int) -> void:
	if index < 0 or index >= _buttons.size():
		return

	if _mode == Mode.ITEM:
		_update_item_detail(index)
		return

	var data = _skill_datas[index]
	var btn = _buttons[index]

	skill_name_lb.text = data.skill_name

	# 行二：类型 + 目标 + 消耗
	var type_str = GameData._TL(TYPE_LABELS.get(data.skill_type, "未知"))
	var target_str = GameData._TL(TARGET_LABELS.get(data.target_type, "未知"))
	var parts := []
	parts.append("%s · %s" % [type_str, target_str])
	if data.mp_cost > 0:
		var mp_fmt := GameData._T("SKILL_DETAIL_MP")
		if mp_fmt == "SKILL_DETAIL_MP": mp_fmt = "MP %d"
		parts.append(mp_fmt % data.mp_cost)
	if data.hp_cost > 0:
		var hp_fmt := GameData._T("SKILL_DETAIL_HP")
		if hp_fmt == "SKILL_DETAIL_HP": hp_fmt = "HP %d"
		parts.append(hp_fmt % data.hp_cost)
	var cd = _get_cooldown.call(_actor, _skill_datas[index].skill_id) if _actor else 0
	if cd > 0:
		var cd_fmt := GameData._T("SKILL_DETAIL_CD")
		if cd_fmt == "SKILL_DETAIL_CD": cd_fmt = "CD %d turns"
		parts.append(cd_fmt % cd)
	skill_meta_lb.text = " | ".join(parts)

	# 描述
	var desc = data.description
	if desc.is_empty():
		desc = _auto_desc(data)
	skill_desc_lb.text = desc


func _update_item_detail(index: int) -> void:
	if index < 0 or index >= _item_entries.size():
		return
	var entry = _item_entries[index]
	var data: ItemData = entry["data"]
	var count: int = entry["count"]

	skill_name_lb.text = data.item_name

	var parts := []
	match data.item_type:
		ItemData.ItemType.HP_POTION:  parts.append(GameData._T("ITEM_TYPE_HP"))
		ItemData.ItemType.MP_POTION:  parts.append(GameData._T("ITEM_TYPE_MP"))
		ItemData.ItemType.BUFF_ITEM:  parts.append(GameData._T("ITEM_TYPE_BUFF"))
		ItemData.ItemType.REVIVE:     parts.append(GameData._T("ITEM_TYPE_REVIVE"))
		_:                              parts.append(GameData._T("ITEM_TYPE_SPECIAL"))
	parts.append("×%d" % count)
	skill_meta_lb.text = " | ".join(parts)

	var desc = data.description
	if desc.is_empty():
		var dparts := []
		if data.hp_restore > 0:  dparts.append(GameData._T("DESC_RESTORE_HP") % data.hp_restore)
		if data.mp_restore > 0:  dparts.append(GameData._T("DESC_RESTORE_MP") % data.mp_restore)
		if data.revive_hp_percent > 0: dparts.append(GameData._T("DESC_REVIVE_HP") % (data.revive_hp_percent * 100))
		desc = "。".join(dparts) + "。" if dparts else GameData._T("DESC_NO_EFFECT")
	skill_desc_lb.text = desc


func _auto_desc(data: SkillData) -> String:
	var parts := []
	match data.skill_type:
		SkillData.SkillType.PHYSICAL:
			parts.append(GameData._T("DESC_PHYSICAL") % int(data.damage_multiplier * 100))
			if data.hit_count > 1:
				parts.append(GameData._T("DESC_HIT_COUNT") % data.hit_count)
		SkillData.SkillType.MAGIC:
			parts.append(GameData._T("DESC_MAGIC") % int(data.damage_multiplier * 100))
			if data.ignore_defense_ratio > 0:
				parts.append(GameData._T("DESC_IGNORE_DEF") % int(data.ignore_defense_ratio * 100))
		SkillData.SkillType.HEAL:
			if data.heal_multiplier > 0:
				parts.append(GameData._T("DESC_HEAL_PCT") % int(data.heal_multiplier * 100))
			if data.flat_heal > 0:
				parts.append(GameData._T("DESC_FLAT_HEAL") % data.flat_heal)
		SkillData.SkillType.MULTI_HIT:
			parts.append(GameData._T("DESC_MULTI_HIT") % [data.hit_count, int(data.damage_multiplier * 100)])
		SkillData.SkillType.BUFF:
			parts.append(GameData._T("DESC_BUFF_SELF") % data.apply_buff_id)
		SkillData.SkillType.DEBUFF:
			parts.append(GameData._T("DESC_DEBUFF_CHANCE") % [int(data.apply_buff_chance * 100), data.apply_buff_id])
	if data.flat_damage > 0:
		parts.append(GameData._T("DESC_FLAT_DMG") % data.flat_damage)
	parts.append(GameData._T("DESC_CD") % data.cooldown_turns)
	return "。".join(parts) + "。"


func _on_skill_click(skill_id: String) -> void:
	_pop_out()
	skill_selected.emit(skill_id)


func _on_item_click(item_id: String) -> void:
	_pop_out()
	item_selected.emit(item_id)


func _on_cancel() -> void:
	_pop_out()
	cancelled.emit()


func _on_bg_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cancel()


## 纯视觉高亮 — 更新按钮样式
func _update_highlight() -> void:
	for i in _buttons.size():
		var btn = _buttons[i]
		if i == _selected_idx:
			btn.add_theme_stylebox_override("normal", _btn_style_hover)
		else:
			btn.add_theme_stylebox_override("normal", _btn_style_normal)


# ══════════════════════════════════════════════
# 动画
# ══════════════════════════════════════════════

func _pop_in() -> void:
	panel_window.modulate.a = 0.0
	panel_window.scale = Vector2(0.85, 0.85)
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(panel_window, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(panel_window, "scale", Vector2(1.0, 1.0), 0.18)


func _pop_out() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(panel_window, "modulate:a", 0.0, 0.1)
	tween.parallel().tween_property(panel_window, "scale", Vector2(0.9, 0.9), 0.1)
	tween.tween_callback(hide)


# ══════════════════════════════════════════════
# 样式
# ══════════════════════════════════════════════

func _setup_button_style() -> void:
	# 按钮样式（_build_skill_list 中应用到每个按钮）
	_btn_style_normal = StyleBoxFlat.new()
	_btn_style_normal.bg_color = Color(0.12, 0.14, 0.2, 0.85)
	_btn_style_normal.border_color = Color(0.25, 0.3, 0.4, 0.5)
	_btn_style_normal.border_width_top = 1
	_btn_style_normal.border_width_bottom = 1
	_btn_style_normal.border_width_left = 1
	_btn_style_normal.border_width_right = 1
	_btn_style_normal.corner_radius_top_left = 4
	_btn_style_normal.corner_radius_top_right = 4
	_btn_style_normal.corner_radius_bottom_left = 4
	_btn_style_normal.corner_radius_bottom_right = 4

	_btn_style_hover = StyleBoxFlat.new()
	_btn_style_hover.bg_color = Color(0.18, 0.22, 0.32, 0.9)
	_btn_style_hover.border_color = Color(0.4, 0.6, 0.9, 0.7)
	_btn_style_hover.border_width_top = 1
	_btn_style_hover.border_width_bottom = 1
	_btn_style_hover.border_width_left = 1
	_btn_style_hover.border_width_right = 1
	_btn_style_hover.corner_radius_top_left = 4
	_btn_style_hover.corner_radius_top_right = 4
	_btn_style_hover.corner_radius_bottom_left = 4
	_btn_style_hover.corner_radius_bottom_right = 4

	# 字体大小
	skill_name_lb.add_theme_font_size_override("font_size", 16)
	skill_meta_lb.add_theme_font_size_override("font_size", 13)
	skill_desc_lb.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_font_size_override("font_size", 16)
