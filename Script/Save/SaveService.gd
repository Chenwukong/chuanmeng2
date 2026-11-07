extends RefCounted
const SCHEMA_VERSION := 4
## GameData 统一入口委托的独立业务模块；运行状态由 facade 显式传入。

static func save_game(game_state, slot: int = 0) -> bool:
	var path = "user://save_%d.json" % slot if slot > 0 else game_state.SAVE_PATH
	var data := serialize_state(game_state)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("存档失败: %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	var error := file.get_error()
	file.close()
	if error != OK:
		push_error("存档写入失败: %s" % path)
		return false
	print("[存档] 已保存到 %s" % path)
	return true


## 读档


static func load_game(game_state, slot: int = 0) -> bool:
	var path = "user://save_%d.json" % slot if slot > 0 else game_state.SAVE_PATH
	if not FileAccess.file_exists(path):
		print("[存档] 存档不存在: %s" % path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		push_error("[存档] JSON 解析失败")
		return false

	if not json.data is Dictionary: return false
	return restore_state(game_state, json.data)


static func delete_save(game_state, slot: int = 0) -> void:
	var path = "user://save_%d.json" % slot if slot > 0 else game_state.SAVE_PATH
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[存档] 已删除 %s" % path)


## 存档列表


static func list_saves(game_state) -> Array:
	var out: Array = []
	var dir = DirAccess.open("user://")
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var name = dir.get_next()
		if name == "": break
		if name.begins_with("save_") and name.ends_with(".json"):
			out.append(name)
	dir.list_dir_end()
	out.sort()
	return out


static func _serialize_dialogue_indexes(game_state) -> Dictionary:
	return game_state.dialogue_progress.duplicate(true)


static func _restore_dialogue_indexes(game_state, data: Dictionary) -> void:
	game_state.dialogue_progress = {}
	for key in data:
		game_state.dialogue_progress[game_state.DialogueDatabase.canonical_id(str(key))] = maxi(0, int(data[key]))
	# 兼容上一版按条件页保存的进度，以及最早的 NPC index 存档。
	for npc_name in game_state.DialogueDatabase.LEGACY_PROGRESS_FLAGS:
		var id: String = game_state.DialogueDatabase.canonical_id(npc_name)
		var flag: String = game_state.DialogueDatabase.LEGACY_PROGRESS_FLAGS[npc_name]
		if not game_state.dialogue_progress.has(id) and game_state.game_flags.get(flag, false):
			game_state.dialogue_progress[id] = 1
	for old_flag in game_state.DialogueDatabase.FLAG_ALIASES:
		var new_flag: String = game_state.DialogueDatabase.FLAG_ALIASES[old_flag]
		if not game_state.game_flags.has(new_flag) and game_state.game_flags.has(old_flag):
			game_state.game_flags[new_flag] = game_state.game_flags[old_flag]

	# 上一版试炼胜利 flag 迁移为段落解锁；尊重新档显式保存的锁定值。
	var mech_locks: Dictionary = game_state.dialogue_locks.get("方寸山_机关人", {})
	# 修复旧配置中插入永久日常段后，胜利分支错误解锁日常段的存档。
	# 该段已移回 waiting，保留已有胜利解锁，不要求玩家再次挑战。
	if mech_locks.has("日常交谈") and mech_locks["日常交谈"] == false:
		mech_locks["通过试炼"] = false
		mech_locks.erase("日常交谈")
		game_state.dialogue_locks["方寸山_机关人"] = mech_locks
	if int(game_state.dialogue_progress.get("方寸山_机关人", 0)) > 1:
		game_state.dialogue_progress["方寸山_机关人"] = 1
	if not mech_locks.has("通过试炼") and game_state.game_flags.get("机关人_试炼通过", false):
		mech_locks["通过试炼"] = false
		game_state.dialogue_locks["方寸山_机关人"] = mech_locks


static func _pet_to_dict(game_state, p: PetData) -> Dictionary:
	return {
		"enemy": p.enemy_name, "name": p.character_name,
		"lv": p.level, "apt": p.aptitude,
		"hp": p.max_hp, "mp": p.max_mp,
		"atk": p.attack, "matk": p.magic_attack,
		"def": p.defense, "mdef": p.magic_defense,
		"spd": p.speed, "skills": p.skill_ids,
		"was": p.was_base_path, "dev": p.devour_count,
		"books": p.book_skills,
	}


static func _pet_from_dict(game_state, d: Dictionary) -> PetData:
	var p = PetData.new()
	p.enemy_name = d.get("enemy", ""); p.character_name = d.get("name", "")
	p.level = d.get("lv", 1); p.aptitude = d.get("apt", PetData.Aptitude.丁)
	p.max_hp = d.get("hp", 100); p.max_mp = d.get("mp", 50)
	p.attack = d.get("atk", 20); p.magic_attack = d.get("matk", 15)
	p.defense = d.get("def", 10); p.magic_defense = d.get("mdef", 8)
	p.speed = d.get("spd", 10)
	var d_skills: Array = d.get("skills", [])
	p.skill_ids.clear()
	p.skill_ids.assign(d_skills)
	p.was_base_path = d.get("was", "")
	p.devour_count = d.get("dev", 0)
	var d_books: Array = d.get("books", [])
	p.book_skills.clear()
	p.book_skills.assign(d_books)
	return p


## 删除存档


static func serialize_state(game_state) -> Dictionary:
	game_state.refresh_level_achievements()
	game_state.refresh_equipment_achievements()
	game_state.refresh_attribute_achievements()

	var data = {
		"version": SCHEMA_VERSION,
		"difficulty": game_state.difficulty,
		"debug_cheats_enabled": game_state.debug_cheats_enabled,
		"character_locks": game_state.character_locks.duplicate(),
		"gold": game_state.gold,
		"talent_points": game_state.talent_points,
		"achievement_stats": game_state.achievement_stats.duplicate(true),
		"achievement_claim_counts": game_state.achievement_claim_counts.duplicate(true),
		"achievement_notified_counts": game_state.achievement_notified_counts.duplicate(true),
		"achievement_level_ids": game_state.achievement_level_ids.duplicate(true),
		"achievement_claimed": game_state.achievement_claimed.duplicate(),
		"achievement_step_remainder": game_state.achievement_step_remainder,
		"talent_ranks": game_state.talent_ranks.duplicate(),
		"game_flags": game_state.game_flags.duplicate(),
		"play_time_sec": game_state.play_time_sec,
		"shichen_idx": game_state.shichen_idx,
		"shichen_accum": game_state.shichen_accum,
		"chapter_id": game_state.chapter_id,
		"scene_path": game_state.current_scene_path,
		"vol_master": GameData.base_vol_master * 100,
		"vol_music":  GameData.base_vol_bgm * 100,
		"vol_sfx":    GameData.base_vol_sfx * 100,
		"party_order": game_state.party_order.duplicate(),
		"pets": {},
		"pet_team": game_state.pet_team.duplicate(),
		"inventory": game_state.player_inventory.serialize() if game_state.player_inventory else {},
		"player_gold": game_state.player_gold,
		"mech_db": {},
		"mech_team": game_state.mech_team.duplicate(),
		"skill_library": game_state.skill_library.duplicate(),
		"active_bounties": game_state.active_bounties.duplicate(),
		"completed_bounty_ids": game_state.completed_bounty_ids.duplicate(),
		"equipment": game_state.player_equipment,
		"equip_bag": game_state.equip_bag,
		"material_bag": game_state.material_bag,
		"dialogue_indexes": game_state._serialize_dialogue_indexes(),
		"dialogue_locks": game_state.dialogue_locks.duplicate(true),
		"disabled_buttons": game_state.disabled_buttons,
		"story_hint": game_state.story_hint,
		"story_map_targets": game_state.story_map_targets.duplicate(true),
	}

	data["characters"] = {}
	for mid in game_state.character_roster:
		data.characters[mid] = game_state.character_roster[mid].save_to_dict()
	for pid in game_state.pet_db:
		data.pets[pid] = game_state._pet_to_dict(game_state.pet_db[pid])
	for mname in game_state.mech_db:
		data.mech_db[mname] = game_state.mech_db[mname].duplicate()

	return data


static func restore_state(game_state, data: Dictionary) -> bool:
	if not is_current_schema(data): return false
	game_state.restore_difficulty(int(data.get("difficulty", 1)))
	game_state.debug_cheats_enabled = bool(data.get("debug_cheats_enabled", false))
	game_state.character_locks = data.get("character_locks", {}).duplicate()
	game_state.character_locks_changed.emit()
	game_state._achievement_notices_suspended = true
	game_state.achievement_notice_queue.clear()
	if is_instance_valid(game_state._achievement_notifications): game_state._achievement_notifications.dismiss_all()
	game_state.achievement_notified_counts = data.get("achievement_notified_counts", {})

	game_state.gold           = data.get("gold", 0)
	game_state.talent_points  = data.get("talent_points", 0)
	game_state.achievement_stats = data.get("achievement_stats", {})
	game_state.achievement_claim_counts = data.get("achievement_claim_counts", {})
	game_state.achievement_level_ids = data.get("achievement_level_ids", {})
	game_state.achievement_claimed = data.get("achievement_claimed", [])
	game_state.achievement_step_remainder = fposmod(float(data.get("achievement_step_remainder", 0.0)), game_state.AchievementDB.PIXELS_PER_STEP)
	game_state.achievements_changed.emit()
	game_state.disabled_buttons = data.get("disabled_buttons", []).duplicate()
	game_state.story_hint = data.get("story_hint", game_state.story_hint)
	game_state.story_map_targets = data.get("story_map_targets", game_state.story_map_targets).duplicate(true)
	# 恢复音量设置
	var v_master = data.get("vol_master", 100.0)
	var v_music = data.get("vol_music", 100.0)
	var v_sfx = data.get("vol_sfx", 100.0)
	if v_master >= 0:
		GameData.base_vol_master = v_master / 100.0
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), -80 if v_master <= 0 else linear_to_db(v_master / 100.0))
	if v_music >= 0:
		GameData.base_vol_bgm = v_music / 100.0
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("BGM"), -80 if v_music <= 0 else linear_to_db(v_music / 100.0))
	if v_sfx >= 0:
		GameData.base_vol_sfx = v_sfx / 100.0
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), -80 if v_sfx <= 0 else linear_to_db(v_sfx / 100.0))
	var d_talents: Dictionary = data.get("talent_ranks", {})
	game_state.talent_ranks = {}
	game_state.talent_ranks.merge(d_talents)
	var d_flags: Dictionary = data.get("game_flags", {})
	game_state.game_flags = {}
	game_state.game_flags.merge(d_flags)
	game_state.play_time_sec  = data.get("play_time_sec", 0)
	game_state.shichen_idx    = data.get("shichen_idx", 10)
	game_state.shichen_accum  = data.get("shichen_accum", 0.0)
	game_state.chapter_id     = data.get("chapter_id", 1)
	game_state.current_scene_path = data.get("scene_path", "res://scenes/MainScene.tscn")
	game_state.dialogue_locks = {}
	for event_id in data.get("dialogue_locks", {}):
		var id: String = game_state.DialogueDatabase.canonical_id(str(event_id))
		game_state.dialogue_locks[id] = data.dialogue_locks[event_id].duplicate(true)
	game_state._restore_dialogue_indexes(data.get("dialogue_indexes", {}))

	game_state._restore_character_roster(data)
	var default_order: Array = game_state.party_db.keys().duplicate()
	game_state.party_order.assign(data.get("party_order", default_order))

	# 恢复背包
	if game_state.player_inventory and data.has("inventory"):
		game_state.player_inventory.deserialize(data.inventory, game_state.item_db)
	
	# 恢复铁甲兽
	game_state._init_mech_pets()
	game_state.player_gold = data.get("player_gold", 5000)
	if data.has("mech_db"):
		for mname in data.mech_db:
			if game_state.mech_db.has(mname):
				var d = data.mech_db[mname]
				game_state.mech_db[mname].level = d.get("level", 1)
				game_state.mech_db[mname].exp = d.get("exp", 0)
				game_state.mech_db[mname].atk = d.get("atk", game_state.mech_db[mname].atk)
				game_state.mech_db[mname].def_ = d.get("def_", game_state.mech_db[mname].def_)
				game_state.mech_db[mname].spd = d.get("spd", game_state.mech_db[mname].spd)
	if data.has("mech_team"):
		var arr: Array = data.mech_team
		game_state.mech_team.clear()
		game_state.mech_team.assign(arr)
	
	# 恢复技能库
	var d_skill: Dictionary = data.get("skill_library", {})
	game_state.skill_library = {}
	game_state.skill_library.merge(d_skill)
	
	# 恢复赏金任务状态
	var d_bounties: Dictionary = data.get("active_bounties", {})
	game_state.active_bounties = {}
	game_state.active_bounties.merge(d_bounties)
	game_state.completed_bounty_ids = data.get("completed_bounty_ids", [])
	# force typed array for completed_bounty_ids
	var cbi: Array = game_state.completed_bounty_ids
	game_state.completed_bounty_ids = []
	game_state.completed_bounty_ids.assign(cbi)

	# 恢复宠物
	game_state.pet_db.clear()
	for pid in data.get("pets", {}):
		game_state.pet_db[pid] = game_state._pet_from_dict(data.pets[pid])
	var raw_pt: Array = data.get("pet_team", [])
	game_state.pet_team.clear()
	game_state.pet_team.assign(raw_pt)
	
	# 恢复装备
	var d_equip: Dictionary = data.get("equipment", {})
	game_state.player_equipment = {}
	game_state.player_equipment.merge(d_equip)
	var raw_bag: Array = data.get("equip_bag", [])
	game_state.equip_bag.clear()
	game_state.equip_bag.assign(raw_bag)
	var raw_mat: Array = data.get("material_bag", [])
	game_state.material_bag.clear()
	game_state.material_bag.assign(raw_mat)
	for pid in game_state.pet_team.duplicate():
		if not game_state.pet_db.has(pid):
			game_state.pet_team.erase(pid)  # 清理不存在的宠物

	game_state.refresh_level_achievements()
	game_state.refresh_equipment_achievements()
	game_state.refresh_attribute_achievements()
	# 载入时已有的达成通过按钮待领数提示，不重播历史弹窗。
	for entry in game_state.AchievementDB.ENTRIES:
		var state = game_state.get_achievement_state(entry)
		game_state.achievement_notified_counts[entry.id] = int(state.claims) + int(state.available)
	game_state._achievement_notices_suspended = false
	game_state.achievements_changed.emit()
	return true
static func is_current_schema(data: Dictionary) -> bool:
	return int(data.get("version", -1)) == SCHEMA_VERSION and data.get("characters") is Dictionary and data.get("party_order") is Array
