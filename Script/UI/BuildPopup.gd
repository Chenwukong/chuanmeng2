extends CanvasLayer
const UIFeedback = preload("res://Script/UI/UISoundFeedback.gd")

signal closed
const Lessons = preload("res://Script/UI/CommerceLesson.gd")

func start_talisman_tutorial() -> void:
	# 教学只展示本次配方所需材料，避免调试装备或大量材料挤到多页之外。
	_equip_items = _equip_items.filter(func(item): return item.get("name", "") == "符纸")
	var names: Array[String] = []
	for id in Lessons.example_requirements(): names.append(MaterialDB.MATERIAL_DB[id].name)
	_material_items = _material_items.filter(func(item): return item.get("name", "") in names)
	_equip_page = 0
	_mat_page = 0
	$CommerceLesson.start_lesson("craft")
	_refresh()

var _equip_items = []   # 装备
var _material_items = []  # 材料
var _resources = [{}, {}, {}, {}]
var _next_resource: int = 0
var _player_gold: int = 0
var _equip_page: int = 0
var _mat_page: int = 0
const SLOTS_PER_PAGE = 20

@onready var equip_slots: Array[Panel] = []
@onready var mat_slots: Array[Panel] = []
@onready var rslots = [$Panel/Resource1, $Panel/Resource2, $Panel/Resource3, $Panel/Resource4]
@onready var cost_label: Label = $"Panel/所需现金"
@onready var cash_label: Label = $"Panel/现有现金"
@onready var close_btn: Button = $Panel/CloseBtn
@onready var build_btn: Button = $Panel/BuildBtn
@onready var cancel_btn: Button = $Panel/CancelBtn


func _ready() -> void:
	$Panel/Recipes.pressed.connect(_open_recipes)
	$CraftingCatalog.recipe_selected.connect(_open_recipes)
	GameData.story_progress_committed.connect($CraftingCatalog.refresh)
	
	for i in 20:
		var sn = "Panel/ItemSlot_%02d" % i
		var slot = get_node(sn) as Panel
		if slot == null: continue
		equip_slots.append(slot)

		var idx = i
		slot.set_meta("keyboard_region", "equipment")
		slot.set_meta("keyboard_default", i == 0)
		slot.gui_input.connect(func(ev: InputEvent): _on_slot_click(ev, idx, "equip"))
		slot.mouse_entered.connect(func(): _on_slot_hover(idx, "equip"))
		slot.mouse_exited.connect(_hide_tooltip.bind(slot))

	for i in 20:
		var sn = "Panel/材料/ItemSlot_%02d" % i
		var slot = get_node(sn) as Panel
		if slot == null: continue
		mat_slots.append(slot)

		var idx = i
		slot.set_meta("keyboard_region", "materials")
		slot.gui_input.connect(func(ev: InputEvent): _on_slot_click(ev, idx, "mat"))
		slot.mouse_entered.connect(func(): _on_slot_hover(idx, "mat"))
		slot.mouse_exited.connect(_hide_tooltip)

	for i in 4:

		rslots[i].set_meta("keyboard_region", "resources")
		rslots[i].gui_input.connect(func(ev: InputEvent): _on_resource_click(i, ev))
		rslots[i].mouse_entered.connect(func(): _on_resource_hover(i))
		rslots[i].mouse_exited.connect(_hide_tooltip.bind(rslots[i]))


	close_btn.pressed.connect(func(): close())
	build_btn.pressed.connect(_build)
	cancel_btn.pressed.connect(_cancel)

	for list_name in ["equip", "mat"]:
		var prefix := "Panel/" if list_name == "equip" else "Panel/材料/"
		get_node(prefix + "PrevPage").pressed.connect(_change_page.bind(list_name, -1))
		get_node(prefix + "NextPage").pressed.connect(_change_page.bind(list_name, 1))

	_player_gold = GameData.player_gold
	_update_page_buttons()
	_refresh()

func _open_recipes(output_id: String = "") -> void:
	if has_node("Recipes"): return
	_cancel()
	_hide_tooltip()
	var popup = preload("res://scenes/UI/TalismanRecipes.tscn").instantiate()
	add_child(popup)
	if not output_id.is_empty(): popup.select_output(output_id)
	popup.crafted.connect(func(output_id):
		_player_gold = GameData.player_gold
		var scene = get_tree().current_scene
		var equipped: Array = scene._get_equipped_items() if scene.has_method("_get_equipped_items") else []
		set_materials(GameData.equip_bag.duplicate() + GameData.material_bag.duplicate() + equipped)
		if $CommerceLesson.visible and output_id == "talisman_fire":
			if scene.has_method("enable_btn"): scene.enable_btn("打造")
			GameData.complete_story_event(Lessons.CRAFT_FLAG)
			$CommerceLesson.show_success()
	)


