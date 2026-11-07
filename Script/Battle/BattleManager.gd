# BattleManager.gd
# 战斗核心控制器 - 支持多角色 vs 多敌人
# 将此脚本挂载到战斗场景的根节点
class_name BattleManager
extends Node
const HealingRules = preload("res://Script/Battle/HealingRules.gd")
const SummonActions = preload("res://Script/Battle/SummonActions.gd")
const SkillActions = preload("res://Script/Battle/SkillActions.gd")
const Resolution = preload("res://Script/Battle/BattleResolution.gd")
signal effect_settled(actor: BattleCharacter, target: BattleCharacter, amount: int, kind: String)
var damage_stats: Dictionary = {}
var healing_stats: Dictionary = {}
var _delayed_revivals: Dictionary = {}
var free_talismans_left: int = 0
const TalismanRules = preload("res://Script/Battle/TalismanRules.gd")

# ── 状态机 ────────────────────────────────────
enum BattleState {
	NONE,
	BATTLE_START,
	PLAYER_TURN,      # 等待当前玩家角色输入
	PLAYER_ACTION,    # 执行玩家行动
	ENEMY_TURN,       # 当前敌人 AI 行动
	CHECK_BATTLE_END,
	BATTLE_WIN,
	BATTLE_LOSE,
}

var state: BattleState = BattleState.NONE

# ── 队伍 ──────────────────────────────────────
var party:   Array[BattleCharacter] = []   # 玩家队伍（最多4人）
var enemies: Array[BattleCharacter] = []   # 敌人队伍（最多4个）

# ── 当前行动者 ───────────────────────────────
var _current_actor: BattleCharacter = null  # 当前行动者

# ── 背包（属于整个队伍共享）─────────────────
var player_inventory: Inventory

# ── 玩家成员 ID（用于永久存档经验）─────────
var _party_member_ids: Array = []

# ── 冷却  { character_name + skill_id : turns } ──
var skill_cooldowns: Dictionary = {}
## 千机变：独立于连斩的临时记录，每次战斗清空。
var ally_skill_history: Dictionary = {}
## 豆兵不进入 party，不占行动条和宠物位；仅作为敌方可攻击的额外目标。
var bean_soldiers: Array[BattleCharacter] = []
var guard_relations:  Dictionary = {}  # 被保护的BattleCharacter → 保护者BattleCharacter
var _threat_mgr: ThreatManager = null          # 仇恨系统
var summoned_pet_ids: Array[String] = []  # 已召唤的宠物ID，防止重复召唤
var summoned_mech_ids: Array[String] = []  # 已召唤的铁甲兽名，防止重复召唤

var turn_count: int = 0
var _double_action_active: bool = false
enum DoubleActionType { NONE, DAMAGE, SUPPORT }
var _双动_first_type: int = DoubleActionType.NONE
var _双动_second_phase: bool = false
var _free_items_used: int = 0  # 缩地成寸：本场已免费使用的道具次数
var _last_skill_id: String = "普通攻击"    # 连斩：上次使用的技能
var _last_target: BattleCharacter = null   # 连斩：上次攻击目标
var _combo_triggered: bool = false         # 连斩：本次行动已触发
var active_melee_animations: int = 0  # 命中后仍需等待角色归位，才能追加行动。
var _hit_stay_nodes: Array = []            # 本次行动中保持受击姿态的目标节点（技能播完统一恢复 idle）

@export var action_delay: float = 2.0

@onready var enemy_ai: EnemyAI = $EnemyAI

# ── 待显示伤害（动画完成后才展示）────────────
var pending_damage: Array[Dictionary] = []
var pending_guard_anim: Dictionary = {}  # { guardian, ally_global_pos, ally_node }
var pass_through_hit: Dictionary = {}  # 本场战斗已被穿透命中的敌人（instance_id → true，避免重复穿透）

# ── 信号 ─────────────────────────────────────
signal state_changed(new_state: BattleState)
signal log_pushed(text: String, log_type: String)
signal damage_floated(target: BattleCharacter, amount: int, float_type: String)
signal character_animated(actor: BattleCharacter, anim_name: String, target: BattleCharacter)
signal actor_turn_started(actor: BattleCharacter, is_player: bool)
signal ranged_attack_completed()
signal skill_failed(msg: String)
signal bonus_attack_started
signal battle_ended(player_won: bool, total_exp: int, total_gold: int, level_ups: Array)
signal party_changed

# ──────────────────────────────────────────────
## 初始化战斗
## party_chars:   Array[BattleCharacter]  已实例化的玩家角色节点
## party_stats:   Array[CharacterStats]    对应的属性数据
## enemy_chars:   Array[BattleCharacter]  已实例化的敌人节点
## enemy_stats:   Array[CharacterStats]    对应的属性数据
func setup(
	party_chars:  Array,
	party_stats:  Array,
	party_ids:    Array,
	enemy_chars:  Array,
	enemy_stats:  Array,
	inventory:    Inventory,
	weapon_specials: Array = []
) -> void:
	party.clear()
	enemies.clear()
	skill_cooldowns.clear()
	ally_skill_history.clear()
	bean_soldiers.clear()
	_delayed_revivals.clear()
	summoned_pet_ids.clear()
	summoned_mech_ids.clear()
	turn_count = 0
	_protagonist_defeated = false
	_threat_mgr = ThreatManager.new()
	damage_stats.clear()
	healing_stats.clear()
	free_talismans_left = GameData.get_talent_rank("jieyuechengben")
	_party_member_ids = party_ids.duplicate()

	for i in party_chars.size():
		var c: BattleCharacter = party_chars[i]
		c.member_id = _party_member_ids[i] if i < _party_member_ids.size() else ""
		if c.member_id.is_empty():
			c.is_summoned_pet = true
		c.setup(party_stats[i], true)
		c.died.connect(_on_character_died.bind(c))
		party.append(c)
		if weapon_specials and i < weapon_specials.size() and not weapon_specials[i].is_empty():
			c.equip_special = weapon_specials[i].duplicate()

	# 神佑世人：给每个成员设置队友引用（不含自己，用于分担伤害）
	for c in party:
		c.ally_refs = party.filter(func(x): return x != c)

	for i in enemy_chars.size():
		var c: BattleCharacter = enemy_chars[i]
	
		c.setup(enemy_stats[i], false)
		c.died.connect(_on_character_died.bind(c))
		enemies.append(c)

	player_inventory = inventory
	preload("res://Script/Battle/FishBond.gd").bind_pairs(self)
	enemy_ai.setup(self)
	# 兽王血脉：初始化所有角色的宠物计数
	refresh_summon_synergies()
	_update_element_resonance()
	# 鬼魂计数器初始化
	for c in party:
		if c.trait_data.has("驭鬼术"):
			c.trait_data["_ghost_count"] = 0
	_record_ghost_home()
	_update_ghost_label()
	# SP 系统：不再需要预建队列，_process 中自动积累

## 战斗中召唤宠物：注册到队伍
func add_summoned_character(bc: BattleCharacter, stats: CharacterStats, pet_id: String = "") -> void:
	bc.is_player = true
	bc.is_summoned_pet = true
	bc.pet_id = pet_id
	bc.setup(stats, true)
	bc.summoner_member_id = _current_actor.member_id
	preload("res://Script/Battle/AccessoryEffects.gd").empower_summon(_current_actor, bc, self)
	bc.died.connect(_on_character_died.bind(bc))
	party.append(bc)
	var start_threat := bc.talent_rank("guard_start_threat")
	if start_threat > 0 and _threat_mgr != null:
		_threat_mgr.force_add(bc, bc.stats.defense * start_threat * 10)
	if not pet_id.is_empty():
		summoned_pet_ids.append(pet_id)
	# 兽王血脉：更新所有角色的宠物计数
	refresh_summon_synergies()
	_update_element_resonance()
	_push_log(GameData._T("LOG_JOIN_BATTLE") % bc.stats.get_display_name(), "system")
	party_changed.emit()

## 移除角色（替换宠物时使用）
func remove_character(bc: BattleCharacter) -> void:
	party.erase(bc)
	if not bc.pet_id.is_empty():
		summoned_pet_ids.erase(bc.pet_id)
	# 兽王血脉更新
	refresh_summon_synergies()
	_update_element_resonance()
	party_changed.emit()

