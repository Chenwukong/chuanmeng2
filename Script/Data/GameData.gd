# GameData.gd
# Autoload 单例 - 注册所有技能、道具数据，初始化玩家存档
# 项目设置 → Autoload 中添加，名称设为 "GameData"
extends Node

## 当前发行内容为测试版序章；正式章节发布时关闭此开关。
const TEST_PROLOGUE: bool = true
const TEST_PROLOGUE_EXP_MULTIPLIER: int = 30

func get_battle_exp_multiplier() -> int:
	return TEST_PROLOGUE_EXP_MULTIPLIER if TEST_PROLOGUE else 1

const DatabaseRegistry = preload("res://Script/Data/Services/DatabaseRegistry.gd")
const ProgressService = preload("res://Script/Data/Services/ProgressService.gd")
const EquipmentService = preload("res://Script/Data/Services/EquipmentService.gd")
const PartyService = preload("res://Script/Data/Services/PartyService.gd")
const SaveService = preload("res://Script/Save/SaveService.gd")

## 命名装备全量注册器（维护文件：Script/Data/EquipDB.gd）
const EquipDB := preload("res://Script/Data/EquipDB.gd")
var item_db:  Dictionary = {}  # { item_id: ItemData }
var party_db: Dictionary = {}  # 当前队伍，引用 character_roster 中的同一份角色数据
var character_roster: Dictionary = {} # 全部可选角色的永久运行数据，未入队也保存等级、属性和可分配点
var character_locks: Dictionary = {} # 运行时锁定覆盖；缺省读取 CharacterDB 的 locked。
signal character_locks_changed

func is_character_unlocked(member_id: String) -> bool:
	var row: Dictionary = CharacterDB.CHARACTER_DB.get(member_id, {})
	if row.is_empty() or not row.get("selectable", true): return false
	return not bool(character_locks.get(member_id, row.get("locked", false)))

func set_character_locked(member_id: String, locked: bool) -> bool:
	if member_id not in CharacterDB.selectable_ids(): return false
	character_locks[member_id] = locked
	character_locks_changed.emit()
	request_auto_save()
	return true

func unlock_character(member_id: String) -> bool:
	return set_character_locked(member_id, false)
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
const DEBUG_GOLD := 999999999
var debug_cheats_enabled := false

func enable_debug_cheats() -> void:
	if in_battle or _npc_dialogue_playing or is_dialogue_active(): return
	preload("res://Script/Data/Services/DebugCheats.gd").enable(self)

var player_gold: int = 5000:
	set(value):
		player_gold = DEBUG_GOLD if debug_cheats_enabled else value
		var peak := maxi(int(achievement_stats.get("gold_peak", 0)), value)
		if peak != int(achievement_stats.get("gold_peak", 0)):
			achievement_stats["gold_peak"] = peak
			achievements_changed.emit()
var player_inventory: Inventory

## 装备系统
var player_equipment: Dictionary = {}   # { slot_key: EquipData 字典 }  已穿上的
var equip_bag: Array[Dictionary] = []   # 未穿上的装备列表（在背包中显示）
var material_bag: Array[Dictionary] = [] # 打造材料背包
## Explicit objective locations; positions are local map pixels stored as [x, y].
var story_map_targets: Array = []
var story_hint: String = "奇迹行者因为刷野而受伤，寒天云叫你去江南野外抓只鸡回来":
	set(value):
		if story_hint != value:
			story_map_targets.clear()
		story_hint = value

## Call after updating story_hint; an empty map_id clears the objective.
func set_story_map_target(map_id: String, target_name: String, label: String = "", x: float = INF, y: float = INF) -> void:
	story_map_targets.clear()
	if map_id.is_empty(): return
	var target := {"map_id": map_id, "target_name": target_name, "label": label if not label.is_empty() else target_name}
	if is_finite(x) and is_finite(y): target["position"] = [x, y]
	story_map_targets.append(target)

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
const AchievementDB = preload("res://Script/Data/AchievementDB.gd")
signal achievements_changed
signal achievement_notice_requested
var achievement_notice_queue: Array[Dictionary] = []
var achievement_notified_counts: Dictionary = {}
var _achievement_notices_suspended: bool = false
var _achievement_notifications: CanvasLayer

func ensure_achievement_notifications() -> void:
	if is_instance_valid(_achievement_notifications): return
	_achievement_notifications = preload("res://scenes/UI/AchievementNotifications.tscn").instantiate()
	add_child(_achievement_notifications)