func _page_count(list_name: String) -> int:
	var count: int = _equip_items.size() if list_name == "equip" else _material_items.size()
	return maxi(1, ceili(float(count) / SLOTS_PER_PAGE))


func _change_page(list_name: String, offset: int) -> void:
	var last_page := _page_count(list_name) - 1
	if list_name == "equip":
		_equip_page = clampi(_equip_page + offset, 0, last_page)
	else:
		_mat_page = clampi(_mat_page + offset, 0, last_page)
	_hide_tooltip()
	_refresh()


func _update_page_buttons() -> void:
	var previous_pages := Vector2i(_equip_page, _mat_page)
	_equip_page = clampi(_equip_page, 0, _page_count("equip") - 1)
	_mat_page = clampi(_mat_page, 0, _page_count("mat") - 1)
	if previous_pages != Vector2i(_equip_page, _mat_page):
		_hide_tooltip()
	for list_name in ["equip", "mat"]:
		var prefix := "Panel/" if list_name == "equip" else "Panel/材料/"
		var page := _equip_page if list_name == "equip" else _mat_page
		var total := _page_count(list_name)
		get_node(prefix + "PageNumber").text = "%d / %d" % [page + 1, total]
		get_node(prefix + "PrevPage").disabled = page == 0
		get_node(prefix + "NextPage").disabled = page >= total - 1


func set_materials(items) -> void:
	_equip_items.clear()
	_material_items.clear()
	for original in items:
		# 界面堆叠会修改 _qty，不能污染材料背包中的原始字典。
		var item: Dictionary = original.duplicate(true)
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
	$CraftingCatalog.refresh()
	$CommerceLesson.update_materials(_resources)
	_update_page_buttons()
	for i in 20:
		var slot = equip_slots[i] if i < equip_slots.size() else null
		if slot == null: continue
		var idx = _equip_page * SLOTS_PER_PAGE + i
		var icon = slot.get_node("Icon") as TextureRect
		var ql := slot.get_node("Qty") as Label
		var wl := slot.get_node("WornLabel") as Label
		var show = idx < _equip_items.size()
		var item = _equip_items[idx] if show else null
		if show and not item.has("slot") and not item.has("craft_type"):
			show = false
		if show:
			_request_icon(icon, item.get("tcp_path", ""))
			var blocked_eq := not _can_add_resource(item)
			slot.modulate = Color(0.4, 0.4, 0.4, 0.5) if blocked_eq else Color.WHITE
			ql.text = str(item.get("_qty", 1)) if item.get("_qty", 1) > 1 else ""
			wl.visible = item.get("_worn", false)
		else:
			_request_icon(icon, "")
			slot.modulate = Color(0.4, 0.4, 0.4, 0.3)
			ql.text = ""
			wl.visible = false
	for i in 20:
		var slot = mat_slots[i] if i < mat_slots.size() else null
		if slot == null: continue
		var m_idx = _mat_page * SLOTS_PER_PAGE + i
		var icon = slot.get_node("Icon") as TextureRect
		var ql := slot.get_node("Qty") as Label
		if m_idx < _material_items.size():
			var item = _material_items[m_idx]
			_request_icon(icon, item.get("tcp_path", ""))
			var blocked := not _can_add_resource(item)
			slot.modulate = Color(0.4, 0.4, 0.4, 0.5) if blocked else Color.WHITE
			ql.text = str(item.get("_qty", 1)) if item.get("_qty", 1) > 1 else ""
		else:
			_request_icon(icon, "")
			slot.modulate = Color(0.4, 0.4, 0.4, 0.3)
			ql.text = ""
	for i in 4:
		var rslot = rslots[i]
		var ricon = rslot.get_node("Icon") as TextureRect
		var res = _resources[i]
		if not res.is_empty():
			_request_icon(ricon, res.get("tcp_path", ""))
			rslot.modulate = Color.WHITE
		else:
			_request_icon(ricon, "")
			rslot.modulate = Color(0.4, 0.4, 0.4, 0.5)
	cost_label.text = "%d" % _calc_cost()
	cash_label.text = "%d" % _player_gold
	_refresh_tooltip.call_deferred()


