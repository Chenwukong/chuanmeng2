# GameData.gd
# Autoload 单例 - 注册所有技能、道具数据，初始化玩家存档
# 项目设置 → Autoload 中添加，名称设为 "GameData"
extends Node

var item_db:  Dictionary = {}  # { item_id: ItemData }
var party_db: Dictionary = {}  # { member_id: CharacterStats }
var party_order: Array[String] = []  # 队伍出场顺序
var world_log: RichTextLabel = null   # 战斗外日志（MainScene 注入）
var world_log_text: String = ""       # 日志内容持久化
var pet_db:   Dictionary = {}     # { pet_id: PetData }
var pet_team: Array[String] = []  # 最多6只出战宠物ID
var mech_db:  Dictionary = {}     # { name: { name, was_base_path, level, exp, atk, def_, spd, skills } }
var mech_team: Array[String] = [] # 可召唤的铁甲兽列表
var player_gold: int = 5000
var player_inventory: Inventory

## 装备系统
var player_equipment: Dictionary = {}   # { slot_key: EquipData 字典 }  已穿上的
var equip_bag: Array[Dictionary] = []   # 未穿上的装备列表（在背包中显示）

## 技能库：记录角色额外习得的技能  { member_id: [skill_id, ...] }
var skill_library: Dictionary = {}

## 赏金任务状态
var active_bounties: Dictionary = {}    # { bounty_id: { "state": "accepted"/"completed", "claimed": false } }
var completed_bounty_ids: Array = []    # 已完成/已领取过的 bounty_id 列表

var player_stats: CharacterStats:
	get: return party_db.values()[0] if not party_db.is_empty() else null

var _enemy_db_cache: Dictionary = {}

## 天赋树数据（talent_id → rank）
var talent_ranks: Dictionary = {}
var talent_points: int = 20

## 游戏全局数据（存档用）
var gold: int = 0
var game_flags: Dictionary = {}  # { flag_name: value } 剧情标记等
var play_time_sec: int = 0
var in_battle: bool = false
var ui_blocked: bool = false    # 弹窗打开时暂停地图操作/追踪怪
var current_scene_path: String = ""
var chapter_id: int = 1
var current_locale: String = "zh"  # 当前语言
## 多语言翻译表（JSON 加载，不依赖 Godot 的 tr()）
static var _lang_cache: Dictionary = {}
static var _current_lang: String = "zh"
static func get_lang() -> String: return _current_lang


## 获取翻译 text = _T("KEY")，带 %s/%d 插值
static func _T(key: String) -> String:
	var table: Dictionary = _lang_cache.get(_current_lang, {})
	return table.get(key, key)


## 翻译类型标签（中文 → 根据当前语言查找翻译键）
const _LABEL_TO_KEY: Dictionary = {
	"未知": "SKILL_UNKNOWN",
	"物理攻击": "SKILL_TYPE_PHYSICAL", "法术攻击": "SKILL_TYPE_MAGIC", "治疗": "SKILL_TYPE_HEAL",
	"增益": "SKILL_TYPE_BUFF", "减益": "SKILL_TYPE_DEBUFF", "多段攻击": "SKILL_TYPE_MULTI", "群体攻击": "SKILL_TYPE_AOE",
	"敌方单体": "TARGET_SINGLE_ENEMY", "己方单体": "TARGET_SINGLE_ALLY", "自身": "TARGET_SELF",
	"敌方全体": "TARGET_ALL_ENEMIES", "己方全体": "TARGET_ALL_ALLIES",
	"确认": "BATTLE_CONFIRM",
}
static func _TL(label: String) -> String:
	var key: String = _LABEL_TO_KEY.get(label, "")
	if not key.is_empty():
		return _T(key)
	return label


## 切换语言
static func set_language(lang: String) -> void:
	if lang in ["zh", "en"]:
		_current_lang = lang
		TranslationServer.set_locale(lang)


## 安全检测是否有对话气球（不依赖 MainScene 类型，兼容单独运行场景）
static func is_dialogue_active() -> bool:
	return Engine.get_main_loop().get_nodes_in_group(&"ballon").size() > 0


## 对话数据库：npc_name → { index, entries }
## entries: [{ chapter, title, type: "normal"|"story", once }]
## 文件自动拼为 "res://Dialogue/chapter{chapter}.dialogue"
## 点击 NPC 时取 entries[index]，按 entry.type 选气泡，once 完成后 index+1
var DIALOGUE_DB = {
	"镖头": {
		"index": 0,
		"entries": [
			{ "chapter": 1, "title": "start",    "type": "story",  "once": true  },
			{ "chapter": 1, "title": "d", "type": "normal", "once": false },
		]
	},
	"剑侠客": {
		"index": 0,
		"entries": [
			{ "chapter": 0, "title": "剑侠客",    "type": "team",  "once": false  },
			{ "chapter": 1, "title": "d", "type": "normal", "once": false },
		]
	},
}

signal battle_ended_for_save()

## 暗雷配置：{ 地图名: { "pool": [怪物名], "min": 最少数量, "min_lv": 最低等级, "max_lv": 最高等级 } }

## 快捷施法（Alt+Q）已迁移到 battleUI 的 _quick_skill_per_char
const ENCOUNTER_CONFIG := {
	"东海湾": {
		"pool": ["超级赤焰兽"],
		"min": 3,
	},
}
const ENCOUNTER_INTERVAL := 120.0   # 像素检查间隔
const ENCOUNTER_CHANCE  := 0.1   # 触发概率（1.0 = 100%）

func _ready() -> void:
	_load_languages()
	_register_skills()
	_register_items()
	_init_party()
	_init_inventory()
	_build_enemy_db()
	_init_debug_pets()  # 测试用：8只不同资质宠物
	_init_mech_pets()
	_init_equip_db()
	_debug_equip_belt()  # 测试：穿一件粗腰带
	debug_party()

# ══════════════════════════════════════════════
# 多语言
# ══════════════════════════════════════════════

func _load_languages() -> void:
	for lang in ["zh", "en"]:
		var path := "res://locales/%s.json" % lang
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			var text := f.get_as_text()
			var json := JSON.new()
			if json.parse(text) == OK:
				_lang_cache[lang] = json.data

# ══════════════════════════════════════════════
# 对外接口
# ══════════════════════════════════════════════

## 调试用：查看怪物自动经验计算
## GameData.debug_exp(10)  → 打印 10 级怪物给多少经验
## GameData.debug_exp_table(1, 100)  → 打印 1-100 级经验表
func debug_exp(level: int) -> void:
	var auto = 30 + level * 15
	print("【怪物经验】等级 %d 的怪物：自动经验 = %d" % [level, auto])
	print("  每级需要经验 = %d" % CharacterStats.calc_exp_to_next(level))
	print("  杀同级的怪需要 %d 只才能升级" % ceili(float(CharacterStats.calc_exp_to_next(level)) / float(auto)))

func debug_exp_table(from_lv: int = 1, to_lv: int = 100) -> void:
	var s = "等级\t自动经验\t升级需要\t杀怪数\n"
	for lv in range(from_lv, to_lv + 1):
		var exp_needed = CharacterStats.calc_exp_to_next(lv)
		var monster_exp = 30 + lv * 15
		s += "%d\t%d\t\t%d\t\t%d\n" % [lv, monster_exp, exp_needed, ceili(float(exp_needed) / float(monster_exp))]
	print(s)

func _init_debug_pets() -> void:
	if not pet_db.is_empty(): return
	var row = _enemy_db_cache.get("超级赤焰兽")
	if row == null: return
	var names = ["超级赤焰兽", "赤焰兽","赤焰兽","赤焰兽","赤焰兽"]
	var apts = [PetData.Aptitude.丁, PetData.Aptitude.丙, PetData.Aptitude.乙, PetData.Aptitude.甲, PetData.Aptitude.特, PetData.Aptitude.丁, PetData.Aptitude.丙, PetData.Aptitude.特]
	for i in names.size() - 1:
		var pet = PetData.new()
		pet.character_name = names[i]
		pet.level = 5
		pet.aptitude = apts[i]
		var mul = PetData.APT_GROWTH_MUL[pet.aptitude]
		pet.max_hp = int(row.hp * mul); pet.max_mp = int(row.get("mp", 0) * mul)
		pet.attack = int(row.atk * mul); pet.magic_attack = int(row.get("matk", row.atk) * mul)
		pet.defense = int(row.def * mul); pet.magic_defense = int(row.get("mdef", int(row.def * 0.8)) * mul)
		pet.speed = int(row.spd * mul); pet.skill_ids = ["普通攻击","妖术"]
		pet.was_base_path = row.get("was_base_path", "")
		pet.pet_id = "debug_pet_%d" % i
		pet_db[pet.pet_id] = pet
	pet_team.clear()
	for i in 6:
		pet_team.append("debug_pet_%d" % i)
	print("[宠物] 已生成 %d 只测试宠物，前6只默认上场" % pet_db.size())