func start_battle() -> void:
	_battle_ended_flag = false
	pass_through_hit.clear()
	var teaching_talismans := TalismanRules.should_teach(self)
	# 爆冲天赋：全体队友开局增加行动条
	var baochong_rank = GameData.get_talent_rank("baochong")
	if baochong_rank > 0:
	#	var bonus_sp = 20.0 if baochong_rank == 1 else 35.0
		var bonus_sp = baochong_rank * 10
		for c in party:
			if not c.is_dead and c.talent_rank("baochong") > 0:
				c.current_sp = mini(100, c.current_sp + bonus_sp)
	_push_log(GameData._T("BATTLE_START"), "system")
	_push_log(GameData._T("LOG_OUR_SIDE") % " / ".join(party.map(func(c): return CharacterStats.display_name(c.stats))), "system")
	_push_log(GameData._T("LOG_ENEMY_SIDE") % " / ".join(enemies.map(func(c): return CharacterStats.display_name(c.stats))), "system")
	_update_element_resonance()
	# 晓之以理：敌人伤害降低
	for c in party:
		if not c.is_dead and c.trait_data.has("晓之以理"):
			var cfg = c.trait_data["晓之以理"]
			var rate = 1.0 - cfg.get("dmg_reduce", 0.10)
			for e in enemies:
				e.add_buff("atk_down", 99, rate, "晓之以理", c)
			break
	# 灵台清明：开局额外灵力
	var spirit_rank = GameData.get_talent_rank("main_spirit")
	if spirit_rank > 0:
		for c in party:
			if not c.is_dead and c.talent_rank("main_spirit") > 0:
				c.current_mp = mini(c.get_effective_max_mp(), c.current_mp + 10 * spirit_rank)
	# 铁壁：护角色血量提升 5%/级
	var hp_rank = GameData.get_talent_rank("guard_hp_up")
	if hp_rank > 0:
		var hp_bonus_pct = 0.05 * hp_rank
		for c in party:
			if not c.is_dead and c.talent_rank("guard_hp_up") > 0:
				c.current_hp = mini(c.get_effective_max_hp(), c.current_hp + int(c.get_effective_max_hp() * hp_bonus_pct))
	# 先声夺人：开局获得仇恨（按防御%）
	var start_threat_rank = GameData.get_talent_rank("guard_start_threat")
	if start_threat_rank > 0 and _threat_mgr != null:
		for c in party:
			if not c.is_dead and c.talent_rank("guard_start_threat") > 0:
				var bonus = c.stats.defense * start_threat_rank * 10
				_threat_mgr.force_add(c, bonus)
	_change_state(BattleState.BATTLE_START)
	# 首次机关人教学让主角先手，避免队友或自动召唤在介绍前结束战斗。
	if teaching_talismans:
		for c in party:
			if not c.is_summoned_pet and CharacterStats.has_role(c.stats.role, CharacterStats.Role.MAIN): c.current_sp = 100
	# 灵兽陪伴：开局自动召唤
	if not teaching_talismans and GameData.get_talent_rank("summon_auto") > 0:
		for pid in GameData.pet_team:
			var pet = GameData.pet_db.get(pid)
			if pet and pid not in summoned_pet_ids and _count_summoned_pets() < get_pet_slot_count():
				# 记录召唤归属，供宠物登记及伤害统计使用；开场动画期间仍是 BATTLE_START。
				for ch in party:
					if not ch.is_dead and ch.talent_rank("summon_auto") > 0:
						_current_actor = ch
						_push_log("[灵兽陪伴] 自动召唤 %s！" % pet.character_name, "system")
						var scene = get_parent()
						if scene and scene.has_method("summon_pet"):
							var pet_node = await scene.summon_pet(pet)
							var target = _pick_random_enemy()
							if target and pet_node:
								print("[灵兽神通 auto-summon] rank=", GameData.get_talent_rank("summon_auto_cast"), " skills=", pet.skill_ids)
								if _current_actor.talent_rank("summon_auto_cast") > 0:
									var skill_id = ""
									for sid in pet.skill_ids:
										if sid != "普通攻击" and SkillManager.get_skill(sid) != null:
											skill_id = sid
											break
									if skill_id.is_empty() and not pet.skill_ids.is_empty():
										skill_id = pet.skill_ids[0]
									if not skill_id.is_empty():
										var bc = pet_node.get_node("BattleCharacter") as BattleCharacter
										if bc:
											_push_log("[灵兽神通] %s 施展 %s！" % [pet.character_name, skill_id], "player_action")
											_apply_skill_result(SkillManager.execute(bc, target, skill_id), bc, target)
								else:
									var dmg = maxi(1, pet.attack - target.get_effective_defense())
									apply_damage(null, target, dmg, {"secondary": true})
									target.sync_visual()
									damage_floated.emit(target, dmg, "normal")
									_push_log("%s 攻击 %s，造成 %d 点伤害" % [pet.character_name, target.stats.get_display_name(), dmg], "player_action")
						break
				break
	await get_tree().create_timer(1.0).timeout
	_change_state(BattleState.CHECK_BATTLE_END)

# ──────────────────────────────────────────────
# SP 行动条驱动
# ──────────────────────────────────────────────

func _process(delta: float) -> void:
	# 只在 CHECK_BATTLE_END（等待SP积累）状态下积累
	if state != BattleState.CHECK_BATTLE_END:
		return
	preload("res://Script/Battle/DelayedRevival.gd").tick(self, delta)

	# 所有存活角色同时积累 SP
	var ready: Array[BattleCharacter] = []
	for c in party + enemies:
		if not c.is_dead and c.accumulate_sp(delta):
			ready.append(c)

	if ready.is_empty():
		return

	# 同时满的按速度排序，速度快的先行动
	ready.sort_custom(func(a, b): return a.get_effective_speed() > b.get_effective_speed())
	_current_actor = ready[0]
	_last_target = null
	_combo_triggered = false
	# 立即切状态防止 _process 重复触发（await 间隙会重新入 process）
	if _current_actor.is_player:
		_change_state(BattleState.PLAYER_TURN)
	else:
		_change_state(BattleState.ENEMY_TURN)
		# 敌方回合开始：仇恨衰减
		_threat_mgr.decay_all()
	# 连续行动计数：新行动者+1，其他人清零
	for c in party + enemies:
		if c == _current_actor:
			c.consecutive_turns += 1
		else:
			c.consecutive_turns = 0
	# 不 reset_sp 在这里—等行动完再清（_finish_player_action / enemy turn end）
	# 不 await：_run_actor_turn 内部第一个 await 前会切状态，阻止 _process 继续
	_run_actor_turn(_current_actor)

## 执行某个角色的回合
func _run_actor_turn(actor: BattleCharacter) -> void:
	preload("res://Script/Battle/AccessoryEffects.gd").begin_turn(actor)
	# 毒/灼烧结算
	await _apply_dot(actor)
	if actor.is_dead:
		_current_actor.reset_sp()
		await _check_battle_end()
		if state not in [BattleState.BATTLE_WIN, BattleState.BATTLE_LOSE]:
			_change_state(BattleState.CHECK_BATTLE_END)
		return

	# 生命恢复：每回合自动回血
	if actor._has_book_type("regen"):
		var heal_pct = actor._book_num("regen")
		if heal_pct > 0:
			var heal_amt = maxi(1, int(actor.stats.max_hp * heal_pct))
			var actual = apply_heal(null, actor, heal_amt)
			if actual > 0:
				actor.sync_visual()
				damage_floated.emit(actor, actual, "heal")
				_push_log(GameData._T("LOG_HP_REGEN") % [actor.stats.get_display_name(), actual], "heal")
				await get_tree().create_timer(0.3).timeout

	# 冰冻/催眠/失魂/虚弱检查 — 跳过回合（不 await，不占回合时间）
	if actor.cannot_act():
		if actor.is_frozen:
			_push_log(GameData._T("BATTLE_FROZEN") % actor.stats.get_display_name(), "system")
			actor.sync_freeze_anim()
		else:
			_push_log("%s 正在沉睡，无法行动！" % actor.stats.get_display_name(), "system")
		actor.tick_buffs()
		_current_actor.reset_sp()
		_change_state(BattleState.CHECK_BATTLE_END)
		return

	if actor.is_weakened:
		actor.is_weakened = false
		actor.hide_debuff()
		_push_log(GameData._T("BATTLE_WEAKENED") % actor.stats.get_display_name(), "system")
		actor.tick_buffs()
		_current_actor.reset_sp()
		_change_state(BattleState.CHECK_BATTLE_END)
		return

	# 正常行动前 tick buff（每回合一次，在自己的回合计数）
	actor.tick_buffs()

	# 疯魔：失去控制，随机普通攻击一名队友
	if actor.has_buff("confuse"):
		var conf_allies: Array = []
		var conf_pool: Array = party if actor.is_player else enemies
		for c in conf_pool:
			if c != actor and not c.is_dead:
				conf_allies.append(c)
		if not conf_allies.is_empty():
			var conf_victim: BattleCharacter = conf_allies[randi() % conf_allies.size()]
			_push_log("%s 陷入疯魔，攻击了队友 %s！" % [actor.stats.get_display_name(), conf_victim.stats.get_display_name()], "system")
			var conf_result = SkillManager.execute(actor, conf_victim, "普通攻击")
			_resolve_skill_effects(conf_result, actor, conf_victim)
			await _apply_skill_result(conf_result, actor, conf_victim)
			await get_tree().create_timer(0.3).timeout
			await _check_battle_end()
			if state in [BattleState.BATTLE_WIN, BattleState.BATTLE_LOSE]:
				return
		_current_actor.reset_sp()
		_change_state(BattleState.CHECK_BATTLE_END)
		return

	if actor.is_player:
		# 玩家角色：切换到等待输入状态
		_double_action_active = false
		_双动_first_type = DoubleActionType.NONE
		_双动_second_phase = false
		_change_state(BattleState.PLAYER_TURN)
		actor_turn_started.emit(actor, true)
		_push_log(GameData._T("LOG_TURN_OF") % actor.stats.get_display_name(), "turn")
		# 等待玩家输入（player_use_* 函数负责继续流程）
	else:
		# 敌方：自动 AI
		_change_state(BattleState.ENEMY_TURN)
		actor_turn_started.emit(actor, false)
		_push_log(GameData._T("LOG_TURN_ACT") % actor.stats.get_display_name(), "turn")
		# 时辰喜好：根据当前时段给怪物加buff/debuff
		_apply_time_pref(actor)
		await get_tree().create_timer(0.4).timeout
		await enemy_ai.execute_turn(actor)
		await _check_battle_end()
		if state in [BattleState.BATTLE_WIN, BattleState.BATTLE_LOSE]:
			return
		_current_actor.reset_sp()
		_change_state(BattleState.CHECK_BATTLE_END)

