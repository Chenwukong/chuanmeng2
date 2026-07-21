extends CanvasLayer

signal closed

var _equip_items = []   # 装备
var _material_items = []  # 材料
var _resources = [{}, {}, {}, {}]
var _next_resource: int = 0
var _player_gold: int = 0
var _equip_page: int = 0  # 0,1,2
var _mat_page: int = 0
const SLOTS_PER_PAGE = 20

@onready var equip_slots: Array[Panel] = []
@onready var mat_slots: Array[Panel] = []
@onready var rslots = [$Resource1, $Resource2, $Resource3, $Resource4]
@onready var cost_label: Label = $"所需现金"
@onready var cash_label: Label = $"现有现金"
@onready var close_btn: TextureButton = $CloseBtn
@onready var build_btn: TextureButton = $BuildBtn
@onready var cancel_btn: TextureButton = $CancelBtn


func _ready() -> void:
	
	for i in 20:
		var sn = "ItemSlot_%02d" % i
		var slot = get_node(sn) as Panel
		if slot == null: continue
		equip_slots.append(slot)
		slot.self_modulate = Color(1, 1, 1, 0)
		var idx = i
		slot.gui_input.connect(func(ev: InputEvent): _on_slot_click(ev, idx, "equip"))
		slot.mouse_entered.connect(func(): _on_slot_hover(idx, "equip"))
		slot.mouse_exited.connect(_hide_tooltip)

	for i in 20:
		var sn = "材料/ItemSlot_%02d" % i
		var slot = get_node(sn) as Panel
		if slot == null: continue
		mat_slots.append(slot)
		slot.self_modulate = Color(1, 1, 1, 0)
		var idx = i
		slot.gui_input.connect(func(ev: InputEvent): _on_slot_click(ev, idx, "mat"))
		slot.mouse_entered.connect(func(): _on_slot_hover(idx, "mat"))
		slot.mouse_exited.connect(_hide_tooltip)

	for i in 4:
		rslots[i].self_modulate = Color(1, 1, 1, 0)
		rslots[i].gui_input.connect(func(ev: InputEvent): _on_resource_click(i, ev))
		rslots[i].mouse_entered.connect(func(): _on_resource_hover(i))
		rslots[i].mouse_exited.connect(_hide_tooltip)

	var tip = RichTextLabel.new()
	tip.name = "TooltipPopup"
	tip.visible = false
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.bbcode_enabled = true
	tip.fit_content = true
	tip.autowrap_mode = TextServer.AUTOWRAP_OFF
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.1, 0.9)
	sb.border_color = Color(0.4, 0.5, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	tip.add_theme_stylebox_override("normal", sb)
	add_child(tip)
	_tooltip_label = tip

	close_btn.pressed.connect(func(): close())
	build_btn.pressed.connect(_build)
	cancel_btn.pressed.connect(_cancel)

	# 装备区翻页按钮
	_equip_page = 0
	for p in range(3):
		var btn = get_node_or_null("Page%d" % (p+1)) as TextureButton
		if btn:
			btn.pressed.connect(func(page = p): _equip_page = page; _update_page_buttons(); _refresh())
	# 材料区翻页按钮
	_mat_page = 0
	for p in range(3):
		var btn = get_node_or_null("材料/Page%d" % (p+1)) as TextureButton
		if btn:
			btn.pressed.connect(func(page = p): _mat_page = page; _update_page_buttons(); _refresh())

	_player_gold = GameData.player_gold
	_update_page_buttons()
	_refresh()


func _update_page_buttons() -> void:
	for p in range(3):
		var eb = get_node_or_null("Page%d" % (p+1)) as TextureButton
		if eb: eb.modulate = Color(1, 1, 1, 1) if p == _equip_page else Color(0.75, 0.75, 0.75, 0.85)
		var mb = get_node_or_null("材料/Page%d" % (p+1)) as TextureButton
		if mb: mb.modulate = Color(1, 1, 1, 1) if p == _mat_page else Color(0.75, 0.75, 0.75, 0.85)


func set_materials(items) -> void:
	_equip_items.clear()
	_material_items.clear()
	for item in items:
		var has_craft = item.has("craft_type")
		var is_equip = item.has("slot") or item.has("equip_data")
		if has_craft:
			# 符纸放左边（和武器同级作为基底），其他符咒材料仍在右边
			if item.get("name", "") == "符纸":
				_equip_items.append(item)
			else:
				_material_items.append(item)
		elif is_equip and item.get("slot", -1) == EquipData.SlotType.WEAPON:
			_equip_items.append(item)
	_stack_all()


func _stack_all() -> void:
	for arr in [_equip_items, _material_items]:
		var stacked = []
		for item in arr:
			var found = false
			for s in stacked:
				if s.get("name", "") == item.get("name", "") and s.get("tcp_path", "") == item.get("tcp_path", ""):
					s["_qty"] = s.get("_qty", 0) + 1
					found = true
					break
			if not found:
				item["_qty"] = 1
				stacked.append(item)
		arr.clear()
		arr.append_array(stacked)
	_refresh()


func _refresh() -> void:
	var current_type = _get_craft_type()
	for i in 20:
		var slot = equip_slots[i] if i < equip_slots.size() else null
		if slot == null: continue
		var idx = _equip_page * SLOTS_PER_PAGE + i
		var icon = slot.get_node("Icon") as TextureRect
		var ql = slot.get_node_or_null("Qty") as Label
		if ql == null:
			ql = Label.new()
			ql.name = "Qty"
			ql.add_theme_font_size_override("font_size", 18)
			ql.add_theme_color_override("font_color", Color(1, 1, 0))
			ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			ql.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			ql.size = Vector2(50, 18)
			ql.position = Vector2(slot.size.x - 55, slot.size.y - 20)
			ql.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(ql)
		var wl = slot.get_node_or_null("WornLabel") as Label
		if wl == null:
			wl = Label.new()
			wl.name = "WornLabel"
			wl.text = "装备"
			wl.add_theme_font_size_override("font_size", 38)
			wl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
			wl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
			wl.add_theme_constant_override("shadow_offset_x", 2)
			wl.add_theme_constant_override("shadow_offset_y", 2)
			wl.size = slot.size
			wl.position = Vector2(0, 0)
			wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			wl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			wl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(wl)
		var show = idx < _equip_items.size()
		var item = _equip_items[idx] if show else null
		if show and not item.has("slot") and not item.has("craft_type"):
			show = false
		if show:
			icon.texture = _load_tcp_icon(item.get("tcp_path", ""))
			# 符咒模式下只灰掉武器，符纸等材料仍可点
			var is_weapon = item.has("slot") or item.has("equip_data")
			var blocked_eq = (current_type == "talisman" and is_weapon) or (current_type == "weapon" and item.has("craft_type") and item.get("craft_type", "") != "weapon")
			slot.modulate = Color(0.4, 0.4, 0.4, 0.5) if blocked_eq else Color.WHITE
			ql.text = str(item.get("_qty", 1)) if item.get("_qty", 1) > 1 else ""
			wl.visible = item.get("_worn", false)
		else:
			icon.texture = null
			slot.modulate = Color(0.4, 0.4, 0.4, 0.3)
			ql.text = ""
			wl.visible = false
	for i in 20:
		var slot = mat_slots[i] if i < mat_slots.size() else null
		if slot == null: continue
		var m_idx = _mat_page * SLOTS_PER_PAGE + i
		var icon = slot.get_node("Icon") as TextureRect
		var ql = slot.get_node_or_null("Qty") as Label
		if ql == null:
			ql = Label.new()
			ql.name = "Qty"
			ql.add_theme_font_size_override("font_size", 18)
			ql.add_theme_color_override("font_color", Color(1, 1, 0))
			ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			ql.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			ql.size = Vector2(50, 18)
			ql.position = Vector2(slot.size.x - 55, slot.size.y - 20)
			ql.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(ql)
		if m_idx < _material_items.size():
			var item = _material_items[m_idx]
			icon.texture = _load_tcp_icon(item.get("tcp_path", ""))
			var blocked = false
			if current_type != "" and item.get("craft_type", "") != current_type:
				blocked = true
			slot.modulate = Color(0.4, 0.4, 0.4, 0.5) if blocked else Color.WHITE
			ql.text = str(item.get("_qty", 1)) if item.get("_qty", 1) > 1 else ""
		else:
			icon.texture = null
			slot.modulate = Color(0.4, 0.4, 0.4, 0.3)
			ql.text = ""
	for i in 4:
		var rslot = rslots[i]
		var ricon = rslot.get_node("Icon") as TextureRect
		var res = _resources[i]
		if not res.is_empty():
			ricon.texture = _load_tcp_icon(res.get("tcp_path", ""))
			rslot.modulate = Color.WHITE
		else:
			ricon.texture = null
			rslot.modulate = Color(0.4, 0.4, 0.4, 0.5)
	cost_label.text = "%d" % _calc_cost()
	cash_label.text = "%d" % _player_gold


func _get_craft_type() -> String:
	for i in 4:
		var r = _resources[i]
		if r.is_empty(): continue
		if r.has("slot") or r.has("equip_data"):
			return "weapon"
		if r.has("craft_type"):
			return r.get("craft_type", "")
	return ""


func _on_slot_click(ev: InputEvent, idx: int, list_name: String) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	if _next_resource >= 4: return
	var items = _equip_items if list_name == "equip" else _material_items
	var page = _equip_page if list_name == "equip" else _mat_page
	var real_idx = page * SLOTS_PER_PAGE + idx
	if real_idx >= items.size(): return
	var item = items[real_idx]
	if _next_resource == 0 and not item.has("craft_type"):
		var eq_slot = item.get("slot", -1)
		if eq_slot != EquipData.SlotType.WEAPON and eq_slot != -1:
			_push_msg("只能强化武器！")
			return
	var current_type = _get_craft_type()
	if current_type != "":
		if item.has("craft_type") and item.get("craft_type", "") != current_type:
			return
		if (item.has("slot") or item.has("equip_data")) and current_type != "weapon":
			return
	_resources[_next_resource] = item.duplicate()
	_resources[_next_resource].erase("_qty")
	_next_resource += 1
	item["_qty"] = item.get("_qty", 1) - 1
	if item["_qty"] <= 0:
		items.remove_at(real_idx)
	_refresh()


func _on_resource_click(idx: int, ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed):
		return
	if ev.button_index != MOUSE_BUTTON_RIGHT and ev.button_index != MOUSE_BUTTON_LEFT:
		return
	var res = _resources[idx]
	if res.is_empty(): return
	_append_back(res)
	_resources[idx] = {}
	_next_resource -= 1
	_refresh()
func _append_back(item: Dictionary) -> void:
	var items: Array
	if item.has("slot") or item.has("equip_data"):
		items = _equip_items
	elif item.get("name", "") == "符纸":
		items = _equip_items
	else:
		items = _material_items
	for m in items:
		if m.get("name", "") == item.get("name", "") and m.get("tcp_path", "") == item.get("tcp_path", ""):
			m["_qty"] = m.get("_qty", 0) + 1
			return
	item["_qty"] = 1
	items.append(item)


func _calc_cost() -> int:
	var total = 0
	for i in 4:
		var res = _resources[i]
		if res.is_empty(): continue
		var p = res.get("price", 100)
		total += p
	return maxi(1, total / 4)


func _build() -> void:
	var cost = _calc_cost()
	if _next_resource < 4:
		_push_msg(GameData._T("BUILD_NEED_MATS"))
		return
	if _player_gold < cost:
		_push_msg(GameData._T("BUILD_NEED_GOLD") % cost)
		return
	var craft_type = _get_craft_type()
	if craft_type == "":
		_push_msg(GameData._T("BUILD_NEED_EQUIP"))
		return
	# ── 符咒打造 ──
	if craft_type == "talisman":
		_build_talisman(cost)
		return
	# ── 武器打造（原有逻辑） ──
	var weapon = {}
	var weapon_idx = -1
	for i in 4:
		var r = _resources[i]
		if r.has("slot") or r.has("equip_data"):
			weapon = r
			weapon_idx = i
			break
	if weapon.is_empty():
		_push_msg(GameData._T("BUILD_NEED_EQUIP"))
		return
	var lv = weapon.get("_build_level", 0)
	if lv >= 10:
		_push_msg(GameData._T("BUILD_MAX_LV"))
		return
	_player_gold -= cost
	GameData.player_gold = _player_gold
	lv += 1
	weapon["_build_level"] = lv
	if not weapon.has("base"): weapon["base"] = {}
	weapon["base"] = weapon["base"].duplicate()
	for i in 4:
		if i == weapon_idx: continue
		var mat = _resources[i]
		if mat.is_empty(): continue
		if not mat.has("craft_type"):
			_append_back(mat)
			continue
		var ctype = mat.get("craft_type", "weapon")
		if ctype != craft_type:
			_append_back(mat)
			continue
		var stat = mat.get("stat", "")
		var minb = mat.get("min_boost", 0)
		var maxb = mat.get("max_boost", 0)
		if stat == "atk": weapon["base"]["atk"] = weapon["base"].get("atk", 0) + randi_range(minb, maxb)
		elif stat == "spd": weapon["base"]["spd"] = weapon["base"].get("spd", 0) + randi_range(minb, maxb)
		elif stat == "hp": weapon["base"]["hp"] = weapon["base"].get("hp", 0) + randi_range(minb, maxb)
		elif stat == "def": weapon["base"]["def"] = weapon["base"].get("def", 0) + randi_range(minb, maxb)
		elif stat == "mp_up": weapon["base"]["mp"] = weapon["base"].get("mp", 0) + randi_range(minb, maxb)
		elif stat == "heal_up": weapon["base"]["heal_up"] = weapon["base"].get("heal_up", 0) + randi_range(minb, maxb)
		elif stat == "lifesteal": weapon["lifesteal"] = weapon.get("lifesteal", 0) + randi_range(minb, maxb)
		elif stat == "gold_boost": weapon["gold_boost"] = weapon.get("gold_boost", 0) + randi_range(minb, maxb)
		elif stat == "reflect": weapon["reflect"] = weapon.get("reflect", 0) + randi_range(minb, maxb)
		elif stat == "night_dmg": weapon["night_dmg"] = weapon.get("night_dmg", 0) + randi_range(minb, maxb)
		elif stat == "heal_targets": weapon["heal_targets"] = weapon.get("heal_targets", 0) + randi_range(minb, maxb)
		elif stat == "true_dmg": weapon["true_dmg"] = weapon.get("true_dmg", 0) + randi_range(minb, maxb)
		elif stat == "crit_rate": weapon["crit_rate"] = weapon.get("crit_rate", 0) + randi_range(minb, maxb)
		elif stat == "mdef": weapon["base"]["mdef"] = weapon["base"].get("mdef", 0) + randi_range(minb, maxb)
		elif stat == "dodge": weapon["dodge"] = weapon.get("dodge", 0) + randi_range(minb, maxb)
		elif stat == "mp": weapon["base"]["mp"] = weapon["base"].get("mp", 0) + randi_range(minb, maxb)
		elif stat == "threat_reduce": weapon["threat_reduce"] = weapon.get("threat_reduce", 0) + randi_range(minb, maxb)
		var mb_idx = GameData.material_bag.find(mat)
		if mb_idx >= 0: GameData.material_bag.remove_at(mb_idx)
	_append_back(weapon)
	GameData.equip_bag.clear()
	for m in _equip_items:
		if not m.has("craft_type"):
			var qty = m.get("_qty", 1)
			for _q in qty:
				var copy = m.duplicate()
				copy.erase("_qty")
				copy.erase("_worn")
				GameData.equip_bag.append(copy)
	var result = {"name": weapon.get("display_name", weapon.get("name", "装备")), "level": lv}
	_resources = [{}, {}, {}, {}]
	_next_resource = 0
	_refresh()
	_show_result_popup(result)


## 符咒打造：4个材料匹配配方 → 产出符咒
func _build_talisman(cost: int) -> void:
	# 统计4个槽位中各材料的数量（用 MATERIAL_DB id 匹配配方）
	var mat_counts := {}
	for i in 4:
		var r = _resources[i]
		var mat_id := ""
		for mid in GameData.MATERIAL_DB:
			if GameData.MATERIAL_DB[mid].get("name", "") == r.get("name", ""):
				mat_id = mid
				break
		if mat_id.is_empty():
			_push_msg("未知材料: %s" % r.get("name", "?"))
			return
		mat_counts[mat_id] = mat_counts.get(mat_id, 0) + 1
	
	# 匹配配方
	var matched: Dictionary = {}
	for recipe in GameData.TALISMAN_RECIPES:
		var req: Dictionary = recipe.get("materials", {})
		if req.size() != mat_counts.size():
			continue
		var ok := true
		for mid in req:
			if mat_counts.get(mid, 0) != req[mid]:
				ok = false
				break
		if ok:
			matched = recipe
			break
	
	if matched.is_empty():
		_push_msg("材料组合不正确，无法打造符咒！")
		return
	
	# 扣钱
	_player_gold -= cost
	GameData.player_gold = _player_gold
	
	# 产出符咒
	var output_id: String = matched.get("output", "")
	var output_name: String = matched.get("output_name", "符咒")
	var item_data = GameData.item_db.get(output_id) as ItemData
	if item_data == null:
		_push_msg("符咒数据错误: %s" % output_id)
		return
	GameData.player_inventory.add_item(item_data, 3)
	
	# 消耗材料（和武器打造同样逻辑：从 material_bag 中 find + remove）
	for i in 4:
		var mat = _resources[i]
		var mb_idx = GameData.material_bag.find(mat)
		if mb_idx >= 0:
			GameData.material_bag.remove_at(mb_idx)
	
	# 清空槽位
	_resources = [{}, {}, {}, {}]
	_next_resource = 0
	_refresh()
	_show_result_popup({"name": output_name, "level": 0})


func _show_result_popup(result: Dictionary) -> void:
	var panel = Panel.new()
	panel.size = Vector2(280, 120)
	panel.position = get_viewport().get_visible_rect().size * 0.5 - Vector2(140, 60)
	add_child(panel)
	var lbl = Label.new()
	var name = result.get("name", "装备")
	var lv = result.get("level", 1)
	var txt: String
	if lv == 0:  # 符咒打造
		txt = GameData._T("BUILD_SUCCESS") % name
	else:
		txt = GameData._T("BUILD_SUCCESS") % (name + " +%d" % lv)
	txt += "\n\n" + GameData._T("BUILD_CLICK_CLOSE")
	lbl.text = txt
	lbl.position = Vector2(15, 15)
	lbl.size = Vector2(250, 90)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			panel.queue_free()
	)


