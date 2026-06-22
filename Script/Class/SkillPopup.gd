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
		custom_minimum_size = Vector2(210, 56)

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

	func setup(data: ItemData, count: int, idx: int, disabled: bool) -> void:
		item_data = data
		item_count = count
		index = idx
		self.disabled = disabled
		custom_minimum_size = Vector2(210, 56)

		text = "%s\n×%d" % [data.item_name, count]
		clip_text = true


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

		var btn = ItemButton.new()
		btn.setup(data, count, idx, count <= 0)
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
		parts.append(GameData._T("SKILL_DETAIL_MP") % data.mp_cost)
	if data.hp_cost > 0:
		parts.append(GameData._T("SKILL_DETAIL_HP") % data.hp_cost)
	var cd = _get_cooldown.call(_actor, _skill_datas[index].skill_id) if _actor else 0
	if cd > 0:
		parts.append(GameData._T("SKILL_DETAIL_CD") % cd)
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