# ──────────────────────────────────────────────
# 玩家行动入口（UI 调用）
# current_actor() 返回当前轮到的玩家角色
# ──────────────────────────────────────────────

## 获取当前行动的玩家角色（给 UI 用）
func current_actor() -> BattleCharacter:
	return _current_actor

## 获取存活的敌人列表（给 UI 目标选择用）
func alive_enemies() -> Array[BattleCharacter]:
	return enemies.filter(func(e): return not e.is_dead) as Array[BattleCharacter]

## 获取存活的玩家角色列表
func alive_party() -> Array[BattleCharacter]:
	return party.filter(func(c): return not c.is_dead) as Array[BattleCharacter]

## 普通攻击
## target: 玩家选中的目标（从 alive_enemies() 选一个）
func player_use_normal_attack(target: BattleCharacter) -> void:
	if state != BattleState.PLAYER_TURN:
		return
	if not is_instance_valid(target) or target not in enemies or target.is_dead:
		skill_failed.emit("攻击目标已失效，请重新选择。")
		return
	if _双动_first_type == DoubleActionType.NONE:
		_双动_first_type = DoubleActionType.DAMAGE
	_last_skill_id = "普通攻击"
	_last_target = target
	_combo_triggered = false
	_change_state(BattleState.PLAYER_ACTION)
	_current_actor.begin_dice_attack()
	var result = SkillManager.execute(_current_actor, target, "普通攻击")
	_resolve_skill_effects(result, _current_actor, target)
	await _apply_skill_result(result, _current_actor, target)
	# 高级连击：45% 概率追加一次普通攻击
	if _current_actor.has_book_skill("高级连击") and not target.is_dead:
		if randf() < 0.45:
			_push_log(GameData._T("LOG_COMBO") % _current_actor.stats.get_display_name(), "player_action")
			var result2 = SkillManager.execute(_current_actor, target, "普通攻击")
			_resolve_skill_effects(result2, _current_actor, target)
			await _apply_skill_result(result2, _current_actor, target)
	await _finish_player_action()

## 使用技能
func player_use_skill(skill_id: String, target: BattleCharacter) -> void:
	await SkillActions.player_use_skill(self, skill_id, target)


func player_use_item(item_id: String, target: BattleCharacter) -> void:
	if state != BattleState.PLAYER_TURN:
		return
	if not is_instance_valid(target) or target not in party or player_inventory == null or not player_inventory.has_item(item_id):
		skill_failed.emit("道具或使用目标已失效，请重新选择。")
		return
	var selected_item: ItemData = player_inventory._slots[item_id].get("data")
	if selected_item == null or selected_item.item_type not in [ItemData.ItemType.HP_POTION, ItemData.ItemType.MP_POTION, ItemData.ItemType.BUFF_ITEM, ItemData.ItemType.REVIVE]:
		skill_failed.emit("该道具不能在战斗中使用。")
		return
	if target.is_dead != (selected_item.item_type == ItemData.ItemType.REVIVE):
		skill_failed.emit("该道具不能对当前目标使用。")
		return
	_change_state(BattleState.PLAYER_ACTION)

	# 确定食用动画 + 音效同步触发
	var slot = player_inventory._slots.get(item_id, {})
	var item_data: ItemData = slot.get("data", null) as ItemData if slot.has("data") else null
	if item_data != null:
		var has_hp = item_data.hp_restore > 0 or item_data.hp_restore_percent > 0.0
		var has_mp = item_data.mp_restore > 0 or item_data.mp_restore_percent > 0.0
		var anim_name = "吃紫" if (has_hp and has_mp) else ("吃血" if has_hp else "吃蓝")
		# 同步播放音效和动画
		if ResourceLoader.exists("res://Audio/SE/heal 1.ogg"):
			var snd = AudioStreamPlayer.new()
			snd.stream = load("res://Audio/SE/heal 1.ogg")
			snd.bus = "SFX"
			add_child(snd)
			snd.play()
			snd.finished.connect(snd.queue_free)
		await target.play_spell_effect(anim_name)

	var item_actor := _current_actor
	var result = player_inventory.use_item(item_id, target, func(recipient, amount, revive): return apply_heal(item_actor, recipient, amount, revive))
	if not result.success:
		skill_failed.emit(result.log_text)
		_change_state(BattleState.PLAYER_TURN)
		return
	print("[道具] item_id=%s success=%s heal=%d mp=%d buff=%s log=%s" % [item_id, result.success, result.heal_amount, result.mp_amount, result.applied_buff, result.log_text])
	# 缩地成寸：战后道具不消耗（首次每级一次）
	var free_max := _current_actor.talent_rank("support_free_item")
	if free_max > 0 and _free_items_used < free_max:
		_free_items_used += 1
		
		if slot and slot.get("data") and slot.get("count", 0) < (slot.get("data") as ItemData).max_stack:
			player_inventory.add_item(slot.get("data"), 1)
	_push_log(result.log_text, "heal" if result.heal_amount > 0 else "system")
	if result.heal_amount > 0:
		damage_floated.emit(target, result.heal_amount, "heal")
		target.sync_visual()
	# MP 回复飘字（蓝色）
	if result.mp_amount > 0:
		damage_floated.emit(target, result.mp_amount, "mp")
		target.sync_visual()
	# 增益道具：头顶显示 buff 名
	if result.applied_buff != "":
		target.show_trait_float(GameData._T(result.applied_buff))
	# 治疗量加成（灵石疗伤）
	var heal_bonus := _current_actor.talent_rank("support_heal_power")
	if heal_bonus > 0 and result.heal_amount > 0:
		var extra = int(result.heal_amount * 0.1 * heal_bonus)
		apply_heal(_current_actor, target, extra, target.is_dead)
		target.sync_visual()
		damage_floated.emit(target, extra, "heal")
	await get_tree().create_timer(action_delay).timeout
	await _finish_player_action()


func _apply_time_pref(enemy: BattleCharacter) -> void:
	var pref = enemy.trait_data.get("_time_pref", "")
	if pref.is_empty(): return
	var period = GameData.current_period
	var period_name = ""
	match period:
		0: period_name = "night"
		1: period_name = "day"
		2: period_name = "dusk"
	if period_name == pref:
		apply_buff(null, enemy, "atk_up", 3, 1.2, "time_pref")
		apply_buff(null, enemy, "haste", 3, 1.15, "time_pref")
	elif period_name == "day" and pref == "night":
		apply_buff(null, enemy, "atk_down", 3, 0.85, "time_pref")
		apply_buff(null, enemy, "slow", 3, 0.85, "time_pref")


## 逃跑
func player_flee() -> void:
	if state != BattleState.PLAYER_TURN:
		return
	var avg_player_spd = _average_speed(party)
	var avg_enemy_spd  = _average_speed(enemies)
	var chance = 0.4 + clamp((avg_player_spd - avg_enemy_spd) * 0.02, -0.2, 0.3)
	if randf() < chance:
		_push_log(GameData._T("LOG_FLEE_OK"), "system")
		_change_state(BattleState.NONE)
		preload("res://Script/Battle/MechFusion.gd").clear_all(self)
		battle_ended.emit(false, 0, 0, [])
	else:
		_push_log(GameData._T("LOG_FLEE_FAIL"), "system")
		await _finish_player_action()

