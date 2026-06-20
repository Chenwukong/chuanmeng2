# BountyPopup.gd
# 悬赏任务弹窗 — 甲乙丙丁四栏任务，蓝色水晶风格
class_name BountyPopup
extends CanvasLayer

signal closed()

# ── 节点引用 ──
@onready var panel: Control = $Panel
@onready var confirm_dialog: Control = $Panel/ConfirmDialog
@onready var confirm_title: Label = $Panel/ConfirmDialog/ConfirmTitle
@onready var confirm_desc: Label = $Panel/ConfirmDialog/Desc
@onready var btn_confirm_yes: Button = $Panel/ConfirmDialog/BtnYes
@onready var btn_confirm_no: Button = $Panel/ConfirmDialog/BtnNo
@onready var bounty_grid: GridContainer = $Panel/ScrollContainer/BountyGrid
@onready var close_btn: Button = $Panel/CloseBtn

# ── 等级标识常量 ──
const RANK_JIA := 3
const RANK_YI  := 2
const RANK_BING := 1
const RANK_DING := 0

## 水晶风格配色
const RANK_COLORS := {
	RANK_DING: Color(0.40, 0.55, 0.70, 1.0),  # 灰蓝水晶
	RANK_BING: Color(0.45, 0.70, 0.90, 1.0),  # 亮蓝水晶
	RANK_YI:   Color(0.55, 0.45, 0.95, 1.0),  # 紫水晶
	RANK_JIA:  Color(0.90, 0.55, 0.20, 1.0),  # 橙金水晶
}
const RANK_LABELS := {
	RANK_DING: "丁",
	RANK_BING: "丙",
	RANK_YI:   "乙",
	RANK_JIA:  "甲",
}
const RANK_ORDER := [RANK_DING, RANK_BING, RANK_YI, RANK_JIA]

# ── 状态 ──
var _pending_bounty: Dictionary = {}   # 等待确认的任务数据
var _bounty_slots: Dictionary = {}     # bounty_id → Control


func open() -> void:
	_refresh_bounties()
	confirm_dialog.hide()
	show()
	_pop_in()


func _refresh_bounties() -> void:
	for c in bounty_grid.get_children():
		c.queue_free()
	_bounty_slots.clear()

	for rank in RANK_ORDER:
		var col_vbox = VBoxContainer.new()
		col_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# ── 栏标题 ──
		var rank_color = RANK_COLORS.get(rank, Color.WHITE)
		var header = PanelContainer.new()
		var header_style = StyleBoxFlat.new()
		header_style.bg_color = Color(0.05, 0.12, 0.28, 0.7)
		header_style.border_color = rank_color
		header_style.border_width_bottom = 2
		header_style.content_margin_left = 12
		header_style.content_margin_top = 6
		header_style.content_margin_bottom = 6
		header.add_theme_stylebox_override("panel", header_style)

		var title_hbox = HBoxContainer.new()
		var gem = Label.new()
		gem.text = "◆"
		gem.add_theme_color_override("font_color", rank_color)
		gem.add_theme_font_size_override("font_size", 14)
		title_hbox.add_child(gem)

		var rank_lbl = Label.new()
		rank_lbl.text = " %s 级 " % RANK_LABELS[rank]
		rank_lbl.add_theme_font_size_override("font_size", 16)
		rank_lbl.add_theme_color_override("font_color", rank_color)
		title_hbox.add_child(rank_lbl)

		var gem2 = Label.new()
		gem2.text = "◆"
		gem2.add_theme_color_override("font_color", rank_color)
		gem2.add_theme_font_size_override("font_size", 14)
		title_hbox.add_child(gem2)

		header.add_child(title_hbox)
		col_vbox.add_child(header)

		# ── 任务卡片 ──
		var tasks = _pick_tasks(rank, 3)
		for task in tasks:
			var card = _create_task_card(task)
			col_vbox.add_child(card)
			_bounty_slots[task.id] = card

		# 补齐空格
		var extra = 3 - tasks.size()
		for i in extra:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(180, 120)
			col_vbox.add_child(spacer)

		bounty_grid.add_child(col_vbox)

	_update_all_card_states()