func _init_mech_pets() -> void:
	mech_db["机关兽"] = {
		"name": "机关兽", "was_base_path": "res://WAS/机关兽",
		"level": 1, "exp": 0, "atk": 30, "def_": 20, "spd": 8,
		"atk_g": 4, "def_g": 3, "spd_g": 1, "skills": ["普通攻击", "破防击"],
	}
	mech_db["机关鸟"] = {
		"name": "机关鸟", "was_base_path": "res://WAS/机关鸟",
		"level": 1, "exp": 0, "atk": 20, "def_": 8, "spd": 22,
		"atk_g": 3, "def_g": 1, "spd_g": 4, "skills": ["普通攻击", "三连击"],
	}
	mech_team = ["机关兽", "机关鸟"]
	print("[铁甲] 已初始化 %d 只铁甲兽" % mech_db.size())


# ══════════════════════════════════════════════
# 技能库 API
# ══════════════════════════════════════════════

## 解锁技能给指定角色
func unlock_skill(member_id: String, skill_id: String) -> void:
	if not skill_library.has(member_id):
		skill_library[member_id] = []
	if skill_id not in skill_library[member_id]:
		skill_library[member_id].append(skill_id)
		print("[技能] %s 习得 %s" % [member_id, skill_id])
	else:
		print("[技能] %s 已掌握 %s，跳过" % [member_id, skill_id])


## 检查角色是否拥有某技能（初始技能 + 技能库）
func has_skill(member_id: String, skill_id: String) -> bool:
	var member = party_db.get(member_id)
	if member and skill_id in member.skill_ids:
		return true
	var extra = skill_library.get(member_id, [])
	return skill_id in extra


## 获取角色所有技能（初始 + 技能库）
func get_all_skills(member_id: String) -> Array[String]:
	var result: Array[String] = []
	var member = party_db.get(member_id)
	if member:
		result.append_array(member.skill_ids)
	var extra = skill_library.get(member_id, [])
	for sid in extra:
		if sid not in result:
			result.append(sid)
	return result


## 获取可学习的技能列表（已有技能的补集）
func get_learnable_skills(member_id: String) -> Array[String]:
	var known = get_all_skills(member_id)
	var result: Array[String] = []
	for sid in SkillManager.list_all_skills():
		if sid not in known:
			result.append(sid)
	return result


## 调试用：查看队伍当前状态
## 在编辑器输出面板调用：GameData.debug_party()
func debug_party() -> void:
	print("")
	print("===== 队伍状态 =====")
	for mid in party_db:
		var c = party_db[mid]
		print("--- %s (%s) Lv.%d  [%s/%s] ---" % [c.character_name, c.character_class, c.level, CharacterStats.element_name(c.element), CharacterStats.role_name(c.role)])
		print("  HP: %d   MP: %d" % [c.max_hp, c.max_mp])
		print("  ATK: %d  MATK: %d  DEF: %d  MDEF: %d  SPD: %d" % [c.attack, c.magic_attack, c.defense, c.magic_defense, c.speed])
		print("  暴击率: %.0f%%  暴击伤害: %.0f%%" % [c.crit_rate * 100, c.crit_mult * 100])
		print("  经验: %d / %d" % [c.exp, c.exp_to_next])
	print("================")


# ══════════════════════════════════════════════
# 存档系统
# ══════════════════════════════════════════════

func _serialize_dialogue_indexes() -> Dictionary:
	var out := {}
	for npc_name in DIALOGUE_DB:
		out[npc_name] = DIALOGUE_DB[npc_name].get("index", 0)
	return out


func _restore_dialogue_indexes(data: Dictionary) -> void:
	for npc_name in data:
		if DIALOGUE_DB.has(npc_name):
			DIALOGUE_DB[npc_name]["index"] = data[npc_name]


const SAVE_PATH := "user://savegame.json"

