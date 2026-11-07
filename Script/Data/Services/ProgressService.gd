extends RefCounted
## GameData 统一入口委托的独立业务模块；运行状态由 facade 显式传入。

static func refresh_level_achievements(game_state) -> void:
	var changed = false
	for entry in game_state.AchievementDB.ENTRIES:
		if not entry.get("repeat_per_character", false): continue
		var metric: String = entry.metric
		var required_level = game_state.AchievementDB.required_level(entry)
		var qualified: Array = game_state.achievement_level_ids.get(metric, [])
		for mid in game_state.character_roster:
			if mid in CharacterDB.selectable_ids() and game_state.character_roster[mid].level >= required_level and mid not in qualified:
				qualified.append(mid)
				changed = true
		game_state.achievement_level_ids[metric] = qualified
		game_state.achievement_stats[metric] = qualified.size()
	if changed: game_state.achievements_changed.emit()


static func get_achievement_state(game_state, entry: Dictionary) -> Dictionary:
	var repeated: bool = entry.get("repeat_per_character", false)
	var limit: int = CharacterDB.selectable_ids().size() if repeated else 1
	var progress = int(game_state.achievement_stats.get(entry.metric, 0))
	var earned = mini(progress / maxi(int(entry.target), 1), limit)
	var claims: int = int(game_state.achievement_claim_counts.get(entry.id, 0)) if repeated else (1 if entry.id in game_state.achievement_claimed else 0)
	return {"progress": progress, "limit": limit, "claims": claims,
		"available": maxi(0, earned - claims), "exhausted": claims >= limit,
		"reached": earned > 0, "repeated": repeated}

## 记录任意可选角色的永久属性历史最高值，洗点不会撤销已达成记录。


static func refresh_attribute_achievements(game_state) -> void:
	var changed = false
	const FIELDS = ["max_hp", "attack", "magic_attack", "defense", "speed"]
	for entry in game_state.AchievementDB.ENTRIES:
		if not entry.has("stat_field"): continue
		var field: String = entry.stat_field
		if field not in FIELDS: continue
		var metric: String = entry.metric
		var previous = int(game_state.achievement_stats.get(metric, 0))
		var peak = previous
		for stats in game_state.character_roster.values(): peak = maxi(peak, int(stats.get(field)))
		if peak > previous:
			game_state.achievement_stats[metric] = peak
			changed = true
	if changed: game_state.achievements_changed.emit()

## 记录实际完成的武器强化等级，出售或卸下不会撤销达成。


static func record_weapon_upgrade(game_state, equipment: Dictionary) -> void:
	if int(equipment.get("slot", -1)) != EquipData.SlotType.WEAPON: return
	var level = int(equipment.get("_build_level", 0))
	if level <= int(game_state.achievement_stats.get("weapon_upgrade_peak", 0)): return
	game_state.achievement_stats["weapon_upgrade_peak"] = level
	game_state.achievements_changed.emit()

## 兼容已有背包和已穿戴的满级武器。


static func refresh_equipment_achievements(game_state) -> void:
	for equipment in game_state.equip_bag: game_state.record_weapon_upgrade(equipment)
	for slots in game_state.player_equipment.values():
		if not slots is Dictionary: continue
		for equipment in slots.values():
			if equipment is Dictionary: game_state.record_weapon_upgrade(equipment)


static func record_walk_distance(game_state, distance: float) -> void:
	if distance <= 0.0 or not is_finite(distance): return
	game_state.achievement_step_remainder += distance
	var steps = int(game_state.achievement_step_remainder / game_state.AchievementDB.PIXELS_PER_STEP)
	if steps > 0:
		game_state.achievement_step_remainder -= steps * game_state.AchievementDB.PIXELS_PER_STEP
		game_state.add_achievement_progress("steps", steps)

## 其他系统可调用此入口增加累计统计。


static func add_achievement_progress(game_state, metric: String, amount: int = 1) -> void:
	if amount <= 0: return
	game_state.achievement_stats[metric] = int(game_state.achievement_stats.get(metric, 0)) + amount
	game_state.achievements_changed.emit()