## 从 BountyData 抽任务（运行时调用，避免编译期依赖）
func _pick_tasks(rank_id: int, count: int) -> Array:
	var pool_key = _rank_to_bounty_rank(rank_id)
	var pool = BountyData.TASK_POOL.get(pool_key, [])
	if pool.is_empty():
		return []
	var available = pool.duplicate()
	available.shuffle()
	var limit = mini(count, available.size())
	var result: Array = []
	for i in limit:
		var entry = available[i].duplicate()  # 深拷贝字典
		entry.rank = pool_key
		result.append(entry)
	return result


func _rank_to_bounty_rank(r: int):
	match r:
		RANK_DING: return BountyData.Rank.DING
		RANK_BING: return BountyData.Rank.BING
		RANK_YI:   return BountyData.Rank.YI
		RANK_JIA:  return BountyData.Rank.JIA
		_:         return BountyData.Rank.DING


func _bounty_rank_to_my(br):
	match br:
		BountyData.Rank.DING: return RANK_DING
		BountyData.Rank.BING: return RANK_BING
		BountyData.Rank.YI:   return RANK_YI
		BountyData.Rank.JIA:  return RANK_JIA
		_: return RANK_DING


## 创建单个任务卡
func _create_task_card(task_dict: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 120)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var br = task_dict.get("rank", BountyData.Rank.DING)
	var rank_id = _bounty_rank_to_my(br)
	var rank_color = RANK_COLORS.get(rank_id, Color.WHITE)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.10, 0.24, 0.88)
	style.border_color = rank_color
	style.border_width_top = 1
	style.border_width_bottom = 2
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_size = 4
	style.shadow_color = Color(rank_color, 0.3)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 任务名称
	var name_lbl = Label.new()
	name_lbl.text = task_dict.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.max_lines_visible = 2
	vbox.add_child(name_lbl)

	# 需求道具
	var item_id = task_dict.get("item_id", "")
	var item_data = GameData.item_db.get(item_id) if not item_id.is_empty() else null
	var item_name = item_data.item_name if item_data else item_id
	var item_icon = item_data.icon_emoji if item_data else "📦"
	var req_count = task_dict.get("count", 1)
	var req_lbl = Label.new()
	req_lbl.text = "%s %s ×%d" % [item_icon, item_name, req_count]
	req_lbl.add_theme_font_size_override("font_size", 11)
	req_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(req_lbl)

	# 金币奖励
	var gold_lbl = Label.new()
	gold_lbl.text = "💰 %d 金币" % task_dict.get("gold", 0)
	gold_lbl.add_theme_font_size_override("font_size", 12)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(gold_lbl)

	# 状态标签
	var state_lbl = Label.new()
	state_lbl.name = "StateLabel"
	state_lbl.add_theme_font_size_override("font_size", 11)
	state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(state_lbl)

	card.add_child(vbox)

	# 点击
	var tid = task_dict.get("id", "")
	card.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_card_clicked(tid)
	)

	return card


func _update_all_card_states() -> void:
	for tid in _bounty_slots:
		var card = _bounty_slots[tid]
		var state_lbl = card.find_child("StateLabel", true, false) as Label
		if not state_lbl: continue

		if GameData.is_bounty_completed(tid):
			state_lbl.text = "✅ 已完成"
			card.modulate = Color(0.6, 0.6, 0.6, 0.7)
		elif GameData.is_bounty_active(tid):
			if _can_complete_bounty(tid):
				state_lbl.text = "⚡ 可提交"
				card.modulate = Color(1.0, 1.0, 0.8, 1.0)
			else:
				state_lbl.text = "⏳ 进行中"
				card.modulate = Color(0.8, 0.85, 1.0, 0.9)
		else:
			state_lbl.text = "📜 可接取"
			card.modulate = Color.WHITE


func _can_complete_bounty(tid: String) -> bool:
	var entry = _find_bounty_data(tid)
	if entry.is_empty(): return false
	return GameData.check_bounty_items(entry.get("item_id", ""), entry.get("count", 1))


func _find_bounty_data(tid: String) -> Dictionary:
	for rank in [BountyData.Rank.JIA, BountyData.Rank.YI, BountyData.Rank.BING, BountyData.Rank.DING]:
		for entry in BountyData.TASK_POOL.get(rank, []):
			if entry.get("id", "") == tid:
				return entry
	return {}