## 保存游戏
func save_game(slot: int = 0) -> void:
	var path = "user://save_%d.json" % slot if slot > 0 else SAVE_PATH

	var data := {
		"version": 3,
		"gold": gold,
		"talent_points": talent_points,
		"talent_ranks": talent_ranks.duplicate(),
		"game_flags": game_flags.duplicate(),
		"play_time_sec": play_time_sec,
		"chapter_id": chapter_id,
		"scene_path": current_scene_path,
		"party": {},
		"party_order": party_order.duplicate(),
		"pets": {},
		"pet_team": pet_team.duplicate(),
		"inventory": player_inventory.serialize() if player_inventory else {},
		"player_gold": player_gold,
		"mech_db": {},
		"mech_team": mech_team.duplicate(),
		"skill_library": skill_library.duplicate(),
		"active_bounties": active_bounties.duplicate(),
		"completed_bounty_ids": completed_bounty_ids.duplicate(),
		"equipment": player_equipment,
		"equip_bag": equip_bag,  # 纯字典，直接存
		"dialogue_indexes": _serialize_dialogue_indexes(),
	}

	for mid in party_db:
		data.party[mid] = party_db[mid].save_to_dict()
	for pid in pet_db:
		data.pets[pid] = _pet_to_dict(pet_db[pid])
	for mname in mech_db:
		data.mech_db[mname] = mech_db[mname].duplicate()

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("存档失败: %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("[存档] 已保存到 %s" % path)


## 读档
func load_game(slot: int = 0) -> bool:
	var path = "user://save_%d.json" % slot if slot > 0 else SAVE_PATH
	if not FileAccess.file_exists(path):
		print("[存档] 存档不存在: %s" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK:
		push_error("[存档] JSON 解析失败")
		return false

	var data: Dictionary = json.data

	gold           = data.get("gold", 0)
	talent_points  = data.get("talent_points", 0)
	var d_talents: Dictionary = data.get("talent_ranks", {})
	talent_ranks = {}
	talent_ranks.merge(d_talents)
	var d_flags: Dictionary = data.get("game_flags", {})
	game_flags = {}
	game_flags.merge(d_flags)
	play_time_sec  = data.get("play_time_sec", 0)
	chapter_id     = data.get("chapter_id", 1)
	current_scene_path = data.get("scene_path", "res://scenes/MainScene.tscn")
	_restore_dialogue_indexes(data.get("dialogue_indexes", {}))

	# 恢复队伍
	for mid in data.get("party", {}):
		var s = CharacterStats.new()
		s.load_from_dict(data.party[mid])
		party_db[mid] = s
	var default_order: Array = party_db.keys().duplicate()
	party_order.assign(data.get("party_order", default_order))

	# 恢复背包
	if player_inventory and data.has("inventory"):
		player_inventory.deserialize(data.inventory, item_db)
	
	# 恢复铁甲兽
	_init_mech_pets()
	player_gold = data.get("player_gold", 5000)
	if data.has("mech_db"):
		for mname in data.mech_db:
			if mech_db.has(mname):
				var d = data.mech_db[mname]
				mech_db[mname].level = d.get("level", 1)
				mech_db[mname].exp = d.get("exp", 0)
				mech_db[mname].atk = d.get("atk", mech_db[mname].atk)
				mech_db[mname].def_ = d.get("def_", mech_db[mname].def_)
				mech_db[mname].spd = d.get("spd", mech_db[mname].spd)
	if data.has("mech_team"):
		var arr: Array = data.mech_team
		mech_team.clear()
		mech_team.assign(arr)
	
	# 恢复技能库
	var d_skill: Dictionary = data.get("skill_library", {})
	skill_library = {}
	skill_library.merge(d_skill)
	
	# 恢复赏金任务状态（v3 新增）
	var d_bounties: Dictionary = data.get("active_bounties", {})
	active_bounties = {}
	active_bounties.merge(d_bounties)
	completed_bounty_ids = data.get("completed_bounty_ids", [])
	# force typed array for completed_bounty_ids
	var cbi: Array = completed_bounty_ids
	completed_bounty_ids = []
	completed_bounty_ids.assign(cbi)

	# 恢复宠物
	pet_db.clear()
	for pid in data.get("pets", {}):
		pet_db[pid] = _pet_from_dict(data.pets[pid])
	var raw_pt: Array = data.get("pet_team", [])
	pet_team.clear()
	pet_team.assign(raw_pt)
	
	# 恢复装备
	var d_equip: Dictionary = data.get("equipment", {})
	player_equipment = {}
	player_equipment.merge(d_equip)
	var raw_bag: Array = data.get("equip_bag", [])
	equip_bag.clear()
	equip_bag.assign(raw_bag)
	for pid in pet_team.duplicate():
		if not pet_db.has(pid):
			pet_team.erase(pid)  # 清理不存在的宠物

	print("[存档] 从 %s 读取成功" % path)
	return true


func capture_pet(enemy_name: String, enemy_stats: CharacterStats) -> String:
	var row = _enemy_db_cache.get(enemy_name)
	if row == null: return ""
	var apt = enemy_stats.capture_aptitude
	if apt < 0: apt = PetData.Aptitude.丁
	var pet = PetData.new()
	pet.from_enemy_with_apt(row, enemy_stats.level, apt as PetData.Aptitude)
	pet.pet_id = "pet_%d" % Time.get_unix_time_from_system()
	pet_db[pet.pet_id] = pet
	print("[宠物] 成功捕捉 %s，资质：%s" % [pet.character_name, PetData.apt_name(pet.aptitude)])
	return pet.pet_id

## 获取第一个宠物（召唤用）
func get_first_pet() -> PetData:
	if pet_db.is_empty(): return null
	return pet_db.values()[0]

## 宠物转字典
func _pet_to_dict(p: PetData) -> Dictionary:
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

func _pet_from_dict(d: Dictionary) -> PetData:
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
func delete_save(slot: int = 0) -> void:
	var path = "user://save_%d.json" % slot if slot > 0 else SAVE_PATH
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[存档] 已删除 %s" % path)


## 存档列表
func list_saves() -> Array:
	var out: Array = []
	var dir := DirAccess.open("user://")
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "": break
		if name.begins_with("save_") and name.ends_with(".json"):
			out.append(name)
	dir.list_dir_end()
	out.sort()
	return out


func get_party_member(member_id: String) -> CharacterStats:
	return party_db.get(member_id, null)

func get_full_party() -> Array:
	return party_db.values()


## 按名字添加队员（从 CHARACTER_DB 查数据，找不到则用参数自定义）
func add_party_by_name(p_name: String, p_class: String = "", p_role: String = "",
	p_elem: String = "", p_level: int = 1, p_was: String = "") -> void:
	# 先从数据库查

	for mid in CHARACTER_DB:
		if CHARACTER_DB[mid].name == p_name:
			if party_db.has(mid):
				return  # 已在队
			var dd: Dictionary = CHARACTER_DB[mid].duplicate()
			_add_member(mid, dd)
			if p_level > 1:
				party_db[mid].level = p_level
			party_order.append(mid)
			return
	# 没找到 → 给默认数据

	var mid := p_name.to_lower().replace(" ", "_")
	if party_db.has(mid):
		
		return
	var dd := {
		"name": p_name, "class": p_class if p_class else "剑修",
		"elem": p_elem if p_elem else "金", "role": p_role if p_role else "攻",
		"hp": 120, "mp": 60, "atk": 25, "matk": 15, "def": 10, "mdef": 8, "spd": 12,
		"crit": 0.12, "crit_mult": 1.5,
		"was_base_path": p_was,
		"skills": ["普通攻击"],
	}
	print(123)
	_add_member(mid, dd)
	party_db[mid].level = p_level
	party_order.append(mid)


## 按 member_id 移除队员
func remove_party_member(member_id: String) -> void:
	party_db.erase(member_id)
	party_order.erase(member_id)

## 按等级范围随机返回怪物 ID（随机遇敌用）
## 按等级范围随机返回怪物 ID（随机遇敌用）
func get_random_enemy_id(min_lv: int = 1, max_lv: int = 99) -> String:
	var candidates = ENEMY_DB.filter(func(row): return row.lv >= min_lv and row.lv <= max_lv)
	if candidates.is_empty():
		return ENEMY_DB[0].name
	return candidates[randi() % candidates.size()].name

func create_enemy(enemy_name: String) -> CharacterStats:
	var row = _enemy_db_cache.get(enemy_name)
	if row == null:
		push_error("GameData: 未知怪物 '%s'，使用默认怪物" % enemy_name)
		row = _enemy_db_cache.values()[0]
	var s = CharacterStats.new()
	s.character_name = row.name
	s.max_hp         = row.hp;    s.max_mp        = row.mp
	s.attack         = row.atk
	s.defense        = row.def
	s.speed          = row.spd;   s.level         = row.lv
	s.skill_ids      = row.skills.duplicate()
	s.ai_strategy    = row.get("ai_strategy", "balanced")
	s.magic_attack   = row.get("matk", row.atk)
	s.magic_defense  = row.get("mdef", int(row.def * 0.8))
	s.was_base_path  = row.get("was_base_path", "")
	s.was_direction  = row.get("was_direction", 0)
	s.exp_reward     = row.get("exp", 0)
	s.attack_sound_path = row.get("attack_sound", "")
	s.cast_sound_path   = row.get("cast_sound", "")
	s.rank             = row.get("rank", "")
	s.element = _parse_element(row.get("elem", "金"))
	s.role    = _parse_role(row.get("role", "护"))
	# 进场时随机资质（捕捉时保留）
	s.capture_aptitude = _roll_aptitude(row.get("rank", ""))
	return s


## 进场随机资质
func _roll_aptitude(rank: String) -> int:
	match rank:
		"boss":    return PetData.Aptitude.甲
		"special": return PetData.Aptitude.特
	# 普通: 丁45% 丙30% 乙18% 甲7%
	var r = randi() % 100
	if r < 45:  return PetData.Aptitude.丁
	if r < 75:  return PetData.Aptitude.丙
	if r < 93:  return PetData.Aptitude.乙
	return PetData.Aptitude.甲

# ══════════════════════════════════════════════
# 怪物数据库
# 字段：name, hp, mp, atk, def, spd, lv, skills, rank(可选:普通/boss/特殊), exp(可选), was_base_path(可选), ai_strategy(可选)
# rank: 普通=资质随机丁丙乙, boss=固定甲, 特殊=固定特
# ══════════════════════════════════════════════

const ENEMY_DB = [
	# ── 普通怪 ──
	{ name = "妖狐·赤尾", hp = 90,  mp = 40,  atk = 22, def = 8,  spd = 10, lv = 1, skills = ["普通攻击","妖术","妖气回复"] },
	{ name = "山魈·獠牙",  hp = 110, mp = 30,  atk = 28, def = 12, spd = 9,  lv = 1, skills = ["普通攻击","妖术"] },
	{ name = "厉鬼·幽魂",  hp = 80,  mp = 60,  atk = 20, def = 5,  spd = 14, lv = 2, skills = ["普通攻击","妖术","蛊毒咒"] },
	{ name = "石傀·巨岩",  hp = 160, atk = 32, def = 22, spd = 5,  lv = 3, skills = ["普通攻击","破防击"] },
	{ name = "火鸦·灼羽",  hp = 70,  mp = 80,  atk = 18, def = 6,  spd = 16, lv = 3, skills = ["普通攻击","妖术","灼焰术"] },
	{ name = "幽蛛·织网",  hp = 100, mp = 50,  atk = 24, def = 10, spd = 12, lv = 4, skills = ["普通攻击","蛊毒咒","妖术"] },
	{ name = "风狼·疾牙",  hp = 120, mp = 30,  atk = 30, def = 8,  spd = 18, lv = 4, skills = ["普通攻击","三连击"] },
	{ name = "寒魄·幽灵",  hp = 90,  mp = 90,  atk = 22, def = 8,  spd = 13, lv = 5, skills = ["普通攻击","冰封诀","妖术"] },
	# ── 精英怪 ──
	{ name = "九尾妖狐",    hp = 200, mp = 80,  atk = 35, def = 15, spd = 12, lv = 6, skills = ["普通攻击","妖术","妖气回复","蛊毒咒"] },
	{ name = "魔将·煞星",  hp = 250, mp = 60,  atk = 42, def = 20, spd = 10, lv = 7, skills = ["普通攻击","三连击","破防击","护体真气"] },
	{ name = "骷髅王",      hp = 220, mp = 70,  atk = 38, def = 18, spd = 11, lv = 7, skills = ["普通攻击","妖术","破防击"] },
	{ name = "熔岩魔人",    hp = 280, mp = 50,  atk = 45, def = 25, spd = 7,  lv = 8, skills = ["普通攻击","灼焰术","破防击"] },
	# ── Boss（捕捉固定甲级）──
	{ name = "九幽魔王",    hp = 400, mp = 120, atk = 50, def = 22, spd = 11, lv = 10, rank = "boss", skills = ["普通攻击","妖术","妖气回复","冰封诀","蛊毒咒"] },
	{ name = "蛟龙·渊王",   hp = 500, mp = 100, atk = 58, def = 28, spd = 13, lv = 12, rank = "boss", skills = ["普通攻击","妖术","三连击","灼焰术","破防击"] },
	{ name = "上古神魔",    hp = 600, mp = 150, atk = 65, def = 30, spd = 15, lv = 15, rank = "boss", skills = ["普通攻击","妖术","妖气回复","冰封诀","三连击","蛊毒咒"] },
	# ── 测试怪物（WAS 动画）──
	{ name = "超级赤焰兽",  hp = 200, mp = 80,  atk = 30, def = 15, spd = 20, lv = 5, exp = 50, skills = ["普通攻击","妖术"], was_base_path = "res://WAS/超级赤焰兽" },
]

func _build_enemy_db() -> void:
	for row in ENEMY_DB:
		# 用 id 做 key，没写 id 则用 name
		var key = row.get("id", row.name)
		_enemy_db_cache[key] = row

# ══════════════════════════════════════════════
# 角色数据库 — add_party_by_name 从这里查找角色数据
# ══════════════════════════════════════════════

const CHARACTER_DB := {
	"yuling": {
		"name": "羽灵神", "class": "战神", "elem": "金", "role": "主",
		"en_name": "Yuling",
		"hp": 150, "mp": 80,  "atk": 3500, "matk": 25, "def": 14, "mdef": 10, "spd": 8,
		"crit": 0.18, "crit_mult": 1.7,
		"was_base_path": "res://WAS/羽灵神-弓/",
		"skills": ["寂静剑法","一苇渡江","金刚护体","金刚护法","横扫千军","达摩护体","如沐春风","虚沉冰封","失魂符","毒瘴","神行步"],
		"attack_sound": "res://Audio/SE/男-枪.ogg", "cast_sound": "res://Audio/SE/男-枪.ogg",
		"ranged": true,
	},
	"erlang": {
		"name": "二郎神", "class": "战神", "elem": "金", "role": "攻",
		"en_name": "Erlang",
		"hp": 150, "mp": 70,  "atk": 30, "matk": 20, "def": 14, "mdef": 10, "spd": 30,
		"crit": 0.18, "crit_mult": 1.7,
		"was_base_path": "res://WAS/二郎神",
		"skills": ["普通攻击","御剑气","雷霆诀","破防击","金刚护体"],
		"attack_sound": "res://Audio/SE/男-枪.ogg",
		"traits": {"愈战愈勇": {"dmg_pct": 0.05, "spd_pct": 0.05}},
	},
	"duoshiyi": {
		"name": "堕十一", "class": "灵师", "elem": "金", "role": "攻",
		"en_name": "Duoshiyi",
		"hp": 120, "mp": 100, "atk": 20, "matk": 30, "def": 10, "mdef": 12, "spd": 25,
		"crit": 0.12, "crit_mult": 1.5,
		"was_base_path": "res://WAS/堕十一",
		"skills": ["普通攻击","召唤铁甲兽","铁甲出击","金刚护法","金刚护魂"],
		"attack_sound": "res://Audio/SE/男-枪.ogg",
		"traits": {"愈战愈勇": {"dmg_pct": 0.05, "spd_pct": 0.05}},
	},
	"qianmian": {
		"name": "千面", "class": "灵师", "elem": "水", "role": "召",
		"en_name": "Qianmian",
		"hp": 120, "mp": 100, "atk": 20, "matk": 30, "def": 10, "mdef": 12, "spd": 25,
		"crit": 0.12, "crit_mult": 1.5,
		"was_base_path": "res://WAS/千面",
		"skills": ["普通攻击","召唤铁甲兽","铁甲出击","金刚护法","金刚护魂","千变万化"],
		"attack_sound": "res://Audio/SE/男-枪.ogg",
	},
	"dingdong": {
		"name": "叮咚", "class": "灵师", "elem": "水", "role": "召",
		"en_name": "Dingdong",
		"hp": 120, "mp": 100, "atk": 2000, "matk": 30, "def": 10, "mdef": 12, "spd": 25,
		"crit": 0.12, "crit_mult": 1.5,
		"was_base_path": "res://WAS/叮咚",
		"skills": ["普通攻击","召唤铁甲兽","铁甲出击","金刚护法","金刚护魂"],
		"attack_sound": "res://Audio/SE/男-枪.ogg",
		"ranged": true,
	},
	"lingfeng": {
		"name": "凌风", "class": "灵师", "elem": "水", "role": "攻辅",
		"en_name": "Lingfeng",
		"hp": 120, "mp": 100, "atk": 20000, "matk": 30, "def": 10, "mdef": 12, "spd": 25,
		"crit": 0.12, "crit_mult": 1.5,
		"was_base_path": "res://WAS/凌风",
		"skills": ["普通攻击","召唤铁甲兽","铁甲出击","金刚护法","金刚护魂","横扫千军"],
		"attack_sound": "res://Audio/SE/男-枪.ogg",
		"traits": {"横扫不休": {"chance": 0.3}},
	},
	"hutouguai": {
		"name": "虎头怪", "class": "灵师", "elem": "木", "role": "召",
		"en_name": "Hutou",
		"hp": 120, "mp": 100, "atk": 20, "matk": 30, "def": 10, "mdef": 12, "spd": 25,
		"crit": 0.12, "crit_mult": 1.5,
		"was_base_path": "res://WAS/虎头怪",
		"skills": ["普通攻击","召唤铁甲兽","铁甲出击","金刚护法","金刚护魂","横扫千军"],
		"attack_sound": "res://Audio/SE/男-枪.ogg",
		"traits": {"兽王血脉": {"hp_pct": 0.3, "atk_pct": 0.3, "def_pct": 0.2, "spd_pct": 0.2}},
	},
	"shentianbing": {
		"name": "神天兵", "class": "灵师", "elem": "金", "role": "护",
		"en_name": "Shentianbing",
		"hp": 120, "mp": 100, "atk": 20, "matk": 30, "def": 10, "mdef": 12, "spd": 25,
		"crit": 0.12, "crit_mult": 1.5,
		"was_base_path": "res://WAS/神天兵",
		"skills": ["普通攻击","召唤铁甲兽","铁甲出击","金刚护法","金刚护魂","横扫千军"],
		"attack_sound": "res://Audio/SE/男-枪.ogg",
		"traits": {"兽王血脉": {"hp_pct": 0.3, "atk_pct": 0.3, "def_pct": 0.2, "spd_pct": 0.2}},
	},
	"xiaoyaosheng": {
		"name": "逍遥生", "class": "灵师", "elem": "金", "role": "护",
		"en_name": "Xiaoyaosheng",
		"hp": 120, "mp": 100, "atk": 20, "matk": 30, "def": 10, "mdef": 12, "spd": 25,
		"crit": 0.12, "crit_mult": 1.5,
		"was_base_path": "res://WAS/逍遥生",
		"skills": ["普通攻击","召唤铁甲兽","铁甲出击","金刚护法","金刚护魂","横扫千军"],
		"attack_sound": "res://Audio/SE/男-枪.ogg",
		"traits": {"兽王血脉": {"hp_pct": 0.3, "atk_pct": 0.3, "def_pct": 0.2, "spd_pct": 0.2}},
	},	
	"jumowang": {
		"name": "巨魔王", "class": "灵师", "elem": "金", "role": "护",
		"en_name": "Jumowang",
		"hp": 120, "mp": 100, "atk": 20, "matk": 30, "def": 10, "mdef": 12, "spd": 25,
		"crit": 0.12, "crit_mult": 1.5,
		"was_base_path": "res://WAS/巨魔王",
		"skills": ["普通攻击","召唤铁甲兽","铁甲出击","金刚护法","金刚护魂","横扫千军"],
		"attack_sound": "res://Audio/SE/男-枪.ogg",
		"traits": {"兽王血脉": {"hp_pct": 0.3, "atk_pct": 0.3, "def_pct": 0.2, "spd_pct": 0.2}},
	},		
	"taoyaoyao": {
		"name": "桃夭夭", "class": "灵师", "elem": "金", "role": "护",
		"en_name": "Taoyaoyao",
		"hp": 120, "mp": 100, "atk": 20, "matk": 30, "def": 10, "mdef": 12, "spd": 25,
		"crit": 0.12, "crit_mult": 1.5,
		"was_base_path": "res://WAS/桃夭夭",
		"skills": ["普通攻击","召唤铁甲兽","铁甲出击","金刚护法","金刚护魂","横扫千军"],
		"attack_sound": "res://Audio/SE/男-枪.ogg",
		"traits": {"兽王血脉": {"hp_pct": 0.3, "atk_pct": 0.3, "def_pct": 0.2, "spd_pct": 0.2}},
	},				
	"yanwushi": {
		"name": "偃无师", "class": "灵师", "elem": "金", "role": "护",
		"en_name": "Yanwushi",
		"hp": 120, "mp": 100, "atk": 20, "matk": 30, "def": 10, "mdef": 12, "spd": 25,
		"crit": 0.12, "crit_mult": 1.5,
		"was_base_path": "res://WAS/偃无师",
		"skills": ["普通攻击","召唤铁甲兽","铁甲出击","金刚护法","金刚护魂","横扫千军"],
		"attack_sound": "res://Audio/SE/男-枪.ogg",
		"traits": {"兽王血脉": {"hp_pct": 0.3, "atk_pct": 0.3, "def_pct": 0.2, "spd_pct": 0.2}},
	},			
	"yingnvxia": {
		"name": "英女侠", "class": "灵师", "elem": "金", "role": "护",
		"en_name": "Yingnvxia",
		"hp": 120, "mp": 100, "atk": 20, "matk": 30, "def": 10, "mdef": 12, "spd": 25,
		"crit": 0.12, "crit_mult": 1.5,
		"was_base_path": "res://WAS/英女侠",
		"skills": ["普通攻击","召唤铁甲兽","铁甲出击","金刚护法","金刚护魂","横扫千军"],
		"attack_sound": "res://Audio/SE/男-枪.ogg",
		"traits": {"兽王血脉": {"hp_pct": 0.3, "atk_pct": 0.3, "def_pct": 0.2, "spd_pct": 0.2}},
	},
	"yingjingling": {
		"name": "影精灵", "class": "灵师", "elem": "金", "role": "护",
		"en_name": "Yingjingling",
		"hp": 120, "mp": 100, "atk": 20, "matk": 30, "def": 10, "mdef": 12, "spd": 25,
		"crit": 0.12, "crit_mult": 1.5,
		"was_base_path": "res://WAS/影精灵",
		"skills": ["普通攻击","召唤铁甲兽","铁甲出击","金刚护法","金刚护魂","横扫千军"],
		"attack_sound": "res://Audio/SE/男-枪.ogg",
		"traits": {"兽王血脉": {"hp_pct": 0.3, "atk_pct": 0.3, "def_pct": 0.2, "spd_pct": 0.2}},
	},		
	"dajiangjun": {
		"name": "大将军", "class": "灵师", "elem": "金", "role": "护",
		"en_name": "Dajiangjun",
		"hp": 120, "mp": 100, "atk": 20, "matk": 30, "def": 10, "mdef": 12, "spd": 25,
		"crit": 0.12, "crit_mult": 1.5,
		"was_base_path": "res://WAS/大将军",
		"skills": ["普通攻击","召唤铁甲兽","铁甲出击","金刚护法","金刚护魂","横扫千军"],
		"attack_sound": "res://Audio/SE/男-枪.ogg",
		"traits": {"横扫不休": {"hp_pct": 0.3, "atk_pct": 0.3, "def_pct": 0.2, "spd_pct": 0.2}},
	},			
	
					
}


func _init_party() -> void:
	party_db.clear()
	party_order.clear()

func _add_member(member_id: String, d: Dictionary) -> void:
	var s = CharacterStats.new()
	s.character_name  = d.name;   s.character_class = d.class
	s.en_name         = d.get("en_name", "")
	s.max_hp          = d.hp;     s.max_mp          = d.mp
	s.attack          = d.atk;    s.magic_attack    = d.matk
	s.defense         = d.def;    s.magic_defense   = d.mdef
	s.speed           = d.spd;    s.level           = 1
	s.crit_rate       = d.crit;   s.crit_mult       = d.crit_mult
	s.was_base_path   = d.get("was_base_path", "")
	s.was_direction   = d.get("was_direction", 2)  # 主角团默认朝左上角
	s.attack_sound_path = d.get("attack_sound", "")
	s.cast_sound_path   = d.get("cast_sound", "")
	s.is_ranged         = d.get("ranged", false)
	# 五行和定位
	s.element = _parse_element(d.get("elem", "金"))
	s.role    = _parse_role(d.get("role", "攻"))
	s.skill_ids       = d.skills
	s.traits          = d.get("traits", {})
	party_db[member_id] = s


## 从字符串解析五行枚举
func _parse_element(s: String) -> CharacterStats.Element:
	match s:
		"木": return CharacterStats.Element.WOOD
		"水": return CharacterStats.Element.WATER
		"火": return CharacterStats.Element.FIRE
		"土": return CharacterStats.Element.EARTH
		_:    return CharacterStats.Element.METAL


## 从字符串解析定位枚举
func _parse_role(s: String) -> int:
	var result := 0
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
func gain_exp(member_id: String, amount: int) -> bool:
	var s = party_db.get(member_id)
	if s == null:
		return false
	s.exp += amount
	if s.exp >= s.exp_to_next:
		_level_up_member(s)
		return true
	return false

func _level_up_member(s: CharacterStats) -> void:
	s.exp -= s.exp_to_next
	s.level += 1
	s.exp_to_next = CharacterStats.calc_exp_to_next(s.level)
	s.max_hp      += s.hp_growth
	s.max_mp      += s.mp_growth
	s.attack      += s.atk_growth
	s.defense     += s.def_growth
	s.speed       += s.speed_growth


# ══════════════════════════════════════════════
# 背包
# ══════════════════════════════════════════════

func _init_inventory() -> void:
	player_inventory = Inventory.new()
	player_inventory.add_item(item_db["hp_potion_s"], 3)
	player_inventory.add_item(item_db["mp_potion_s"], 2)
	player_inventory.add_item(item_db["atk_pill"],    1)
	player_inventory.add_item(item_db["revive_pill"], 1)
	# 测试用宠物技能书（全部40本，每种2本）
	var all_book_ids := [
		"book_haste_high","book_haste","book_hp_high","book_hp",
		"book_def_high","book_def","book_mdef_high","book_mdef",
		"book_atk_high","book_atk","book_matk_high","book_matk",
		"book_crit_high","book_crit","book_mcrit_high","book_mcrit",
		"book_regen_high","book_regen","book_double_atk","book_double_mag",
		"book_lifesteal_h","book_lifesteal","book_reflect_h","book_reflect",
		"book_revive_h","book_revive","book_venom_h","book_venom",
		"book_mp_save_h","book_mp_save","book_immune_h","book_immune",
		"book_slow_h","book_slow","book_fluct_h","book_fluct",
		"book_night_h","book_night","book_gold_h","book_gold",
	]
	for bid in all_book_ids:
		if item_db.has(bid):
			player_inventory.add_item(item_db[bid], 2)
	# 测试用任务道具
	player_inventory.add_item(item_db["quest_fox_tail"],     3)
	player_inventory.add_item(item_db["quest_mandrill_fang"], 2)
	player_inventory.add_item(item_db["quest_ghost_core"],    1)
	player_inventory.add_item(item_db["quest_fire_feather"],  5)
	player_inventory.add_item(item_db["quest_spider_silk"],   2)


# ══════════════════════════════════════════════
# 赏金任务接口
# ══════════════════════════════════════════════

## 接受一个悬赏任务
func accept_bounty(bounty_id: String) -> void:
	if bounty_id in completed_bounty_ids:
		return
	active_bounties[bounty_id] = { "state": "accepted", "claimed": false }

## 放弃一个悬赏任务
func abandon_bounty(bounty_id: String) -> void:
	active_bounties.erase(bounty_id)

## 检查任务是否已被接受或完成
func is_bounty_active(bounty_id: String) -> bool:
	return bounty_id in active_bounties

func is_bounty_completed(bounty_id: String) -> bool:
	return bounty_id in completed_bounty_ids

## 检查背包中是否有足够任务道具
func check_bounty_items(item_id: String, count: int) -> bool:
	return player_inventory.has_item(item_id, count)

## 扣除任务道具
func consume_bounty_items(item_id: String, count: int) -> bool:
	return player_inventory.remove_item(item_id, count)

## 发放金币奖励
func give_bounty_reward(amount: int) -> void:
	player_gold += amount
	gold += amount  # 同步全局 gold 字段

## 标记任务为已完成（不再出现）
func complete_bounty(bounty_id: String) -> void:
	active_bounties.erase(bounty_id)
	if bounty_id not in completed_bounty_ids:
		completed_bounty_ids.append(bounty_id)

# ══════════════════════════════════════════════
# 技能注册 & 技能库
# ══════════════════════════════════════════════

## 全部技能定义 — 字典格式，方便查看/扩展
## 字段含义：type(类型) target(目标) mp(法力) dmg(倍率) hits(段数)
##          heal(治疗倍率) flat(固定值) cd(冷却) buff(效果ID) bturn(回合) bchance(概率)
##          desc(描述) magic(法术伤害)
const SKILL_DB := {
	"普通攻击": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 0, "dmg": 1.0, "hits": 1, "sound": "res://Audio/SE/男-枪.ogg",
		"desc": "对目标造成 100% 物理伤害",
	},
	"御剑气": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 15, "dmg": 1.8, "cd": 1, "sound": "res://Audio/SE/男-枪.ogg",
		"desc": "凝聚剑气，对目标造成 180% 物理伤害",
	},
	"寂静剑法": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 30, "dmg": 1.3, "cd": 2, "sound": "res://Audio/SE/男-枪.ogg",
		"desc": "寂静剑气覆盖全场，对所有敌人造成 130% 物理伤害",
	},
	"雷霆诀": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "dmg": 2.0, "cd": 2, "magic": true, "sound": "res://Audio/SE/男-枪.ogg",
		"desc": "召来雷霆，对目标造成 200% 法术伤害",
	},
	"横扫千军": {
		"type": SkillData.SkillType.MULTI_HIT, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 12, "dmg": 2, "hits": 3, 
		"desc": "快速攻击 3 次，每次造成 50% 物理伤害",
	},
	"回元术": {
		"type": SkillData.SkillType.HEAL, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 12, "heal": 0.25, "flat": 10, "cd": 2, "sound": "res://Audio/SE/heal 1.ogg",
		"hsize": "medium",
		"desc": "恢复自身 25% 最大气血 + 10 点",
	},
	"护体真气": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SELF,
		"mp": 10, "buff": "shield", "bturn": 3,
		"desc": "运转真气护体，3 回合内防御翻倍",
	},
	"蛊毒咒": {
		"type": SkillData.SkillType.DEBUFF, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 16, "buff": "poison", "bturn": 3, "bchance": 0.85,
		"desc": "下蛊毒咒，85% 概率使目标中毒 3 回合",
	},
	"毒瘴": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "dmg": 1.0, "magic": true, "cd": 2,
		"buff": "poison", "bturn": 4, "bchance": 1.0,
		"desc": "释放毒瘴侵蚀敌人，造成 100% 法术伤害并 100% 使目标中毒 4 回合",
	},
	"虚沉冰封": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 18, "dmg": 1.4, "cd": 3, "magic": true, "sound": "res://Audio/SE/法术13.ogg",
		"buff": "freeze", "bturn": 1, "bchance": 1,
		"desc": "冰封敌人，造成 140% 法术伤害，100% 概率冰冻 1 回合",
	},
	"失魂符": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 22, "dmg": 1.6, "cd": 3, "magic": true, "sound": "res://Audio/SE/法术5.ogg",
		"buff": "失魂", "bturn": 1, "bchance": 1,
		"desc": "以符咒摄取敌人魂魄，造成 160% 法术伤害，100% 封印 1 回合。被封印的敌人阵亡时魂魄离体消散",
	},
	"破防击": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 8, "dmg": 1.2, "buff": "def_broken", "bturn": 2, "bchance": 0.90,
		"desc": "击破防御，造成 120% 伤害，90% 概率破防 2 回合",
	},
	"一苇渡江": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 15, "cd": 2, "buff": "haste", "bturn": 3, "bvalue": 1.3,
		"desc": "选定目标加速并随机增益 3 名未加速队友，3 回合速度提升 30%",
	},
	"神行步": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 15, "cd": 2, "buff": "haste", "bturn": 3, "bvalue": 1.3,
		"desc": "选定目标加速并随机增益 3 名未加速队友，3 回合速度提升 30%",
	},
	"达摩护体": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 20, "cd": 3, "buff": "hp_up", "bturn": 3, "bvalue": 1.3,
		"desc": "选定目标并随机护体 3 名队友，3 回合气血上限提升 30%",
	},
	"金刚护体": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 20, "cd": 3, "buff": "def_up", "bturn": 3, "bvalue": 1.5,
		"desc": "选定目标并随机护体 3 名队友，3 回合物防提升 50%",
	},
	"金刚护法": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 20, "cd": 3, "buff": "atk_up", "bturn": 3, "bvalue": 1.5,
		"desc": "选定目标并随机护法 3 名队友，3 回合物理攻击提升 50%",
	},
	"金刚护魂": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 20, "cd": 3, "buff": "mdef_up", "bturn": 3, "bvalue": 1.5,
		"desc": "选定目标并随机护魂 3 名队友，3 回合魔防提升 50%",
	},
	"如沐春风": {
		"type": SkillData.SkillType.HEAL, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 18, "heal": 0.15, "flat": 30, "cd": 2, "sound": "res://Audio/SE/heal 1.ogg",
		"hsize": "group",
		"desc": "选定目标及随机 3 名队友恢复 15% 最大气血 + 30 点",
	},
	"烈焰诀": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 25, "dmg": 2.5, "cd": 3, "magic": true,
		"desc": "召唤烈焰，对目标造成 250% 法术伤害",
	},
	"地烈火": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "dmg": 1.6, "cd": 3, "magic": true,
		"desc": "地底涌出烈火，对目标及随机 2 名敌人造成 160% 法术伤害",
	},
	# ── 召唤技能 ──
	"召唤铁甲兽": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SELF,
		"mp": 30, "cd": 3,
		"desc": "打开铁甲界面，召唤机关兽或机关鸟助战",
	},
	"铁甲出击": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 10, "dmg": 0, "cd": 1,
		"desc": "指挥所有铁甲兽对目标发动一次联合攻击",
	},
	# ── 变身技能 ──
	"千变万化": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 30, "cd": 5,
		"desc": "千面千相，变化为一名队友的外貌和技能（不含主角）",
	},
	# ── 敌方技能 ──
	"妖术": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "dmg": 1.6, "magic": true,
		"desc": "施展妖术，造成 160% 法术伤害",
	},
	"妖气回复": {
		"type": SkillData.SkillType.HEAL, "target": SkillData.TargetType.SELF,
		"mp": 15, "heal": 0.2,
		"desc": "吸取妖气，恢复 20% 最大气血",
	},
	"灼焰术": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 18, "dmg": 1.3, "magic": true,
		"buff": "burn", "bturn": 2, "bchance": 0.75,
		"desc": "喷吐烈焰，造成 130% 法术伤害，75% 概率灼烧 2 回合",
	},
}

