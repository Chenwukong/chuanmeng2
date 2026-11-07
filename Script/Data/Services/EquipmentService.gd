extends RefCounted
## GameData 统一入口委托的独立业务模块；运行状态由 facade 显式传入。

static func _ensure_equip_dict(game_state, member_id: String) -> Dictionary:
	if not game_state.player_equipment.has(member_id) or not game_state.player_equipment[member_id] is Dictionary:
		game_state.player_equipment[member_id] = {}
	return game_state.player_equipment[member_id]

## 检查某角色能否把该装备穿到指定槽位；返回空串 = 允许，否则为拒绝原因
## 规则：槽位必须匹配；武器还会校验角色的 "weapons" 允许列表（CharacterDB，空 = 不限）


static func can_equip(game_state, member_id: String, equip_item: Dictionary, slot_key: String) -> String:
	if equip_item.is_empty():
		return ""
	var item_slot: int = equip_item.get("slot", -1)
	if item_slot >= 0:
		var expect = EquipData.slot_key(item_slot)
		if not expect.is_empty() and expect != slot_key:
			return "不能放在 %s 槽，该装备只能放在 %s 槽" % [slot_key, expect]
	if item_slot == EquipData.SlotType.WEAPON:
		var wtype: String = equip_item.get("weapon_type", "")
		if not wtype.is_empty():
			var row: Dictionary = CharacterDB.CHARACTER_DB.get(member_id, {})
			var allowed: Array = row.get("weapons", [])
			if not allowed.is_empty() and not allowed.has(wtype):
				var who: String = row.get("name", member_id)
				return "%s 只能装备%s武器，无法使用「%s」" % [who, "、".join(allowed), wtype]
	return ""

## 穿上一件装备（by 背包索引，自动替换同槽位，旧装备退回背包）
## 返回是否穿成功；槽位/武器类型不匹配会拒绝（原因可用 can_equip 查询）


static func equip_item_by_index(game_state, member_id: String, slot_key: String, bag_index: int) -> bool:
	if bag_index < 0 or bag_index >= game_state.equip_bag.size():
		return false
	var eq_dict = game_state._ensure_equip_dict(member_id)
	var equip_item = game_state.equip_bag[bag_index]
	if not game_state.can_equip(member_id, equip_item, slot_key).is_empty():
		return false
	var old = eq_dict.get(slot_key, {})
	if not old.is_empty():
		game_state.equip_bag.append(old)
	eq_dict[slot_key] = equip_item
	game_state.equip_bag.remove_at(bag_index)
	return true

## 卸下一件装备，退回背包


static func unequip_item(game_state, member_id: String, slot_key: String) -> Dictionary:
	var eq_dict = game_state._ensure_equip_dict(member_id)
	var old = eq_dict.get(slot_key, {})
	if not old.is_empty():
		game_state.equip_bag.append(old)
	eq_dict.erase(slot_key)
	return old

## 往背包中添加一件装备


static func add_equip_to_bag(game_state, equip_dict: Dictionary) -> void:
	game_state.equip_bag.append(equip_dict)

## 获取某个角色某个槽位的装备


static func get_equipment(game_state, member_id: String, slot_key: String) -> Dictionary:
	var eq_dict = game_state.player_equipment.get(member_id, {})
	if eq_dict is Dictionary:
		return eq_dict.get(slot_key, {})
	return {}

## 某个角色全套装备属性合计


static func get_equipment_stats(game_state, member_id: String) -> Dictionary:
	var eq_dict = game_state.player_equipment.get(member_id, {})
	if eq_dict is Dictionary:
		return EquipData.calc_full_stats(eq_dict)
	return {}

## 生成随机装备（测试用）


static func generate_random_equip(game_state, slot: EquipData.SlotType = EquipData.SlotType.WEAPON,
		level: int = 1) -> Dictionary:
	return EquipData.create_equip(slot, level)


# ══════════════════════════════════════════════
# 命名装备库（TCP 图片对应的固定装备）
# ══════════════════════════════════════════════


static func _init_equip_db(game_state) -> void:
	# 命名装备全部在 Script/Data/EquipDB.gd 注册
	game_state.EquipDB.register_all()
## 测试用：把天赋树（Component/TalentTree.tscn）里所有天赋设为满级