func _on_card_clicked(tid: String) -> void:
	if GameData.is_bounty_completed(tid):
		return
	var entry = _find_bounty_data(tid)
	if entry.is_empty():
		return

	if GameData.is_bounty_active(tid):
		if _can_complete_bounty(tid):
			_submit_bounty(entry)
		else:
			_show_notification("道具不足！请收集足够的任务道具后再来提交。")
		return

	_pending_bounty = entry
	_show_confirm_dialog(entry)


func _submit_bounty(entry: Dictionary) -> void:
	var item_id = entry.get("item_id", "")
	var count = entry.get("count", 1)
	var gold = entry.get("gold", 0)
	var repeatable = entry.get("repeatable", false)
	var tid = entry.get("id", "")

	if not GameData.consume_bounty_items(item_id, count):
		_show_notification("道具不足！")
		return

	GameData.give_bounty_reward(gold)

	if repeatable:
		GameData.active_bounties.erase(tid)
		_show_notification("✅ 任务完成！获得 %d 金币！" % gold)
	else:
		GameData.complete_bounty(tid)
		_show_notification("🎉 任务完成！获得 %d 金币！\n此任务不再出现。" % gold)

	_refresh_bounties()


func _show_confirm_dialog(entry: Dictionary) -> void:
	var item_id = entry.get("item_id", "")
	var item_data = GameData.item_db.get(item_id) if not item_id.is_empty() else null
	var item_name = item_data.item_name if item_data else item_id
	var count = entry.get("count", 1)
	var gold = entry.get("gold", 0)
	var repeatable = entry.get("repeatable", false)

	var rank_br = entry.get("rank", BountyData.Rank.DING)
	var rank_lbl = "?"
	match rank_br:
		BountyData.Rank.JIA:  rank_lbl = "甲"
		BountyData.Rank.YI:   rank_lbl = "乙"
		BountyData.Rank.BING: rank_lbl = "丙"
		BountyData.Rank.DING: rank_lbl = "丁"

	confirm_title.text = "📜 %s (%s级)" % [entry.get("name", "?"), rank_lbl]
	confirm_desc.text = "%s\n\n需求：%s ×%d\n奖励：💰 %d 金币\n%s" % [
		entry.get("desc", ""),
		item_name, count, gold,
		"⚠ 此任务不可重复" if not repeatable else "🔄 可重复领取"
	]
	confirm_dialog.show()


func _show_notification(msg: String) -> void:
	confirm_title.text = "📢 提示"
	confirm_desc.text = msg
	btn_confirm_yes.text = "确定"
	btn_confirm_no.hide()
	confirm_dialog.show()
	await get_tree().create_timer(2.0).timeout
	confirm_dialog.hide()
	btn_confirm_no.show()
	btn_confirm_yes.text = "接受"


func _on_confirm_accept() -> void:
	if _pending_bounty.is_empty():
		confirm_dialog.hide()
		return

	var entry = _pending_bounty
	_pending_bounty = {}
	confirm_dialog.hide()

	var tid = entry.get("id", "")
	if GameData.is_bounty_completed(tid):
		_show_notification("此任务已完成，无法重复领取。")
		return
	if GameData.is_bounty_active(tid):
		_show_notification("此任务已接受！")
		return

	GameData.accept_bounty(tid)
	_show_notification("✅ 已接受任务：%s" % entry.get("name", ""))
	_refresh_bounties()


func _on_confirm_cancel() -> void:
	_pending_bounty = {}
	confirm_dialog.hide()


func _on_close() -> void:
	_pop_out()
	closed.emit()


func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	btn_confirm_yes.pressed.connect(_on_confirm_accept)
	btn_confirm_no.pressed.connect(_on_confirm_cancel)
	confirm_dialog.hide()
	hide()
	open()


func _pop_in() -> void:
	panel.modulate = Color(1, 1, 1, 0); panel.scale = Vector2(0.85, 0.85)
	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(panel, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(panel, "scale", Vector2(1, 1), 0.25)


func _pop_out() -> void:
	var t = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
	t.tween_property(panel, "modulate:a", 0.0, 0.12)
	t.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.12)
	t.tween_callback(hide)