func _finish_player_action() -> void:
	# 支援符咒、逃跑失败等入口可能仍在 PLAYER_TURN；豆兵齐攻期间必须锁住输入。
	if state == BattleState.PLAYER_TURN: _change_state(BattleState.PLAYER_ACTION)
	if _current_actor:
		_current_actor.completed_actions += 1
		_current_actor.dice_action_multiplier = 1.0
	# 统一恢复本次行动中保持受击姿态的目标（先归位再回 idle）
	for node in _hit_stay_nodes:
		if node and is_instance_valid(node):
			var bc := node.get_node_or_null("BattleCharacter") as BattleCharacter
			if bc and not bc.is_dead and not bc.is_frozen and not bc.is_weakened:
				if node.has_meta("_hit_orig_pos") and node.has_method("play_idle"):
					var orig: Vector2 = node.get_meta("_hit_orig_pos")
					node.remove_meta("_hit_orig_pos")
					var tw = node.create_tween()
					tw.tween_property(node, "position", orig, 0.2)
					tw.tween_callback(node.play_idle)
				elif node.has_method("play_idle"):
					node.play_idle()
	_hit_stay_nodes.clear()
	if _current_actor and _current_actor.has_meta("bean_army"):
		var army = _current_actor.get_meta("bean_army")
		if is_instance_valid(army): await army.after_owner_action()
	# 愈战愈勇特效（走回原地后播放）
	if _current_actor:
		var yzyy_stacks: int = _current_actor.trait_data.get("_yzyy_pending", 0)
		if yzyy_stacks > 0:
			_current_actor.trait_data.erase("_yzyy_pending")
			_current_actor.play_dual_spell_effect()
			_current_actor.show_trait_float("愈战愈勇")
			_push_log(GameData._T("LOG_YYY_STACK") % [_current_actor.stats.get_display_name(), yzyy_stacks], "player_action")
	await _check_battle_end()
	if state in [BattleState.BATTLE_WIN, BattleState.BATTLE_LOSE]:
		return
	# 双动特性：第一次行动后追加一次不同类别的行动
	if _current_actor and _双动_first_type != DoubleActionType.NONE and not _双动_second_phase:
		if _current_actor.trait_data.has("双动"):
			_双动_second_phase = true
			_change_state(BattleState.PLAYER_TURN)
			bonus_attack_started.emit()
			_current_actor.show_trait_float("双动")
			_push_log(GameData._T("LOG_DOUBLE_ACTION") % _current_actor.stats.get_display_name(), "player_action")
			return
	if _current_actor:
		_current_actor.reset_sp()
	# 连斩天赋：概率立即重放一次同样的攻击
	if not _combo_triggered:
		var combo_rank = _current_actor.talent_rank("attack_combo") if _current_actor else 0
		if combo_rank > 0 and _current_actor and not _current_actor.is_dead and _last_target and not _last_target.is_dead:
			var combo_chance = 0.05 * combo_rank
			if randf() < combo_chance:
				_combo_triggered = true
				_push_log("%s 触发连击！" % _current_actor.stats.get_display_name(), "system")
				var result = SkillManager.execute(_current_actor, _last_target, _last_skill_id)
				_resolve_skill_effects(result, _current_actor, _last_target)
				await _apply_skill_result(result, _current_actor, _last_target)
	_double_action_active = false
	_双动_first_type = DoubleActionType.NONE
	_change_state(BattleState.CHECK_BATTLE_END)

## 通用群体 buff（一苇渡江/达摩护体/金刚护体/金刚护法等）
func _apply_aoe_buff(target: BattleCharacter, buff_id: String, turns: int, value: float, skill_id: String) -> void:
	var anim_names = {
		"haste": "加速", "hp_up": "加血上限", "def_up": "加物防", "atk_up": "加力", "mdef_up": "加魔防"
	} 

	# 受益者列表
	var data = SkillManager.get_skill(skill_id)
	var extra_count = data.extra_targets if data != null else 3
	var beneficiaries: Array[BattleCharacter] = [target]
	var candidates: Array[BattleCharacter] = []
	for c in party:
		if c != target and not c.is_dead and c.get_buff_layer_count(buff_id) < 3 and not c.has_buff_source(buff_id, skill_id):
			candidates.append(c)
	candidates.shuffle()
	for j in mini(extra_count, candidates.size()):
		beneficiaries.append(candidates[j])

	# 所有人身上的法术特效同时启动
	for b in beneficiaries:
		b.play_spell_effect(skill_id)
		# 提前上 buff（不等施法动画），触发头像变化
		apply_buff(_current_actor, b, buff_id, turns, value, skill_id, false)
		# 金刚护体：双抗（额外施加魔防）
		if skill_id == "金刚护体":
			apply_buff(_current_actor, b, "mdef_up", turns, value, skill_id, false)
		# 加速抖动
		if buff_id == "haste":
			var visual = b.get_parent()
			if visual and visual.has_method("shake"):
				visual.shake()
		# 加力量放大
		if buff_id == "atk_up":
			var visual = b.get_parent()
			if visual and visual.has_method("play_power_up_scale"):
				visual.play_power_up_scale()
		# 加物防金光闪烁
		if buff_id == "def_up":
			var visual = b.get_parent()
			if visual and visual.has_method("flash_gold"):
				visual.flash_gold()

	# 施法者播放施法动画
	var caster_node = _current_actor.get_parent()
	if caster_node and caster_node.has_method("play_cast_sequence"):
		await caster_node.play_cast_sequence(skill_id)

	# 施法完毕后上 buff（add_buff 已在施法前提前调用）
	var anim_name = anim_names.get(buff_id, buff_id)
	for b in beneficiaries:
		# 停止抖动
		var visual = b.get_parent()
		if visual and visual.has_method("stop_shake"):
			visual.stop_shake()
		# 显示 buff 图标
		b.show_buff(anim_name)
		if buff_id == "hp_up":
			await b.play_hp_up_effect()  # 动画内部会调用 sync_visual
		else:
			b.sync_visual()
		_push_log(GameData._T("LOG_STRONG") % b.stats.get_display_name(), "system")
	# 群体 Buff 仇恨
	_threat_mgr.add_buff_threat(_current_actor, true)
	await get_tree().create_timer(action_delay).timeout
	await _finish_player_action()


## 点天灯：给单个目标加灯笼
func _try_add_lantern_to(target: BattleCharacter) -> int:
	if target == null or target.is_dead:
		return 0
	var parent_nd = target.get_parent()
	if parent_nd == null:
		return 0
	var lantern = parent_nd.get_node_or_null("LanternDisplay") as LanternDisplay
	if lantern == null:
		lantern = LanternDisplay.new()
		lantern.name = "LanternDisplay"
		parent_nd.add_child(lantern)
	var full = lantern.add_lantern()
	if full:
		var heal_pct = 0.2
		if _current_actor and _current_actor.trait_data.has("点天灯"):
			heal_pct = _current_actor.trait_data["点天灯"].get("heal_pct", 0.2)
		var heal_amt = int(target.stats.max_hp * heal_pct)
		lantern.clear_lanterns()
		_current_actor.show_trait_float("点天灯")
		return heal_amt
	return 0


## 点天灯：给 AoE buff 的所有目标加灯笼
func _try_add_lantern_to_targets(main_target: BattleCharacter) -> void:
	if _current_actor == null or not _current_actor.trait_data.has("点天灯"):
		return
	var a1 = _try_add_lantern_to(main_target)
	if a1 > 0:
		apply_heal(_current_actor, main_target, a1, main_target.is_dead)
		main_target.sync_visual()
	var extra = _get_extra_heal_target_count(_current_actor)
	if extra <= 0:
		return
	var cands = party.filter(func(c): return c != main_target and not c.is_dead)
	cands.shuffle()
	for j in mini(extra, cands.size()):
		var a2 = _try_add_lantern_to(cands[j])
		if a2 > 0:
			apply_heal(_current_actor, cands[j], a2, cands[j].is_dead)
			cands[j].sync_visual()


## 保护队友 — ally 由 BattleUI 点击选择
func player_guard(ally: BattleCharacter) -> void:
	if state != BattleState.PLAYER_TURN: return
	_change_state(BattleState.PLAYER_ACTION)
	guard_relations[ally] = _current_actor
	# 保护动画：守护者瞬移到被保护者身前播放防御动画
	var nd = _current_actor.get_parent()
	var ally_nd = ally.get_parent()
	if nd and nd.has_method("guard_warp") and ally_nd is Node2D:
		nd.guard_warp((ally_nd as Node2D).global_position, (ally_nd as Node2D).z_index)
	elif nd and nd.has_method("play_guard_cast"):
		nd.play_guard_cast()
	_current_actor.show_trait_float("守护")
	_current_actor.play_dual_spell_effect()
	_push_log(GameData._T("LOG_GUARD_SET") % [_current_actor.stats.get_display_name(), ally.stats.get_display_name()], "player_action")
	await get_tree().create_timer(action_delay).timeout
	# 保护动画播完后瞬移回原位
	if nd and nd.has_method("guard_return"):
		nd.guard_return()
	elif nd and nd.has_method("play_idle"):
		nd.play_idle()
	await _finish_player_action()

## 召唤宠物上场，宠物会随机攻击一个敌人再归位
func player_summon(pet: PetData, prefer_pos: Vector2 = Vector2.INF) -> void:
	await SummonActions.player_summon(self, pet, prefer_pos)


func _do_pet_attack_damage(pet: PetData, target: BattleCharacter) -> void:
	SummonActions._do_pet_attack_damage(self, pet, target)


func player_summon_mech(mech_name: String, replace_bc: BattleCharacter = null) -> void:
	await SummonActions.player_summon_mech(self, mech_name, replace_bc)


func get_pet_slot_count() -> int:
	return 1 + GameData.get_talent_rank("summon_pet_slot")

func _count_summoned_pets() -> int:
	var count := 0
	for c in party:
		if c.is_summoned_pet and not c.is_dead: count += 1
	return count

## 无宠物时的召唤兜底
func player_summon_fallback() -> void:
	await SummonActions.player_summon_fallback(self)


func _do_pet_attack(pet: PetData, target: BattleCharacter) -> void:
	await SummonActions._do_pet_attack(self, pet, target)