func _get_craft_type() -> String:
	for resource in _resources:
		if resource.get("name", "") == "符纸": return "talisman"
	for i in 4:
		var r = _resources[i]
		if r.is_empty(): continue
		if r.has("slot") or r.has("equip_data"):
			return "weapon"
		if r.has("craft_type"):
			return r.get("craft_type", "")
	return ""


## 武器和符纸都是基底，同一次打造只能放入一个。
func _is_craft_base(item: Dictionary) -> bool:
	return item.has("slot") or item.has("equip_data") or item.get("name", "") == "符纸"


func _can_add_resource(item: Dictionary) -> bool:
	if _next_resource >= _resources.size():
		return false
	if _is_craft_base(item):
		for resource in _resources:
			if not resource.is_empty() and _is_craft_base(resource):
				return false
	var current_type := _get_craft_type()
	if item.get("name", "") == "符纸":
		for resource in _resources:
			if not resource.is_empty() and not _is_talisman_ingredient(resource): return false
		return true
	if current_type == "talisman": return _is_talisman_ingredient(item)
	if current_type.is_empty():
		return true
	if item.has("slot") or item.has("equip_data"):
		return current_type == "weapon"
	return item.get("craft_type", "") == current_type

func _is_talisman_ingredient(item: Dictionary) -> bool:
	if item.has("slot") or item.has("equip_data"): return false
	if item.get("craft_type", "") != "talisman": return false
	for recipe in MaterialDB.TALISMAN_RECIPES:
		for id in recipe.materials:
			if MaterialDB.MATERIAL_DB[id].name == item.get("name", ""): return true
	return false


func _on_slot_click(ev: InputEvent, idx: int, list_name: String) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	if _next_resource >= 4: return
	var items = _equip_items if list_name == "equip" else _material_items
	var page = _equip_page if list_name == "equip" else _mat_page
	var real_idx = page * SLOTS_PER_PAGE + idx
	if real_idx >= items.size(): return
	var item = items[real_idx]
	if not _can_add_resource(item):
		return
	# 任意槽取回后填入第一个空位，避免覆盖其他已放入的材料。
	var empty_slot := -1
	for i in _resources.size():
		if _resources[i].is_empty():
			empty_slot = i
			break
	if empty_slot < 0:
		return
	_resources[empty_slot] = item.duplicate()
	_resources[empty_slot].erase("_qty")
	_next_resource += 1
	item["_qty"] = item.get("_qty", 1) - (0 if GameData.debug_cheats_enabled and item.has("craft_type") else 1)
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
	var before_upgrade: Dictionary = weapon.duplicate(true)
	_player_gold -= cost
	GameData.player_gold = _player_gold
	_player_gold = GameData.player_gold
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
		var mb_idx = GameData.material_bag.find_custom(func(owned): return owned.get("name", "") == mat.get("name", "") and owned.get("tcp_path", "") == mat.get("tcp_path", ""))
		if mb_idx >= 0 and not GameData.debug_cheats_enabled: GameData.material_bag.remove_at(mb_idx)
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
	var result = {"name": weapon.get("display_name", weapon.get("name", "装备")), "level": lv, "changes": _upgrade_changes(before_upgrade, weapon)}
	_resources = [{}, {}, {}, {}]
	_next_resource = 0
	_refresh()
	GameData.record_weapon_upgrade(weapon)
	_show_result_popup(result)