# ══════════════════════════════════════════════
# 宠物技能书库（被动技能）
# ══════════════════════════════════════════════
const BOOK_SKILL_DB := {
	# ── 速度 ──
	"高级敏捷": {"name":"高级敏捷","icon":"⚡","type":"haste","desc":"速度永久提升 30%","value":1.3},
	"敏捷":     {"name":"敏捷","icon":"⚡","type":"haste","desc":"速度永久提升 15%","value":1.15},
	# ── 气血 ──
	"高级血量": {"name":"高级血量","icon":"❤️","type":"hp_up","desc":"气血上限永久提升 25%","value":1.25},
	"血量":     {"name":"血量","icon":"❤️","type":"hp_up","desc":"气血上限永久提升 12%","value":1.12},
	# ── 物防 ──
	"高级物防": {"name":"高级物防","icon":"🛡️","type":"def_up","desc":"物防永久提升 25%","value":1.25},
	"物防":     {"name":"物防","icon":"🛡️","type":"def_up","desc":"物防永久提升 12%","value":1.12},
	# ── 魔防 ──
	"高级魔防": {"name":"高级魔防","icon":"🔮","type":"mdef_up","desc":"魔防永久提升 25%","value":1.25},
	"魔防":     {"name":"魔防","icon":"🔮","type":"mdef_up","desc":"魔防永久提升 12%","value":1.12},
	# ── 攻击 ──
	"高级强力": {"name":"高级强力","icon":"💪","type":"atk_up","desc":"攻击永久提升 25%","value":1.25},
	"强力":     {"name":"强力","icon":"💪","type":"atk_up","desc":"攻击永久提升 12%","value":1.12},
	# ── 法伤 ──
	"高级魔之心": {"name":"高级魔之心","icon":"💜","type":"matk_up","desc":"法术伤害永久提升 25%","value":1.25},
	"魔之心":     {"name":"魔之心","icon":"💜","type":"matk_up","desc":"法术伤害永久提升 12%","value":1.12},
	# ── 暴击 ──
	"高级必杀": {"name":"高级必杀","icon":"💥","type":"crit_up","desc":"暴击率永久提升 20%","value":0.20},
	"必杀":     {"name":"必杀","icon":"💥","type":"crit_up","desc":"暴击率永久提升 10%","value":0.10},
	# ── 法术暴击 ──
	"高级法术暴击": {"name":"高级法术暴击","icon":"🌟","type":"mcrit_up","desc":"法术暴击率永久提升 20%","value":0.20},
	"法术暴击":     {"name":"法术暴击","icon":"🌟","type":"mcrit_up","desc":"法术暴击率永久提升 10%","value":0.10},
	# ── 恢复 ──
	"高级生命恢复": {"name":"高级生命恢复","icon":"💚","type":"regen","desc":"每回合自动恢复 10% 最大气血","value":0.10},
	"生命恢复":     {"name":"生命恢复","icon":"💚","type":"regen","desc":"每回合自动恢复 5% 最大气血","value":0.05},
	# ── 连击 ──
	"高级连击":     {"name":"高级连击","icon":"👊","type":"double_attack","desc":"普通攻击有 45% 概率连击两次","value":0.45},
	"高级魔法连击": {"name":"高级魔法连击","icon":"✨","type":"double_magic","desc":"法术技能有 35% 概率施放两次","value":0.35},
	# ── 吸血 ──
	"高级吸血": {"name":"高级吸血","icon":"🩸","type":"lifesteal","desc":"物理攻击时吸收 25% 伤害为气血","value":0.25},
	"吸血":     {"name":"吸血","icon":"🩸","type":"lifesteal","desc":"物理攻击时吸收 15% 伤害为气血","value":0.15},
	# ── 反震 ──
	"高级反震": {"name":"高级反震","icon":"↩️","type":"reflect","desc":"受到物理攻击时反弹 40% 伤害","value":0.40},
	"反震":     {"name":"反震","icon":"↩️","type":"reflect","desc":"受到物理攻击时反弹 25% 伤害","value":0.25},
	# ── 神佑复生 ──
	"高级神佑复生": {"name":"高级神佑复生","icon":"🕊️","type":"revive","desc":"阵亡时有 30% 概率满血复活","value":0.30},
	"神佑复生":     {"name":"神佑复生","icon":"🕊️","type":"revive","desc":"阵亡时有 15% 概率半血复活","value":0.15},
	# ── 毒 ──
	"高级毒": {"name":"高级毒","icon":"☠️","type":"venom","desc":"物理攻击有 25% 概率使目标中毒3回合","value":0.25},
	"毒":     {"name":"毒","icon":"☠️","type":"venom","desc":"物理攻击有 15% 概率使目标中毒3回合","value":0.15},
	# ── 慧根 ──
	"高级慧根": {"name":"高级慧根","icon":"🧠","type":"mp_save","desc":"技能灵力消耗减少 40%","value":0.40},
	"慧根":     {"name":"慧根","icon":"🧠","type":"mp_save","desc":"技能灵力消耗减少 20%","value":0.20},
	# ── 神迹 ──
	"高级神迹": {"name":"高级神迹","icon":"✨","type":"immune","desc":"免疫所有异常状态","value":1.0},
	"神迹":     {"name":"神迹","icon":"✨","type":"immune","desc":"50% 概率抵抗异常状态","value":0.50},
	# ── 迟钝 ──
	"高级迟钝": {"name":"高级迟钝","icon":"🐢","type":"slow_tank","desc":"速度降低 30%，气血上限提升 30%","value":{"speed":0.70,"hp":1.45}},
	"迟钝":     {"name":"迟钝","icon":"🐢","type":"slow_tank","desc":"速度降低 20%，气血上限提升 15%","value":{"speed":0.80,"hp":1.15}},
	# ── 法波动 ──
	"高级法波动": {"name":"高级法波动","icon":"🌊","type":"magic_fluctuate","desc":"法术伤害在 70%~130% 间浮动","value":{"low":0.70,"high":1.30}},
	"法波动":     {"name":"法波动","icon":"🌊","type":"magic_fluctuate","desc":"法术伤害在 85%~115% 间浮动","value":{"low":0.85,"high":1.15}},
	# ── 夜战 ──
	"高级夜战": {"name":"高级夜战","icon":"🌙","type":"night","desc":"夜间伤害+20%、速度+15%","value":{"dmg":1.20,"spd":1.15}},
	"夜战":     {"name":"夜战","icon":"🌙","type":"night","desc":"夜间伤害+10%、速度+8%","value":{"dmg":1.10,"spd":1.08}},
	# ── 来财 ──
	"高级来财": {"name":"高级来财","icon":"💰","type":"gold_boost","desc":"战斗金币收益提升 100%","value":2.0},
	"来财":     {"name":"来财","icon":"💰","type":"gold_boost","desc":"战斗金币收益提升 50%","value":1.5},
}

