extends RefCounted
## GameData 统一入口委托的独立业务模块；运行状态由 facade 显式传入。

static func get_party_member(game_state, member_id: String) -> CharacterStats:
	return game_state.party_db.get(member_id, null)


static func get_full_party(game_state) -> Array:
	return game_state.party_db.values()


## 按名字添加队员（从 CharacterDB.CHARACTER_DB 查数据，找不到则用参数自定义）


static func add_party_by_name(game_state, p_name: String, p_class: String = "", p_role: String = "",
	p_elem: String = "", p_level: int = 1, p_was: String = "") -> void:
	# 先从数据库查

	if game_state.teamIsFull():
		return
		
	for mid in CharacterDB.CHARACTER_DB:
		if CharacterDB.CHARACTER_DB[mid].name == p_name:
			if game_state.party_db.has(mid):
				return  # 已在队
			var dd: Dictionary = CharacterDB.CHARACTER_DB[mid].duplicate()
			game_state._add_member(mid, dd)
			if p_level > game_state.party_db[mid].level:
				game_state._apply_growth_range(game_state.party_db[mid], game_state.party_db[mid].level, p_level)
				game_state.party_db[mid].level = p_level
			game_state.refresh_level_achievements()
			game_state.party_order.append(mid)
			return
	# 没找到 → 给默认数据

	var mid = p_name.to_lower().replace(" ", "_")
	if game_state.party_db.has(mid):
		
		return
	var dd = {
		"name": p_name, "class": p_class if p_class else "剑修",
		"elem": p_elem if p_elem else "金", "role": p_role if p_role else "攻",
		"hp": 120, "mp": 60, "atk": 25, "matk": 15, "def": 10, "mdef": 8, "spd": 12,
		"crit": 0.12, "crit_mult": 1.5,
		"was_base_path": p_was,
		"skills": ["普通攻击"],
	}
	print(123)
	game_state._add_member(mid, dd)
	if p_level > 1:
		game_state._apply_growth_range(game_state.party_db[mid], game_state.party_db[mid].level, p_level)
		game_state.party_db[mid].level = p_level
	game_state.party_order.append(mid)


## 按 member_id 移除队员，永久角色数据仍保留在 character_roster


static func remove_party_member(game_state, member_id: String) -> void:
	if game_state.party_db.has(member_id) and game_state.party_db[member_id].traits.has("废物"):
		game_state.party_db.erase(member_id)
		game_state.party_order.erase(member_id)
		return
	game_state.party_db.erase(member_id)
	game_state.party_order.erase(member_id)

## 按等级范围随机返回怪物 ID（随机遇敌用）
## 按等级范围随机返回怪物 ID（随机遇敌用）


static func unlock_skill(game_state, member_id: String, skill_id: String) -> void:
	if not game_state.skill_library.has(member_id):
		game_state.skill_library[member_id] = []
	if skill_id not in game_state.skill_library[member_id]:
		game_state.skill_library[member_id].append(skill_id)
		# 也写入 party_db 确保战斗时加载（支持大小写容错）
		var db_id = member_id
		if not game_state.party_db.has(db_id):
			for k in game_state.party_db:
				if k.to_lower() == member_id.to_lower():
					db_id = k
					break
		if game_state.party_db.has(db_id):
			var mb = game_state.party_db[db_id]
			if skill_id not in mb.skill_ids:
				mb.skill_ids.append(skill_id)
	else:
		print("[技能] %s 已掌握 %s，跳过" % [member_id, skill_id])


## 检查角色是否拥有某技能（初始技能 + 技能库）


static func has_skill(game_state, member_id: String, skill_id: String) -> bool:
	return skill_id in get_all_skills(game_state, member_id)


## 获取角色所有技能（初始 + 技能库）


static func get_all_skills(game_state, member_id: String) -> Array[String]:
	var result: Array[String] = []
	var member = game_state.party_db.get(member_id)
	if member:
		result.append_array(member.skill_ids)
		# 已有存档同样按等级学习表补齐可用技能，不将新技能另设为固有技能。
		for entry in SkillDB.SKILL_LEARN_DB.get(member_id, []):
			if entry.level > member.level: continue
			for sid in entry.skills:
				if sid not in result: result.append(sid)
	# 固有技能从角色定义读取，新增技能也能直接用于已有存档。
	if member:
		for sid in CharacterDB.CHARACTER_DB.get(member_id, {}).get("innate_skills", []):
			if sid not in result: result.append(sid)
	var extra = game_state.skill_library.get(member_id, [])
	for sid in extra:
		if sid not in result:
			result.append(sid)
	return result


## 获取可学习的技能列表（已有技能的补集）


static func get_learnable_skills(game_state, member_id: String) -> Array[String]:
	var known = game_state.get_all_skills(member_id)
	var result: Array[String] = []
	for sid in SkillManager.list_all_skills():
		if sid not in known:
			result.append(sid)
	return result