## 符咒打造：4个材料匹配配方 → 产出符咒
func _build_talisman(cost: int) -> void:
	# 统计4个槽位中各材料的数量（用 MATERIAL_DB id 匹配配方）
	var mat_counts := {}
	for i in 4:
		var r = _resources[i]
		var mat_id := ""
		for mid in MaterialDB.MATERIAL_DB:
			if MaterialDB.MATERIAL_DB[mid].get("name", "") == r.get("name", ""):
				mat_id = mid
				break
		if mat_id.is_empty():
			_push_msg("未知材料: %s" % r.get("name", "?"))
			return
		mat_counts[mat_id] = mat_counts.get(mat_id, 0) + 1
	
	# 匹配配方
	var matched: Dictionary = {}
	for recipe in MaterialDB.TALISMAN_RECIPES:
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
	if not preload("res://Script/Data/CraftingCatalog.gd").is_unlocked(matched):
		_push_msg("该配方尚未解锁。")
		return
	
	# 产出符咒
	var output_id: String = matched.get("output", "")
	var output_name: String = matched.get("output_name", "符咒")
	var item_data = GameData.item_db.get(output_id) as ItemData
	if item_data == null:
		_push_msg("符咒数据错误: %s" % output_id)
		return
	if GameData.player_inventory.get_count(output_id) + 3 > item_data.max_stack:
		_push_msg("%s数量已接近上限，请至少留出3张的空间再制符。" % output_name)
		return
	_player_gold -= cost
	GameData.player_gold = _player_gold
	_player_gold = GameData.player_gold
	GameData.player_inventory.add_item(item_data, 3)
	
	# 消耗材料（和武器打造同样逻辑：从 material_bag 中 find + remove）
	for i in 4:
		var mat = _resources[i]
		var mb_idx = GameData.material_bag.find_custom(func(owned): return owned.get("name", "") == mat.get("name", "") and owned.get("tcp_path", "") == mat.get("tcp_path", ""))
		if mb_idx >= 0 and not GameData.debug_cheats_enabled:
			GameData.material_bag.remove_at(mb_idx)
	
	# 清空槽位
	_resources = [{}, {}, {}, {}]
	_next_resource = 0
	_refresh()
	# 原料、费用和产出全部结算后再提交教学，自动存档不能保存到半完成状态。
	if $CommerceLesson.visible and output_id == "talisman_fire":
		var scene := get_tree().current_scene
		if scene.has_method("enable_btn"): scene.enable_btn("打造")
		GameData.complete_story_event(Lessons.CRAFT_FLAG)
	_show_result_popup({"name": output_name, "level": 0})
	if $CommerceLesson.visible and output_id == "talisman_fire": $CommerceLesson.show_success()


