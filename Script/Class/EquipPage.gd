class_name EquipPage
extends Panel

enum ItemTab { EQUIP, CONSUMABLE, KEY_ITEM, MATERIAL }

const SLOTS_PER_PAGE := 20

const SLOT_NODE_MAP := {
	"Slot_Weapon": "武器",
	"Slot_Head": "头盔",
	"Slot_Necklace": "项链",
	"Slot_Body": "铠甲",
	"Slot_Belt": "腰带",
	"Slot_Shoes": "鞋子",
}

var equipment: Dictionary = {}
var equip_bag: Array[Dictionary] = []
var inventory_items: Dictionary = {}

@onready var portrait: TextureRect = %Portrait
@onready var detail_label: Label = %DetailLabel
@onready var tab_equip: TextureButton = %Tab_Equip
@onready var tab_consumable: TextureButton = %Tab_Consumable
@onready var tab_keyitem: TextureButton = %Tab_KeyItem
@onready var tab_material: TextureButton = %Tab_Material
@onready var prev_button: TextureButton = %PrevButton
@onready var next_button: TextureButton = %NextButton
@onready var page_label: Label = %PageLabel

var _item_slots: Array[Panel] = []
var _item_icons: Array[TextureRect] = []
var _current_tab: ItemTab = ItemTab.EQUIP
var _current_page: int = 0
var _filtered_ids: Array[String] = []
var _selected_equip_idx: int = -1
var _tcp_icon_cache: Dictionary = {}

signal closed()
signal request_equip(slot_key: String, bag_index: int)
signal request_unequip(slot_key: String)


var _tooltip_label: RichTextLabel

func _ready() -> void:
	_collect_item_slots()
	_connect_signals()
	get_node("CloseBtn").pressed.connect(func(): hide(); closed.emit())
	_refresh_gold()
	# 自定义 tooltip
	_tooltip_label = RichTextLabel.new()
	_tooltip_label.name = "TooltipPopup"
	_tooltip_label.visible = false
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.fit_content = true
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tooltip_label.add_theme_stylebox_override("normal", _make_tooltip_style())
	add_child(_tooltip_label)


func _make_tooltip_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.14, 0.95)
	s.border_color = Color(0.3, 0.3, 0.5, 0.8)
	s.set_border_width_all(1)
	s.corner_radius_top_left = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _show_tooltip(text: String, local_pos: Vector2) -> void:
	if _tooltip_label == null: return
	_tooltip_label.text = text
	_tooltip_label.position = local_pos + Vector2(20, 20)
	_tooltip_label.reset_size()
	_tooltip_label.visible = true


func _hide_tooltip() -> void:
	if _tooltip_label: _tooltip_label.visible = false


func _collect_item_slots() -> void:
	_item_slots.clear()
	_item_icons.clear()

	for i in range(SLOTS_PER_PAGE):
		var slot := get_node_or_null("RightArea/ItemSlot_%02d" % i) as Panel
		_item_slots.append(slot)

		var icon: TextureRect = null
		if slot != null:
			icon = slot.get_node_or_null("Icon") as TextureRect
			slot.gui_input.connect(_on_item_slot_input.bind(i))
			slot.mouse_entered.connect(_on_item_slot_hovered.bind(i))
			slot.mouse_exited.connect(_hide_tooltip)
			if icon != null:
				icon.layout_mode = 0

		_item_icons.append(icon)