func notify_achievement(title: String, message: String, kind: String = "completed") -> void:
	achievement_notice_queue.append({"title": title, "message": message, "kind": kind})
	var line := "[color=#e6c579]【%s】[/color]%s\n" % [title, message.replace("\n", " ")]
	world_log_text += line
	if is_instance_valid(world_log):
		world_log.append_text(line)
		world_log.scroll_to_line(world_log.get_line_count())
	achievement_notice_requested.emit()

func _check_achievement_notifications() -> void:
	if _achievement_notices_suspended: return
	for entry in AchievementDB.ENTRIES:
		var state := get_achievement_state(entry)
		var earned := int(state.claims) + int(state.available)
		var seen := maxi(int(achievement_notified_counts.get(entry.id, 0)), int(state.claims))
		achievement_notified_counts[entry.id] = maxi(seen, earned)
		if earned <= seen: continue
		var message: String = "完成「%s」，前往成就页面领取奖励。" % entry.name
		if state.repeated:
			message = "「%s」新增 %d 次达成（%d/%d），可领取全体属性点奖励。" % [entry.name, earned - seen, earned, int(state.limit)]
		notify_achievement("成就达成", message)

func get_claimable_achievement_count() -> int:
	var count := 0
	for entry in AchievementDB.ENTRIES: count += int(get_achievement_state(entry).available)
	return count

var achievement_stats: Dictionary = {}
var achievement_claimed: Array = []
var achievement_step_remainder: float = 0.0
var achievement_claim_counts: Dictionary = {}
var achievement_level_ids: Dictionary = {} # metric → 已达标的不同角色ID列表

## 按每条成就的 required_level 统计不同角色，离队、降级不撤销。
func refresh_level_achievements() -> void:
	ProgressService.refresh_level_achievements(self)


func get_achievement_state(entry: Dictionary) -> Dictionary:
	return ProgressService.get_achievement_state(self, entry)


func refresh_attribute_achievements() -> void:
	ProgressService.refresh_attribute_achievements(self)


func record_weapon_upgrade(equipment: Dictionary) -> void:
	ProgressService.record_weapon_upgrade(self, equipment)


func refresh_equipment_achievements() -> void:
	ProgressService.refresh_equipment_achievements(self)


func record_walk_distance(distance: float) -> void:
	ProgressService.record_walk_distance(self, distance)


func add_achievement_progress(metric: String, amount: int = 1) -> void:
	ProgressService.add_achievement_progress(self, metric, amount)


func claim_achievement(id: String) -> bool:
	return ProgressService.claim_achievement(self, id)


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


## NPC 对话配置独立维护，运行进度仍由 GameData 存取。
const DialogueDatabase = preload("res://Script/Data/Dialogue/DialogueDB.gd")
var DIALOGUE_DB: Dictionary = DialogueDatabase.create_database()
const StoryTriggerDatabase = preload("res://Script/Data/Dialogue/StoryTriggerDB.gd")
var STORY_TRIGGER_DB: Dictionary = StoryTriggerDatabase.create_database()
var dialogue_locks: Dictionary = {} # 事件 ID → 段落 ID → 是否锁定（覆盖配置默认值）
var dialogue_progress: Dictionary = {} # NPC 事件 ID → 下一段对话序号

signal battle_ended_for_save()
signal story_progress_committed()
signal auto_saved()

const AUTO_SAVE_INTERVAL := 60.0
var _auto_save_elapsed := 0.0
var _auto_save_pending := false

const DifficultyDB = preload("res://Script/Data/DifficultyDB.gd")
var _difficulty := 1
var _difficulty_locked := false
var difficulty: int:
	get: return _difficulty
var difficulty_locked: bool:
	get: return _difficulty_locked

func select_difficulty(value: int) -> bool:
	if _difficulty_locked or value < 0 or value >= DifficultyDB.PROFILES.size(): return false
	_difficulty = value
	_difficulty_locked = true
	request_auto_save()
	return true

func restore_difficulty(value: int) -> void:
	# 读档只恢复已锁定的选择，旧存档默认普通，不在途中重新询问。
	_difficulty = value if value >= 0 and value < DifficultyDB.PROFILES.size() else 1
	_difficulty_locked = true

func get_enemy_difficulty_multiplier(stat: String) -> float:
	return DifficultyDB.enemy_multiplier(_difficulty, stat)

const FIRST_BOSS_TALENT_REWARD := "reward.fangcun_guard20.talent"
const TALENT_TUTORIAL_COMPLETED := "tutorial.talent.completed"

