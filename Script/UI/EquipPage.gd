class_name EquipPage
extends Panel

enum ItemTab { EQUIP, CONSUMABLE, KEY_ITEM, MATERIAL }

const SLOTS_PER_PAGE := 20
const AFFIX_COLOR: String = "#70478c"  # 词缀文字/数值颜色
const HEADER_COLOR: String = "#315c88"  # tooltip 分区标题颜色

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
var material_items: Array[Dictionary] = []  # 打造材料（material_bag）
var _member_id: String = ""
var _member_ids: Array[String] = []
var _member_idx: int = 0
var shop_mode: bool = false  # 商店模式下双击=售卖
const UNWEARABLE_MATERIAL = preload("res://Component/InventoryUnwearable.tres")


@onready var portrait: TextureRect = %Portrait
@onready var detail_label: Label = %DetailLabel
@onready var tab_equip: BaseButton = %Tab_Equip
@onready var tab_consumable: BaseButton = %Tab_Consumable
@onready var tab_keyitem: BaseButton = %Tab_KeyItem
@onready var tab_material: BaseButton = %Tab_Material
@onready var prev_button: BaseButton = %PrevButton
@onready var next_button: BaseButton = %NextButton
@onready var page_label: Label = %PageLabel
@onready var char_name_label: Label = null

var _item_slots: Array[Panel] = []
var _item_icons: Array[TextureRect] = []
var _current_tab: ItemTab = ItemTab.EQUIP
var _current_page: int = 0
var _filtered_ids: Array[String] = []
var _material_source: Array = []
var _search := ""
var _sort_mode := 0
var _filter_mode := 0
var _selected_equip_idx: int = -1

signal closed()
signal request_equip(slot_key: String, bag_index: int)
signal request_unequip(slot_key: String)
signal request_sell(bag_index: int)


@onready var _tooltip_label: RichTextLabel = $TooltipPopup
@onready var _comparison_tooltip: RichTextLabel = $ComparisonTooltip

func _ready() -> void:
	if has_node("BagTools"):
		$BagTools/Search.text_changed.connect(func(value): _search = value.strip_edges(); _apply_bag_tools())
		$BagTools/Sort.item_selected.connect(func(index): _sort_mode = index; _apply_bag_tools())
		$BagTools/Filter.item_selected.connect(func(index): _filter_mode = index; _apply_bag_tools())
	_collect_item_slots()
	char_name_label = get_node_or_null("LeftArea/PortraitLabel") as Label
	_connect_signals()
	get_node("CloseBtn").pressed.connect(func():
		var snd = AudioStreamPlayer.new()
		snd.stream = load("res://Audio/SE/003-System03.ogg")
		snd.bus = "SFX"
		get_tree().root.add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)
		hide(); closed.emit())
	_refresh_gold()


func _show_tooltip(text: String, local_pos: Vector2, comparison: String = "", equipped: bool = false, item: Dictionary = {}, comparison_item: Dictionary = {}) -> void:
	if _tooltip_label == null: return
	var owner := get_viewport().gui_get_focus_owner()
	if owner and is_ancestor_of(owner) and owner.has_focus():
		local_pos = owner.get_global_rect().end - global_position
	_tooltip_label.theme_type_variation = &"EquippedTooltip" if equipped else (&"CandidateTooltip" if "未穿戴" in text else &"RichTextLabel")
	_comparison_tooltip.theme_type_variation = &"EquippedTooltip"
	_tooltip_label.display_icon(item, _load_tcp_icon(str(item.get("tcp_path", ""))) if not item.is_empty() else null)
	_comparison_tooltip.display_icon(comparison_item, _load_tcp_icon(str(comparison_item.get("tcp_path", ""))) if not comparison_item.is_empty() else null)
	_tooltip_label.text = text
	_tooltip_label.fit_content = true
	_tooltip_label.size = Vector2(280, 0)
	_tooltip_label.position = local_pos + Vector2(20, 20)
	_tooltip_label.show()
	_comparison_tooltip.visible = not comparison.is_empty()
	if _comparison_tooltip.visible:
		_comparison_tooltip.text = comparison
		_comparison_tooltip.fit_content = true
		_comparison_tooltip.size = Vector2(280, 0)
	_clamp_keyboard_tooltip.call_deferred()


func _hide_tooltip() -> void:
	if _tooltip_label: _tooltip_label.hide()
	if _comparison_tooltip: _comparison_tooltip.hide()


## 对比表的右列单元：新值 + 红绿差值（suffix 传 "%" 表示百分比词缀）
func _compare_cell(label: String, old_val: int, new_val: int, suffix: String) -> String:
	var tag: String = "color=#20734d"
	if new_val < old_val: tag = "color=#a53242"
	elif new_val == old_val: tag = "color=#526985"
	return "%s +%d%s [%s](%+d%s)[/color]" % [label, new_val, suffix, tag, new_val - old_val, suffix]


func _collect_item_slots() -> void:
	_item_slots.clear()
	_item_icons.clear()

	for i in range(SLOTS_PER_PAGE):
		var slot = get_node_or_null("RightArea/ItemSlot_%02d" % i) as Panel
		_item_slots.append(slot)

		var icon: TextureRect = null
		if slot != null:
			icon = slot.get_node_or_null("Icon") as TextureRect
			slot.gui_input.connect(_on_item_slot_input.bind(i))
			slot.set_meta("keyboard_activate", _keyboard_item_actions.bind(i))
			slot.set_meta("keyboard_region", "items")
			slot.set_meta("keyboard_default", i == 0)
			slot.mouse_entered.connect(_on_item_slot_hovered.bind(i))
			slot.mouse_exited.connect(_hide_tooltip)
			if icon != null:
				icon.layout_mode = 0

		_item_icons.append(icon)