func _connect_signals() -> void:
	tab_equip.pressed.connect(_on_tab_pressed.bind(ItemTab.EQUIP))
	tab_consumable.pressed.connect(_on_tab_pressed.bind(ItemTab.CONSUMABLE))
	tab_keyitem.pressed.connect(_on_tab_pressed.bind(ItemTab.KEY_ITEM))
	tab_material.pressed.connect(_on_tab_pressed.bind(ItemTab.MATERIAL))
	prev_button.pressed.connect(_on_prev_page)
	next_button.pressed.connect(_on_next_page)

	for node_name in SLOT_NODE_MAP:
		var slot := get_node_or_null("LeftArea/%s" % node_name) as Panel
		if slot == null:
			continue
		# 所有非 Button 子节点忽略鼠标，让 ClickBtn 捕获点击
		for child in slot.get_children():
			if not (child is Button) and child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var btn := slot.get_node_or_null("ClickBtn") as Button
		if btn:
			
			# Panel 是 layout_mode=0，子节点 anchors 无效，手动同步尺寸
			btn.size = slot.size
			btn.position = Vector2.ZERO
			slot.resized.connect(func(): btn.size = slot.size)
			btn.pressed.connect(_on_equip_slot_pressed.bind(SLOT_NODE_MAP[node_name]))
			btn.gui_input.connect(_on_equip_slot_rightclick.bind(SLOT_NODE_MAP[node_name]))
			btn.mouse_entered.connect(_on_equip_slot_hovered.bind(SLOT_NODE_MAP[node_name]))
			btn.mouse_exited.connect(_hide_tooltip)
			print("[EquipPage] 已连接 %s/ClickBtn size=%s" % [node_name, btn.size])
		var icon := slot.get_node_or_null("Icon") as TextureRect
		# 不再调 _prepare_icon_rect，统一由 _refresh_equip_slots 管理布局
		if icon != null:
			icon.layout_mode = 0


func set_inventory(items: Dictionary) -> void:
	inventory_items = items


func set_equip_bag(bag: Array) -> void:
	equip_bag = bag
	print("[EquipPage] set_equip_bag — size=%d" % equip_bag.size())


func set_equipment(eq: Dictionary) -> void:
	equipment = eq
	if is_node_ready():
		_refresh_equip_slots()


func set_portrait(tex: Texture2D) -> void:
	if portrait:
		portrait.texture = tex


func full_refresh() -> void:
	_switch_tab(ItemTab.EQUIP)
	_refresh_equip_slots()
	_refresh_gold()


func _refresh_gold() -> void:
	var gold_label := get_node_or_null("gold") as Label
	if gold_label:
		gold_label.text = "%d" % GameData.player_gold


func _load_tcp_icon(tcp_path: String) -> Texture2D:
	if tcp_path.is_empty():
		return null
	if _tcp_icon_cache.has(tcp_path):
		return _tcp_icon_cache[tcp_path]
	if not FileAccess.file_exists(tcp_path):
		push_warning("[EquipPage] TCP 文件不存在: %s" % tcp_path)
		return null

	var reader := TcpReader.new()
	if not reader.load_from_file(tcp_path):
		push_warning("[EquipPage] TCP 加载失败: %s - %s" % [tcp_path, reader.get_last_error()])
		return null

	var decoded := reader.decode_frame(0)
	if decoded.is_empty():
		push_warning("[EquipPage] TCP 解码为空: %s (frames=%d)" % [tcp_path, reader.total_frames])
		# 尝试再解码一次，打印详情
		var d2 := reader.decode_frame(0)
		print("[EquipPage]   重试: empty=%s keys=%s" % [d2.is_empty(), d2.keys()])
		return null

	var tex := decoded.get("texture", null) as Texture2D
	print("[EquipPage] TCP 解码成功: %s size=%s texture=%s" % [tcp_path, decoded.get("width"), "OK" if tex else "NULL"])
	if tex != null:
		_tcp_icon_cache[tcp_path] = tex
	return tex


func _on_tab_pressed(tab: ItemTab) -> void:
	_switch_tab(tab)


func _switch_tab(tab: ItemTab) -> void:
	_current_tab = tab
	_current_page = 0
	_selected_equip_idx = -1

	tab_equip.button_pressed = tab == ItemTab.EQUIP
	tab_consumable.button_pressed = tab == ItemTab.CONSUMABLE
	tab_keyitem.button_pressed = tab == ItemTab.KEY_ITEM
	tab_material.button_pressed = tab == ItemTab.MATERIAL

	_rebuild_filtered_list()
	_render_page()