func grant_first_boss_talent_reward(preset_id: String) -> bool:
	if preset_id != "方寸山_守关20" or story_flag(FIRST_BOSS_TALENT_REWARD): return false
	talent_points += 1
	complete_story_event(FIRST_BOSS_TALENT_REWARD)
	return true

func request_auto_save() -> void:
	_auto_save_pending = true

func _process(delta: float) -> void:
	# 不依赖存档弹窗，也不因切换地图重新计时。
	if current_scene_path.is_empty() or not difficulty_locked: return
	_auto_save_elapsed += delta
	if _auto_save_elapsed >= AUTO_SAVE_INTERVAL:
		_auto_save_elapsed = fmod(_auto_save_elapsed, AUTO_SAVE_INTERVAL)
		request_auto_save()
	# 战斗状态未序列化；结算、剧情和地图恢复全部完成后再落盘。
	if _auto_save_pending and not in_battle and not _npc_dialogue_playing and not is_dialogue_active() and not ui_blocked:
		_auto_save_pending = false
		if save_game(0): auto_saved.emit()
	if not in_battle and not _npc_dialogue_playing and not is_dialogue_active() and not ui_blocked:
		if story_flag(FIRST_BOSS_TALENT_REWARD) and not story_flag(TALENT_TUTORIAL_COMPLETED):
			var scene := get_tree().current_scene
			if is_instance_valid(scene) and scene.has_method("begin_talent_tutorial"):
				scene.begin_talent_tutorial()

## 暗雷配置：{ 地图名: { "pool": [怪物名], "min": 最少数量, "min_lv": 最低等级, "max_lv": 最高等级 } }

## 快捷施法（Alt+Q）已迁移到 battleUI 的 _quick_skill_per_char
const ENCOUNTER_CONFIG := {
	"东海湾": {
		"pool": [ "火沙虫"],
		"min": 8,
	},
}
const ENCOUNTER_INTERVAL := 120.0   # 像素检查间隔
const ENCOUNTER_CHANCE  := 0.1   # 触发概率（1.0 = 100%）
const ENCOUNTER_COOLDOWN_MS: int = 5000
var _encounter_protected_until_ms: int = 0

## 全局战后保护，使用单调时钟，打开小地图或换地图不会绕过。
func start_encounter_cooldown() -> void:
	_encounter_protected_until_ms = Time.get_ticks_msec() + ENCOUNTER_COOLDOWN_MS

func is_encounter_on_cooldown() -> bool:
	return Time.get_ticks_msec() < _encounter_protected_until_ms

func _init() -> void:
	randomize()

func _ready() -> void:
	achievements_changed.connect(_check_achievement_notifications)
	battle_ended_for_save.connect(request_auto_save)
	story_progress_committed.connect(request_auto_save)
	
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
	add_equip_to_bag(EquipData.get_named("基础符纸"))
	add_equip_to_bag(EquipData.get_named("赦令符纸"))
	add_equip_to_bag(EquipData.get_named("朱砂符纸"))
	add_equip_to_bag(EquipData.get_named("八卦符纸"))
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
		var st := EnemyDB.resolve_enemy_stats(row)
		pet.max_hp = int(int(st.get("hp", 0)) * mul); pet.max_mp = int(int(st.get("mp", 0)) * mul)
		pet.attack = int(int(st.get("atk", 0)) * mul); pet.magic_attack = int(int(st.get("matk", 0)) * mul)
		pet.defense = int(int(st.get("def", 0)) * mul); pet.magic_defense = int(int(st.get("mdef", 0)) * mul)
		pet.speed = int(int(st.get("spd", 0)) * mul); pet.skill_ids = ["普通攻击","妖术"]
		pet.was_base_path = row.get("was_base_path", "")
		pet.pet_id = "debug_pet_%d" % i
		pet_db[pet.pet_id] = pet
	pet_team.clear()
	for i in 6:
		pet_team.append("debug_pet_%d" % i)



func _init_mech_pets() -> void:
	DatabaseRegistry._init_mech_pets(self)


func unlock_skill(member_id: String, skill_id: String) -> void:
	PartyService.unlock_skill(self, member_id, skill_id)


func has_skill(member_id: String, skill_id: String) -> bool:
	return PartyService.has_skill(self, member_id, skill_id)


func get_all_skills(member_id: String) -> Array[String]:
	return PartyService.get_all_skills(self, member_id)


func get_learnable_skills(member_id: String) -> Array[String]:
	return PartyService.get_learnable_skills(self, member_id)


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
	return SaveService._serialize_dialogue_indexes(self)