func _connect_signals() -> void:
	set_meta("keyboard_region_order", ["character", "equipment", "items", "tabs", "paging", "close"])
	prev_button.set_meta("keyboard_region", "paging")
	next_button.set_meta("keyboard_region", "paging")
	get_node("CloseBtn").set_meta("keyboard_region", "close")
	for button in [tab_equip, tab_consumable, tab_keyitem, tab_material]: button.set_meta("keyboard_region", "tabs")
	tab_equip.pressed.connect(_on_tab_pressed.bind(ItemTab.EQUIP))
	tab_consumable.pressed.connect(_on_tab_pressed.bind(ItemTab.CONSUMABLE))
	tab_keyitem.pressed.connect(_on_tab_pressed.bind(ItemTab.KEY_ITEM))
	tab_material.pressed.connect(_on_tab_pressed.bind(ItemTab.MATERIAL))
	prev_button.pressed.connect(_on_prev_page)
	next_button.pressed.connect(_on_next_page)
	# 角色切换按钮
	var char_prev = get_node_or_null("PrevBtn") as BaseButton
	var char_next = get_node_or_null("NextBtn") as TextureButton
	if char_prev:
		char_prev.set_meta("keyboard_region", "character")
		char_prev.pressed.connect(_prev_char)
	if char_next:
		char_next.set_meta("keyboard_region", "character")
		char_next.pressed.connect(_next_char)

	for node_name in SLOT_NODE_MAP:
		var slot = get_node_or_null("LeftArea/%s" % node_name) as Panel
		if slot == null:
			continue
		# 所有非 Button 子节点忽略鼠标，让 ClickBtn 捕获点击
		for child in slot.get_children():
			if not (child is Button) and child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var btn = slot.get_node_or_null("ClickBtn") as Button
		if btn:
			
			# Panel 是 layout_mode=0，子节点 anchors 无效，手动同步尺寸
			btn.size = slot.size
			btn.position = Vector2.ZERO
			slot.resized.connect(func(): btn.size = slot.size)
			btn.pressed.connect(_on_equip_slot_pressed.bind(SLOT_NODE_MAP[node_name]))
			btn.set_meta("keyboard_activate", _keyboard_equipped_actions.bind(btn, str(SLOT_NODE_MAP[node_name])))
			btn.set_meta("keyboard_region", "equipment")
			btn.gui_input.connect(_on_equip_slot_rightclick.bind(SLOT_NODE_MAP[node_name]))
			btn.mouse_entered.connect(_on_equip_slot_hovered.bind(SLOT_NODE_MAP[node_name]))
			btn.mouse_exited.connect(_hide_tooltip)
		
		var icon = slot.get_node_or_null("Icon") as TextureRect
		# 不再调 _prepare_icon_rect，统一由 _refresh_equip_slots 管理布局
		if icon != null:
			icon.layout_mode = 0


func set_inventory(items: Dictionary) -> void:
	inventory_items = items


func set_materials(items: Array) -> void:
	_material_source = items.duplicate(true)
	# 同名材料堆叠
	material_items.clear()
	var stacked: Array[Dictionary] = []
	for item in items:
		if not _matches_search(str(item.get("name", ""))): continue
		if _current_tab == ItemTab.MATERIAL and not _passes_material_filter(item): continue
		var found := false
		for s in stacked:
			if s.get("name", "") == item.get("name", "") and s.get("tcp_path", "") == item.get("tcp_path", "") and s.get("craft_type", "") == item.get("craft_type", ""):
				s["_qty"] = s.get("_qty", 0) + 1
				found = true
				break
		if not found:
			var copy = item.duplicate()
			copy["_qty"] = 1
			stacked.append(copy)
	material_items = stacked
	material_items.sort_custom(func(a, b): return _compare_bag_items(a, b))

func _matches_search(value: String) -> bool:
	return _search.is_empty() or value.to_lower().contains(_search.to_lower())

func _compare_bag_items(a: Dictionary, b: Dictionary) -> bool:
	if _sort_mode == 1 and a.get("_qty", 1) != b.get("_qty", 1): return a.get("_qty", 1) > b.get("_qty", 1)
	if _sort_mode == 2:
		var a_type := str(a.get("craft_type", a.get("slot", "")))
		var b_type := str(b.get("craft_type", b.get("slot", "")))
		if a_type != b_type: return a_type < b_type
	return str(a.get("display_name", a.get("name", ""))) < str(b.get("display_name", b.get("name", "")))

func _passes_material_filter(item: Dictionary) -> bool:
	if _filter_mode == 0: return true
	if _filter_mode == 1: return item.get("craft_type", "") == "weapon"
	if _filter_mode == 2: return item.get("craft_type", "") == "talisman"
	return item.get("material_type", "") == "mech_upgrade"

func _apply_bag_tools() -> void:
	_current_page = 0
	_selected_equip_idx = -1
	_hide_tooltip()
	set_materials(_material_source.duplicate(true))
	_rebuild_filtered_list()
	_render_page()


func set_equip_bag(bag: Array) -> void:
	equip_bag = bag
	print("[EquipPage] set_equip_bag — size=%d" % equip_bag.size())


func set_equipment(eq: Dictionary) -> void:
	equipment = eq
	if is_node_ready():
		_refresh_equip_slots()