func _rebuild_filtered_list() -> void:
	_filtered_ids.clear()

	if _current_tab == ItemTab.EQUIP:
		for _i in equip_bag.size():
			_filtered_ids.append("")
		return

	var all_ids := inventory_items.keys()
	all_ids.sort()
	for item_id in all_ids:
		var entry = inventory_items[item_id]
		var data: ItemData = entry.get("data")
		if data == null:
			continue

		match _current_tab:
			ItemTab.CONSUMABLE:
				if data.item_category == ItemData.ItemCategory.CONSUMABLE:
					_filtered_ids.append(item_id)
			ItemTab.KEY_ITEM:
				if data.item_category == ItemData.ItemCategory.QUEST:
					_filtered_ids.append(item_id)
			ItemTab.MATERIAL:
				if data.item_category == ItemData.ItemCategory.MATERIAL:
					_filtered_ids.append(item_id)


func _render_page() -> void:
	if _current_tab == ItemTab.EQUIP:
		# 装备标签直接按 equip_bag 渲染，不用 _filtered_ids
		var total_pages := maxi(1, ceili(float(equip_bag.size()) / SLOTS_PER_PAGE))
		page_label.text = "%d/%d" % [_current_page + 1, total_pages]
		var start_idx := _current_page * SLOTS_PER_PAGE

		for i in range(SLOTS_PER_PAGE):
			var slot: Panel = _item_slots[i] if i < _item_slots.size() else null
			var icon: TextureRect = _item_icons[i] if i < _item_icons.size() else null
			if slot == null or icon == null:
				continue
			var idx := start_idx + i
			if idx >= equip_bag.size():
				_clear_item_slot(slot, icon)
			else:
				_render_equip_item(idx, slot, icon)
		return

	# 消耗品/任务/材料走原逻辑
	var total_pages := maxi(1, ceili(float(_filtered_ids.size()) / SLOTS_PER_PAGE))
	page_label.text = "%d/%d" % [_current_page + 1, total_pages]
	var start_idx := _current_page * SLOTS_PER_PAGE

	for i in range(SLOTS_PER_PAGE):
		var slot: Panel = _item_slots[i] if i < _item_slots.size() else null
		var icon: TextureRect = _item_icons[i] if i < _item_icons.size() else null
		if slot == null or icon == null:
			continue

		var idx := start_idx + i
		if idx >= _filtered_ids.size():
			_clear_item_slot(slot, icon)
			continue
		_render_inventory_item(idx, slot, icon)
		