func _register_skills() -> void:
	for sid in SKILL_DB:
		var row = SKILL_DB[sid]
		var sk = SkillData.new()
		sk.skill_id          = sid
		sk.skill_name        = sid
		sk.description       = row.get("desc", "")
		sk.icon_emoji        = row.get("icon", "✨")
		sk.skill_type        = row.type
		sk.target_type       = row.target
		sk.mp_cost           = row.get("mp", 0)
		sk.damage_multiplier = row.get("dmg", 0.0)
		sk.is_magic_damage   = row.get("magic", false)
		sk.hit_count         = row.get("hits", 1)
		sk.heal_multiplier   = row.get("heal", 0.0)
		sk.flat_heal         = row.get("flat", 0)
		sk.heal_size         = row.get("hsize", "medium")
		sk.flat_damage       = row.get("flat_dmg", 0)
		sk.cooldown_turns    = row.get("cd", 0)
		sk.apply_buff_id     = row.get("buff", "")
		sk.apply_buff_turns  = row.get("bturn", 0)
		sk.apply_buff_chance = row.get("bchance", 0.0)
		sk.apply_buff_value  = row.get("bvalue", 0.0)
		sk.sound_path        = row.get("sound", "")
		SkillManager.register_skill(sk)

# ══════════════════════════════════════════════
# 道具注册

