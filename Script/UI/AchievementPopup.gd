extends CanvasLayer
const UIFeedback = preload("res://Script/UI/UISoundFeedback.gd")
signal closed
const DB = preload("res://Script/Data/AchievementDB.gd")
var _filter: int = 0
static var _collapsed_categories: Dictionary = {}
var _groups: Dictionary = {}

func _ready() -> void:
	GameData.ensure_achievement_notifications()
	GameData.refresh_level_achievements()
	GameData.refresh_equipment_achievements()
	GameData.refresh_attribute_achievements()
	$Content/Header/Close.pressed.connect(close)
	var names := ["全部", "可领取", "未完成", "已领取"]
	for i in names.size():
		var button := Button.new()
		button.text = names[i]
		button.toggle_mode = true
		button.button_pressed = i == _filter
		button.pressed.connect(_set_filter.bind(i))
		$Content/Filters.add_child(button)
	GameData.achievements_changed.connect(_refresh)
	for button in $Content/Filters.get_children(): _style_button(button)
	_refresh()

func _style_button(button: Button) -> void:
	var sheet = preload("res://Graphic/UI/小号按钮.png")
	var regions := [Rect2(0, 0, 42, 21), Rect2(42.5, 0, 40.2, 21.7), Rect2(84.6, 0, 41.3, 21.5)]
	var states := ["normal", "hover", "pressed"]
	for i in states.size():
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = regions[i]
		var style := StyleBoxTexture.new()
		style.texture = atlas
		style.texture_margin_left = 5
		style.texture_margin_right = 5
		style.texture_margin_top = 4
		style.texture_margin_bottom = 4
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		button.add_theme_stylebox_override(states[i], style)
	# 书法字体原始行框下方留白很大，缩短行框以匹配实际字形。
	var font := FontVariation.new()
	font.base_font = preload("res://Graphic/UI/Font/aajiuzhongxiao.ttf")
	font.spacing_bottom = -22
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 22)
	button.custom_minimum_size = Vector2(88, 34)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.90, 0.45))

func _set_filter(value: int) -> void:
	_filter = value
	for i in $Content/Filters.get_child_count():
		$Content/Filters.get_child(i).button_pressed = i == value
	_refresh()

func _refresh() -> void:
	for child in $Content/Scroll/List.get_children():
		$Content/Scroll/List.remove_child(child)
		child.queue_free()
	_groups.clear()
	var completed := 0
	var claimable := 0
	var categories: Dictionary = {}
	for entry in DB.ENTRIES:
		var state: Dictionary = GameData.get_achievement_state(entry)
		var available: bool = state.available > 0
		if state.reached: completed += 1
		claimable += int(state.available)
		if _filter == 1 and not available: continue
		if _filter == 2 and (available or state.exhausted): continue
		if _filter == 3 and int(state.claims) <= 0: continue
		var category: String = entry.get("category", "其他")
		if category.strip_edges().is_empty(): category = "其他"
		if not categories.has(category): categories[category] = []
		categories[category].append(entry)
	for category in categories:
		_create_group(category, categories[category])
	$Content/Summary.text = "已完成 %d / %d    可领取 %d    累计行走 %d 步" % [completed, DB.ENTRIES.size(), claimable, int(GameData.achievement_stats.get("steps", 0))]
	if categories.is_empty():
		var empty := Label.new()
		empty.text = "暂无此类成就"
		$Content/Scroll/List.add_child(empty)

func _create_group(category: String, entries: Array) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 8)
	$Content/Scroll/List.add_child(group)
	var header := Button.new()
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.custom_minimum_size.y = 38
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.12, 0.22, 0.40))
	header.add_theme_color_override("font_hover_color", Color(0.12, 0.22, 0.40))
	header.add_theme_color_override("font_pressed_color", Color(0.12, 0.22, 0.40))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.46, 0.61, 0.87, 0.55)
	style.border_color = Color(0.37, 0.49, 0.73, 0.6)
	style.border_width_bottom = 1
	style.set_corner_radius_all(5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	header.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.56, 0.70, 0.96, 0.75)
	header.add_theme_stylebox_override("hover", hover)
	header.add_theme_stylebox_override("pressed", hover)
	group.add_child(header)
	var body := VBoxContainer.new()
	body.name = "Entries"
	body.add_theme_constant_override("separation", 10)
	group.add_child(body)
	var available := 0
	for entry in entries:
		available += int(GameData.get_achievement_state(entry).available)
		body.add_child(_create_card(entry))
	_groups[category] = {"header": header, "body": body, "count": entries.size(), "available": available}
	header.pressed.connect(_toggle_category.bind(category))
	_update_group(category)