static func claim_achievement(game_state, id: String) -> bool:
	game_state.refresh_level_achievements()
	game_state.refresh_equipment_achievements()
	game_state.refresh_attribute_achievements()
	for entry in game_state.AchievementDB.ENTRIES:
		if entry.id != id: continue
		var state = game_state.get_achievement_state(entry)
		if state.available <= 0: return false
		for reward in entry.rewards:
			if not reward.type in game_state.AchievementDB.REWARD_NAMES or int(reward.amount) <= 0:
				return false
		for reward in entry.rewards:
			if reward.type == "item":
				var item_id: String = reward.get("item_id", "")
				if not game_state.item_db.has(item_id) or game_state.player_inventory == null: return false
				if game_state.player_inventory.get_count(item_id) + int(reward.amount) > game_state.item_db[item_id].max_stack: return false
		if state.repeated:
			game_state.achievement_claim_counts[id] = int(state.claims) + 1
		else:
			game_state.achievement_claimed.append(id)
		var received: PackedStringArray = []
		for reward in entry.rewards:
			match reward.type:
				"all_potential":
					for stats in game_state.character_roster.values(): stats.potential_left += int(reward.amount)
					received.append("全体可选角色各 +%d 可分配属性点" % int(reward.amount))
				"talent_points":
					game_state.talent_points += int(reward.amount)
					received.append("天赋点 +%d" % int(reward.amount))
				"gold":
					var gained = game_state.add_gold(int(reward.amount))
					received.append("金币 +%d" % gained)
				"item":
					var item: ItemData = game_state.item_db[reward.item_id]
					game_state.player_inventory.add_item(item, int(reward.amount))
					received.append("%s × %d" % [item.item_name, int(reward.amount)])
					if item.passive_gold_bonus > 0:
						received.append("背包被动已生效：全部金币收入 +%d%%" % item.passive_gold_bonus)
		game_state.achievements_changed.emit()
		var message: String = "「%s」\n%s" % [entry.name, "、".join(received)]
		if state.repeated:
			message += "\n已领取 %d/%d 次" % [int(state.claims) + 1, int(state.limit)]
		game_state.notify_achievement("奖励已领取", message, "claimed")
		return true
	return false


## 游戏全局数据（存档用）


static func accept_bounty(game_state, bounty_id: String) -> void:
	if bounty_id in game_state.completed_bounty_ids:
		return
	game_state.active_bounties[bounty_id] = { "state": "accepted", "claimed": false }

## 放弃一个悬赏任务


static func abandon_bounty(game_state, bounty_id: String) -> void:
	game_state.active_bounties.erase(bounty_id)

## 检查任务是否已被接受或完成


static func is_bounty_active(game_state, bounty_id: String) -> bool:
	return bounty_id in game_state.active_bounties


static func is_bounty_completed(game_state, bounty_id: String) -> bool:
	return bounty_id in game_state.completed_bounty_ids

## 检查背包中是否有足够任务道具


static func check_bounty_items(game_state, item_id: String, count: int) -> bool:
	return game_state.player_inventory.has_item(item_id, count)

## 扣除任务道具


static func consume_bounty_items(game_state, item_id: String, count: int) -> bool:
	return game_state.player_inventory.remove_item(item_id, count)

## 装备提供的金币收益倍率（所有角色已穿装备的 gold_boost 之和；1.0 = 无加成）


static func get_gold_multiplier(game_state) -> float:
	var total: int = 0
	for mid in game_state.player_equipment:
		var eq_dict: Dictionary = game_state.player_equipment.get(mid, {})
		if not eq_dict is Dictionary:
			continue
		for slot_key in eq_dict:
			var item = eq_dict[slot_key]
			if item is Dictionary:
				total += int(item.get("gold_boost", 0))
	if game_state.player_inventory:
		for slot in game_state.player_inventory.get_all_items():
			if int(slot.count) > 0:
				total += int(slot.data.passive_gold_bonus)
	return 1.0 + float(total) / 100.0


## 发放金币（自动应用装备金币加成），返回实际到帐数


static func add_gold(game_state, amount: int) -> int:
	if amount <= 0: return 0
	var gained: int = int(round(float(amount) * game_state.get_gold_multiplier()))
	game_state.player_gold += gained
	game_state.gold += gained  # 同步全局 gold 字段
	return gained


## 发放金币奖励


static func give_bounty_reward(game_state, amount: int) -> void:
	game_state.add_gold(amount)

## 标记任务为已完成（不再出现）


static func complete_bounty(game_state, bounty_id: String) -> void:
	game_state.active_bounties.erase(bounty_id)
	if bounty_id not in game_state.completed_bounty_ids:
		game_state.completed_bounty_ids.append(bounty_id)

# ══════════════════════════════════════════════
# 技能注册 & 技能库
# ══════════════════════════════════════════════