func _register_items() -> void:
	const HP = ItemData.ItemType.HP_POTION
	const MP = ItemData.ItemType.MP_POTION
	const BF = ItemData.ItemType.BUFF_ITEM
	const RV = ItemData.ItemType.REVIVE
	const BOOK = ItemData.ItemType.SKILL_BOOK

	var rows = [
		# ── 回复类 ──
		{ id = "hp_potion_s", name = "小还魂丹", icon = "🟥", type = HP, hp = 50,  desc = "恢复50点气血" },
		{ id = "hp_potion_m", name = "中还魂丹", icon = "🔴", type = HP, hp = 120, desc = "恢复120点气血" },
		{ id = "hp_potion_l", name = "大还魂丹", icon = "❤️", type = HP, hp = 300, desc = "恢复300点气血" },
		{ id = "mp_potion_s", name = "小灵力石", icon = "🟦", type = MP, mp = 30,  desc = "恢复30点灵力" },
		{ id = "mp_potion_m", name = "中灵力石", icon = "🔵", type = MP, mp = 70,  desc = "恢复70点灵力" },
		{ id = "mp_potion_l", name = "大灵力石", icon = "💙", type = MP, mp = 150, desc = "恢复150点灵力" },
		# ── 增益类 ──
		{ id = "atk_pill",    name = "大力仙丹", icon = "🟡", type = BF, buff_id = "atk_up", buff_turns = 3, desc = "攻击力提升3回合" },
		{ id = "shield_pill", name = "铁甲仙丹", icon = "🟤", type = BF, buff_id = "shield", buff_turns = 3, desc = "防御力提升3回合" },
		{ id = "haste_pill",  name = "追风仙丹", icon = "🟢", type = BF, buff_id = "haste",  buff_turns = 3, desc = "速度提升3回合" },
		# ── 复活类 ──
		{ id = "revive_pill", name = "九转金丹", icon = "⭕", type = RV, revive_pct = 0.5, desc = "复活并恢复50%气血" },
		# ── 宠物技能书 ──
		{ id = "book_haste_high",  name = "高级敏捷", icon = "⚡", type = BOOK, book_id = "高级敏捷", desc = "速度+30%" },
		{ id = "book_haste",       name = "敏捷",     icon = "⚡", type = BOOK, book_id = "敏捷",     desc = "速度+15%" },
		{ id = "book_hp_high",     name = "高级血量", icon = "❤️", type = BOOK, book_id = "高级血量", desc = "气血+25%" },
		{ id = "book_hp",          name = "血量",     icon = "❤️", type = BOOK, book_id = "血量",     desc = "气血+12%" },
		{ id = "book_def_high",    name = "高级物防", icon = "🛡️", type = BOOK, book_id = "高级物防", desc = "物防+25%" },
		{ id = "book_def",         name = "物防",     icon = "🛡️", type = BOOK, book_id = "物防",     desc = "物防+12%" },
		{ id = "book_mdef_high",   name = "高级魔防", icon = "🔮", type = BOOK, book_id = "高级魔防", desc = "魔防+25%" },
		{ id = "book_mdef",        name = "魔防",     icon = "🔮", type = BOOK, book_id = "魔防",     desc = "魔防+12%" },
		{ id = "book_atk_high",    name = "高级强力", icon = "💪", type = BOOK, book_id = "高级强力", desc = "攻击+25%" },
		{ id = "book_atk",         name = "强力",     icon = "💪", type = BOOK, book_id = "强力",     desc = "攻击+12%" },
		{ id = "book_matk_high",   name = "高级魔之心", icon = "💜", type = BOOK, book_id = "高级魔之心", desc = "法伤+25%" },
		{ id = "book_matk",        name = "魔之心",   icon = "💜", type = BOOK, book_id = "魔之心",   desc = "法伤+12%" },
		{ id = "book_crit_high",   name = "高级必杀", icon = "💥", type = BOOK, book_id = "高级必杀", desc = "暴击率+20%" },
		{ id = "book_crit",        name = "必杀",     icon = "💥", type = BOOK, book_id = "必杀",     desc = "暴击率+10%" },
		{ id = "book_mcrit_high",  name = "高级法术暴击", icon = "🌟", type = BOOK, book_id = "高级法术暴击", desc = "法术暴击率+20%" },
		{ id = "book_mcrit",       name = "法术暴击", icon = "🌟", type = BOOK, book_id = "法术暴击", desc = "法术暴击率+10%" },
		{ id = "book_regen_high",  name = "高级生命恢复", icon = "💚", type = BOOK, book_id = "高级生命恢复", desc = "每回合回血10%" },
		{ id = "book_regen",       name = "生命恢复", icon = "💚", type = BOOK, book_id = "生命恢复", desc = "每回合回血5%" },
		{ id = "book_double_atk",  name = "高级连击", icon = "👊", type = BOOK, book_id = "高级连击", desc = "普攻45%二连" },
		{ id = "book_double_mag",  name = "高级魔法连击", icon = "✨", type = BOOK, book_id = "高级魔法连击", desc = "法术35%二连" },
		{ id = "book_lifesteal_h", name = "高级吸血", icon = "🩸", type = BOOK, book_id = "高级吸血", desc = "吸收25%伤害" },
		{ id = "book_lifesteal",   name = "吸血",     icon = "🩸", type = BOOK, book_id = "吸血",     desc = "吸收15%伤害" },
		{ id = "book_reflect_h",   name = "高级反震", icon = "↩️", type = BOOK, book_id = "高级反震", desc = "反弹40%伤害" },
		{ id = "book_reflect",     name = "反震",     icon = "↩️", type = BOOK, book_id = "反震",     desc = "反弹25%伤害" },
		{ id = "book_revive_h",    name = "高级神佑复生", icon = "🕊️", type = BOOK, book_id = "高级神佑复生", desc = "30%满血复活" },
		{ id = "book_revive",      name = "神佑复生", icon = "🕊️", type = BOOK, book_id = "神佑复生", desc = "15%半血复活" },
		{ id = "book_venom_h",     name = "高级毒",   icon = "☠️", type = BOOK, book_id = "高级毒",   desc = "25%使目标中毒" },
		{ id = "book_venom",       name = "毒",       icon = "☠️", type = BOOK, book_id = "毒",       desc = "15%使目标中毒" },
		{ id = "book_mp_save_h",   name = "高级慧根", icon = "🧠", type = BOOK, book_id = "高级慧根", desc = "灵力消耗-40%" },
		{ id = "book_mp_save",     name = "慧根",     icon = "🧠", type = BOOK, book_id = "慧根",     desc = "灵力消耗-20%" },
		{ id = "book_immune_h",    name = "高级神迹", icon = "✨", type = BOOK, book_id = "高级神迹", desc = "免疫所有异常" },
		{ id = "book_immune",      name = "神迹",     icon = "✨", type = BOOK, book_id = "神迹",     desc = "50%抵抗异常" },
		{ id = "book_slow_h",      name = "高级迟钝", icon = "🐢", type = BOOK, book_id = "高级迟钝", desc = "速度-30% 气血+30%" },
		{ id = "book_slow",        name = "迟钝",     icon = "🐢", type = BOOK, book_id = "迟钝",     desc = "速度-20% 气血+15%" },
		{ id = "book_fluct_h",     name = "高级法波动", icon = "🌊", type = BOOK, book_id = "高级法波动", desc = "法伤70%~130%" },
		{ id = "book_fluct",       name = "法波动",   icon = "🌊", type = BOOK, book_id = "法波动",   desc = "法伤85%~115%" },
		{ id = "book_night_h",     name = "高级夜战", icon = "🌙", type = BOOK, book_id = "高级夜战", desc = "夜间伤害+20%速度+15%" },
		{ id = "book_night",       name = "夜战",     icon = "🌙", type = BOOK, book_id = "夜战",     desc = "夜间伤害+10%速度+8%" },
		{ id = "book_gold_h",      name = "高级来财", icon = "💰", type = BOOK, book_id = "高级来财", desc = "金币收益+100%" },
		{ id = "book_gold",        name = "来财",     icon = "💰", type = BOOK, book_id = "来财",     desc = "金币收益+50%" },
	]

	for row in rows:
		var d = ItemData.new()
		d.item_id           = row.id
		d.item_name         = row.name
		d.icon_emoji        = row.icon
		d.item_type         = row.type
		d.item_category     = row.get("cat", ItemData.ItemCategory.CONSUMABLE)
		d.hp_restore        = row.get("hp", 0)
		d.mp_restore        = row.get("mp", 0)
		d.buff_id           = row.get("buff_id", "")
		d.buff_turns        = row.get("buff_turns", 0)
		d.revive_hp_percent = row.get("revive_pct", 0.0)
		d.book_skill_id     = row.get("book_id", "")
		d.description       = row.desc
		d.max_stack         = 10
		item_db[d.item_id]  = d

	# ── 任务道具（悬赏用）──
	const QT = ItemData.ItemType.SPECIAL
	const QC = ItemData.ItemCategory.QUEST
	var quest_rows = [
		{ id = "quest_fox_tail",    name = "妖狐之尾", icon = "🦊", cat = QC, type = QT, desc = "从妖狐身上斩下的尾巴，散发着妖气。" },
		{ id = "quest_mandrill_fang", name = "山魈之牙", icon = "🦷", cat = QC, type = QT, desc = "山魈的獠牙，尚有余温。" },
		{ id = "quest_ghost_core",  name = "幽魂之核", icon = "💠", cat = QC, type = QT, desc = "厉鬼死后凝结的魂核，灵力充沛。" },
		{ id = "quest_golem_stone", name = "石傀之心", icon = "🪨", cat = QC, type = QT, desc = "石傀的核心石，坚硬无比。" },
		{ id = "quest_fire_feather",name = "火鸦之羽", icon = "🔥", cat = QC, type = QT, desc = "火鸦身上最亮的赤羽，依旧灼热。" },
		{ id = "quest_spider_silk", name = "幽蛛之丝", icon = "🕸️", cat = QC, type = QT, desc = "幽蛛吐出的灵丝，坚韧而透明。" },
		{ id = "quest_wind_fang",   name = "风狼之牙", icon = "🌪️", cat = QC, type = QT, desc = "风狼的利齿，刻着古老的风痕。" },
		{ id = "quest_ice_crystal", name = "寒魄冰晶", icon = "❄️", cat = QC, type = QT, desc = "寒魄幽灵消散后留下的不化冰晶。" },
	]
	for row in quest_rows:
		var d = ItemData.new()
		d.item_id       = row.id
		d.item_name     = row.name
		d.icon_emoji    = row.icon
		d.item_type     = row.type
		d.item_category = row.cat
		d.description   = row.desc
		d.max_stack     = 99
		item_db[d.item_id] = d