## 设置当前装备的角色
func set_member_id(mid: String) -> void:
	_member_id = mid
	# 构建队伍列表
	_member_ids.clear()
	for pid in GameData.party_order:
		if GameData.party_db.has(pid):
			_member_ids.append(pid)
	if _member_ids.is_empty():
		for pid in GameData.party_db:
			_member_ids.append(pid)
	_member_idx = _member_ids.find(mid)
	if _member_idx < 0:
		_member_idx = 0
	_load_member_portrait()
	_refresh_char_label()
	equipment = GameData.player_equipment.get(mid, {})
	if is_node_ready():
		_refresh_equip_slots()

var _animating: bool = false

func _prev_char() -> void:
	if _member_ids.is_empty() or _animating: return
	_animating = true
	var orig = position.x
	await _shift_x(orig + 30)
	_member_idx = (_member_idx - 1 + _member_ids.size()) % _member_ids.size()
	_switch_to_member(_member_ids[_member_idx])
	await _unshift_x(orig)
	_animating = false

func _next_char() -> void:
	if _member_ids.is_empty() or _animating: return
	_animating = true
	var orig = position.x
	await _shift_x(orig - 30)
	_member_idx = (_member_idx + 1) % _member_ids.size()
	_switch_to_member(_member_ids[_member_idx])
	await _unshift_x(orig)
	_animating = false

func _shift_x(to: float) -> void:
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "position:x", to, 0.08)
	await tw.finished

func _unshift_x(orig: float) -> void:
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "position:x", orig, 0.15)

func _switch_to_member(mid: String) -> void:
	_member_id = mid
	_load_member_portrait()
	_refresh_char_label()
	equipment = GameData.player_equipment.get(mid, {})
	_selected_equip_idx = -1
	_refresh_equip_slots()
	if _current_tab == ItemTab.EQUIP: _render_page()

func _refresh_char_label() -> void:
	if char_name_label:
		var s = GameData.party_db.get(_member_id)
		char_name_label.text = s.get_display_name() if s else ""

func _load_member_portrait() -> void:
	if _member_id.is_empty() or not portrait: return
	var s = GameData.party_db.get(_member_id)
	if s == null: return
	var root_texture = preload("res://Script/Assets/AssetLoader.gd").root_portrait(s.was_base_path, s.portrait_path, s.character_name)
	if root_texture != null:
		portrait.texture = root_texture
		return
	if s.was_base_path.is_empty(): return
	var p = s.was_base_path + "/头像/头像.was"
	if not FileAccess.file_exists(p): return
	var r_frame: Dictionary = preload("res://Script/Assets/AssetLoader.gd").was_frame(p)
	if r_frame.is_empty(): return
	var d = r_frame
	if not d.is_empty():
		portrait.texture = d.get("texture", null)


func set_portrait(tex: Texture2D) -> void:
	if portrait:
		portrait.texture = tex


func full_refresh() -> void:
	_switch_tab(ItemTab.EQUIP)
	_refresh_equip_slots()
	_refresh_gold()


func _refresh_gold() -> void:
	var gold_label = get_node_or_null("gold") as Label
	if gold_label:
		gold_label.text = "%d" % GameData.player_gold


func _load_tcp_icon(tcp_path: String) -> Texture2D:
	return preload("res://Script/Assets/AssetLoader.gd").tcp_texture(tcp_path)


func _on_tab_pressed(tab: ItemTab) -> void:
	_switch_tab(tab)


func _switch_tab(tab: ItemTab) -> void:
	if has_node("BagTools"):
		_filter_mode = 0
		$BagTools/Filter.clear()
		var labels: Array = ["全部", "可穿戴", "不可穿戴"] if tab == ItemTab.EQUIP else (["全部", "武器材料", "制符材料", "铁甲材料"] if tab == ItemTab.MATERIAL else (["全部", "恢复气血", "恢复灵力", "复活", "增益"] if tab == ItemTab.CONSUMABLE else ["全部", "符咒", "技能书", "任务物品"]))
		for label in labels: $BagTools/Filter.add_item(label)
	_current_tab = tab
	_current_page = 0
	_selected_equip_idx = -1

	tab_equip.button_pressed = tab == ItemTab.EQUIP
	tab_consumable.button_pressed = tab == ItemTab.CONSUMABLE
	tab_keyitem.button_pressed = tab == ItemTab.KEY_ITEM
	tab_material.button_pressed = tab == ItemTab.MATERIAL
	set_materials(_material_source.duplicate(true))

	_rebuild_filtered_list()
	_render_page()


## 背包保留全部装备；不可穿戴的物品在渲染时置灰。
func _visible_equip_indices() -> Array:
	var out: Array = []
	for i in equip_bag.size():
		var item: Dictionary = equip_bag[i]
		if item.is_empty() or not _matches_search(str(item.get("display_name", item.get("name", "")))): continue
		if _filter_mode > 0:
			var can_wear := GameData.can_equip(_member_id, item, EquipData.slot_key(item.get("slot", 0))).is_empty()
			if (_filter_mode == 1 and not can_wear) or (_filter_mode == 2 and can_wear): continue
		out.append(i)
	out.sort_custom(func(a, b): return _compare_bag_items(equip_bag[a], equip_bag[b]))
	return out