func player_capture(target: BattleCharacter) -> void:
	if state != BattleState.PLAYER_TURN: return
	if not is_instance_valid(target) or target not in enemies or target.is_dead:
		skill_failed.emit("捕捉目标已失效，请重新选择。")
		return
	_change_state(BattleState.PLAYER_ACTION)
	var hp_pct = target.hp_percent()
	var catch_chance = 0.3 + (1.0 - hp_pct) * 0.5
	if randf() < catch_chance:
		var pid = GameData.capture_pet(target.stats.get_display_name(), target.stats)
		_push_log(GameData._T("LOG_CAPTURE_OK") % [
			target.stats.character_name,
			PetData.apt_name(GameData.pet_db[pid].aptitude) if GameData.pet_db.has(pid) else "?"
		], "system")
		# 走过来再消失
		var enemy_nd = target.get_parent() as Node2D
		if enemy_nd:
			var caster_nd = _current_actor.get_parent() as Node2D
			if caster_nd:
				# 播放走路动画
				if enemy_nd.has_method("play_animation"):
					enemy_nd.play_animation("move")
				elif enemy_nd.get_node_or_null("WASAnimationPlayer"):
					enemy_nd.get_node("WASAnimationPlayer").play("move", false)
				var target_pos = caster_nd.global_position + Vector2(0, -40)
				var tw = enemy_nd.create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
				tw.tween_property(enemy_nd, "global_position", target_pos, 1.5)
				tw.tween_property(enemy_nd, "modulate:a", 0.0, 0.3)
				tw.tween_callback(func(): enemy_nd.visible = false)
		# 标记死亡（不发死亡信号）
		Resolution.retire(self, _current_actor, target, true)
		await _check_battle_end()
	else:
		_push_log(GameData._T("LOG_CAPTURE_FAIL") % target.stats.get_display_name(), "system")
		# 捕捉失败，目标反击（普攻或随机法术）
		var pool = ["普通攻击"]
		for sid in target.stats.skill_ids:
			if sid == "普通攻击": continue
			var sd = SkillManager.get_skill(sid)
			if sd and target.current_mp >= sd.mp_cost:
				pool.append(sid)
		var counter_skill = pool[randi() % pool.size()]
		# 播放怪物攻击音效
		var enemy_nd2 = target.get_parent()
		if enemy_nd2:
			var atk_snd = enemy_nd2.get_node_or_null("Audio_Attack") as AudioStreamPlayer
			if atk_snd: atk_snd.play()
		var cd = SkillManager.get_skill(counter_skill)
		if cd and not cd.sound_path.is_empty():
			var snd = AudioStreamPlayer.new()
			snd.stream = load(cd.sound_path)
			snd.bus = "SFX"
			add_child(snd)
			snd.play()
			snd.finished.connect(snd.queue_free)
		var counter_result = SkillManager.execute(target, _current_actor, counter_skill)
		_resolve_skill_effects(counter_result, target, _current_actor)
		if counter_result.success:
			await _apply_skill_result(counter_result, target, _current_actor)
	await get_tree().create_timer(action_delay).timeout
	await _finish_player_action()


func _pick_random_enemy() -> BattleCharacter:
	var alive = alive_enemies()
	if alive.is_empty(): return null
	return alive[randi() % alive.size()]

# ──────────────────────────────────────────────
# 敌方 AI 执行入口（由 EnemyAI 调用）
# ──────────────────────────────────────────────

## EnemyAI 决策后，调用此方法执行技能
func execute_enemy_skill(actor: BattleCharacter, skill_id: String, target: BattleCharacter) -> void:
	# 封印（似玉生香）：沉默敌人，下回合不能施法，强制普通攻击
	if actor.has_buff("silence") and skill_id != "普通攻击":
		skill_id = "普通攻击"
		_push_log("【封印】%s 被封印，无法施法！" % actor.stats.get_display_name(), "system")
	var data = SkillManager.get_skill(skill_id)
	if data and not data.sound_path.is_empty() and ResourceLoader.exists(data.sound_path):
		var snd = AudioStreamPlayer.new()
		snd.stream = load(data.sound_path)
		snd.bus = "SFX"
		add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)

	# 群攻整组结算，不能让双鱼结利用先后顺序互相保命。
	if data and (data.target_type == SkillData.TargetType.ALL_ENEMIES or data.skill_type == SkillData.SkillType.AOE or not data.fullscreen_anim.is_empty()):
		preload("res://Script/Battle/FishBond.gd").begin_group(self)
		for victim in alive_party():
			var group_result = SkillManager.execute(actor, victim, skill_id)
			_resolve_skill_effects(group_result, actor, victim)
			await _apply_skill_result(group_result, actor, victim)
		preload("res://Script/Battle/FishBond.gd").end_group(self)
		return
	var result = SkillManager.execute(actor, target, skill_id)
	_resolve_skill_effects(result, actor, target)
	await _apply_skill_result(result, actor, target)
	# 敌人施加的 debuff：动画播完后显示（同玩家技能）
	if result and result.applied_buff != "" and target and target.has_method("_refresh_buff_icon"):
		target._refresh_buff_icon()

# ──────────────────────────────────────────────
# 公共工具
# ──────────────────────────────────────────────

## 结果应用（动画 + 飘字 + 日志）
func _get_extra_heal_target_count(actor: BattleCharacter) -> int:
	return HealingRules._get_extra_heal_target_count(self, actor)


func _get_heal_side(actor: BattleCharacter) -> Array[BattleCharacter]:
	return HealingRules._get_heal_side(self, actor)


func _pick_extra_heal_targets(actor: BattleCharacter, used_targets: Array, count: int) -> Array[BattleCharacter]:
	return HealingRules._pick_extra_heal_targets(self, actor, used_targets, count)


func _calc_heal_amount_for_target(actor: BattleCharacter, target: BattleCharacter, skill_id: String, fallback_amount: int) -> int:
	return HealingRules._calc_heal_amount_for_target(self, actor, target, skill_id, fallback_amount)


func _apply_extra_heal_targets(
	actor: BattleCharacter,
	primary_target: BattleCharacter,
	base_amount: int,
	heal_size: String,
	skill_id: String = "",
	already_healed: Array = []
) -> void:
	HealingRules._apply_extra_heal_targets(self, actor, primary_target, base_amount, heal_size, skill_id, already_healed)


func _apply_skill_result(
	result: SkillManager.SkillResult,
	actor: BattleCharacter,
	target: BattleCharacter
) -> void:
	if not result.success:
		_push_log(result.log_text, "system")
		await get_tree().create_timer(0.3).timeout
		return

	_resolve_skill_effects(result, actor, target)
	# 保护拦截：如果有保护者挡在目标前面，伤害由保护者承担
	var actual_target = target
	var guardian: BattleCharacter = null
	if not actor.is_player:
		guardian = guard_relations.get(target)
		if guardian and not guardian.is_dead:
			actual_target = guardian
			# 守护仇恨：守卫承担的伤害 × 0.5
			var total_dmg = 0
			for dmg in result.damage_list:
				total_dmg += dmg
			_threat_mgr.add_guard_threat(guardian, total_dmg)
			_push_log(GameData._T("LOG_BLOCK") % [guardian.stats.get_display_name(), target.stats.get_display_name()], "system")
			# 标记本次攻击有保护者需要动画
			pending_guard_anim = { "guardian": guardian, "ally_global_pos": target.get_parent().global_position, "ally_node": target.get_parent() }

	# 根据技能类型决定动画：物理/多段=走过去攻击, 法术/治疗/增益=原地施法
	var anim_name = "cast"
	if result.skill_type == SkillData.SkillType.PHYSICAL or result.skill_type == SkillData.SkillType.MULTI_HIT:
		anim_name = "attack"
	
	# 远程攻击：角色原地施法，发射投射物
	var is_ranged_attack = anim_name == "attack" and actor.stats.is_ranged

	# 设置施法者节点的法术动画名（用于 AnimSprite）
	var caster_node = actor.get_parent()
	if caster_node and caster_node.has_method("play_cast_sequence"):
		if is_ranged_attack:
			caster_node._current_spell_anim = "远程攻击"
			anim_name = "ranged_attack"
		else:
			caster_node._current_spell_anim = result.skill_id

	character_animated.emit(actor, anim_name, actual_target)
	await get_tree().create_timer(0.25).timeout

	# 存入待显示伤害
	var meta_mul = actor.metamorphosis_mod
	var skill_data = SkillManager.get_skill(result.skill_id)
	# 符能天赋：符咒伤害加成 5%/级
	if is_ranged_attack and CharacterStats.has_role(actor.stats.role, CharacterStats.Role.MAIN):
		var funeng_rank = actor.talent_rank("funeng")
		if funeng_rank > 0:
			meta_mul *= (1.0 + 0.05 * funeng_rank)
	for dmg in result.damage_list:
		var is_aoe = result.skill_type == SkillData.SkillType.AOE
		# 提前判定技能落空（龙卷雨击等，受运气影响）
		var miss_rate = _calc_miss_chance(actor, actual_target, skill_data.miss_chance if skill_data else 0.0)
		var missed = miss_rate > 0.0 and randf() < miss_rate
		pending_damage.append({
			"attacker": actor,
			"target": actual_target,
			"amount": int(dmg * meta_mul),
			"type": _damage_float_type(result),
			"is_magic": result.is_magic,
			"is_aoe": is_aoe,
			"missed": missed,
		})
	if result.heal_amount > 0 or result.shield_amount > 0:
		var hsize = skill_data.heal_size if skill_data else "medium"
		if result.heal_amount > 0:
			pending_damage.append({
				"attacker": actor,
				"target": actual_target,
				"amount": int(result.heal_amount * meta_mul),
				"type": "crit" if result.is_crit else "heal",
				"is_heal": true,
				"heal_size": hsize,
				"skill_id": result.skill_id,
			})
		if result.shield_amount > 0:
			pending_damage.append({
				"attacker": actor,
				"target": actual_target,
				"amount": result.shield_amount,
				"type": "shield",
				"skill_id": result.skill_id,
			})

	var log_type = "player_action" if actor.is_player else "enemy_action"
	_push_log(result.log_text, log_type)

	if result.applied_buff != "":
		_push_log(GameData._T("LOG_BUFF_GET") % [target.stats.get_display_name(), GameData._T(result.applied_buff)], "system")
		# 单目标/自身 BUFF 的 hp_up：血条上限 tween 效果（同达摩护体）
		if result.applied_buff == "hp_up" and actual_target and not actual_target.is_dead:
			await actual_target.play_hp_up_effect()

	# 特性：烈焰灼魂 — 技能命中后有概率让目标灼烧（Boss免疫）
	if actor and target and not target.is_dead and target.stats.rank != "boss":
		var burn_trait = actor.trait_data.get("烈焰灼魂", {})
		if burn_trait.size() > 0:
			var chance = burn_trait.get("burn_chance", 0.0)
			if randf() < chance:
				var burn_dmg = burn_trait.get("burn_dmg", 0.05)
				apply_buff(actor, target, "burn", 2, int(target.stats.max_hp * burn_dmg))
				_push_log("%s 被烈焰灼伤！" % target.stats.get_display_name(), "debuff")

	# 远程攻击：等待投射物命中结算（battleUI 动画回调中 emit ranged_attack_completed）
	if is_ranged_attack:
		await ranged_attack_completed
	else:
		await get_tree().create_timer(action_delay).timeout
	# 固定延时可能短于近战动画；连击不得在上一击归位前启动。
	while active_melee_animations > 0:
		await get_tree().process_frame

	# 兜底：确保 pending damage 已被刷新（正常情况下 battleUI 动画回调已调用）
	flush_pending_damage()