func _render_equip_item(idx: int, slot: Panel, icon: TextureRect) -> void:
	var eq: Dictionary = equip_bag[idx] if idx < equip_bag.size() else {}
	if eq.is_empty():
		_clear_item_slot(slot, icon)
		return

	var tex := _load_tcp_icon(str(eq.get("tcp_path", "")))
	icon.texture = tex
	icon.visible = true
	# layout_mode=0，不用 anchors
	icon.position = Vector2(4, 4)
	icon.size = slot.size - Vector2(8, 8)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# 背包格 tooltip：当前装备 vs 已穿装备对比
	var lines: Array[String] = []
	var name_str = eq.get("display_name", eq.get("name", ""))
	var rarity_name := EquipData.rarity_name(eq.get("rarity", EquipData.Rarity.COMMON))
	lines.append("%s [%s]" % [name_str, rarity_name])

	# 背包装备的基础属性
	var base_labels := {"atk":"攻击", "def":"防御", "mdef":"法防", "hp":"气血", "mp":"灵力", "spd":"速度"}
	for bk in eq.get("base", {}):
		var val = eq.base[bk]
		if val != 0:
			lines.append("  %s +%d" % [base_labels.get(bk, bk), val])

	# 词缀
	for af in eq.get("affixes", []):
		var af_label := EquipData.affix_label(af.get("type", -1))
		if af_label != "":
			lines.append("  %s +%d%%" % [af_label, int(af.get("value", 0))])

	# 对比已穿装备
	var slot_key := EquipData.slot_key(eq.get("slot", -1))
	if not slot_key.is_empty():
		var worn = equipment.get(slot_key, {})
		if not worn.is_empty():
			lines.append("[u]── 已穿 ──[/u]")
			var worn_name = worn.get("display_name", worn.get("name", ""))
			lines.append("%s [%s]" % [worn_name, EquipData.rarity_name(worn.get("rarity", 0))])
			# 合并所有属性键（已穿 + 未穿的）
			var all_keys: Array[String] = []
			for bk in worn.get("base", {}): all_keys.append(bk)
			for bk in eq.get("base", {}): 
				if not bk in all_keys: all_keys.append(bk)
			for bk in all_keys:
				var worn_val = worn.get("base", {}).get(bk, 0)
				var new_val = eq.get("base", {}).get(bk, 0)
				if worn_val == 0 and new_val == 0: continue
				var tag = "color=green"
				if new_val < worn_val: tag = "color=red"
				elif new_val == worn_val: tag = "color=gray"
				if worn_val == 0:
					lines.append("  %s [%s]新增 +%d[/color]" % [base_labels.get(bk, bk), tag, new_val])
				elif new_val == 0:
					lines.append("  %s %d  [%s]失去 %d[/color]" % [base_labels.get(bk, bk), worn_val, tag, -worn_val])
				else:
					var diff = new_val - worn_val
					lines.append("  %s %d → %d  [%s]%+d[/color]" % [base_labels.get(bk, bk), worn_val, new_val, tag, diff])
			var all_affix_types: Array[int] = []
			for af in worn.get("affixes", []):
				var t = af.get("type", -1)
				if not t in all_affix_types: all_affix_types.append(t)
			for af in eq.get("affixes", []):
				var t = af.get("type", -1)
				if not t in all_affix_types: all_affix_types.append(t)
			for t in all_affix_types:
				var worn_val = 0; var new_val = 0
				for af in worn.get("affixes", []):
					if af.get("type", -1) == t: worn_val = int(af.get("value", 0)); break
				for af in eq.get("affixes", []):
					if af.get("type", -1) == t: new_val = int(af.get("value", 0)); break
				if worn_val == 0 and new_val == 0: continue
				var af_label = EquipData.affix_label(t)
				var tag = "color=green" if new_val > worn_val else ("color=red" if new_val < worn_val else "color=gray")
				if worn_val == 0:
					lines.append("  %s [%s]新增 +%d%%[/color]" % [af_label, tag, new_val])
				elif new_val == 0:
					lines.append("  %s [%s]失去 %d%%[/color]" % [af_label, tag, worn_val])
				else:
					lines.append("  %s %d%% → %d%% [%s]%+d%%[/color]" % [af_label, worn_val, new_val, tag, new_val - worn_val])

	lines.append("")
	lines.append("[color=gray]左键选中  双击装备[/color]")

	var bbcode = "\n".join(lines)
	icon.tooltip_text = ""
	slot.set_meta("tooltip_bbcode", bbcode)
	slot.set_meta("tooltip_slot_key", EquipData.slot_key(eq.get("slot", -1)))

	if idx == _selected_equip_idx:
		var hl := StyleBoxFlat.new()
		hl.bg_color = Color(0.2, 0.4, 0.15, 0.7)
		hl.border_color = Color(0.4, 0.9, 0.3, 0.8)
		hl.border_width_top = 1
		hl.border_width_bottom = 1
		hl.border_width_left = 1
		hl.border_width_right = 1
		slot.add_theme_stylebox_override("panel", hl)
	else:
		_reset_slot_style(slot)


func _render_inventory_item(idx: int, slot: Panel, icon: TextureRect) -> void:
	var item_id := _filtered_ids[idx]
	var entry = inventory_items.get(item_id, {})
	var data: ItemData = entry.get("data")
	icon.texture = null

	icon.tooltip_text = "%s\n×%d\n%s" % [data.item_name, entry.get("count", 0), data.description] if data else ""
	_reset_slot_style(slot)
	

func _clear_item_slot(slot: Panel, icon: TextureRect) -> void:
	icon.texture = null
	icon.tooltip_text = ""
	_reset_slot_style(slot)


func _format_base_stats(base: Dictionary) -> String:
	var text := ""
	for key in base:
		if base[key] != 0:
			text += "%s+%d " % [key, base[key]]
	return text


func _reset_slot_style(slot: Panel) -> void:
	slot.remove_theme_stylebox_override("panel")


func _on_prev_page() -> void:
	if _current_page > 0:
		_current_page -= 1
		_render_page()