func _restore_dialogue_indexes(data: Dictionary) -> void:
	SaveService._restore_dialogue_indexes(self, data)


const SAVE_PATH := "user://savegame.json"

## 保存游戏
func save_game(slot: int = 0) -> bool:
	return SaveService.save_game(self, slot)


func load_game(slot: int = 0) -> bool:
	return SaveService.load_game(self, slot)


func capture_pet(enemy_name: String, enemy_stats: CharacterStats) -> String:
	return DatabaseRegistry.capture_pet(self, enemy_name, enemy_stats)


func get_first_pet() -> PetData:
	return DatabaseRegistry.get_first_pet(self)


func _pet_to_dict(p: PetData) -> Dictionary:
	return SaveService._pet_to_dict(self, p)


func _pet_from_dict(d: Dictionary) -> PetData:
	return SaveService._pet_from_dict(self, d)


func delete_save(slot: int = 0) -> void:
	SaveService.delete_save(self, slot)


func list_saves() -> Array:
	return SaveService.list_saves(self)


func get_party_member(member_id: String) -> CharacterStats:
	return PartyService.get_party_member(self, member_id)


func get_full_party() -> Array:
	return PartyService.get_full_party(self)


func add_party_by_name(p_name: String, p_class: String = "", p_role: String = "",
	p_elem: String = "", p_level: int = 1, p_was: String = "") -> void:
	PartyService.add_party_by_name(self, p_name, p_class, p_role, p_elem, p_level, p_was)


func remove_party_member(member_id: String) -> void:
	PartyService.remove_party_member(self, member_id)


func get_random_enemy_id(min_lv: int = 1, max_lv: int = 99) -> String:
	return DatabaseRegistry.get_random_enemy_id(self, min_lv, max_lv)


func is_night_time() -> bool:
	return shichen_idx <= 2 or shichen_idx >= 9

## 参战队伍中的最高等级（口径与 BattleScene 一致：pending_party 优先，其次 party_order；无参战队伍返回 0）
func highest_party_level() -> int:
	return DatabaseRegistry.highest_party_level(self)


func create_enemy(enemy_name: String) -> CharacterStats:
	return DatabaseRegistry.create_enemy(self, enemy_name)


func _build_enemy_db() -> void:
	DatabaseRegistry._build_enemy_db(self)


func _roll_aptitude(rank: String, lv: int = 1) -> int:
	return DatabaseRegistry._roll_aptitude(self, rank, lv)