func _cancel() -> void:
	for i in 4:
		var res = _resources[i]
		if not res.is_empty():
			_append_back(res)
			_resources[i] = {}
	_next_resource = 0
	_refresh()


func _push_msg(text: String) -> void:
	var log = get_tree().current_scene.get_node_or_null("UI/BattleLog") as RichTextLabel
	if log:
		log.append_text("[color=yellow]🔨 %s[/color]\n" % text)


func close() -> void:
	closed.emit()
	queue_free()
	# 关闭音效
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://Audio/SE/003-System03.ogg")
	snd.bus = "SFX"
	get_tree().root.add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)


var _tooltip_label: RichTextLabel = null
var _icon_cache: Dictionary = {}

func _on_slot_hover(idx: int, list_name: String) -> void:
	var items = _equip_items if list_name == "equip" else _material_items
	var page = _equip_page if list_name == "equip" else _mat_page
	var real_idx = page * SLOTS_PER_PAGE + idx
	if real_idx >= items.size(): return
	_show_item_tip(items[real_idx])


func _on_resource_hover(idx: int) -> void:
	var item = _resources[idx]
	if item.is_empty(): return
	_show_item_tip(item)


func _show_item_tip(item: Dictionary) -> void:
	if _tooltip_label == null: return
	var lines = []
	var name = item.get("display_name", item.get("name", ""))
	var lv = item.get("_build_level", 0)
	if lv > 0: name += " +%d" % lv
	if not name.is_empty(): lines.append("[color=#FFD700]%s[/color]" % name)
	var base = item.get("base", {})
	for k in base:
		if base[k] is int:
			lines.append("%s: +%d" % [{"hp":GameData._T("BUILD_TOOLTIP_HP"),"atk":GameData._T("BUILD_TOOLTIP_ATK"),"def":GameData._T("BUILD_TOOLTIP_DEF"),"spd":GameData._T("BUILD_TOOLTIP_SPD"),"matk":GameData._T("BUILD_TOOLTIP_MATK"),"mdef":GameData._T("BUILD_TOOLTIP_MDEF"),"mp":GameData._T("BUILD_TOOLTIP_MP"),"heal_up":GameData._T("BUILD_TOOLTIP_HEAL")}.get(k, k), base[k]])
	for extra in ["lifesteal", "gold_boost", "reflect", "night_dmg", "heal_targets", "true_dmg", "crit_rate", "dodge", "threat_reduce"]:
		var val = item.get(extra, 0)
		if val > 0:
			match extra:
				"lifesteal": lines.append(GameData._T("BUILD_TOOLTIP_LIFESTEAL") + ": +%d" % val)
				"gold_boost": lines.append(GameData._T("BUILD_TOOLTIP_GOLD") + ": +%d" % val)
				"reflect": lines.append(GameData._T("BUILD_TOOLTIP_REFLECT") + ": +%d" % val)
				"night_dmg": lines.append(GameData._T("BUILD_TOOLTIP_NIGHT") + ": +%d" % val)
				"heal_targets": lines.append(GameData._T("BUILD_TOOLTIP_HEALTARGETS") + ": +%d" % val)
				"true_dmg": lines.append(GameData._T("BUILD_TOOLTIP_TRUE_DMG") + ": +%d" % val)
				"crit_rate": lines.append(GameData._T("BUILD_TOOLTIP_CRIT_RATE") + ": +%d" % val)
				"dodge": lines.append(GameData._T("BUILD_TOOLTIP_DODGE") + ": +%d" % val)
				"threat_reduce": lines.append(GameData._T("BUILD_TOOLTIP_THREAT_REDUCE") + ": +%d" % val)
	var price = item.get("price", 0)
	if price > 0: lines.append(GameData._T("BUILD_TOOLTIP_PRICE") % price)
	var stat = item.get("stat", "")
	var minb = item.get("min_boost", 0)
	var maxb = item.get("max_boost", 0)
	if stat != "" and not item.has("slot") and not item.has("equip_data"):
		var stat_name = {"hp":GameData._T("BUILD_TOOLTIP_HP"),"atk":GameData._T("BUILD_TOOLTIP_ATK"),"def":GameData._T("BUILD_TOOLTIP_DEF"),"spd":GameData._T("BUILD_TOOLTIP_SPD"),"matk":GameData._T("BUILD_TOOLTIP_MATK"),"mdef":GameData._T("BUILD_TOOLTIP_MDEF"),"mp":GameData._T("BUILD_TOOLTIP_MP"),"mp_up":GameData._T("BUILD_TOOLTIP_MP"),"heal_up":GameData._T("BUILD_TOOLTIP_HEAL"),"lifesteal":GameData._T("BUILD_TOOLTIP_LIFESTEAL"),"gold_boost":GameData._T("BUILD_TOOLTIP_GOLD"),"reflect":GameData._T("BUILD_TOOLTIP_REFLECT"),"night_dmg":GameData._T("BUILD_TOOLTIP_NIGHT"),"heal_targets":GameData._T("BUILD_TOOLTIP_HEALTARGETS"),"true_dmg":GameData._T("BUILD_TOOLTIP_TRUE_DMG"),"crit_rate":GameData._T("BUILD_TOOLTIP_CRIT_RATE"),"dodge":GameData._T("BUILD_TOOLTIP_DODGE"),"threat_reduce":GameData._T("BUILD_TOOLTIP_THREAT_REDUCE")}.get(stat, stat)
		var boost_range = str(minb) if minb == maxb else "%d~%d" % [minb, maxb]
		lines.append("[color=#8f8]→ %s +%s[/color]" % [stat_name, boost_range])
	var ctype = item.get("craft_type", "")
	if ctype == "weapon": lines.append(GameData._T("BUILD_TOOLTIP_WEAPON"))
	elif ctype == "talisman": lines.append(GameData._T("BUILD_TOOLTIP_TALISMAN"))
	_tooltip_label.text = "\n".join(lines)
	_tooltip_label.position = get_viewport().get_mouse_position() + Vector2(20, 20)
	_tooltip_label.reset_size()
	_tooltip_label.visible = true


func _hide_tooltip() -> void:
	if _tooltip_label: _tooltip_label.visible = false


func _load_tcp_icon(tcp_path: String) -> Texture2D:
	if tcp_path.is_empty(): return null
	if _icon_cache.has(tcp_path): return _icon_cache[tcp_path]
	if not FileAccess.file_exists(tcp_path): return null
	var reader = TcpReader.new()
	if not reader.load_from_file(tcp_path): return null
	var decoded = reader.decode_frame(0)
	if decoded.is_empty(): return null
	var tex = decoded.get("texture", null) as Texture2D
	if tex != null: _icon_cache[tcp_path] = tex
	return tex