func _rebuild_filtered_list() -> void:
	_filtered_ids.clear()
	if _current_tab == ItemTab.MATERIAL: return

	if _current_tab == ItemTab.EQUIP:
		for _i in equip_bag.size():
			_filtered_ids.append("")
		return

	var all_ids = inventory_items.keys()
	all_ids.sort()
	for item_id in all_ids:
		var entry = inventory_items[item_id]
		var data: ItemData = entry.get("data")
		if data == null:
			continue
		if not _matches_search(data.item_name): continue
		if _current_tab == ItemTab.CONSUMABLE and _filter_mode > 0:
			var types := [ItemData.ItemType.HP_POTION, ItemData.ItemType.MP_POTION, ItemData.ItemType.REVIVE, ItemData.ItemType.BUFF_ITEM]
			if data.item_type != types[_filter_mode - 1]: continue
		elif _current_tab == ItemTab.KEY_ITEM:
			if _filter_mode == 1 and not str(item_id).begins_with("talisman_"): continue
			if _filter_mode == 2 and data.item_type != ItemData.ItemType.SKILL_BOOK: continue
			if _filter_mode == 3 and data.item_category != ItemData.ItemCategory.QUEST: continue

		match _current_tab:
			ItemTab.CONSUMABLE:
				# 药品：回血、回蓝、buff、复活
				if data.item_type in [ItemData.ItemType.HP_POTION, ItemData.ItemType.MP_POTION, ItemData.ItemType.BUFF_ITEM, ItemData.ItemType.REVIVE]:
					_filtered_ids.append(item_id)
			ItemTab.KEY_ITEM:
				# 道具：任务物品、符咒、技能书
				if data.item_category == ItemData.ItemCategory.QUEST or data.item_type in [ItemData.ItemType.SPECIAL, ItemData.ItemType.SKILL_BOOK]:
					_filtered_ids.append(item_id)
			ItemTab.MATERIAL:
				# 材料从 material_items 渲染，_filtered_ids 存索引
				for _i in material_items.size():
					_filtered_ids.append("")
	_filtered_ids.sort_custom(func(a, b):
		if _sort_mode == 1 and inventory_items[a].count != inventory_items[b].count: return inventory_items[a].count > inventory_items[b].count
		if _sort_mode == 2 and inventory_items[a].data.item_type != inventory_items[b].data.item_type: return inventory_items[a].data.item_type < inventory_items[b].data.item_type
		return inventory_items[a].data.item_name < inventory_items[b].data.item_name
	)


func _render_page() -> void:
	if _current_tab == ItemTab.EQUIP:
		# 装备标签：显示全部装备，不可穿戴项置灰
		var vis: Array = _visible_equip_indices()
		var total_pages = maxi(1, ceili(float(vis.size()) / SLOTS_PER_PAGE))
		_current_page = clampi(_current_page, 0, total_pages - 1)
		page_label.text = "%d/%d" % [_current_page + 1, total_pages]
		var start_idx = _current_page * SLOTS_PER_PAGE

		for i in range(SLOTS_PER_PAGE):
			var slot: Panel = _item_slots[i] if i < _item_slots.size() else null
			var icon: TextureRect = _item_icons[i] if i < _item_icons.size() else null
			if slot == null or icon == null:
				continue
			var vi = start_idx + i
			if vi >= vis.size():
				_clear_item_slot(slot, icon)
			else:
				_render_equip_item(vis[vi], slot, icon)
		return

	# 材料标签：直接渲染 material_items
	if _current_tab == ItemTab.MATERIAL:
		var total_pages = maxi(1, ceili(float(material_items.size()) / SLOTS_PER_PAGE))
		_current_page = clampi(_current_page, 0, total_pages - 1)
		page_label.text = "%d/%d" % [_current_page + 1, total_pages]
		var start_idx = _current_page * SLOTS_PER_PAGE
		for i in range(SLOTS_PER_PAGE):
			var slot: Panel = _item_slots[i] if i < _item_slots.size() else null
			var icon: TextureRect = _item_icons[i] if i < _item_icons.size() else null
			if slot == null or icon == null:
				continue
			var idx = start_idx + i
			if idx >= material_items.size():
				_clear_item_slot(slot, icon)
			else:
				_render_material_item(idx, slot, icon)
		return

	# 消耗品/任务走原逻辑
	var total_pages = maxi(1, ceili(float(_filtered_ids.size()) / SLOTS_PER_PAGE))
	_current_page = clampi(_current_page, 0, total_pages - 1)
	page_label.text = "%d/%d" % [_current_page + 1, total_pages]
	var start_idx = _current_page * SLOTS_PER_PAGE

	for i in range(SLOTS_PER_PAGE):
		var slot: Panel = _item_slots[i] if i < _item_slots.size() else null
		var icon: TextureRect = _item_icons[i] if i < _item_icons.size() else null
		if slot == null or icon == null:
			continue

		var idx = start_idx + i
		if idx >= _filtered_ids.size():
			_clear_item_slot(slot, icon)
			continue
		_render_inventory_item(idx, slot, icon)
		

func _render_equip_item(idx: int, slot: Panel, icon: TextureRect) -> void:
	var eq: Dictionary = equip_bag[idx] if idx < equip_bag.size() else {}
	if eq.is_empty():
		_clear_item_slot(slot, icon)
		return

	# 隐藏其他标签遗留的 emoji 和数量
	var emoji = slot.get_node_or_null("Emoji") as Label
	if emoji: emoji.visible = false
	var qty = slot.get_node_or_null("Qty") as Label
	if qty: qty.text = ""

	# 隐藏消耗品/道具的 emoji 标签

	if emoji: emoji.visible = false

	preload("res://Script/Assets/AssetLoader.gd").request_tcp(icon, str(eq.get("tcp_path", "")))
	icon.visible = true
	# layout_mode=0，不用 anchors
	icon.position = Vector2(4, 4)
	icon.size = slot.size - Vector2(8, 8)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# 两张独立卡片：当前穿戴与待装备，待装备保留红绿属性差值。
	var slot_key: String = EquipData.slot_key(eq.get("slot", -1))
	var wear_reason := GameData.can_equip(_member_id, eq, slot_key)
	icon.material = UNWEARABLE_MATERIAL if not wear_reason.is_empty() else null
	var worn: Dictionary = equipment.get(slot_key, {})
	var candidate := _equipment_tooltip(eq, worn, false)
	if not wear_reason.is_empty():
		candidate = "[color=#a53242]不可穿戴：%s[/color]\n" % wear_reason + candidate
	candidate += "\n\n[color=#526985]左键选中  双击装备[/color]"
	icon.tooltip_text = ""
	slot.set_meta("tooltip_equipment", eq)
	slot.set_meta("tooltip_bbcode", candidate)
	slot.set_meta("tooltip_comparison", _equipment_tooltip(worn, eq, true) if not worn.is_empty() else "")
	slot.set_meta("tooltip_slot_key", slot_key)

	if idx == _selected_equip_idx:
		var hl = StyleBoxFlat.new()
		hl.bg_color = Color(0.2, 0.4, 0.15, 0.7)
		hl.border_color = Color(0.4, 0.9, 0.3, 0.8)
		hl.border_width_top = 1
		hl.border_width_bottom = 1
		hl.border_width_left = 1
		hl.border_width_right = 1
		slot.add_theme_stylebox_override("panel", hl)
	else:
		_reset_slot_style(slot)