## 显示所有待显示的伤害（动画完成后调用）
## 符咒直接结算伤害时，同步记录仇恨（普通技能由 pending_damage 结算）。
func apply_talisman_damage(actor: BattleCharacter, target: BattleCharacter, amount: int) -> int:
	if target == null: return 0
	var fire: bool = actor and actor.stats.talisman_type == CharacterStats.TalismanType.FIRE
	if fire: target.killed_by_fire = true
	var actual := apply_damage(actor, target, amount, {"is_magic": true})
	if fire and not target.is_dead: target.killed_by_fire = false
	return actual


func apply_damage(actor: BattleCharacter, target: BattleCharacter, amount: int, options: Dictionary = {}) -> int:
	var event := options.duplicate()
	event.merge({"attacker": actor, "target": target, "amount": amount, "kind": "damage"}, true)
	if not event.has("emit_float"): event["emit_float"] = false
	return Resolution.apply(self, event)


func apply_heal(actor: BattleCharacter, target: BattleCharacter, amount: int, revive: bool = false, options: Dictionary = {}) -> int:
	var event := options.duplicate()
	event.merge({"attacker": actor, "target": target, "amount": amount, "kind": "revive" if revive else "heal"}, true)
	if not event.has("emit_float"): event["emit_float"] = false
	return Resolution.apply(self, event)


func _record_settlement(actor: BattleCharacter, target: BattleCharacter, amount: int, kind: String) -> void:
	if actor and actor.is_player and kind in ["damage", "heal", "revive"]:
		var key := actor.summoner_member_id if actor.is_summoned_pet and not actor.summoner_member_id.is_empty() else actor.member_id
		if not key.is_empty():
			var totals := damage_stats if kind == "damage" else healing_stats
			totals[key] = totals.get(key, 0) + amount
	effect_settled.emit(actor, target, amount, kind)


func flush_pending_damage() -> void:
	# 先移出队列，防止同步死亡信号等回调重入导致同一伤害执行两次。
	var batch := pending_damage.duplicate()
	pending_damage.clear()
	var damage_targets: Dictionary = {}
	for event in batch:
		if not event.get("is_heal", false) and event.get("type", "") not in ["heal", "shield"]:
			damage_targets[event.target] = true
	var group := damage_targets.size() > 1
	if group: preload("res://Script/Battle/FishBond.gd").begin_group(self)
	for event in batch:
		event["kind"] = "shield" if event.type == "shield" else "heal" if event.get("is_heal", false) or event.type == "heal" else "damage"
		Resolution.apply(self, event)
		if event.kind == "heal":
			_apply_extra_heal_targets(event.get("attacker"), event.target, event.amount, event.get("heal_size", "medium"), event.get("skill_id", ""))
	if group: preload("res://Script/Battle/FishBond.gd").end_group(self)

## 同一次群伤的事件包括 attacker / target / amount。
func apply_damage_group(events: Array) -> Array[int]:
	preload("res://Script/Battle/FishBond.gd").begin_group(self)
	var amounts: Array[int] = []
	for event in events: amounts.append(Resolution.apply(self, event))
	preload("res://Script/Battle/FishBond.gd").end_group(self)
	return amounts


## 执行保护者瞬移（在敌人开始移动前调用）
func flush_guard_warp() -> bool:
	if pending_guard_anim.is_empty(): return false
	var guardian: BattleCharacter = pending_guard_anim.guardian
	var ally_pos: Vector2 = pending_guard_anim.ally_global_pos
	if guardian and not guardian.is_dead:
		var nd = guardian.get_parent() as HeroNode
		if nd:
			var target_nd = (pending_guard_anim.ally_node as Node2D)
			var target_z = target_nd.z_index if target_nd else 0
			nd.guard_warp(ally_pos, target_z)
			return true
	pending_guard_anim.clear()
	return false

## 执行保护者归位（在敌人攻击完毕后调用）
func flush_guard_return() -> void:
	if pending_guard_anim.is_empty(): return
	var guardian: BattleCharacter = pending_guard_anim.guardian
	pending_guard_anim.clear()
	if guardian and not guardian.is_dead:
		var nd = guardian.get_parent() as HeroNode
		if nd: nd.guard_return()

## 持续伤害
func _apply_dot(target: BattleCharacter) -> void:
	preload("res://Script/Battle/SancaiFormation.gd").recover_mana(self, target)
	# 持续回血（五气招元等 regen buff）：每回合恢复最大气血百分比
	if target.has_buff("regen"):
		var regen_pct: float = target.get_buff_value("regen")
		if regen_pct == null: regen_pct = 0.05
		var heal_amt = maxi(1, int(target.stats.max_hp * regen_pct))
		var actual = apply_heal(null, target, heal_amt)
		if actual > 0:
			target.sync_visual()
			damage_floated.emit(target, actual, "heal")
			_push_log(GameData._T("LOG_HP_REGEN") % [target.stats.get_display_name(), actual], "heal")
			await get_tree().create_timer(0.3).timeout
	for buff_id in ["poison", "burn"]:
		if not target.has_buff(buff_id):
			continue
		# Boss 免疫灼烧伤害（buff 已被 add_buff 阻挡，此检查为兜底）
		if buff_id == "burn" and target.stats.rank == "boss":
			continue
		
		if buff_id == "burn":
			# 灼烧：按层数多次触发（不同来源各自烧一次）
			var burn_layers: Array = target.buffs.get("burn", {}).get("layers", [])
			for i in range(burn_layers.size()):
				if target.is_dead:
					return
				var dmg = maxi(1, int(target.stats.max_hp * 0.04))
				apply_damage(null, target, dmg, {"secondary": true})
				target.sync_visual()
				damage_floated.emit(target, dmg, "burn")
				target.play_spell_effect("烧伤")
				_push_log(GameData._T("LOG_DOT_DMG") % [
					target.stats.get_display_name(),
					"灼烧",
					dmg
				], "debuff")
				if i < burn_layers.size() - 1:
					await get_tree().create_timer(0.35).timeout
		else:
			# 中毒：单层触发，每回合扣 5% 最大气血
			var dmg = maxi(1, int(target.stats.max_hp * 0.05))
			apply_damage(null, target, dmg, {"secondary": true})
			target.sync_visual()
			damage_floated.emit(target, dmg, "poison")
			_push_log(GameData._T("LOG_DOT_DMG") % [
				target.stats.get_display_name(),
				"中毒",
				dmg
			], "debuff")
			await get_tree().create_timer(0.35).timeout
			if target.is_dead:
				return
	# 裂伤流血（独立处理，使用存储的伤害值）
	if target.has_buff("bleed"):
		var bleed_dmg = target.get_buff_value("bleed")
		if bleed_dmg == null or bleed_dmg < 1:
			bleed_dmg = maxi(1, int(target.stats.max_hp * 0.05))
		apply_damage(null, target, bleed_dmg, {"secondary": true})
		target.sync_visual()
		damage_floated.emit(target, bleed_dmg, "bleed")
		_push_log("%s 流血 %d 点" % [target.stats.get_display_name(), bleed_dmg], "debuff")

## 计算技能落空概率（受双方运气影响：施法者运气高 → 更容易命中）
func _calc_miss_chance(caster: BattleCharacter, target: BattleCharacter, base_miss: float) -> float:
	if base_miss <= 0.0 or caster == null or target == null:
		return base_miss
	var caster_luck = caster.stats.luck + caster.equip_special.get("luck", 0)
	var target_luck = target.stats.luck + target.equip_special.get("luck", 0)
	var miss = base_miss - float(caster_luck - target_luck) / 100.0
	return clampf(miss, 0.0, 1.0)