func _on_next_page() -> void:
	var total_pages := maxi(1, ceili(float(_filtered_ids.size()) / SLOTS_PER_PAGE))
	if _current_page < total_pages - 1:
		_current_page += 1
		_render_page()


func _refresh_equip_slots() -> void:
	for node_name in SLOT_NODE_MAP:
		var slot_key: String = SLOT_NODE_MAP[node_name]
		var slot := get_node_or_null("LeftArea/%s" % node_name) as Panel
		if slot == null:
			continue

		var icon := slot.get_node_or_null("Icon") as TextureRect
		var lbl := slot.get_node_or_null("SlotLabel") as Label
		var eq: Dictionary = equipment.get(slot_key, {})

		slot.remove_theme_stylebox_override("panel")
		if eq.is_empty():
			if icon:
				icon.texture = null
			if lbl:
				lbl.text = slot_key
		else:
			if icon:
				var tcp := str(eq.get("tcp_path", ""))
				var tex := _load_tcp_icon(tcp)
				icon.layout_mode = 0
				icon.texture = tex
				icon.visible = true
				icon.position = Vector2(4, 4)
				icon.size = slot.size - Vector2(8, 8)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if lbl:
				lbl.text = ""  # 已装备不显示名字

		# 装备信息 tooltip，挂在 ClickBtn 上让鼠标悬停弹窗
		var btn := slot.get_node_or_null("ClickBtn") as Button
		if btn:
			if eq.is_empty():
				btn.tooltip_text = "%s（空）" % slot_key
			else:
				var lines: Array[String] = []
				var name_str = eq.get("display_name", eq.get("name", ""))
				var rt := EquipData.rarity_name(eq.get("rarity", 0))
				lines.append("%s [%s]" % [name_str, rt])

				# 基础属性翻译
				var base_labels := {"atk":"攻击", "def":"防御", "mdef":"法防", "hp":"气血", "mp":"灵力", "spd":"速度"}
				for bk in eq.get("base", {}):
					var val = eq.base[bk]
					if val != 0:
						lines.append("  %s +%d" % [base_labels.get(bk, bk), val])

				# 词缀
				for af in eq.get("affixes", []):
					var af_label := EquipData.affix_label(af.get("type", -1))
					if af_label != "":
						lines.append("  %s +%d%%" % [af_label, int(af.get("value", 0))])

				# 武器额外专属词条
				if slot_key == "武器":
					var weapon_bonus = eq.get("weapon_affixes", [])
					if weapon_bonus.is_empty():
						
						return
						var rarity_lv = eq.get("rarity", 0)
						if rarity_lv >= 1:
							lines.append("  ★ 吸血 +5%")
						if rarity_lv >= 2:
							lines.append("  ★ 力量 +8%")
						if rarity_lv >= 4:
							lines.append("  ★ 暴击率 +3%")
					else:
						for wa in weapon_bonus:
							var wlabel := EquipData.affix_label(wa.get("type", -1))
							if wlabel != "":
								lines.append("  ★ %s +%d%%" % [wlabel, int(wa.get("value", 0))])

				lines.append("")
				lines.append("右键卸下")
				btn.tooltip_text = "\n".join(lines)

		if _selected_equip_idx >= 0 and _selected_equip_idx < equip_bag.size():
			var selected_eq := equip_bag[_selected_equip_idx]
			var selected_slot := EquipData.slot_key(selected_eq.get("slot", -1))
			if selected_slot == slot_key:
				var hl := StyleBoxFlat.new()
				hl.bg_color = Color(0.15, 0.35, 0.15, 0.5)
				hl.border_color = Color(0.4, 0.9, 0.3, 0.7)
				hl.border_width_top = 1
				hl.border_width_bottom = 1
				hl.border_width_left = 1
				hl.border_width_right = 1
				slot.add_theme_stylebox_override("panel", hl)