func _equipment_tooltip(eq: Dictionary, other: Dictionary, current: bool) -> String:
	var lines: Array[String] = []
	lines.append("[font_size=18][color=%s]%s[/color][/font_size]" % ["#20734d" if current else "#315c88", "✓ 已穿戴 · 当前装备" if current else "未穿戴 · 背包装备"])
	
	var title: String = eq.get("display_name", eq.get("name", ""))
	var level := int(eq.get("_build_level", 0))
	if level > 0: title += " +%d" % level
	lines.append("[font_size=18][b]%s[/b][/font_size]" % title)
	var desc := str(eq.get("desc", ""))
	if desc.is_empty() and eq.has("id"):
		desc = str(EquipData.get_named(str(eq.id)).get("desc", ""))
	lines.append("[color=#405878]%s[/color]" % (desc if not desc.is_empty() else "（无描述）"))
	var accessory_description := preload("res://Script/Data/AccessoryEffectDB.gd").description(eq)
	if not accessory_description.is_empty():
		lines.append("[color=#315c88]%s[/color]" % accessory_description)
	lines.append("")
	lines.append("[color=%s]属性[/color]" % HEADER_COLOR)
	var labels := {"atk":"攻击", "dmg":"伤害", "def":"防御", "mdef":"法防", "hp":"气血", "mp":"蓝量", "spd":"速度", "heal_up":"治疗量"}
	var special := {"lifesteal":"吸血", "gold_boost":"金币加成", "reflect":"反弹", "night_dmg":"夜战增伤", "dodge":"闪避", "true_dmg":"真实伤害", "crit_rate":"暴击(运气)", "heal_targets":"多目标治疗", "threat_reduce":"减仇恨"}
	# 使用相同的属性顺序；缺失属性显示 0，便于两张卡片逐项比较。
	var keys: Array = other.get("base", {}).keys() if current else eq.get("base", {}).keys()
	var second: Dictionary = eq.get("base", {}) if current else other.get("base", {})
	for key in second:
		if not key in keys: keys.append(key)
	for key in keys:
		var value := int(eq.get("base", {}).get(key, 0))
		var previous := int(other.get("base", {}).get(key, 0))
		if value == 0 and previous == 0: continue
		var label: String = labels.get(key, key)
		lines.append(_compare_cell(label, previous, value, "") if not current and not other.is_empty() else "%s +%d" % [label, value])
	for key in special:
		var value := int(eq.get(key, 0))
		var previous := int(other.get(key, 0))
		if value == 0 and previous == 0: continue
		lines.append(_compare_cell(special[key], previous, value, "") if not current and not other.is_empty() else "%s +%d" % [special[key], value])
	var affixes: Dictionary = {}
	var previous_affixes: Dictionary = {}
	for affix in eq.get("affixes", []):
		affixes[affix.get("type", -1)] = int(affix.get("value", 0))
	for affix in other.get("affixes", []):
		previous_affixes[affix.get("type", -1)] = int(affix.get("value", 0))
	var types: Array = previous_affixes.keys() if current else affixes.keys()
	for type in (affixes if current else previous_affixes):
		if not type in types: types.append(type)
	if not types.is_empty():
		lines.append("")
		lines.append("[color=%s]词缀[/color]" % AFFIX_COLOR)
	for type in types:
		var label := EquipData.affix_label(type)
		if label.is_empty(): continue
		label = "[color=%s]%s[/color]" % [AFFIX_COLOR, label]
		var value := int(affixes.get(type, 0))
		var previous := int(previous_affixes.get(type, 0))
		lines.append(_compare_cell(label, previous, value, "%") if not current and not other.is_empty() else "%s +%d%%" % [label, value])
	return "\n".join(lines)