# ══════════════════════════════════════════════
# 装备系统工具
# ══════════════════════════════════════════════

func _ensure_equip_dict(member_id: String) -> Dictionary:
	if not player_equipment.has(member_id) or not player_equipment[member_id] is Dictionary:
		player_equipment[member_id] = {}
	return player_equipment[member_id]

## 穿上一件装备（by 背包索引，自动替换同槽位，旧装备退回背包）
func equip_item_by_index(member_id: String, slot_key: String, bag_index: int) -> void:
	if bag_index < 0 or bag_index >= equip_bag.size(): return
	var eq_dict = _ensure_equip_dict(member_id)
	var equip_item = equip_bag[bag_index]
	var old = eq_dict.get(slot_key, {})
	if not old.is_empty():
		equip_bag.append(old)
	eq_dict[slot_key] = equip_item
	equip_bag.remove_at(bag_index)

## 卸下一件装备，退回背包
func unequip_item(member_id: String, slot_key: String) -> Dictionary:
	var eq_dict = _ensure_equip_dict(member_id)
	var old = eq_dict.get(slot_key, {})
	if not old.is_empty():
		equip_bag.append(old)
	eq_dict.erase(slot_key)
	return old

## 往背包中添加一件装备
func add_equip_to_bag(equip_dict: Dictionary) -> void:
	equip_bag.append(equip_dict)

