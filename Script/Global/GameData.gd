# GameData.gd
# Autoload 单例 - 注册所有技能、道具数据，初始化玩家存档
# 项目设置 → Autoload 中添加，名称设为 "GameData"
extends Node

## 命名装备全量注册器（维护文件：Script/Data/EquipDB.gd）
const EquipDB := preload("res://Script/Data/EquipDB.gd")
var item_db:  Dictionary = {}  # { item_id: ItemData }
var party_db: Dictionary = {}  # { member_id: CharacterStats }
var party_order: Array[String] = []  # 队伍出场顺序
var world_log: RichTextLabel = null   # 战斗外日志（MainScene 注入）
var world_log_text: String = ""       # 日志内容持久化
var pet_db:   Dictionary = {}     # { pet_id: PetData }
var pet_team: Array[String] = []  # 最多6只出战宠物ID
var mech_db:  Dictionary = {}     # { name: { name, was_base_path, level, exp, atk, def_, spd, skills } }
var mech_team: Array[String] = [] # 可召唤的铁甲兽列表
static var shichen_idx: int = 2    # 当前时辰索引（跨场景持久）
static var shichen_accum: float = 0.0  # 时辰累计时间

static var base_vol_master: float = 1.0
static var base_vol_bgm: float = 1.0
static var base_vol_sfx: float = 1.0
var player_gold: int = 5000
var player_inventory: Inventory

## 装备系统
var player_equipment: Dictionary = {}   # { slot_key: EquipData 字典 }  已穿上的
var equip_bag: Array[Dictionary] = []   # 未穿上的装备列表（在背包中显示）
var material_bag: Array[Dictionary] = [] # 打造材料背包
var story_hint: String = "奇迹行者因为刷野而受伤，寒天云叫你去江南野外抓只鸡回来"  # 剧情提示
var disabled_buttons: Array = []  # 主界面禁用的按钮，从存档恢复

## 技能库：记录角色额外习得的技能  { member_id: [skill_id, ...] }
var skill_library: Dictionary = {}

## 赏金任务状态
var active_bounties: Dictionary = {}    # { bounty_id: { "state": "accepted"/"completed", "claimed": false } }
var completed_bounty_ids: Array = []    # 已完成/已领取过的 bounty_id 列表

var player_stats: CharacterStats:
	get: return party_db.values()[0] if not party_db.is_empty() else null

var _enemy_db_cache: Dictionary = {}

## 天赋树数据（talent_id → rank）
static var talent_ranks: Dictionary = {}
var talent_points: int = 20

## 游戏全局数据（存档用）
var gold: int = 0
var game_flags: Dictionary = {}  # { flag_name: value } 剧情标记等
var play_time_sec: int = 0
var current_period: int = 0  # 0=夜间/傍晚, 1=白天, 2=黄昏
var in_battle: bool = false
var ui_blocked: bool = false    # 弹窗打开时暂停地图操作/追踪怪
var current_scene_path: String = ""
var _hit_stop_count: int = 0
var _hit_stop_base_scale: float = 1.0
var chapter_id: int = 1
var current_locale: String = "zh"  # 当前语言
signal screen_shake_requested(strength: float, duration: float)
static func has_talent(talent_id: String) -> bool:
	return talent_ranks.get(talent_id, 0) > 0

static func get_talent_rank(talent_id: String) -> int:
	return talent_ranks.get(talent_id, 0)

static func set_talent_rank(talent_id: String, rank: int) -> void:
	talent_ranks[talent_id] = rank
static var _lang_cache: Dictionary = {}
static var _current_lang: String = "zh"
static func get_lang() -> String: return _current_lang

func hit_stop(duration: float = 0.2, scale: float = 0.05, shake_strength: float = 6.0, shake_duration: float = 0.14) -> void:
	if duration <= 0.0:
		return
	if shake_strength > 0.0 and shake_duration > 0.0:
		screen_shake_requested.emit(shake_strength, shake_duration)
	if _hit_stop_count == 0:
		_hit_stop_base_scale = Engine.time_scale
	_hit_stop_count += 1
	Engine.time_scale = minf(_hit_stop_base_scale, scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	_hit_stop_count = maxi(0, _hit_stop_count - 1)
	if _hit_stop_count == 0:
		Engine.time_scale = _hit_stop_base_scale

func death_hit_stop(is_boss: bool = false) -> void:
	if is_boss:
		hit_stop(0.5, 0.03, 12.0, 0.45)
	else:
		hit_stop(0.2, 0.04, 6.0, 0.22)


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
	"凌风": {
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
		"pool": ["毒云龟", "黑熊", "火沙虫"],
		"min": 8,
	},
}
const ENCOUNTER_INTERVAL := 120.0   # 像素检查间隔
const ENCOUNTER_CHANCE  := 0.1   # 触发概率（1.0 = 100%）