func _render_inventory_item(idx: int, slot: Panel, icon: TextureRect) -> void:
	icon.material = null
	var item_id = _filtered_ids[idx]
	var entry = inventory_items.get(item_id, {})
	var data: ItemData = entry.get("data")
	var count: int = entry.get("count", 0)

	# 优先用 tcp 纹理，其次 emoji
	var emoji_label = slot.get_node_or_null("Emoji") as Label
	if emoji_label == null:
		emoji_label = Label.new()
		emoji_label.name = "Emoji"
		emoji_label.add_theme_font_size_override("font_size", 36)
		emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emoji_label.size = slot.size
		emoji_label.position = Vector2.ZERO
		emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(emoji_label)

	if data:
		if not data.icon_path.is_empty():
			preload("res://Script/Assets/AssetLoader.gd").request_tcp(icon, data.icon_path)
			icon.visible = true
			icon.position = Vector2(4, 4)
			icon.size = slot.size - Vector2(8, 8)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			emoji_label.visible = false
		else:
			preload("res://Script/Assets/AssetLoader.gd").request_tcp(icon, "")
			emoji_label.text = data.icon_emoji
			emoji_label.visible = true
		slot.set_meta("tooltip_text", "%s\n×%d\n%s" % [data.item_name, count, data.description])
	else:
		preload("res://Script/Assets/AssetLoader.gd").request_tcp(icon, "")
		emoji_label.visible = false
		slot.set_meta("tooltip_text", "")
	
	# 渲染数量
	var qty_label = slot.get_node_or_null("Qty") as Label
	if qty_label == null:
		qty_label = Label.new()
		qty_label.name = "Qty"
		qty_label.add_theme_font_size_override("font_size", 18)
		qty_label.add_theme_color_override("font_color", Color(1, 1, 0))
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		qty_label.size = Vector2(50, 18)
		qty_label.position = Vector2(slot.size.x - 55, slot.size.y - 20)
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(qty_label)
	qty_label.text = str(count) if count > 1 else ""

	_reset_slot_style(slot)
	

## 渲染材料槽位（material_bag）
func _render_material_item(idx: int, slot: Panel, icon: TextureRect) -> void:
	icon.material = null
	var mat: Dictionary = material_items[idx] if idx < material_items.size() else {}
	if mat.is_empty():
		_clear_item_slot(slot, icon)
		return
	var qty: int = mat.get("_qty", 1)
	var tcp_path: String = mat.get("icon_path", mat.get("tcp_path", ""))
	var mat_name: String = mat.get("name", "材料")
	var mat_desc: String = mat.get("desc", "")

	var emoji_label = slot.get_node_or_null("Emoji") as Label
	if emoji_label == null:
		emoji_label = Label.new()
		emoji_label.name = "Emoji"
		emoji_label.add_theme_font_size_override("font_size", 36)
		emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emoji_label.size = slot.size
		emoji_label.position = Vector2.ZERO
		emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(emoji_label)

	if not tcp_path.is_empty():
		var tex: Texture2D = load(tcp_path) if tcp_path.get_extension().to_lower() in ["svg", "png", "webp"] else _load_tcp_icon(tcp_path)
		icon.set_meta("asset_tcp_path", "")
		icon.texture = tex
		icon.visible = true
		icon.position = Vector2(4, 4)
		icon.size = slot.size - Vector2(8, 8)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		emoji_label.visible = false
	else:
		preload("res://Script/Assets/AssetLoader.gd").request_tcp(icon, "")
		emoji_label.text = "📦"
		emoji_label.visible = true

	slot.set_meta("tooltip_text", "%s\n×%d\n%s" % [mat_name, qty, mat_desc])

	var qty_label = slot.get_node_or_null("Qty") as Label
	if qty_label == null:
		qty_label = Label.new()
		qty_label.name = "Qty"
		qty_label.add_theme_font_size_override("font_size", 18)
		qty_label.add_theme_color_override("font_color", Color(1, 1, 0))
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		qty_label.size = Vector2(50, 18)
		qty_label.position = Vector2(slot.size.x - 55, slot.size.y - 20)
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(qty_label)
	qty_label.text = str(qty) if qty > 1 else ""

	_reset_slot_style(slot)


func _clear_item_slot(slot: Panel, icon: TextureRect) -> void:
	icon.material = null
	preload("res://Script/Assets/AssetLoader.gd").request_tcp(icon, "")
	_reset_slot_style(slot)
	slot.set_meta("tooltip_text", "")
	slot.set_meta("tooltip_bbcode", "")
	slot.set_meta("tooltip_comparison", "")
	var emoji = slot.get_node_or_null("Emoji") as Label
	if emoji: emoji.visible = false
	var qty = slot.get_node_or_null("Qty") as Label
	if qty: qty.text = ""


func _format_base_stats(base: Dictionary) -> String:
	var text = ""
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
	var source_size: int
	match _current_tab:
		ItemTab.EQUIP: source_size = _visible_equip_indices().size()
		ItemTab.MATERIAL: source_size = material_items.size()
		_: source_size = _filtered_ids.size()
	var total_pages = maxi(1, ceili(float(source_size) / SLOTS_PER_PAGE))
	if _current_page < total_pages - 1:
		_current_page += 1
		_render_page()