func _toggle_category(category: String) -> void:
	_collapsed_categories[category] = not bool(_collapsed_categories.get(category, false))
	_update_group(category)

func _update_group(category: String) -> void:
	if not _groups.has(category): return
	var group: Dictionary = _groups[category]
	var collapsed: bool = _collapsed_categories.get(category, false)
	group.body.visible = not collapsed
	group.header.text = "%s  %s  ·  %d项" % ["▶" if collapsed else "▼", category, int(group.count)]
	if group.available > 0: group.header.text += "    待领取 %d 份" % int(group.available)
	group.header.tooltip_text = "点击展开" if collapsed else "点击收起"

func _create_card(entry: Dictionary) -> PanelContainer:
	var state: Dictionary = GameData.get_achievement_state(entry)
	var progress := int(state.progress)
	var reached: bool = state.available > 0
	var claimed: bool = state.exhausted
	var card := PanelContainer.new()
	card.set_meta("keyboard_detail", func(): pass)
	card.name = String(entry.id)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.66, 0.76, 0.95, 0.45)
	style.border_color = Color(0.66, 0.53, 0.24, 0.7) if reached else Color(0.40, 0.52, 0.76, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var title := Label.new()
	title.text = "◆ %s  ·  %s" % [entry.name, entry.get("category", "成就")]
	title.add_theme_color_override("font_color", Color(0.12, 0.20, 0.38))
	title.add_theme_font_override("font", preload("res://Graphic/UI/Font/尔雅趣宋体.ttf"))
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var description := Label.new()
	description.text = String(entry.description).replace("{level}", str(DB.required_level(entry))).replace("{target}", str(int(entry.target)))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color(0.17, 0.25, 0.43))
	column.add_child(description)
	var bar := ProgressBar.new()
	var goal: int = int(state.limit) if state.repeated else int(entry.target)
	bar.max_value = goal
	bar.value = mini(progress, goal)
	bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.23, 0.34, 0.57, 0.35)
	track.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.76, 0.60, 0.25)
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.custom_minimum_size.y = 12
	column.add_child(bar)
	var row := HBoxContainer.new()
	column.add_child(row)
	var reward_texts: PackedStringArray = []
	for reward in entry.rewards:
		var reward_name: String = DB.REWARD_NAMES.get(reward.type, reward.type)
		if reward.type == "item" and GameData.item_db.has(reward.get("item_id", "")):
			reward_name = GameData.item_db[reward.item_id].item_name
		reward_texts.append("%s × %d" % [reward_name, int(reward.amount)])
	var detail := Label.new()
	detail.text = "%d / %d    奖励：%s" % [mini(progress, int(entry.target)), int(entry.target), "、".join(reward_texts)]
	if state.repeated:
		detail.text = "达标角色 %d / %d    已领取 %d / %d 次    奖励：%s" % [mini(progress, goal), goal, int(state.claims), int(state.limit), "、".join(reward_texts)]
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_color_override("font_color", Color(0.17, 0.25, 0.43))
	row.add_child(detail)
	var claim := Button.new()
	claim.name = "ClaimButton"
	claim.text = "已领取" if claimed else ("领取奖励" if reached else "未完成")
	if state.repeated:
		if reached:
			claim.text = "领取（%d）" % int(state.available)
		elif int(state.claims) > 0 and not claimed:
			claim.text = "已领 %d/%d" % [int(state.claims), int(state.limit)]
	claim.disabled = claimed or not reached
	claim.pressed.connect(_claim.bind(String(entry.id)))
	_style_button(claim)
	row.add_child(claim)
	return card

func _claim(id: String) -> void:
	if not GameData.claim_achievement(id):
		UIFeedback.play_ui(&"error")
		GameData.notify_achievement("领取失败", "尚未达成、已经领取或背包空间不足，请检查后重试。", "failed")

	else:
		UIFeedback.play_ui(&"success")

func close() -> void:
	hide()
	closed.emit()
	queue_free()
