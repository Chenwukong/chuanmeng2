extends RefCounted
## 调试入口：反复执行只补齐内容，不累乘角色成长。
static func enable(data) -> void:
	data.debug_cheats_enabled = true
	data.player_gold = data.DEBUG_GOLD
	data.gold = data.DEBUG_GOLD
	var all_skills: Array[String] = []
	for id in preload("res://Script/Data/SkillDB.gd").SKILL_DB: all_skills.append(str(id))
	for id in data.character_roster:
		var stats = data.character_roster[id]
		var levels := maxi(0, 100 - int(stats.level))
		data._apply_growth_range(stats, stats.level, maxi(100, stats.level))
		stats.potential_left += levels * 5
		stats.level = maxi(100, stats.level)
		stats.exp = 0
		stats.exp_to_next = CharacterStats.calc_exp_to_next(stats.level)
		stats.saved_hp = stats.max_hp
		stats.saved_mp = stats.max_mp
		stats.skill_ids.assign(all_skills)
		data.skill_library[id] = all_skills.duplicate()
	data._debug_unlock_all_talents()
	data._debug_add_all_equips()
	# 每种材料保留4份实体，满足四槽打造；无限模式的消费入口均不扣除。
	for id in MaterialDB.MATERIAL_DB:
		var material: Dictionary = data.get_material(id)
		var count := 0
		for owned in data.material_bag:
			if owned.get("name", "") == material.get("name", ""): count += 1
		for i in maxi(0, 4 - count): data.material_bag.append(material.duplicate(true))
	data.refresh_level_achievements()
	data.refresh_attribute_achievements()
	data.achievements_changed.emit()
	data.request_auto_save()