func _init() -> void:
	randomize()

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
	var auto = CharacterStats.calc_monster_exp(level)
	print("【怪物经验】等级 %d 的怪物：经验 = %d" % [level, auto])
	print("  每级需要经验 = %d" % CharacterStats.calc_exp_to_next(level))
	print("  杀同级的怪需要 %d 只才能升级" % ceili(float(CharacterStats.calc_exp_to_next(level)) / float(auto)))

func debug_exp_table(from_lv: int = 1, to_lv: int = 100) -> void:
	var s = "等级\t怪物经验\t升级需要\t杀怪数\n"
	for lv in range(from_lv, to_lv + 1):
		var exp_needed = CharacterStats.calc_exp_to_next(lv)
		var monster_exp = CharacterStats.calc_monster_exp(lv)
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



# ══════════════════════════════════════════════
# 技能库 API
# ══════════════════════════════════════════════

## 解锁技能给指定角色
func unlock_skill(member_id: String, skill_id: String) -> void:
	if not skill_library.has(member_id):
		skill_library[member_id] = []
	if skill_id not in skill_library[member_id]:
		skill_library[member_id].append(skill_id)
		# 也写入 party_db 确保战斗时加载（支持大小写容错）
		var db_id = member_id
		if not party_db.has(db_id):
			for k in party_db:
				if k.to_lower() == member_id.to_lower():
					db_id = k
					break
		if party_db.has(db_id):
			var mb = party_db[db_id]
			if skill_id not in mb.skill_ids:
				mb.skill_ids.append(skill_id)
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
		print("  暴击伤害: %.0f%%" % [c.crit_mult * 100])
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

	var data = {
		"version": 3,
		"gold": gold,
		"talent_points": talent_points,
		"talent_ranks": talent_ranks.duplicate(),
		"game_flags": game_flags.duplicate(),
		"play_time_sec": play_time_sec,
		"shichen_idx": shichen_idx,
		"shichen_accum": shichen_accum,
		"chapter_id": chapter_id,
		"scene_path": current_scene_path,
		"vol_master": GameData.base_vol_master * 100,
		"vol_music":  GameData.base_vol_bgm * 100,
		"vol_sfx":    GameData.base_vol_sfx * 100,
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
		"equip_bag": equip_bag,
		"material_bag": material_bag,
		"dialogue_indexes": _serialize_dialogue_indexes(),
		"disabled_buttons": disabled_buttons,
		"story_hint": story_hint,
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
	disabled_buttons = data.get("disabled_buttons", []).duplicate()
	story_hint = data.get("story_hint", story_hint)
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
	talent_ranks = {}
	talent_ranks.merge(d_talents)
	var d_flags: Dictionary = data.get("game_flags", {})
	game_flags = {}
	game_flags.merge(d_flags)
	play_time_sec  = data.get("play_time_sec", 0)
	shichen_idx    = data.get("shichen_idx", 10)
	shichen_accum  = data.get("shichen_accum", 0.0)
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
	var raw_mat: Array = data.get("material_bag", [])
	material_bag.clear()
	material_bag.assign(raw_mat)
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


## 按名字添加队员（从 CharacterDB.CHARACTER_DB 查数据，找不到则用参数自定义）
func add_party_by_name(p_name: String, p_class: String = "", p_role: String = "",
	p_elem: String = "", p_level: int = 1, p_was: String = "") -> void:
	# 先从数据库查

	if teamIsFull():
		return
		
	for mid in CharacterDB.CHARACTER_DB:
		if CharacterDB.CHARACTER_DB[mid].name == p_name:
			if party_db.has(mid):
				return  # 已在队
			var dd: Dictionary = CharacterDB.CHARACTER_DB[mid].duplicate()
			_add_member(mid, dd)
			if p_level > party_db[mid].level:
				_apply_growth_range(party_db[mid], party_db[mid].level, p_level)
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
	if p_level > 1:
		_apply_growth_range(party_db[mid], party_db[mid].level, p_level)
		party_db[mid].level = p_level
	party_order.append(mid)


## 按 member_id 移除队员
func remove_party_member(member_id: String) -> void:
	if party_db.has(member_id) and party_db[member_id].traits.has("废物"):
		party_db.erase(member_id)
		party_order.erase(member_id)
		return
	party_db.erase(member_id)
	party_order.erase(member_id)

## 按等级范围随机返回怪物 ID（随机遇敌用）
## 按等级范围随机返回怪物 ID（随机遇敌用）
func get_random_enemy_id(min_lv: int = 1, max_lv: int = 99) -> String:
	var candidates = EnemyDB.ENEMY_DB.filter(func(row): return row.lv >= min_lv and row.lv <= max_lv)
	if candidates.is_empty():
		return EnemyDB.ENEMY_DB[0].name
	return candidates[randi() % candidates.size()].name

func is_night_time() -> bool:
	return shichen_idx <= 2 or shichen_idx >= 9

func create_enemy(enemy_name: String) -> CharacterStats:
	var row = _enemy_db_cache.get(enemy_name)
	if row == null:
		push_error("GameData: 未知怪物 '%s'，使用默认怪物" % enemy_name)
		row = _enemy_db_cache.values()[0]
	var s = CharacterStats.new()
	s.character_name = row.name
	var nm := 1.3 if is_night_time() else 1.0
	s.max_hp         = int(row.hp * nm);    s.max_mp        = int(row.mp * nm)
	s.attack         = int(row.atk * nm)
	s.defense        = int(row.def * nm)
	s.speed          = int(row.spd * nm);   s.level         = row.lv
	s.skill_ids      = row.skills.duplicate()
	s.ai_strategy    = row.get("ai_strategy", "balanced")
	s.luck           = row.get("luck", 0)
	s.magic_attack   = int(row.get("matk", row.atk) * nm)
	s.magic_defense  = int(row.get("mdef", int(row.def * 0.8)) * nm)
	s.was_base_path  = row.get("was_base_path", "")
	s.was_direction  = row.get("was_direction", 0)
	s.portrait_path  = row.get("portrait_path", "")
	s.portrait_offset = row.get("portrait_offset", Vector2.ZERO)
	s.team_offset     = row.get("team_offset", Vector2.ZERO)
	s.exp_reward     = int(row.get("exp", 0) * nm)
	s.attack_sound_path = row.get("attack_sound", "")
	s.cast_sound_path   = row.get("cast_sound", "")
	s.rank             = row.get("rank", "")
	s.element = _parse_element(row.get("elem", "金"))
	s.role    = _parse_role(row.get("role", "护"))
	s.traits  = row.get("traits", {}).duplicate()
	s.use_png = row.get("use_png", false)
	# 进场时随机资质（捕捉时保留）
	s.capture_aptitude = _roll_aptitude(row.get("rank", ""), row.lv)
	return s


func _build_enemy_db() -> void:
	for row in EnemyDB.ENEMY_DB:
		var key = row.get("id", row.name)
		_enemy_db_cache[key] = row


## 进场随机资质
func _roll_aptitude(rank: String, lv: int = 1) -> int:
	match rank:
		"boss":    return PetData.Aptitude.甲
		"special": return PetData.Aptitude.特
	var lv_mod := clampf(lv / 50.0, 0.0, 1.0)
	if is_night_time():
		lv_mod = minf(lv_mod * 1.3, 1.0)
	# 甲 = lv_mod × 15%，乙 = lv_mod × 25%，丙 = lv_mod × 30%，剩余丁
	var jia  := int(lv_mod * 15)
	var yi   := jia + int(lv_mod * 25)
	var bing := yi  + int(lv_mod * 30)
	var r = randi() % 100
	if r < jia:    return PetData.Aptitude.甲
	if r < yi:     return PetData.Aptitude.乙
	if r < bing:   return PetData.Aptitude.丙
	return PetData.Aptitude.丁

# ══════════════════════════════════════════════
const SHOP_NPC_DB = {
	# NPC 商店配置：level = 商店装备档位（自动卖 ≤level 的所有等级档装备，见 EQUIP_SHOP_TABLE）
	# items/prices = 旧式固定商品清单（会追加在等级档商品之后，可留空）
	"镖头": { "level": 1, "items": ["equip_2902", "equip_2952", "equip_2953"] },
}

# ══════════════════════════════════════════════
# 装备商店等级档位表：key = 商品等级（1 级村装 / 10 级城装 …）
# 商店等级 shop_level 会卖出所有 key ≤ shop_level 的档位（如 10 级商店 = 档 1/5/10 全卖）
# value = 该档上架的命名装备 id 列表（装备在 EquipData.register_named 注册，见 _init_equip_db）
# ══════════════════════════════════════════════
const EQUIP_SHOP_TABLE := {
	1:  ["青锋剑", "朴刀", "竹杖"],
	5:  ["精钢剑", "铁骨扇", "红缨枪"],
	10: ["寒光剑", "流星锤", "蛇形杖"],
}

## 把一件命名装备包装成商店货架商品（找不到返回空字典）
static func _build_shop_item(eid: String, price_override: int = 0) -> Dictionary:
	var eq := EquipData.get_named(eid)
	if eq.is_empty():
		return {}
	var price := price_override if price_override > 0 else int(eq.get("price", 0))
	return {
		"name": eq.get("display_name", eq.get("name", "装备")),
		"price": price,
		"tcp_path": eq.get("tcp_path", ""),
		"equip_data": eq,
	}

## 按商店等级取装备货架：收集所有 商品等级 ≤ shop_level 的档位装备
static func get_equip_shop_items(shop_level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for lv in EQUIP_SHOP_TABLE:
		if int(lv) > shop_level:
			continue
		for eid in EQUIP_SHOP_TABLE[lv]:
			var it := _build_shop_item(eid)
			if not it.is_empty():
				result.append(it)
	return result

static func get_shop_items(npc_name: String) -> Array[Dictionary]:
	var entry = SHOP_NPC_DB.get(npc_name, {})
	var result: Array[Dictionary] = []
	# 等级档商品：NPC 配置了 level 就按表卖 ≤level 的装备
	var lv := int(entry.get("level", 0))
	if lv > 0:
		result.append_array(get_equip_shop_items(lv))
	# 旧式固定清单（追加在等级档之后）
	var item_ids: Array = entry.get("items", [])
	var custom_prices: Dictionary = entry.get("prices", {})
	for eid in item_ids:
		var it := _build_shop_item(eid, int(custom_prices.get(eid, 0)))
		if not it.is_empty():
			result.append(it)
	return result


# ═══ 打造材料数据库 ═══
static func get_material(id: String) -> Dictionary:
	return MaterialDB.MATERIAL_DB.get(id, {}).duplicate()

# ═══ 传送圈位置数据库 ═══
const TELEPORT_DB = {
	"map_changan": [
		{ "label": "建邺", "scene": "map_jianye", "pos": Vector2(500, 300) },
	],
}

static func get_teleports(map_id: String) -> Array:
	return TELEPORT_DB.get(map_id, []).duplicate()


func _init_party() -> void:
	party_db.clear()
	party_order.clear()


## 按成长系数把 s 的面板属性从 from_level 补到 to_level（每级加成与 _level_up_member 一致；
## 不含能力点/经验/技能——技能与能力点在入队时已按最终等级另行处理）
func _apply_growth_range(s: CharacterStats, from_level: int, to_level: int) -> void:
	var steps := to_level - from_level
	if steps <= 0:
		return
	s.max_hp         += s.hp_growth * steps
	s.max_mp         += s.mp_growth * steps
	s.attack         += s.atk_growth * steps
	s.magic_attack   += s.matk_growth * steps
	s.defense        += s.def_growth * steps
	s.magic_defense  += s.mdef_growth * steps
	s.speed          += s.speed_growth * steps

func _add_member(member_id: String, d: Dictionary) -> void:
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
	s.element = _parse_element(d.get("elem", "金"))
	s.role    = _parse_role(d.get("role", "攻"))
	s.skill_ids       = _get_initial_skills(member_id, d)
	s.traits          = d.get("traits", {})
	# 初始等级 >1：按成长系数补齐 1→level 的面板成长（与逐级升级成长一致）
	_apply_growth_range(s, 1, s.level)
	party_db[member_id] = s


## 从字符串解析五行枚举
func _parse_element(s: String) -> CharacterStats.Element:
	match s:
		"无": return CharacterStats.Element.NONE
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
		var levels_gained := _level_up_member(s)
		return levels_gained > 0
	return false

## 洗髓丹：返还该角色全部已分配的能力点，返回返还点数（0 = 无可返还）
func refund_ability_points(member_id: String) -> int:
	var s = party_db.get(member_id)
	if s == null: return 0
	var total = s.alloc_hp + s.alloc_mp + s.alloc_atk + s.alloc_def + s.alloc_spd + s.alloc_magic
	if total <= 0: return 0
	s.max_hp = maxi(s.max_hp - (s.alloc_hp + s.alloc_magic), 1)
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
func _get_initial_skills(member_id: String, d: Dictionary) -> Array[String]:
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


func _level_up_member(s: CharacterStats) -> int:
	var gained := 0
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
	return gained


# ══════════════════════════════════════════════
# 背包
# ══════════════════════════════════════════════

func _init_inventory() -> void:
	player_inventory = Inventory.new()
	player_inventory.add_item(item_db["hp_potion_s"], 3)
	player_inventory.add_item(item_db["mp_potion_s"], 2)
	player_inventory.add_item(item_db["atk_pill"],    1)
	player_inventory.add_item(item_db["revive_pill"], 1)
	player_inventory.add_item(item_db["item_xisuidan"], 1)
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
	# 测试用符咒
	player_inventory.add_item(item_db["talisman_fire"], 5)
	player_inventory.add_item(item_db["talisman_thunder"], 5)
	player_inventory.add_item(item_db["talisman_ice"], 5)
	player_inventory.add_item(item_db["talisman_haste"], 5)
	player_inventory.add_item(item_db["talisman_ceasefire"], 5)
	player_inventory.add_item(item_db["talisman_revive"], 5)


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



func _register_skills() -> void:
	for sid in SkillDB.SKILL_DB:
		var row = SkillDB.SKILL_DB[sid]
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
		sk.shield_pct        = row.get("shield", 0.0)
		sk.heal_size         = row.get("hsize", "medium")
		sk.flat_damage       = row.get("flat_dmg", 0)
		sk.ignore_defense_ratio = row.get("ignore_def", 0.0)
		sk.miss_chance = row.get("miss_chance", 0.0)
		sk.target_atk_dmg_mult = row.get("tatk_dmg", 0.0)
		sk.cooldown_turns    = row.get("cd", 0)
		sk.apply_buff_id     = row.get("buff", "")
		sk.apply_buff2_id    = row.get("buff2", "")
		sk.apply_buff_turns  = row.get("bturn", 0)
		sk.apply_buff_chance = row.get("bchance", 0.0)
		sk.apply_buff_value  = row.get("bvalue", 0.0)
		sk.self_buff_id      = row.get("self_buff", "")
		sk.self_buff_turns   = row.get("self_bturn", 0)
		sk.extra_targets    = row.get("extra", 0)
		sk.fullscreen_anim  = row.get("fullscreen", "")
		sk.sacrifice_hp_pct = row.get("sac_hp", 0.5)
		sk.sacrifice_def_pct = row.get("sac_def", 0.5)
		sk.ghost_cost = row.get("ghost_cost", 0)
		sk.ghosts_per_charge = row.get("ghosts_per_charge", 2)
		sk.boost_pct = row.get("boost_pct", 0.0)
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
	const SP = ItemData.ItemType.SPECIAL

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
		{ id = "book_crit_high",   name = "高级必杀", icon = "💥", type = BOOK, book_id = "高级必杀", desc = "运气+20" },
		{ id = "book_crit",        name = "必杀",     icon = "💥", type = BOOK, book_id = "必杀",     desc = "运气+10" },
		{ id = "book_mcrit_high",  name = "高级法术暴击", icon = "🌟", type = BOOK, book_id = "高级法术暴击", desc = "运气+20，法术可暴击" },
		{ id = "book_mcrit",       name = "法术暴击", icon = "🌟", type = BOOK, book_id = "法术暴击", desc = "运气+10，法术可暴击" },
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
		# ── 符咒（消耗品）──
		{ id = "talisman_fire",      name = "星火篆", icon = "🔥", tcp = "res://TCP/符咒/3290.tcp", type = SP, dmg = 1.5, hit_sound = "res://Audio/SE/火1.ogg", desc = "造成火焰伤害并灼烧" },
		{ id = "talisman_thunder",   name = "五雷咒", icon = "⚡", tcp = "res://TCP/符咒/0865.tcp", type = SP, dmg = 1.8, hit_sound = "res://Audio/SE/124-Thunder02.ogg", desc = "造成雷电伤害并概率麻痹" },
		{ id = "talisman_ice",       name = "冰冻符咒", icon = "❄️", tcp = "res://TCP/符咒/3290.tcp", type = SP, dmg = 2.0, hit_sound = "res://Audio/SE/法术5.ogg", desc = "造成冰冻伤害并封印" },
		{ id = "talisman_haste",     name = "加速符咒", icon = "💨", tcp = "res://TCP/符咒/3290.tcp", type = SP, hit_sound = "res://Audio/SE/法术5.ogg", desc = "为队友施加加速效果" },
		{ id = "talisman_ceasefire", name = "止战符咒", icon = "🕊️", tcp = "res://TCP/符咒/3290.tcp", type = SP, hit_sound = "res://Audio/SE/法术5.ogg", desc = "削减敌人灵力" },
		{ id = "talisman_revive",    name = "借尸符",   icon = "💀", tcp = "res://TCP/符咒/3290.tcp", type = SP, hit_sound = "res://Audio/SE/heal 1.ogg", desc = "复活一名阵亡队友，恢复30%气血" },
		# ── 洗髓丹（场外道具：返还能力点）──
		{ id = "item_xisuidan", name = "洗髓丹", tcp = "res://TCP/丹药/0677.tcp", cat = ItemData.ItemCategory.MISC, type = SP, desc = "使用后返还该角色全部已分配的能力点（在属性加点面板使用）" },
	]

	for row in rows:
		var d = ItemData.new()
		d.item_id           = row.id
		d.item_name         = row.name
		d.icon_emoji        = row.get("icon", "")
		d.icon_path         = row.get("tcp", "")
		d.item_type         = row.type
		d.item_category     = row.get("cat", ItemData.ItemCategory.CONSUMABLE)
		d.hp_restore        = row.get("hp", 0)
		d.mp_restore        = row.get("mp", 0)
		d.buff_id           = row.get("buff_id", "")
		d.buff_turns        = row.get("buff_turns", 0)
		d.revive_hp_percent = row.get("revive_pct", 0.0)
		d.damage_multiplier = row.get("dmg", 1.0)
		d.hit_sound         = row.get("hit_sound", "")
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

## 检查某角色能否把该装备穿到指定槽位；返回空串 = 允许，否则为拒绝原因
## 规则：槽位必须匹配；武器还会校验角色的 "weapons" 允许列表（CharacterDB，空 = 不限）
func can_equip(member_id: String, equip_item: Dictionary, slot_key: String) -> String:
	if equip_item.is_empty():
		return ""
	var item_slot: int = equip_item.get("slot", -1)
	if item_slot >= 0:
		var expect := EquipData.slot_key(item_slot)
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
func equip_item_by_index(member_id: String, slot_key: String, bag_index: int) -> bool:
	if bag_index < 0 or bag_index >= equip_bag.size():
		return false
	var eq_dict = _ensure_equip_dict(member_id)
	var equip_item = equip_bag[bag_index]
	if not can_equip(member_id, equip_item, slot_key).is_empty():
		return false
	var old = eq_dict.get(slot_key, {})
	if not old.is_empty():
		equip_bag.append(old)
	eq_dict[slot_key] = equip_item
	equip_bag.remove_at(bag_index)
	return true

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
		level: int = 1) -> Dictionary:
	return EquipData.create_equip(slot, level)