func _refresh_equip_slots() -> void:
	for node_name in SLOT_NODE_MAP:
		var slot_key: String = SLOT_NODE_MAP[node_name]
		var slot = get_node_or_null("LeftArea/%s" % node_name) as Panel
		if slot == null:
			continue

		var icon = slot.get_node_or_null("Icon") as TextureRect
		var lbl = slot.get_node_or_null("SlotLabel") as Label
		var eq: Dictionary = equipment.get(slot_key, {})

		slot.remove_theme_stylebox_override("panel")
		if eq.is_empty():
			if icon:
				preload("res://Script/Assets/AssetLoader.gd").request_tcp(icon, "")
			if lbl:
				lbl.text = slot_key
		else:
			if icon:
				var tcp = str(eq.get("tcp_path", ""))
				icon.layout_mode = 0
				preload("res://Script/Assets/AssetLoader.gd").request_tcp(icon, tcp)
				icon.visible = true
				icon.position = Vector2(4, 4)
				icon.size = slot.size - Vector2(8, 8)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if lbl:
				lbl.text = ""  # 已装备不显示名字

		# 装备槽 tooltip：统一由 _on_equip_slot_hovered 自定义弹窗，
		# 这里清空系统 tooltip，避免鼠标悬停时同时弹出两个
		var btn = slot.get_node_or_null("ClickBtn") as Button
		if btn:
			btn.tooltip_text = ""

		if _selected_equip_idx >= 0 and _selected_equip_idx < equip_bag.size():
			var selected_eq = equip_bag[_selected_equip_idx]
			var selected_slot = EquipData.slot_key(selected_eq.get("slot", -1))
			if selected_slot == slot_key:
				var hl = StyleBoxFlat.new()
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
	var lines: Array[String] = ["[font_size=18][color=#20734d]✓ 已穿戴 · 当前装备[/color][/font_size]"]
	
	var name_str = eq.get("display_name", eq.get("name", ""))
	lines.append("[b]%s[/b]" % name_str)
	var base_labels = {"atk":"攻击", "def":"防御", "mdef":"法防", "hp":"气血", "mp":"蓝量", "spd":"速度"}
	lines.append("[color=%s]属性[/color]" % HEADER_COLOR)
	for bk in eq.get("base", {}):
		var val = eq.base[bk]
		if val != 0:
			lines.append("  %s +%d" % [base_labels.get(bk, bk), val])
	# 词缀区：与属性分开，带标题，显示红色
	if not eq.get("affixes", []).is_empty():
		lines.append("")
		lines.append("[color=%s]词缀[/color]" % AFFIX_COLOR)
	for af in eq.get("affixes", []):
		var af_label: String = EquipData.affix_label(af.get("type", -1))
		if af_label != "":
			lines.append("[color=%s]  %s +%d%%[/color]" % [AFFIX_COLOR, af_label, int(af.get("value", 0))])
	lines.append("")
	lines.append("[color=#526985]右键卸下[/color]")
	_show_tooltip("\n".join(lines), get_local_mouse_position(), "", true, eq)


func _on_item_slot_hovered(slot_index: int) -> void:
	var idx = _current_page * SLOTS_PER_PAGE + slot_index
	if _current_tab == ItemTab.EQUIP:
		var vis: Array = _visible_equip_indices()
		var vi = _current_page * SLOTS_PER_PAGE + slot_index
		if vi < 0 or vi >= vis.size(): return
		var slot = _item_slots[slot_index] if slot_index < _item_slots.size() else null
		if slot == null: return
		var bbcode = slot.get_meta("tooltip_bbcode", "")
		if bbcode.is_empty(): return
		_show_tooltip(bbcode, get_local_mouse_position(), slot.get_meta("tooltip_comparison", ""), false, slot.get_meta("tooltip_equipment", {}), equipment.get(slot.get_meta("tooltip_slot_key", ""), {}))
		return
	# 非装备标签：用 slot meta
	if _current_tab == ItemTab.MATERIAL:
		if idx >= material_items.size(): return
	else:
		if idx >= _filtered_ids.size(): return
	var slot = _item_slots[slot_index] if slot_index < _item_slots.size() else null
	if slot == null: return
	var tip = slot.get_meta("tooltip_text", "")
	if tip.is_empty(): return
	_show_tooltip(tip, get_local_mouse_position())


func _on_equip_slot_pressed(slot_key: String) -> void:
	var eq: Dictionary = equipment.get(slot_key, {})
	if _selected_equip_idx >= 0 and _selected_equip_idx < equip_bag.size():
		var selected = equip_bag[_selected_equip_idx]
		var reason := GameData.can_equip(_member_id, selected, slot_key)
		if not reason.is_empty():
			detail_label.text = reason
			_play_sfx("res://Audio/SE/002-System02.ogg")
			return
		GameData.equip_item_by_index(_member_id, slot_key, _selected_equip_idx)
		equip_bag = GameData.equip_bag
		_selected_equip_idx = -1
		detail_label.text = "已装备 %s 到 %s" % [selected.get("display_name", ""), slot_key]
		equipment = GameData.player_equipment.get(_member_id, {})
		_play_sfx("res://Audio/SE/001-System01.ogg")
		_refresh_equip_slots()
		_render_page()
		return

	if eq.is_empty():
		detail_label.text = "%s（空）-- 先在装备标签里选一件装备" % slot_key
	else:
		pass
		detail_label.text = "%s %s" % [
			eq.get("display_name", ""),
			_format_base_stats(eq.get("base", {})),
		]


func _on_equip_slot_rightclick(event: InputEvent, slot_key: String) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	# 右键或双击都卸下
	if event.button_index == MOUSE_BUTTON_RIGHT or event.double_click:
		var eq: Dictionary = equipment.get(slot_key, {})
		if not eq.is_empty():
			GameData.unequip_item(_member_id, slot_key)
			equip_bag = GameData.equip_bag
			detail_label.text = "%s 已卸下" % slot_key
			equipment = GameData.player_equipment.get(_member_id, {})
			_play_sfx("res://Audio/SE/002-System02.ogg")
			_refresh_equip_slots()
			_render_page()