## Tick 全体 buff
func _tick_all_buffs() -> void:
	for c in party + enemies:
		if not c.is_dead:
			c.tick_buffs()

## Tick 全体冷却
func _tick_all_cooldowns() -> void:
	for key in skill_cooldowns.keys():
		skill_cooldowns[key] -= 1
		if skill_cooldowns[key] <= 0:
			skill_cooldowns.erase(key)

## 查询单个技能冷却（传入角色和技能 ID）
func get_skill_cooldown(actor: BattleCharacter, skill_id: String) -> int:
	return maxi(skill_cooldowns.get(_cd_key(actor, skill_id), 0), actor.skill_wait_remaining(SkillManager.get_skill(skill_id)))

func _cd_key(actor: BattleCharacter, skill_id: String) -> String:
	return actor.stats.get_display_name() + ":" + skill_id


## 根据伤害结果决定浮动数字类型
func _damage_float_type(result) -> String:
	if result.is_crit:
		return "crit"
	if result.is_magic:
		return "magic"
	return "normal"


func _average_speed(group: Array[BattleCharacter]) -> float:
	if group.is_empty():
		return 0.0
	var total = 0.0
	for c in group:
		total += c.get_effective_speed()
	return total / group.size()

# ──────────────────────────────────────────────
# 战斗结束判定
# ──────────────────────────────────────────────
var _battle_ended_flag: bool = false
var _protagonist_defeated := false

func _protagonist_death_ends_battle(character: BattleCharacter) -> bool:
	return GameData.DifficultyDB.protagonist_death_defeat(GameData.difficulty) and character.is_player and not character.is_summoned_pet and character.member_id == "youxiaoyun" and character.is_dead

func _check_battle_end() -> void:
	if _battle_ended_flag:
		return
	var all_enemies_dead = enemies.all(func(e): return e.is_dead)
	var all_party_dead   = party.all(func(c): return c.is_dead)
	var protagonist_dead := _protagonist_defeated or party.any(_protagonist_death_ends_battle)

	if all_enemies_dead or all_party_dead or protagonist_dead:
		_battle_ended_flag = true
		_delayed_revivals.clear()
		preload("res://Script/Battle/MechFusion.gd").clear_all(self)

	if all_enemies_dead and not protagonist_dead:
		_change_state(BattleState.BATTLE_WIN)
		var total_exp = 0
		var total_gold = 0
		for e in enemies:
			total_exp += _calc_exp_reward(e)
			total_gold += _calc_gold_reward(e)
		# 来财：金币收益加成（所有存活队友的来财倍率累乘）
		var gold_boost = 1.0
		for c in party:
			if not c.is_dead:
				gold_boost *= c.get_gold_boost()
		total_gold = maxi(1, int(total_gold * gold_boost))
		# 天赋异禀：经验加成
		var exp_talent_rank = GameData.get_talent_rank("main_exp_boost")
		if exp_talent_rank > 0:
			total_exp = int(total_exp * (1.0 + exp_talent_rank * 0.15))
		# 财迷心窍：金币加成
		var gold_talent_rank = GameData.get_talent_rank("main_gold_boost")
		if gold_talent_rank > 0:
			total_gold = int(total_gold * (1.0 + gold_talent_rank * 0.15))
		if GameData.is_night_time():
			total_exp = int(total_exp * 1.5)
			total_gold = int(total_gold * 1.5)
		var level_ups: Array = []
		# 在统一结算处应用，显示奖励与实际入账一致，且不影响金币。
		total_exp *= GameData.get_battle_exp_multiplier()
		for i in party.size():
			var c = party[i]
			if c.is_dead:
				continue
			var old_skills: Array = []
			if not c.member_id.is_empty():
				old_skills = GameData.get_all_skills(c.member_id).duplicate()
			var old_level: int = c.stats.level
			var did_level_up = c.gain_exp(total_exp)
			var new_skills: Array = []
			if not c.member_id.is_empty():
				GameData.gain_exp(c.member_id, total_exp)
				var all_skills = GameData.get_all_skills(c.member_id)
				for sk in all_skills:
					if sk not in old_skills:
						new_skills.append(sk)
			elif not c.pet_id.is_empty():
				var pet: PetData = GameData.pet_db.get(c.pet_id)
				if pet != null:
					pass
			elif c.stats.character_class == "铁甲":
				if GameData.mech_db.has(c.stats.get_display_name()):
					var m: Dictionary = GameData.mech_db[c.stats.get_display_name()]
					m.exp = m.get("exp", 0) + total_exp
			if did_level_up:
				_push_log(GameData._T("LOG_LV_UP") % [c.stats.get_display_name(), c.stats.level], "system")
				level_ups.append({
					"name": c.stats.get_display_name(),
					"old_level": old_level,
					"new_level": c.stats.level,
					"new_skills": new_skills,
					"new_hp": c.stats.max_hp,
					"new_mp": c.stats.max_mp,
					"atk_gain": c.stats.attack,
					"def_gain": c.stats.defense,
				})
		var gold_gained: int = GameData.add_gold(total_gold)
		# 等死亡动画播放
		await get_tree().create_timer(1.2).timeout
		for e in enemies:
			var nd = e.get_parent()
			if nd: nd.visible = false
		await get_tree().create_timer(0.5).timeout
		battle_ended.emit(true, total_exp, gold_gained, level_ups)

	elif all_party_dead or protagonist_dead:
		_change_state(BattleState.BATTLE_LOSE)
		_push_log("【困难模式】主角死亡，战斗失败！" if protagonist_dead else GameData._T("LOG_ALL_DEAD"), "system")
		await get_tree().create_timer(0.5).timeout
		battle_ended.emit(false, 0, 0, [])

func _calc_exp_reward(enemy: BattleCharacter) -> int:
	if enemy.stats.exp_reward > 0:
		return enemy.stats.exp_reward
	var avg_level = 0
	for c in party:
		avg_level += c.stats.level
	avg_level = avg_level / maxi(1, party.size())
	# 怪物经验按自身等级计算（20+20lv）×阶段系数，与主角升级需求同档对应
	var base = CharacterStats.calc_monster_exp(enemy.stats.level)
	var diff = enemy.stats.level - avg_level
	return maxi(5, int(base * (1.0 + diff * 0.1)))

func _calc_gold_reward(enemy: BattleCharacter) -> int:
	var base = 20 + enemy.stats.level * 10
	return maxi(5, base + randi() % maxi(1, base / 3))

# ──────────────────────────────────────────────
# 工具
# ──────────────────────────────────────────────
func _change_state(new_state: BattleState) -> void:
	if new_state == BattleState.PLAYER_ACTION and state != BattleState.PLAYER_ACTION:
		preload("res://Script/Battle/AccessoryEffects.gd").begin_action(_current_actor)
	if new_state == BattleState.CHECK_BATTLE_END:
		preload("res://Script/Battle/AccessoryEffects.gd").finish_turn(_current_actor, self)
	state = new_state
	if new_state == BattleState.CHECK_BATTLE_END:
		_tick_all_cooldowns()
	state_changed.emit(new_state)

func _push_log(text: String, log_type: String = "system") -> void:
	log_pushed.emit(text, log_type)

## 更新骨精灵鬼魂计数 Label
func _update_ghost_label() -> void:
	for c in party:
		if c.member_id == "gujingling":
			var nd = c.get_parent()
			var ghost = nd.get_node_or_null("Ghost") as AnimatedSprite2D if nd else null
			if ghost:
				var count = c.trait_data.get("_ghost_count", 0)
				var lbl = ghost.get_node_or_null("Label") as Label
				if lbl: lbl.text = str(count)
				ghost.visible = count > 0 and _is_ghost_owner_home(c)
			break

## 骨精灵是否在原点（鬼魂只有在家才显示）
func _is_ghost_owner_home(c: BattleCharacter) -> bool:
	var nd = c.get_parent()
	if nd == null: return true
	return nd.position.distance_to(nd.get_meta("_ghost_home", nd.position)) < 5.0

## 记录骨精灵原点
func _record_ghost_home() -> void:
	for c in party:
		if c.member_id == "gujingling":
			var nd = c.get_parent()
			if nd:
				nd.set_meta("_ghost_home", nd.position)
			break

## 隐藏/显示骨精灵鬼魂（同时更新数字）
func _set_ghost_visible(v: bool) -> void:
	for c in party:
		if c.member_id == "gujingling":
			var nd = c.get_parent()
			var ghost = nd.get_node_or_null("Ghost") if nd else null
			if ghost:
				var count = c.trait_data.get("_ghost_count", 0)
				var lbl = ghost.get_node_or_null("Label") as Label
				if lbl: lbl.text = str(count)
				ghost.visible = v and count > 0
			break

## 是否让骨精灵离开原点的移动类技能
func _is_movement_skill(skill_id: String) -> bool:
	return skill_id in ["双生", "割喉之战", "暗影突袭", "横扫千军", "破釜沉舟", "瞬狱影杀阵", "阎王令"]

func _play_error_sound() -> void:
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://Audio/SE/057-Wrong01.ogg")
	snd.bus = "SFX"
	add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)