# ══════════════════════════════════════════════
# 命名装备库（TCP 图片对应的固定装备）
# ══════════════════════════════════════════════

func _init_equip_db() -> void:
	# 命名装备全部在 Script/Data/EquipDB.gd 注册
	EquipDB.register_all()
func _debug_equip_belt() -> void:
	equip_bag = equip_bag.filter(func(eq): return eq is Dictionary and not eq.is_empty())
	if equip_bag.is_empty():
		for equip_id in ["equip_2958", "equip_2910", "equip_2957"]:
			var eq := EquipData.get_named(equip_id)
			if not eq.is_empty():
				equip_bag.append(eq)
	# 测试：放几件打造材料
	if material_bag.is_empty():
		for mid in ["black_ore", "gold_ore", "gold_ore", "red_shell", "cloud_herb", "blood_stone", "gold_ore", "shattered_green","shattered_green", "thorn_horn", "moon_stone", "lake_heart", "vitality",
				"talisman_paper", "talisman_paper", "talisman_paper", "talisman_paper", "talisman_paper",
				"cloud_herb", "cloud_herb", "cloud_herb",
				"flame_herb", "flame_herb",
				"thunder_wood", "thunder_wood",
				"ice_crystal", "ice_crystal",
				"peace_moss", "peace_moss"]:
			var mat = MaterialDB.MATERIAL_DB.get(mid, {}).duplicate()
			if not mat.is_empty():
				material_bag.append(mat)

func bossFight(boss):
	var map = get_tree().get_first_node_in_group("map")
	map.start_preset_battle(boss)

func teamIsFull():
	if party_db.size() > 4 and !has_talent("duoduoyishan"):
		return true