## 获取某个角色某个槽位的装备
func get_equipment(member_id: String, slot_key: String) -> Dictionary:
	var eq_dict = player_equipment.get(member_id, {})
	if eq_dict is Dictionary:
		return eq_dict.get(slot_key, {})
	return {}

## 某个角色全套装备属性合计
func get_equipment_stats(member_id: String) -> Dictionary:
	var eq_dict = player_equipment.get(member_id, {})
	if eq_dict is Dictionary:
		return EquipData.calc_full_stats(eq_dict)
	return {}

## 生成随机装备（测试用）
func generate_random_equip(slot: EquipData.SlotType = EquipData.SlotType.WEAPON,
		rarity: EquipData.Rarity = EquipData.Rarity.COMMON,
		level: int = 1) -> Dictionary:
	return EquipData.create_equip(slot, rarity, level)


# ══════════════════════════════════════════════
# 命名装备库（TCP 图片对应的固定装备）
# ══════════════════════════════════════════════

func _init_equip_db() -> void:
	# ── 腰带 ──
	EquipData.register_named("equip_2902", EquipData.SlotType.BELT, EquipData.Rarity.COMMON,
		"粗腰带", {"hp": 80}, "res://TCP/腰带/2902.tcp")
	EquipData.register_named("equip_2903", EquipData.SlotType.BELT, EquipData.Rarity.COMMON,
		"细腰带", {"hp": 60}, "res://TCP/腰带/2903.tcp")
	EquipData.register_named("equip_2906", EquipData.SlotType.BELT, EquipData.Rarity.UNCOMMON,
		"牛皮腰带", {"hp": 140}, "res://TCP/腰带/2906.tcp")
	EquipData.register_named("equip_2908", EquipData.SlotType.BELT, EquipData.Rarity.UNCOMMON,
		"犀皮腰带", {"hp": 180}, "res://TCP/腰带/2908.tcp")
	EquipData.register_named("equip_2910", EquipData.SlotType.BELT, EquipData.Rarity.RARE,
		"虎筋腰带", {"hp": 260}, "res://TCP/腰带/2910.tcp")
	EquipData.register_named("equip_2912", EquipData.SlotType.BELT, EquipData.Rarity.RARE,
		"龙鳞腰带", {"hp": 340}, "res://TCP/腰带/2912.tcp")
	EquipData.register_named("equip_2950", EquipData.SlotType.BELT, EquipData.Rarity.EPIC,
		"玄武腰带", {"hp": 480}, "res://TCP/腰带/2950.tcp")
	EquipData.register_named("equip_2952", EquipData.SlotType.BELT, EquipData.Rarity.COMMON,
		"布腰带", {"hp": 50}, "res://TCP/腰带/2952.tcp")
	EquipData.register_named("equip_2953", EquipData.SlotType.BELT, EquipData.Rarity.COMMON,
		"棉腰带", {"hp": 70}, "res://TCP/腰带/2953.tcp")
	EquipData.register_named("equip_2954", EquipData.SlotType.BELT, EquipData.Rarity.UNCOMMON,
		"铁腰带", {"hp": 160}, "res://TCP/腰带/2954.tcp")
	EquipData.register_named("equip_2955", EquipData.SlotType.BELT, EquipData.Rarity.EPIC,
		"朱雀腰带", {"hp": 440, "spd": 12}, "res://TCP/腰带/2955.tcp")
	EquipData.register_named("equip_2956", EquipData.SlotType.BELT, EquipData.Rarity.EPIC,
		"白虎腰带", {"hp": 460, "atk": 15}, "res://TCP/腰带/2956.tcp")
	EquipData.register_named("equip_2957", EquipData.SlotType.BELT, EquipData.Rarity.LEGENDARY,
		"青龙腰带", {"hp": 600, "spd": 2000}, "res://TCP/腰带/2957.tcp")
	EquipData.register_named("equip_2958", EquipData.SlotType.BELT, EquipData.Rarity.LEGENDARY,
		"九龙神腰带", {"hp": 750, "def": 30}, "res://TCP/腰带/2958.tcp")
	# --- 武器
	EquipData.register_named("equip_2958", EquipData.SlotType.WEAPON, EquipData.Rarity.LEGENDARY,
		"九龙神腰带", {"hp": 750, "def": 30}, "res://TCP/腰带/2958.tcp")

## 调试：往背包放几件腰带看看效果
func _debug_equip_belt() -> void:
	equip_bag = equip_bag.filter(func(eq): return eq is Dictionary and not eq.is_empty())
	if equip_bag.is_empty():
		for equip_id in ["equip_2902", "equip_2910", "equip_2957"]:
			var eq := EquipData.get_named(equip_id)
			if not eq.is_empty():
				equip_bag.append(eq)
		print("[装备调试] 已往背包放入粗腰带、虎筋腰带、青龙腰带")