func _on_character_died(character: BattleCharacter) -> void:
	print("[DEBUG 死亡] %s 死亡，检查复活..." % character.stats.get_display_name())
	# 清理保护关系
	var to_erase: Array = []
	for k in guard_relations:
		if k == character or guard_relations[k] == character:
			to_erase.append(k)
	for k in to_erase:
		guard_relations.erase(k)
	# 敌人死亡音效
	if not character.is_player:
		var parent = character.get_parent()
		if parent:
			var die_snd = parent.get_node_or_null("Audio_Die") as AudioStreamPlayer2D
			if die_snd:
				die_snd.stream = load("res://Audio/SE/怪叫-1.ogg")
				die_snd.volume_db = - 2
				die_snd.play()
	else:
		# 友军死亡音效
		var snd = AudioStreamPlayer.new()
		snd.stream = load("res://Audio/SE/011-System11.ogg")
		snd.bus = "SFX"
		add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)

	if not _battle_ended_flag and _protagonist_death_ends_battle(character):
		_protagonist_defeated = true
		await _check_battle_end()
		return
	var revive_chance_pct = character.trait_data.get("复生", character.trait_data.get("_revive", 0))
	print("[DEBUG 复活] %s 复生概率=%d%%" % [character.stats.get_display_name(), revive_chance_pct])
	if revive_chance_pct > 0 and randi() % 100 < revive_chance_pct:
		# 死亡复活：回满血
		apply_heal(null, character, character.get_effective_max_hp(), true)
		character.sync_visual()
		_push_log(GameData._T("LOG_REVIVE") % character.stats.get_display_name(), "system")
		damage_floated.emit(character, character.get_effective_max_hp(), "heal")
		return
	# 神佑复生：有概率复活
	if character._has_book_type("revive"):
		var revive_chance = 0.0
		var revive_hp_pct = 0.5
		for b in character.book_skills:
			var bdb = SkillDB.BOOK_SKILL_DB.get(b, {})
			if bdb.get("type", "") == "revive":
				revive_chance = max(revive_chance, bdb.get("value", 0.0))
		if "高级神佑复生" in character.book_skills:
			revive_hp_pct = 1.0
		if randf() < revive_chance:
			var heal_amt = maxi(1, int(character.stats.max_hp * revive_hp_pct))
			apply_heal(null, character, heal_amt, true)
			character.sync_visual()
			_push_log(GameData._T("LOG_REVIVE") % character.stats.get_display_name(), "system")
			damage_floated.emit(character, heal_amt, "heal")
			return
	preload("res://Script/Battle/DelayedRevival.gd").schedule(self, character)
	_push_log(GameData._T("LOG_DEAD") % character.stats.get_display_name(), "system")
	# 赏金任务：击杀追踪
	if not character.is_player:
		var enemy_name = character.stats.character_name
		for rank in [BountyData.Rank.DING, BountyData.Rank.BING, BountyData.Rank.YI, BountyData.Rank.JIA]:
			for b in BountyData.TASK_POOL.get(rank, []):
				var bid = b.get("id", "")
				if bid.is_empty(): continue
				if not GameData.active_bounties.has(bid): continue
				if b.get("kill_target", "") == enemy_name:
					var flag_key = "bounty_kill_" + bid
					var cur = GameData.game_flags.get(flag_key, 0)
					GameData.game_flags[flag_key] = cur + 1
					var req = b.get("kill_required", 1)
					if cur + 1 >= req:
						_push_log(GameData._T("LOG_BOUNTY_KILL_DONE") % b.get("name", ""), "system")
	# 吞噬：击杀者永久获得 HP
	if not character.is_player and character.last_attacker:
		var killer = character.last_attacker
		if killer.trait_data.has("吞噬") and not killer.is_dead:
			var cfg = killer.trait_data["吞噬"]
			var lv_floor = cfg.get("level_floor", 5)
			if character.stats.level >= killer.stats.level - lv_floor:
				var gain = cfg.get("hp_gain", 4)
				killer.stats.max_hp += gain
				killer.current_hp = mini(killer.get_effective_max_hp(), killer.current_hp + gain)
				if not killer.member_id.is_empty() and GameData.party_db.has(killer.member_id):
					GameData.party_db[killer.member_id].max_hp += gain
				killer.sync_visual()
				_push_log(GameData._T("LOG_DEVOUR") % [killer.stats.get_display_name(), gain], "system")
	character.last_attacker = null
	if not character.pet_id.is_empty() and character.is_summoned_pet:
		summoned_pet_ids.erase(character.pet_id)
	_threat_mgr.clear_threat(character)
	# 兽王血脉：宠物死亡后更新
	if character.is_summoned_pet:
		refresh_summon_synergies()
	_update_element_resonance()
	await _check_battle_end()

# ══════════════════════════════════════════════
# 五行共鸣
# ══════════════════════════════════════════════
const _ELEM_BUFFS := {
	CharacterStats.Element.FIRE:  { "dmg": "matk_up", "name": "火之共鸣" },
	CharacterStats.Element.METAL: { "dmg": "atk_up",  "name": "金之共鸣" },
	CharacterStats.Element.WATER: { "dmg": "haste",   "name": "水之共鸣" },
	CharacterStats.Element.EARTH: { "dmg": "def_up",  "name": "土之共鸣" },
	CharacterStats.Element.WOOD:  { "dmg": "heal_up", "name": "木之共鸣" },
}

func _update_element_resonance() -> void:
	for c in party:
		c.trait_data.erase("_elem_resonance")
	var counts: Dictionary = {}
	for c in party:
		if c.is_dead: continue
		var e = c.stats.element
		if e == CharacterStats.Element.NONE: continue
		counts[e] = counts.get(e, 0) + 1
	for elem in counts:
		var count: int = counts[elem]
		if count < 2: continue
		var info: Dictionary = _ELEM_BUFFS.get(elem, {})
		var buff_id: String = info.get("dmg", "")
		if buff_id.is_empty(): continue
		var value = 1.20 if count >= 5 else (1.15 if count >= 4 else (1.10 if count >= 3 else 1.05))
		for c in party:
			if c.is_dead: continue
			if not c.trait_data.has("_elem_resonance"):
				c.trait_data["_elem_resonance"] = {}
			c.trait_data["_elem_resonance"][buff_id] = value
	# 五行齐全（不含无属性）：额外小幅加成
	if counts.keys().size() >= 5:
		for c in party:
			if c.is_dead: continue
			if not c.trait_data.has("_elem_resonance"):
				c.trait_data["_elem_resonance"] = {}
			for k in ["atk_up", "matk_up", "def_up", "haste", "hp_up"]:
				c.trait_data["_elem_resonance"]["all_" + k] = 1.1

func consume_talisman() -> bool:
	return TalismanRules.consume(self, _current_actor)

func talisman_targets(actor: BattleCharacter, target: BattleCharacter) -> Array[BattleCharacter]:
	return TalismanRules.targets(self, actor, target)

func talisman_damage(actor: BattleCharacter, target: BattleCharacter) -> int:
	return TalismanRules.damage(actor, target)

func apply_talisman_support(actor: BattleCharacter, target: BattleCharacter) -> void:
	TalismanRules.support(self, actor, target)

func talisman_support_targets(target: BattleCharacter) -> Array[BattleCharacter]:
	return TalismanRules.support_targets(self, target)

func apply_buff(actor: BattleCharacter, target: BattleCharacter, id: String, turns: int, value = null, source: String = "", record_threat: bool = true) -> void:
	Resolution.apply_buff(self, actor, target, id, turns, value, source, record_threat)

func _resolve_skill_effects(result: SkillManager.SkillResult, actor: BattleCharacter, target: BattleCharacter) -> void:
	if not result.success: return
	var effects := result.effects.duplicate()
	result.effects.clear()
	for effect in effects:
		if preload("res://Script/Battle/AccessoryEffects.gd").blocks_debuff(target, effect.id, actor):
			if result.applied_buff == effect.id: result.applied_buff = ""
			result.log_text += "（%s免疫负面效果）" % target.stats.get_display_name()
		apply_buff(actor, target, effect.id, effect.turns, effect.get("value"), effect.get("source", ""))

func recover_after_battle() -> void:
	var rank := GameData.get_talent_rank("support_battle_end_heal")
	if rank <= 0: return
	for character in party:
		if not character.is_dead and character.talent_rank("support_battle_end_heal") > 0:
			apply_heal(null, character, int(character.get_effective_max_hp() * 0.05 * rank))
			character.restore_mp(int(character.get_effective_max_mp() * 0.05 * rank))

func select_talisman(actor: BattleCharacter, type: int) -> void:
	if actor and type >= 0 and type < TalismanRules.ITEM_IDS.size():
		actor.stats.talisman_type = type as CharacterStats.TalismanType

## 全部召唤物数量；豆兵仍是召唤物，但不用于兽王血脉或宠物槽位计数。
func active_summon_count() -> int:
	var count := _count_summoned_pets()
	for soldier in bean_soldiers:
		if is_instance_valid(soldier) and not soldier.is_dead: count += 1
	return count

func refresh_summon_synergies() -> void:
	# 兽王血脉仅统计正式宠物/机甲，豆兵不计入。
	var count := _count_summoned_pets()
	for character in party:
		if is_instance_valid(character) and not character.is_dead: character.recalc_summon_buffs(count)