## 用打造前后差值展示实际随机结果，相同属性的多份材料合并显示。
func _upgrade_changes(before: Dictionary, after: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for group in ["base", "extra"]:
		var previous: Dictionary = before.get("base", {}) if group == "base" else before
		var current: Dictionary = after.get("base", {}) if group == "base" else after
		for key in current:
			if group == "extra" and key not in ["lifesteal", "gold_boost", "reflect", "night_dmg", "heal_targets", "true_dmg", "crit_rate", "dodge", "threat_reduce"]:
				continue
			if not (current[key] is int or current[key] is float):
				continue
			var old_value = previous.get(key, 0)
			var increase = current[key] - old_value
			if increase > 0:
				lines.append("%s   %s → %s   [color=#25704b]+%s[/color]" % [_stat_label(str(key)), str(old_value), str(current[key]), str(increase)])
	return lines


func _show_result_popup(result: Dictionary) -> void:
	UIFeedback.play_ui(&"success")
	var popup = preload("res://scenes/UI/CraftResultPopup.tscn").instantiate()
	popup.set_meta("keyboard_modal", true)
	popup.set_meta("keyboard_cancel", popup.queue_free)
	add_child(popup)
	var item_name: String = result.get("name", "装备")
	var level: int = result.get("level", 1)
	popup.get_node("Panel/ItemName").text = item_name + (" +%d" % level if level > 0 else "")
	popup.get_node("Panel/Description").text = "强化完成，装备属性已提升" if level > 0 else "制符完成，成品已放入行囊"
	var changes: Array = result.get("changes", [])
	popup.get_node("Panel/Changes").text = "\n".join(changes) if not changes.is_empty() else ("本次未增加额外属性" if level > 0 else "获得符咒 ×3")
	popup.get_node("Panel/Confirm").set_meta("keyboard_default", true)
	popup.get_node("Panel/Confirm").pressed.connect(popup.queue_free)
	popup.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			popup.queue_free()
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
	UIFeedback.play_ui(&"error")
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


@onready var _tooltip_label: RichTextLabel = $TooltipPopup
var _tooltip_source: Control
## UI 只提交图标请求；缓存、分帧解码和过期检查由资源服务统一管理。
func _request_icon(icon: TextureRect, path: String) -> void:
	preload("res://Script/Assets/AssetLoader.gd").request_tcp(icon, path)


func _on_slot_hover(idx: int, list_name: String) -> void:
	var items = _equip_items if list_name == "equip" else _material_items
	var page = _equip_page if list_name == "equip" else _mat_page
	var real_idx = page * SLOTS_PER_PAGE + idx
	if real_idx >= items.size():
		_hide_tooltip()
		return
	var source: Control = equip_slots[idx] if list_name == "equip" else mat_slots[idx]
	_show_item_tip(items[real_idx], source)


func _on_resource_hover(idx: int) -> void:
	var item = _resources[idx]
	if item.is_empty():
		_hide_tooltip()
		return
	_show_item_tip(item, rslots[idx])


func _show_item_tip(item: Dictionary, source: Control = null) -> void:
	_tooltip_source = source
	if _tooltip_label == null: return
	var lines = []
	var name = item.get("display_name", item.get("name", ""))
	var lv = item.get("_build_level", 0)
	if lv > 0: name += " +%d" % lv
	if not name.is_empty(): lines.append("[color=#FFD700]%s[/color]" % name)
	var base = item.get("base", {})
	for key in base:
		if base[key] is int or base[key] is float:
			lines.append("%s: %s%s" % [_stat_label(str(key)), "+" if base[key] >= 0 else "", str(base[key])])
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
		var stat_name := _stat_label(str(stat))
		var boost_range = str(minb) if minb == maxb else "%d~%d" % [minb, maxb]
		lines.append("[color=#8f8]→ %s +%s[/color]" % [stat_name, boost_range])
	var ctype = item.get("craft_type", "")
	if ctype == "weapon": lines.append(GameData._T("BUILD_TOOLTIP_WEAPON"))
	elif ctype == "talisman": lines.append(GameData._T("BUILD_TOOLTIP_TALISMAN"))
	_tooltip_label.text = "\n".join(lines)
	_tooltip_label.reset_size()
	_tooltip_label.show()
	_place_tooltip()
	_place_tooltip.call_deferred()

func _place_tooltip() -> void:
	if not _tooltip_label.visible: return
	var at := get_viewport().get_mouse_position()
	if is_instance_valid(_tooltip_source) and not _tooltip_source.get_global_rect().has_point(at):
		at = _tooltip_source.get_global_rect().end
	var bounds := get_viewport().get_visible_rect().size
	_tooltip_label.position = (at + Vector2(18, 18)).clamp(Vector2(8, 8), (bounds - _tooltip_label.size - Vector2(8, 36)).max(Vector2(8, 8)))

func _hide_tooltip(source: Control = null) -> void:
	# 新格子可能先进入，旧格子才离开；旧事件不能关闭新格子的说明。
	if source != null and source != _tooltip_source: return
	_tooltip_source = null
	if _tooltip_label: _tooltip_label.hide()

func _refresh_tooltip() -> void:
	if not is_instance_valid(_tooltip_source): return
	if _tooltip_source in equip_slots: _on_slot_hover(equip_slots.find(_tooltip_source), "equip")
	elif _tooltip_source in mat_slots: _on_slot_hover(mat_slots.find(_tooltip_source), "mat")
	elif _tooltip_source in rslots: _on_resource_hover(rslots.find(_tooltip_source))

func _stat_label(key: String) -> String:
	var labels := {
		"hp": "BUILD_TOOLTIP_HP", "atk": "BUILD_TOOLTIP_ATK", "dmg": "BUILD_TOOLTIP_DMG",
		"def": "BUILD_TOOLTIP_DEF", "spd": "BUILD_TOOLTIP_SPD", "matk": "BUILD_TOOLTIP_MATK",
		"mdef": "BUILD_TOOLTIP_MDEF", "mp": "BUILD_TOOLTIP_MP", "mp_up": "BUILD_TOOLTIP_MP",
		"heal_up": "BUILD_TOOLTIP_HEAL", "lifesteal": "BUILD_TOOLTIP_LIFESTEAL",
		"gold_boost": "BUILD_TOOLTIP_GOLD", "reflect": "BUILD_TOOLTIP_REFLECT",
		"night_dmg": "BUILD_TOOLTIP_NIGHT", "heal_targets": "BUILD_TOOLTIP_HEALTARGETS",
		"true_dmg": "BUILD_TOOLTIP_TRUE_DMG", "crit_rate": "BUILD_TOOLTIP_CRIT_RATE",
		"dodge": "BUILD_TOOLTIP_DODGE", "threat_reduce": "BUILD_TOOLTIP_THREAT_REDUCE",
		"luck": "BUILD_TOOLTIP_LUCK", "crit_dmg": "BUILD_TOOLTIP_CRIT_DMG",
		"penetration": "BUILD_TOOLTIP_PENETRATION"
	}
	return GameData._T(labels.get(key, "BUILD_TOOLTIP_OTHER"))


func _load_tcp_icon(tcp_path: String) -> Texture2D:
	return preload("res://Script/Assets/AssetLoader.gd").tcp_texture(tcp_path)