## 调试用：查看队伍当前状态
## 在编辑器输出面板调用：GameData.debug_party()


static func _init_party(game_state) -> void:
	game_state.party_db.clear()
	game_state.party_order.clear()
	game_state.character_roster.clear()
	for mid in CharacterDB.selectable_ids():
		game_state.character_roster[mid] = game_state._create_member_stats(mid, CharacterDB.CHARACTER_DB[mid])
	game_state.refresh_level_achievements()

## 完整角色名册与当前队伍分开存储，队员始终引用名册中的同一对象。


static func _restore_character_roster(game_state, data: Dictionary) -> void:
	game_state.party_db.clear()
	game_state.character_roster.clear()
	var saved_characters: Dictionary = data.get("characters", {})
	for mid in CharacterDB.CHARACTER_DB:
		if not CharacterDB.CHARACTER_DB[mid].get("selectable", true) and not saved_characters.has(mid): continue
		var stats = game_state._create_member_stats(mid, CharacterDB.CHARACTER_DB[mid])
		if saved_characters.has(mid): stats.load_from_dict(saved_characters[mid])
		game_state.character_roster[mid] = stats
	for mid in saved_characters:
		if not game_state.character_roster.has(mid):
			var stats = CharacterStats.new()
			stats.load_from_dict(saved_characters[mid])
			game_state.character_roster[mid] = stats
	for mid in data.get("party_order", []):
		if game_state.character_roster.has(mid):
			game_state.party_db[mid] = game_state.character_roster[mid]


## 按成长系数把 s 的面板属性从 from_level 补到 to_level（每级加成与 _level_up_member 一致；
## 不含能力点/经验/技能——技能与能力点在入队时已按最终等级另行处理）


static func _apply_growth_range(game_state, s: CharacterStats, from_level: int, to_level: int) -> void:
	var steps = to_level - from_level
	if steps <= 0:
		return
	s.max_hp         += s.hp_growth * steps
	s.max_mp         += s.mp_growth * steps
	s.attack         += s.atk_growth * steps
	s.magic_attack   += s.matk_growth * steps
	s.defense        += s.def_growth * steps
	s.magic_defense  += s.mdef_growth * steps
	s.speed          += s.speed_growth * steps


static func _add_member(game_state, member_id: String, d: Dictionary) -> void:
	if member_id in CharacterDB.CHARACTER_DB:
		if not game_state.character_roster.has(member_id):
			game_state.character_roster[member_id] = game_state._create_member_stats(member_id, d)
		game_state.party_db[member_id] = game_state.character_roster[member_id]
	else:
		game_state.party_db[member_id] = game_state._create_member_stats(member_id, d)
	game_state.refresh_level_achievements()


static func _create_member_stats(game_state, member_id: String, d: Dictionary) -> CharacterStats:
	var s = CharacterStats.new()
	s.character_name  = d.name;   s.character_class = d.class
	s.en_name         = d.get("en_name", "")
	s.max_hp          = d.hp;     s.max_mp          = d.mp
	s.attack          = d.atk;    s.magic_attack    = d.matk
	s.defense         = d.def;    s.magic_defense   = d.mdef
	s.speed           = d.spd;    s.level           = d.get("lv", 1)   # 入队初始等级：读 CharacterDB 条目的 "lv"（缺省 1）
	s.potential_left  = s.level * 5  # 初始能力点池（1 级 5 点，之后每级 +5）
	s.exp_to_next     = CharacterStats.calc_exp_to_next(s.level)
	s.crit_mult       = d.get("crit_mult", 1.5)
	s.luck            = d.get("luck", 0)
	s.was_base_path   = d.get("was_base_path", "")
	s.was_direction   = d.get("was_direction", 2)  # 主角团默认朝左上角
	s.portrait_path   = d.get("portrait_path", "")
	s.portrait_offset = d.get("portrait_offset", Vector2.ZERO)
	s.team_offset     = d.get("team_offset", Vector2.ZERO)
	s.use_png         = d.get("use_png", false)
	# 成长资质
	s.hp_growth       = d.get("hp_g", 15)
	s.mp_growth       = d.get("mp_g", 8)
	s.atk_growth      = d.get("atk_g", 4)
	s.def_growth      = d.get("def_g", 2)
	s.speed_growth    = d.get("spd_g", 1)
	s.matk_growth     = d.get("matk_g", 3)
	s.mdef_growth     = d.get("mdef_g", 1)
	s.attack_sound_path = d.get("attack_sound", "")
	s.cast_sound_path   = d.get("cast_sound", "")
	s.is_ranged         = d.get("ranged", false)
	# 五行和定位
	s.element = game_state._parse_element(d.get("elem", "金"))
	s.role    = game_state._parse_role(d.get("role", "攻"))
	s.skill_ids       = game_state._get_initial_skills(member_id, d)
	s.traits          = d.get("traits", {})
	# 初始等级 >1：按成长系数补齐 1→level 的面板成长（与逐级升级成长一致）
	game_state._apply_growth_range(s, 1, s.level)
	return s