const SHOP_NPC_DB = {
	"符材商人": {"materials": ["talisman_paper", "flame_herb", "cloud_herb", "thunder_wood", "ice_crystal", "peace_moss"]},
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
	1:  ["青铜短剑", "柳叶刀", "曲柳杖"],
	5:  ["吴越剑", "精钢扇", "锯齿矛"],
	10: ["龙泉剑", "烈焰锤", "玄铁牛角杖", "回春玉佩", "御灵佩", "藏锋坠", "余春瓶"],
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
	for mid in entry.get("materials", []):
		var material: Dictionary = MaterialDB.MATERIAL_DB.get(mid, {}).duplicate(true)
		if not material.is_empty():
			result.append({"name": material.get("name", mid), "price": int(material.get("price", 0)), "tcp_path": material.get("tcp_path", ""), "material_data": material})
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
	PartyService._init_party(self)


func _restore_character_roster(data: Dictionary) -> void:
	PartyService._restore_character_roster(self, data)


func _apply_growth_range(s: CharacterStats, from_level: int, to_level: int) -> void:
	PartyService._apply_growth_range(self, s, from_level, to_level)


func _add_member(member_id: String, d: Dictionary) -> void:
	PartyService._add_member(self, member_id, d)


func _create_member_stats(member_id: String, d: Dictionary) -> CharacterStats:
	return PartyService._create_member_stats(self, member_id, d)


func _parse_element(s: String) -> CharacterStats.Element:
	return PartyService._parse_element(self, s)


func _parse_role(s: String) -> int:
	return PartyService._parse_role(self, s)


func gain_exp(member_id: String, amount: int) -> bool:
	return PartyService.gain_exp(self, member_id, amount)


func refund_ability_points(member_id: String) -> int:
	return PartyService.refund_ability_points(self, member_id)


func _get_initial_skills(member_id: String, d: Dictionary) -> Array[String]:
	return PartyService._get_initial_skills(self, member_id, d)


func _level_up_member(s: CharacterStats) -> int:
	return PartyService._level_up_member(self, s)


func _init_inventory() -> void:
	DatabaseRegistry._init_inventory(self)


func accept_bounty(bounty_id: String) -> void:
	ProgressService.accept_bounty(self, bounty_id)


func abandon_bounty(bounty_id: String) -> void:
	ProgressService.abandon_bounty(self, bounty_id)


func is_bounty_active(bounty_id: String) -> bool:
	return ProgressService.is_bounty_active(self, bounty_id)


func is_bounty_completed(bounty_id: String) -> bool:
	return ProgressService.is_bounty_completed(self, bounty_id)


func check_bounty_items(item_id: String, count: int) -> bool:
	return ProgressService.check_bounty_items(self, item_id, count)


func consume_bounty_items(item_id: String, count: int) -> bool:
	return ProgressService.consume_bounty_items(self, item_id, count)


func get_gold_multiplier() -> float:
	return ProgressService.get_gold_multiplier(self)


func add_gold(amount: int) -> int:
	return ProgressService.add_gold(self, amount)


func give_bounty_reward(amount: int) -> void:
	ProgressService.give_bounty_reward(self, amount)


func complete_bounty(bounty_id: String) -> void:
	ProgressService.complete_bounty(self, bounty_id)


func _register_skills() -> void:
	DatabaseRegistry._register_skills(self)


func _register_items() -> void:
	DatabaseRegistry._register_items(self)


func _ensure_equip_dict(member_id: String) -> Dictionary:
	return EquipmentService._ensure_equip_dict(self, member_id)


func can_equip(member_id: String, equip_item: Dictionary, slot_key: String) -> String:
	return EquipmentService.can_equip(self, member_id, equip_item, slot_key)


func equip_item_by_index(member_id: String, slot_key: String, bag_index: int) -> bool:
	return EquipmentService.equip_item_by_index(self, member_id, slot_key, bag_index)


func unequip_item(member_id: String, slot_key: String) -> Dictionary:
	return EquipmentService.unequip_item(self, member_id, slot_key)


func add_equip_to_bag(equip_dict: Dictionary) -> void:
	EquipmentService.add_equip_to_bag(self, equip_dict)


func get_equipment(member_id: String, slot_key: String) -> Dictionary:
	return EquipmentService.get_equipment(self, member_id, slot_key)


func get_equipment_stats(member_id: String) -> Dictionary:
	return EquipmentService.get_equipment_stats(self, member_id)


func generate_random_equip(slot: EquipData.SlotType = EquipData.SlotType.WEAPON,
		level: int = 1) -> Dictionary:
	return EquipmentService.generate_random_equip(self, slot, level)


func _init_equip_db() -> void:
	EquipmentService._init_equip_db(self)


func _debug_unlock_all_talents() -> void:
	var scene: PackedScene = load("res://scenes/UI/TalentTree.tscn")
	if scene == null:
		push_warning("未找到 Component/TalentTree.tscn，无法开启天赋")
		return
	var inst := scene.instantiate()
	var stack: Array = [inst]
	var count := 0
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is TalentNode and not (n as TalentNode).talent_id.is_empty():
			var tid: String = (n as TalentNode).talent_id
			talent_ranks[tid] = maxi(int(talent_ranks.get(tid, 0)), (n as TalentNode).max_rank)
			count += 1
		for c in n.get_children():
			stack.append(c)
	inst.free()
	print("[测试] 已开启全部天赋：%d 个" % count)


## 测试用：把全部命名装备加入背包（已存在的跳过，避免重复堆积）
func _debug_add_all_equips() -> void:
	var have: Dictionary = {}
	for eq in equip_bag:
		if eq is Dictionary:
			have[str(eq.get("id", ""))] = true
	var added: int = 0
	for eid in EquipData.named_db:
		if have.has(str(eid)):
			continue
		add_equip_to_bag(EquipData.get_named(str(eid)))
		added += 1
	print("[测试] 已加入全部装备 %d 件（背包共 %d 件）" % [added, equip_bag.size()])


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

## 顺序对话 + 段落锁。只有实际播放结束的当前段才能推进。
func get_npc_dialogue(event_id: String, check_unlock: bool = true) -> Dictionary:
	return DialogueDatabase.resolve(DIALOGUE_DB, event_id, game_flags, dialogue_progress, dialogue_locks, check_unlock)

var _npc_dialogue_playing: bool = false

## NPC 交互与区域触发共用入口；区域默认不播放被锁住时的等待台词。
func play_npc_dialogue(event_id: String, check_unlock: bool = true, allow_waiting: bool = true, block_player: bool = false, completion_event: String = "") -> bool:
	if _npc_dialogue_playing or in_battle or is_dialogue_active(): return false
	var entry := get_npc_dialogue(event_id, check_unlock)
	if entry.is_empty() or (not allow_waiting and entry.get("is_waiting", false)): return false
	var scene := get_tree().current_scene
	if scene == null: return false
	var method: String = {"story": "show_story_chat", "team": "show_team_chat"}.get(entry.get("type", "normal"), "show_normal_chat")
	if not scene.has_method(method): return false
	_npc_dialogue_playing = true
	var previous_block: bool = ui_blocked
	if block_player: ui_blocked = true
	var completed: bool = await scene.call(method, entry["file"], entry["title"])
	if completed:
		finish_npc_dialogue(entry)
		if not completion_event.is_empty(): complete_story_event(completion_event)
	if block_player: ui_blocked = previous_block
	_npc_dialogue_playing = false
	return completed

## 剧情只写 NPC：do GameData.unlock_npc_dialogue("机关人")。
## 解锁只改变顺序锁点的播放许可，不跳段、不自动弹出；第二参数仅兼容旧调用。
func unlock_npc_dialogue(event_id: String, entry_id: String = "") -> bool:
	return _set_npc_dialogue_lock(event_id, entry_id, false)

func lock_npc_dialogue(event_id: String, entry_id: String = "") -> bool:
	return _set_npc_dialogue_lock(event_id, entry_id, true)

func is_npc_dialogue_locked(event_id: String, entry_id: String = "") -> bool:
	if entry_id.is_empty(): entry_id = _npc_dialogue_gate(event_id)
	return DialogueDatabase.is_locked(DIALOGUE_DB, event_id, entry_id, dialogue_locks)

## 顺序锁点自动定位：待播段本身有锁时操作它，否则操作紧随其后的段落。
## 使用配置上的锁点而非“寻找下一个未解锁段”，重复解锁不会误解锁更后面的剧情。
func _npc_dialogue_gate(event_id: String) -> String:
	var id := DialogueDatabase.canonical_id(event_id)
	var entries: Array = DIALOGUE_DB.get(id, {}).get("entries", [])
	if entries.is_empty(): return ""
	var index := clampi(int(dialogue_progress.get(id, 0)), 0, entries.size() - 1)
	var entry: Dictionary = entries[index]
	var entry_id: String = str(entry.get("id", ""))
	if not entry.has("locked") and not dialogue_locks.get(id, {}).has(entry_id) and index + 1 < entries.size():
		entry = entries[index + 1]
	return str(entry.get("id", ""))

func _set_npc_dialogue_lock(event_id: String, entry_id: String, locked: bool) -> bool:
	var id := DialogueDatabase.canonical_id(event_id)
	if entry_id.is_empty(): entry_id = _npc_dialogue_gate(id)
	if DialogueDatabase.find_entry(DIALOGUE_DB, id, entry_id).is_empty():
		push_warning("未知对话段落：%s / %s" % [event_id, entry_id])
		return false
	if is_npc_dialogue_locked(id, entry_id) == locked: return false
	if not dialogue_locks.has(id): dialogue_locks[id] = {}
	dialogue_locks[id][entry_id] = locked
	story_progress_committed.emit()
	return true

func finish_npc_dialogue(entry: Dictionary) -> bool:
	if not entry.get("advance", false): return false
	var id: String = entry.get("event_id", "")
	var index: int = int(entry.get("index", -1))
	if id.is_empty() or int(dialogue_progress.get(id, 0)) != index: return false
	var current := get_npc_dialogue(id, bool(entry.get("check_unlock", true)))
	if not current.get("advance", false) or current.get("id", "") != entry.get("id", ""): return false
	dialogue_progress[id] = index + 1
	story_progress_committed.emit()
	return true

func story_flag(id: String) -> bool:
	return bool(game_flags.get(str(DialogueDatabase.FLAG_ALIASES.get(id, id)), false))

func set_story_flag(id: String, value: bool = true) -> void:
	game_flags[str(DialogueDatabase.FLAG_ALIASES.get(id, id))] = value

## 幂等完成接口；未来首次奖励可放在调用返回 true 的分支，重复挑战不会重领。
func complete_story_event(id: String) -> bool:
	if story_flag(id): return false
	set_story_flag(id)
	story_progress_committed.emit()
	return true

func teamIsFull():
	return PartyService.teamIsFull(self)