# ═══ Tooltip hover ═══
func _on_equip_slot_hovered(slot_key: String) -> void:
	var eq: Dictionary = equipment.get(slot_key, {})
	if eq.is_empty(): return
	var lines: Array[String] = []
	var name_str = eq.get("display_name", eq.get("name", ""))
	lines.append("[b]%s[/b] [%s]" % [name_str, EquipData.rarity_name(eq.get("rarity", 0))])
	var base_labels := {"atk":"攻击", "def":"防御", "mdef":"法防", "hp":"气血", "mp":"灵力", "spd":"速度"}
	for bk in eq.get("base", {}):
		var val = eq.base[bk]
		if val != 0:
			lines.append("  %s +%d" % [base_labels.get(bk, bk), val])
	for af in eq.get("affixes", []):
		var af_label := EquipData.affix_label(af.get("type", -1))
		if af_label != "":
			lines.append("  %s +%d%%" % [af_label, int(af.get("value", 0))])
	lines.append("")
	lines.append("[color=gray]右键卸下[/color]")
	_show_tooltip("\n".join(lines), get_local_mouse_position())


func _on_item_slot_hovered(slot_index: int) -> void:
	var idx := _current_page * SLOTS_PER_PAGE + slot_index
	if _current_tab != ItemTab.EQUIP or idx >= equip_bag.size(): return
	var slot := _item_slots[slot_index] if slot_index < _item_slots.size() else null
	if slot == null: return
	var bbcode = slot.get_meta("tooltip_bbcode", "")
	if bbcode.is_empty(): return
	_show_tooltip(bbcode, get_local_mouse_position())


func _on_equip_slot_pressed(slot_key: String) -> void:
	var eq: Dictionary = equipment.get(slot_key, {})
	if _selected_equip_idx >= 0 and _selected_equip_idx < equip_bag.size():
		var selected := equip_bag[_selected_equip_idx]
		var expected_key := EquipData.slot_key(selected.get("slot", -1))
		if expected_key != slot_key:
			detail_label.text = "不能放在 %s 槽，该装备只能放在 %s 槽" % [slot_key, expected_key]
			return
		GameData.equip_item_by_index(slot_key, _selected_equip_idx)
		equip_bag = GameData.equip_bag
		_selected_equip_idx = -1
		detail_label.text = "已装备 %s 到 %s" % [selected.get("display_name", ""), slot_key]
		_refresh_equip_slots()
		_render_page()
		return

	if eq.is_empty():
		detail_label.text = "%s（空）-- 先在装备标签里选一件装备" % slot_key
	else:
		pass
		detail_label.text = "%s [%s] %s" % [
			eq.get("display_name", ""),
			EquipData.rarity_name(eq.get("rarity", EquipData.Rarity.COMMON)),
			_format_base_stats(eq.get("base", {})),
		]


func _on_equip_slot_rightclick(event: InputEvent, slot_key: String) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		return
	var eq: Dictionary = equipment.get(slot_key, {})
	if not eq.is_empty():
		GameData.unequip_item(slot_key)
		equip_bag = GameData.equip_bag
		detail_label.text = "%s 已卸下" % slot_key
		_refresh_equip_slots()
		_render_page()


func _on_item_slot_input(event: InputEvent, slot_index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	var idx := _current_page * SLOTS_PER_PAGE + slot_index
	if _current_tab != ItemTab.EQUIP:
		if idx < _filtered_ids.size():
			var item_id := _filtered_ids[idx]
			var data: ItemData = inventory_items[item_id].get("data")
			if data:
				detail_label.text = "%s ×%d -- %s" % [data.item_name, inventory_items[item_id].get("count", 0), data.description]
		return

	if idx >= equip_bag.size():
		return

	# 双击自动穿戴
	if event.double_click:
		var eq := equip_bag[idx]
		var slot_key := EquipData.slot_key(eq.get("slot", -1))
		if slot_key.is_empty():
			return
		GameData.equip_item_by_index(slot_key, idx)
		equip_bag = GameData.equip_bag
		_selected_equip_idx = -1
		detail_label.text = "已装备 %s" % eq.get("display_name", "")
		_refresh_equip_slots()
		_render_page()
		return

	# 单击选中
	_selected_equip_idx = idx
	var sel := equip_bag[idx]
	detail_label.text = "已选中 %s [%s] -- 点击左侧槽位穿上或双击自动穿戴" % [
		sel.get("display_name", ""),
		EquipData.rarity_name(sel.get("rarity", EquipData.Rarity.COMMON)),
	]
	_render_page()
	_refresh_equip_slots()