## 从字符串解析五行枚举


static func _parse_element(game_state, s: String) -> CharacterStats.Element:
	match s:
		"无": return CharacterStats.Element.NONE
		"木": return CharacterStats.Element.WOOD
		"水": return CharacterStats.Element.WATER
		"火": return CharacterStats.Element.FIRE
		"土": return CharacterStats.Element.EARTH
		_:    return CharacterStats.Element.METAL


## 从字符串解析定位枚举


static func _parse_role(game_state, s: String) -> int:
	var result = 0
	for ch in s:
		match ch:
			"攻": result |= CharacterStats.Role.ATTACK
			"辅": result |= CharacterStats.Role.SUPPORT
			"召": result |= CharacterStats.Role.SUMMON
			"护": result |= CharacterStats.Role.GUARD
			_ :   result |= CharacterStats.Role.MAIN
	return result if result != 0 else CharacterStats.Role.MAIN

# ══════════════════════════════════════════════
# 经验与升级（永久存档）
# ══════════════════════════════════════════════

## 给玩家角色增加经验（永久存档），返回是否升级


static func gain_exp(game_state, member_id: String, amount: int) -> bool:
	var s = game_state.party_db.get(member_id)
	if s == null:
		return false
	s.exp += amount
	if s.exp >= s.exp_to_next:
		var levels_gained = game_state._level_up_member(s)
		return levels_gained > 0
	return false

## 洗髓丹：返还该角色全部已分配的能力点，返回返还点数（0 = 无可返还）


static func refund_ability_points(game_state, member_id: String) -> int:
	var s = game_state.party_db.get(member_id)
	if s == null: return 0
	var total = s.alloc_hp + s.alloc_mp + s.alloc_atk + s.alloc_def + s.alloc_spd + s.alloc_magic
	if total <= 0: return 0
	s.max_hp = maxi(s.max_hp - s.alloc_hp, 1)   # 魔力不再加气血（与加点一致）
	s.max_mp = maxi(s.max_mp - (s.alloc_mp + s.alloc_magic), 0)
	s.attack = maxi(s.attack - s.alloc_atk, 1)
	s.defense = maxi(s.defense - s.alloc_def, 0)
	s.speed = maxi(s.speed - s.alloc_spd, 1)
	s.magic_attack = maxi(s.magic_attack - s.alloc_magic, 0)
	s.potential_left += total
	s.alloc_hp = 0; s.alloc_mp = 0; s.alloc_atk = 0
	s.alloc_def = 0; s.alloc_spd = 0; s.alloc_magic = 0
	return total

## 根据 SkillDB.SKILL_LEARN_DB 获取角色初始技能（包含≤等级的所有技能）


static func _get_initial_skills(game_state, member_id: String, d: Dictionary) -> Array[String]:
	var table = SkillDB.SKILL_LEARN_DB.get(member_id)
	if table == null:
		var fallback: Array[String] = []
		var raw = d.get("skills", [])
		for s in raw:
			fallback.append(str(s))
		if fallback.is_empty():
			fallback = ["普通攻击"]
		return fallback
	var start_lv = d.get("lv", 1)
	var result: Array[String] = []
	for entry in table:
		if entry.level <= start_lv:
			for sid in entry.skills:
				if sid not in result:
					result.append(sid)
	if result.is_empty():
		result = ["普通攻击"]
	return result


static func _level_up_member(game_state, s: CharacterStats) -> int:
	var gained = 0
	while s.exp_to_next > 0 and s.exp >= s.exp_to_next:
		s.exp -= s.exp_to_next
		s.level += 1
		s.potential_left += 5  # 每级 +5 能力点
		s.exp_to_next = CharacterStats.calc_exp_to_next(s.level)
		s.max_hp      += s.hp_growth
		s.max_mp      += s.mp_growth
		s.attack      += s.atk_growth
		s.magic_attack += s.matk_growth
		s.defense     += s.def_growth
		s.magic_defense += s.mdef_growth
		s.speed       += s.speed_growth
		# 检查技能学习
		if "member_id" in s and not s.member_id.is_empty():
			var learn_table = SkillDB.SKILL_LEARN_DB.get(s.member_id, [])
			for entry in learn_table:
				if entry.level == s.level:
					for sid in entry.skills:
						if sid not in s.skill_ids:
							s.skill_ids.append(sid)
							print("%s 学会了 %s！" % [s.character_name, sid])
		gained += 1
	game_state.refresh_level_achievements()
	game_state.refresh_attribute_achievements()
	return gained


# ══════════════════════════════════════════════
# 背包
# ══════════════════════════════════════════════


static func teamIsFull(game_state):
	if game_state.party_db.size() > 4 and !game_state.has_talent("duoduoyishan"):
		return true