func _on_item_slot_input(event: InputEvent, slot_index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	# 右键：直接装备
	if event.button_index == MOUSE_BUTTON_RIGHT and _current_tab == ItemTab.EQUIP:
		var visible_indices := _visible_equip_indices()
		var visible_index := _current_page * SLOTS_PER_PAGE + slot_index
		var bag_idx: int = visible_indices[visible_index] if visible_index < visible_indices.size() else -1
		if _current_tab == ItemTab.EQUIP and bag_idx >= 0 and bag_idx < GameData.equip_bag.size():
			var eq: Dictionary = GameData.equip_bag[bag_idx]
			var slot = EquipData.slot_key(eq.get("slot", 0))
			var reason := GameData.can_equip(_member_id, eq, slot)
			if not reason.is_empty():
				detail_label.text = reason
				_play_sfx("res://Audio/SE/002-System02.ogg")
				return
			GameData.equip_item_by_index(_member_id, slot, bag_idx)
			equip_bag = GameData.equip_bag
			equipment = GameData.player_equipment.get(_member_id, {})
			_play_sfx("res://Audio/SE/001-System01.ogg")
			_refresh_equip_slots()
			_render_page()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	var idx = _current_page * SLOTS_PER_PAGE + slot_index
	if _current_tab == ItemTab.MATERIAL:
		if idx < material_items.size():
			var mat = material_items[idx]
			detail_label.text = "%s ×%d -- %s" % [mat.get("name", "?"), mat.get("_qty", 1), mat.get("desc", "")]
		return
	if _current_tab != ItemTab.EQUIP:
		if idx < _filtered_ids.size():
			var item_id = _filtered_ids[idx]
			var entry = inventory_items.get(item_id, {})
			var data: ItemData = entry.get("data")
			if data:
				detail_label.text = "%s ×%d -- %s" % [data.item_name, entry.get("count", 0), data.description]
		return

	if _current_tab == ItemTab.EQUIP:
		# 装备标签显示的是过滤后的列表，换算回背包真实索引
		var vis: Array = _visible_equip_indices()
		var vi = _current_page * SLOTS_PER_PAGE + slot_index
		if vi < 0 or vi >= vis.size():
			return
		idx = vis[vi]

	if idx >= equip_bag.size():
		return

	# 双击自动穿戴
	if event.double_click:
		if shop_mode:
			request_sell.emit(idx)
			return
		var eq = equip_bag[idx]
		var slot_key = EquipData.slot_key(eq.get("slot", -1))
		if slot_key.is_empty():
			return
		var reason := GameData.can_equip(_member_id, eq, slot_key)
		if not reason.is_empty():
			detail_label.text = reason
			_play_sfx("res://Audio/SE/002-System02.ogg")
			return
		GameData.equip_item_by_index(_member_id, slot_key, idx)
		equip_bag = GameData.equip_bag
		_selected_equip_idx = -1
		detail_label.text = "已装备 %s" % eq.get("display_name", "")
		equipment = GameData.player_equipment.get(_member_id, {})
		_play_sfx("res://Audio/SE/001-System01.ogg")
		_refresh_equip_slots()
		_render_page()
		return

	# 单击选中
	_selected_equip_idx = idx
	var sel = equip_bag[idx]
	detail_label.text = "已选中 %s -- 点击左侧槽位穿上或双击自动穿戴" % [
		sel.get("display_name", ""),
	]
	_render_page()
	_refresh_equip_slots()


## 播放界面音效
func _play_sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var snd = AudioStreamPlayer.new()
	snd.stream = load(path)
	snd.bus = "SFX"
	get_tree().root.add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)


func keyboard_page(direction: int) -> void:
	_on_tab_pressed(posmod(int(_current_tab) + direction, 4) as ItemTab)

func _keyboard_item_actions(index: int) -> void:
	var navigator = get_tree().current_scene.get("_keyboard_nav")
	if navigator == null: return
	if _current_tab != ItemTab.EQUIP:
		var inspect := InputEventMouseButton.new()
		inspect.button_index = MOUSE_BUTTON_LEFT
		inspect.pressed = true
		_on_item_slot_input(inspect, index)
		return
	var visible_indices := _visible_equip_indices()
	var visible_index := _current_page * SLOTS_PER_PAGE + index
	if visible_index >= visible_indices.size(): return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = true
	navigator.show_actions(_item_slots[index], [["出售" if shop_mode else "装备", _on_item_slot_input.bind(event, index)]])

func _keyboard_equipped_actions(button: Control, slot_key: String) -> void:
	var navigator = get_tree().current_scene.get("_keyboard_nav")
	if navigator == null: return
	var entries: Array = []
	if _selected_equip_idx >= 0:
		entries.append(["穿上选中的装备", _on_equip_slot_pressed.bind(slot_key)])
	if not equipment.get(slot_key, {}).is_empty():
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = true
		entries.append(["卸下", _on_equip_slot_rightclick.bind(event, slot_key)])
	if not entries.is_empty(): navigator.show_actions(button, entries)


func _clamp_keyboard_tooltip() -> void:
	if not is_instance_valid(_tooltip_label) or not _tooltip_label.visible: return
	var bounds := get_viewport().get_visible_rect().size
	var margin := Vector2(8, 8)
	var gap := 14.0
	var count := 2 if _comparison_tooltip.visible else 1
	var width := minf(280.0, (bounds.x - 16.0 - gap * (count - 1)) / count)
	var cards: Array = [_tooltip_label]
	if count == 2: cards.push_front(_comparison_tooltip)
	var height := 0.0
	for card in cards:
		card.custom_minimum_size.x = width
		card.size.x = width
		card.fit_content = false
		card.size.y = minf(card.get_content_height() + card.get_theme_stylebox("normal").get_minimum_size().y, bounds.y - 44.0)
		height = maxf(height, card.size.y)
	var total_width := width * count + gap * (count - 1)
	var origin := _tooltip_label.global_position
	# 整组移动，始终保持两张卡片之间的空隙和共同的顶部位置。
	if origin.x + total_width > bounds.x - margin.x:
		origin.x -= total_width + 40.0
	origin = origin.clamp(margin, (bounds - Vector2(total_width, height) - Vector2(8, 36)).max(margin))
	for i in cards.size():
		cards[i].global_position = origin + Vector2(i * (width + gap), 0)

