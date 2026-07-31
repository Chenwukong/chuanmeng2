# BattleManager.gd
# 战斗核心控制器 - 支持多角色 vs 多敌人
# 将此脚本挂载到战斗场景的根节点
class_name BattleManager
extends Node

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

@export var action_delay: float = 2.0

@onready var enemy_ai: EnemyAI = $EnemyAI

# ── 待显示伤害（动画完成后才展示）────────────
var pending_damage: Array[Dictionary] = []
var pending_guard_anim: Dictionary = {}  # { guardian, ally_global_pos, ally_node }

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
	summoned_pet_ids.clear()
	summoned_mech_ids.clear()
	turn_count = 0
	_threat_mgr = ThreatManager.new()
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

	for i in enemy_chars.size():
		var c: BattleCharacter = enemy_chars[i]
	
		c.setup(enemy_stats[i], false)
		c.died.connect(_on_character_died.bind(c))
		enemies.append(c)

	player_inventory = inventory
	enemy_ai.setup(self)
	# 兽王血脉：初始化所有角色的宠物计数
	var pet_count = 0
	for c in party:
		if c.is_summoned_pet and not c.is_dead: pet_count += 1
	for c in party:
		c.recalc_summon_buffs(pet_count)
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
	bc.died.connect(_on_character_died.bind(bc))
	party.append(bc)
	if not pet_id.is_empty():
		summoned_pet_ids.append(pet_id)
	# 兽王血脉：更新所有角色的宠物计数
	var pet_count = 0
	for c in party:
		if c.is_summoned_pet and not c.is_dead: pet_count += 1
	for c in party:
		c.recalc_summon_buffs(pet_count)
	_update_element_resonance()
	_push_log(GameData._T("LOG_JOIN_BATTLE") % bc.stats.get_display_name(), "system")
	party_changed.emit()

## 移除角色（替换宠物时使用）
func remove_character(bc: BattleCharacter) -> void:
	party.erase(bc)
	if not bc.pet_id.is_empty():
		summoned_pet_ids.erase(bc.pet_id)
	# 兽王血脉更新
	var pet_count = 0
	for c in party:
		if c.is_summoned_pet and not c.is_dead: pet_count += 1
	for c in party:
		c.recalc_summon_buffs(pet_count)
	_update_element_resonance()
	party_changed.emit()

func start_battle() -> void:
	_battle_ended_flag = false
	# 爆冲天赋：全员开局增加行动条
	var baochong_rank = GameData.get_talent_rank("baochong")
	if baochong_rank > 0:
	#	var bonus_sp = 20.0 if baochong_rank == 1 else 35.0
		var bonus_sp = baochong_rank * 10
		for c in party:
			if not c.is_dead:
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
				e.add_buff("atk_down", 99, rate, "晓之以理")
			break
	# 灵台清明：开局额外灵力
	var spirit_rank = GameData.get_talent_rank("main_spirit")
	if spirit_rank > 0:
		for c in party:
			if not c.is_dead:
				c.current_mp = mini(c.get_effective_max_mp(), c.current_mp + 10 * spirit_rank)
	# 铁壁：护角色血量提升 5%/级
	var hp_rank = GameData.get_talent_rank("guard_hp_up")
	if hp_rank > 0:
		var hp_bonus_pct = 0.05 * hp_rank
		for c in party:
			if not c.is_dead and CharacterStats.has_role(c.stats.role, CharacterStats.Role.GUARD):
				c.current_hp = mini(c.get_effective_max_hp(), c.current_hp + int(c.get_effective_max_hp() * hp_bonus_pct))
	# 先声夺人：开局获得仇恨（按防御%）
	var start_threat_rank = GameData.get_talent_rank("guard_start_threat")
	if start_threat_rank > 0 and _threat_mgr != null:
		for c in party:
			if not c.is_dead and CharacterStats.has_role(c.stats.role, CharacterStats.Role.GUARD):
				var bonus = c.stats.defense * start_threat_rank * 10
				_threat_mgr.force_add(c, bonus)
	_change_state(BattleState.BATTLE_START)
	# 灵兽陪伴：开局自动召唤
	if GameData.get_talent_rank("summon_auto") > 0:
		for pid in GameData.pet_team:
			var pet = GameData.pet_db.get(pid)
			if pet and pid not in summoned_pet_ids and _count_summoned_pets() < get_pet_slot_count():
				var old_state = state
				state = BattleState.PLAYER_TURN
				for ch in party:
					if not ch.is_dead and not ch.is_summoned_pet:
						_current_actor = ch
						_push_log("[灵兽陪伴] 自动召唤 %s！" % pet.character_name, "system")
						var scene = get_parent()
						if scene and scene.has_method("summon_pet"):
							var pet_node = await scene.summon_pet(pet)
							var target = _pick_random_enemy()
							if target and pet_node:
								print("[灵兽神通 auto-summon] rank=", GameData.get_talent_rank("summon_auto_cast"), " skills=", pet.skill_ids)
								if GameData.get_talent_rank("summon_auto_cast") > 0:
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
									target.take_damage(dmg)
									target.sync_visual()
									damage_floated.emit(target, dmg, "normal")
									_push_log("%s 攻击 %s，造成 %d 点伤害" % [pet.character_name, target.stats.get_display_name(), dmg], "player_action")
						break
				state = old_state
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
			var actual = actor.heal(heal_amt)
			if actual > 0:
				actor.sync_visual()
				damage_floated.emit(actor, actual, "heal")
				_push_log(GameData._T("LOG_HP_REGEN") % [actor.stats.get_display_name(), actual], "heal")
				await get_tree().create_timer(0.3).timeout

	# 冰冻/虚弱检查 — 跳过回合（不 await，不占回合时间）
	if actor.is_frozen:
		_push_log(GameData._T("BATTLE_FROZEN") % actor.stats.get_display_name(), "system")
		actor.sync_freeze_anim()
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
	if _双动_first_type == DoubleActionType.NONE:
		_双动_first_type = DoubleActionType.DAMAGE
	_last_skill_id = "普通攻击"
	_last_target = target
	_combo_triggered = false
	_change_state(BattleState.PLAYER_ACTION)
	var result = SkillManager.execute(_current_actor, target, "普通攻击")
	await _apply_skill_result(result, _current_actor, target)
	# 高级连击：45% 概率追加一次普通攻击
	if _current_actor.has_book_skill("高级连击") and not target.is_dead:
		if randf() < 0.45:
			_push_log(GameData._T("LOG_COMBO") % _current_actor.stats.get_display_name(), "player_action")
			var result2 = SkillManager.execute(_current_actor, target, "普通攻击")
			await _apply_skill_result(result2, _current_actor, target)
	await _finish_player_action()

## 使用技能
func player_use_skill(skill_id: String, target: BattleCharacter) -> void:
	if state != BattleState.PLAYER_TURN:
		return
	var cd_key = _cd_key(_current_actor, skill_id)
	# 横扫不休：跳过冷却
	var no_cd = _current_actor.check_no_cooldown_after_skill(skill_id)
	if no_cd:
		_push_log(GameData._T("LOG_NO_CD") % [_current_actor.stats.get_display_name(), "横扫不休"], "player_action")
		_current_actor.show_trait_float("横扫不休")
	print("横扫不休 check: ", no_cd)
	if not no_cd and skill_cooldowns.get(cd_key, 0) > 0:
		_push_log(GameData._T("LOG_SKILL_CD") % [skill_id, skill_cooldowns[cd_key]], "system")
		return
	_last_skill_id = skill_id
	_last_target = target
	_combo_triggered = false
	_change_state(BattleState.PLAYER_ACTION)
	var data = SkillManager.get_skill(skill_id)
	if data == null:
		_push_log(GameData._T("BATTLE_SKILL_NOT_FOUND"), "system")
		await _finish_player_action()
		return

	# 双动：记录首次行动类型，第二次限制不同类（在所有分支之前检查）
	if _current_actor and _current_actor.trait_data.has("双动"):
		var sk_type = DoubleActionType.NONE
		match data.skill_type:
			SkillData.SkillType.PHYSICAL, SkillData.SkillType.MAGIC, SkillData.SkillType.MULTI_HIT:
				sk_type = DoubleActionType.DAMAGE
			SkillData.SkillType.HEAL, SkillData.SkillType.BUFF, SkillData.SkillType.DEBUFF:
				sk_type = DoubleActionType.SUPPORT
		if sk_type == DoubleActionType.NONE:
			pass  # 未分类技能（如召唤）不限制
		elif _双动_first_type == DoubleActionType.NONE:
			_双动_first_type = sk_type
		elif _双动_second_phase and sk_type == _双动_first_type:
			_push_log(GameData._T("LOG_DOUBLE_BLOCKED") % _current_actor.stats.get_display_name(), "system")
			_play_error_sound()
			_change_state(BattleState.PLAYER_TURN)
			# 触发新回合的 UI 刷新和聚焦
			actor_turn_started.emit(_current_actor, true)
			return

	# 预检查：铁甲出击无铁甲时直接失败，不消耗资源
	if skill_id == "铁甲出击":
		var has_mech = false
		for c in party:
			if not c.is_dead and c.stats.character_class == "铁甲":
				has_mech = true
				break
		if not has_mech:
			skill_failed.emit(GameData._T("LOG_MECH_NO_LAUNCH"))
			_push_log(GameData._T("LOG_MECH_NO_LAUNCH"), "system")
			_play_error_sound()
			_change_state(BattleState.PLAYER_TURN)
			return
	
	# 预检查：千变万化不能变成主角
	if skill_id == "千变万化" and target and (target == _current_actor or target.is_dead or CharacterStats.has_role(target.stats.role, CharacterStats.Role.MAIN)):
		skill_failed.emit(GameData._T("BATTLE_CANT_TRANSFORM"))
		_push_log(GameData._T("BATTLE_CANT_TRANSFORM"), "system")
		_play_error_sound()
		_change_state(BattleState.PLAYER_TURN)
		return
	
	if data.cooldown_turns > 0 and not no_cd:
		skill_cooldowns[cd_key] = data.cooldown_turns
	# 慧根：MP 消耗减免
	var actual_mp_cost = data.mp_cost
	if _current_actor.get_mp_cost_reduction() > 0:
		actual_mp_cost = maxi(1, int(data.mp_cost * (1.0 - _current_actor.get_mp_cost_reduction())))
	if actual_mp_cost > 0 and not _current_actor.use_mp(actual_mp_cost):
		_push_log(GameData._T("BATTLE_LOW_MP"), "system")
		await _finish_player_action()
		return

	# 舍生取义：检查血量条件
	if skill_id == "舍生取义":
		var sac_data = SkillManager.get_skill(skill_id)
		if sac_data and _current_actor.current_hp <= _current_actor.get_effective_max_hp() * sac_data.sacrifice_hp_pct:
			_push_log("[舍生取义] 气血不足，无法施放！", "system")
		_play_error_sound()
		await _finish_player_action()
		return

	# 摄魂痛击：绑定死亡计数
	if skill_id == "摄魂痛击" and target and not target.is_dead:
		target.died.connect(func():
			_current_actor.trait_data["_soul_strike_kills"] = _current_actor.trait_data.get("_soul_strike_kills", 0) + 1
			_push_log("【摄魂痛击】威力提升！当前 %d 层" % _current_actor.trait_data["_soul_strike_kills"], "system")
		, CONNECT_ONE_SHOT)

	# 愈战愈勇：伤害类技能才叠层（BUFF/HEAL 不算）
	if data.skill_type != SkillData.SkillType.BUFF and data.skill_type != SkillData.SkillType.HEAL:
		_current_actor.apply_stacking_buff()

	# 驭鬼术特性：使用技能时鬼魂 +1（阎王令除外消耗鬼魂，普攻不加）
	if _current_actor.trait_data.has("驭鬼术") and skill_id != "阎王令" and skill_id != "普通攻击":
		var count = _current_actor.trait_data.get("_ghost_count", 0) + 1
		_current_actor.trait_data["_ghost_count"] = count
		_update_ghost_label()

	# 播放技能音效
	if not data.sound_path.is_empty() and ResourceLoader.exists(data.sound_path):
		var snd = AudioStreamPlayer.new()
		snd.stream = load(data.sound_path)
		snd.bus = "SFX"
		add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)

	# 千变万化：变身成一名队友（外观+技能，保留属性）
	if skill_id == "千变万化":
		# 变外观
		var nd = _current_actor.get_parent()
		if nd and nd.has_method("reload_was"):
			nd.reload_was(target.stats.was_base_path)
		# 变技能（保留千变万化）
		var new_skills = target.stats.skill_ids.duplicate()
		if "千变万化" not in new_skills:
			new_skills.append("千变万化")
		_current_actor.stats.skill_ids = new_skills
		# 变远程/近战属性
		_current_actor.stats.is_ranged = target.stats.is_ranged
		_current_actor.stats.role = target.stats.role
		_current_actor.stats.element = target.stats.element
		_current_actor.trait_data = target.trait_data.duplicate()
		_current_actor.stats.traits = target.stats.traits.duplicate()
		_current_actor.stats.was_base_path = target.stats.was_base_path
		_current_actor.trait_data["_metamorphosis"] = true
		_current_actor.metamorphosis_mod = 0.7
		_update_element_resonance()
		_push_log(GameData._T("LOG_TRANSFORM") % [_current_actor.stats.get_display_name(), target.stats.get_display_name()], "player_action")
		_current_actor.show_trait_float("千变万化")
		await _finish_player_action()
		return

	# 寂静剑法：全屏序列帧动画 + 对所有敌人造成物理伤害
	# 全屏法术：对所有存活敌人生效（寂静剑法等）
	if data and data.fullscreen_anim != "":
		var fs_targets: Array[BattleCharacter] = []
		for e in enemies:
			if not e.is_dead:
				fs_targets.append(e)
		var fs_caster = _current_actor.get_parent()
		if fs_caster and fs_caster.has_method("play_cast_sequence"):
			await fs_caster.play_cast_sequence(skill_id)
		if FullscreenAnimation.has_animation(data.fullscreen_anim):
			await FullscreenAnimation.play(data.fullscreen_anim).finished
		for e in enemies:
			if e.is_dead and e.stats.rank != "boss":
				var nd = e.get_parent()
				if nd and is_instance_valid(nd):
					var tw = nd.create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
					tw.tween_property(nd, "position", nd.position + Vector2(-600, -400), 0.8)
					tw.parallel().tween_property(nd, "modulate:a", 0.0, 0.8)
					tw.tween_callback(func(): nd.visible = false)
		_push_log("%s 施展【%s】，全场震撼！" % [_current_actor.stats.get_display_name(), data.skill_name], "player_action")
		for t in fs_targets:
			var tn = t.get_parent() as Node2D
			if tn:
				if tn.has_method("play_hit_reaction"): tn.play_hit_reaction()
				if tn.has_method("play_hit_flash"): tn.play_hit_flash()
			var dmg = maxi(1, int((_current_actor.get_effective_magic_attack() if data.is_magic_damage else _current_actor.get_effective_attack()) * data.damage_multiplier) - int(t.get_effective_defense()))
			dmg = int(dmg * randf_range(0.95, 1.05) * _current_actor.metamorphosis_mod)
			dmg = SkillManager.apply_marked_bonus(_current_actor, t, dmg)
			t.take_damage(dmg)
			t.sync_visual()
			damage_floated.emit(t, dmg, "normal")
		# 全屏法术附带 debuff（灼烧等）
		if data.apply_buff_id != "":
			for t in fs_targets:
				if not t.is_dead and not t.stats.rank == "boss":
					t.add_buff(data.apply_buff_id, data.apply_buff_turns, data.apply_buff_value, data.skill_id)
		await _finish_player_action()
		return

	# 铁甲出击：所有存活的铁甲兽依次攻击目标
	if skill_id == "铁甲出击":
		var mechs: Array[BattleCharacter] = []
		for c in party:
			if not c.is_dead and c.stats.character_class == "铁甲":
				mechs.append(c)
		# 施法者播放施法动画
		var caster_node = _current_actor.get_parent()
		if caster_node and caster_node.has_method("play_cast_sequence"):
			caster_node.play_cast_sequence(skill_id)
		_push_log(GameData._T("LOG_MECH_LAUNCH") % _current_actor.stats.get_display_name(), "player_action")
		for mech in mechs:
			var target_pos = target.get_parent().global_position
			var nd = mech.get_parent() as Node2D
			var on_hit = func():
				var dmg = maxi(1, mech.stats.attack - int(target.get_effective_defense()))
				dmg = int(dmg * randf_range(0.95, 1.05) * _current_actor.metamorphosis_mod)
				target.take_damage(dmg)
				target.sync_visual()
				damage_floated.emit(target, dmg, "normal")
				_push_log(GameData._T("LOG_MECH_ATK") % [mech.stats.get_display_name(), target.stats.get_display_name(), dmg], "player_action")
			if nd and nd.has_method("play_attack_sequence"):
				await nd.play_attack_sequence(target_pos, target.get_parent() as EnemyNode, on_hit)
			else:
				on_hit.call()
			await get_tree().create_timer(0.5).timeout
		await _finish_player_action()
		return

	# 横扫千军：多段攻击动画（走到→连续3刀→回来），每刀结算一次伤害
	# 多段攻击：连续攻击多次（横扫千军、破釜沉舟等）
	if data and data.skill_type == SkillData.SkillType.MULTI_HIT:
		_set_ghost_visible(false)
		# 横扫千军：检查血量条件（HP > 50% 才可用）
		if skill_id == "横扫千军" and _current_actor.current_hp <= _current_actor.get_effective_max_hp() * 0.5:
			_push_log("【横扫千军】气血不足 50%，无法使用！", "system")
			_play_error_sound()
			await _finish_player_action()
			return
		var result = SkillManager.execute(_current_actor, target, skill_id)
		if not result.success:
			_push_log(result.log_text, "system")
			await _finish_player_action()
			return
		# 保护拦截
		var actual_target = target
		if not _current_actor.is_player:
			var g = guard_relations.get(target)
			if g and not g.is_dead:
				actual_target = g
		# 播放多段攻击动画
		var nd = _current_actor.get_parent() as Node2D
		var hits = result.damage_list.size()
		var meta_mul = _current_actor.metamorphosis_mod
		var blitz_total_dmg = 0
		
		# on_hit：命中后立刻结算伤害
		var on_hit = func():
			blitz_total_dmg = 0
			var dmg_list = result.damage_list.duplicate()
			for i in range(dmg_list.size()):
				dmg_list[i] = int(dmg_list[i] * meta_mul)
				blitz_total_dmg += dmg_list[i]
			var actual_total = 0
			for dmg in dmg_list:
				var actual = actual_target.take_damage(dmg)
				actual_total += actual
				if actual_target.is_dead:
					break
			actual_target.sync_visual()
			damage_floated.emit(actual_target, blitz_total_dmg, "crit" if result.is_crit else "normal")
			_push_log(result.log_text, "player_action")
		
		if nd and nd.has_method("play_blitz_sequence") and skill_id == "暗影突袭":
			var sk_sound = data.sound_path if data else ""
			await nd.play_blitz_sequence(target.get_parent().global_position, actual_target.get_parent() as Node2D, hits, on_hit, sk_sound)
		elif nd and nd.has_method("play_multihit_sequence"):
			await nd.play_multihit_sequence(target.get_parent().global_position, actual_target.get_parent() as Node2D, hits, on_hit)
		else:
			await on_hit.call()
			await get_tree().create_timer(0.3).timeout
		# 回原位后回血
		_apply_lifesteal(_current_actor, blitz_total_dmg)
		_set_ghost_visible(true)
		# 横扫千军专属：降低双抗 30% 持续 3 回合
		if skill_id == "横扫千军":
			_current_actor.add_buff("def_broken", 3, 0.7, skill_id)
			_current_actor.add_buff("mdef_broken", 3, 0.7, skill_id)
			_push_log("【横扫千军】%s 双抗降低 30%" % _current_actor.stats.get_display_name(), "system")
		await _finish_player_action()
		return

	# 一苇渡江：目标必加速 + 随机3个未加速队友加速
	if skill_id == "一苇渡江":
		_apply_aoe_buff(target, "haste", 3, data.apply_buff_value if data.apply_buff_value != 0.0 else 1.3, skill_id)
		_try_add_lantern_to_targets(target)
		return
	if skill_id == "神行步":
		_apply_aoe_buff(target, "haste", 3, data.apply_buff_value if data.apply_buff_value != 0.0 else 1.3, skill_id)
		_try_add_lantern_to_targets(target)
		return
	# 达摩护体 / 金刚护体 / 金刚护法：目标 + 随机3个队友
	if skill_id == "达摩护体":
		_apply_aoe_buff(target, "hp_up", 3, data.apply_buff_value if data.apply_buff_value != 0.0 else 1.3, skill_id)
		_try_add_lantern_to_targets(target)
		return
	if skill_id == "金刚护体":
		_apply_aoe_buff(target, "def_up", 3, data.apply_buff_value if data.apply_buff_value != 0.0 else 1.5, skill_id)
		_try_add_lantern_to_targets(target)
		return
	if skill_id == "金刚护法":
		_apply_aoe_buff(target, "atk_up", 3, data.apply_buff_value if data.apply_buff_value != 0.0 else 1.5, skill_id)
		_try_add_lantern_to_targets(target)
		return
	if skill_id == "金刚护魂":
		_apply_aoe_buff(target, "mdef_up", 3, data.apply_buff_value if data.apply_buff_value != 0.0 else 1.5, skill_id)
		_try_add_lantern_to_targets(target)
		return

	# 群体治疗（如沐春风等）：extra>0 的 HEAL 技能
	if data and data.skill_type == SkillData.SkillType.HEAL and data.extra_targets > 0:
		var heal_targets: Array[BattleCharacter] = [target]
		var base_extra = data.extra_targets
		var max_targets = base_extra + _get_extra_heal_target_count(_current_actor)
		var candidates: Array[BattleCharacter] = []
		for c in party:
			if c != target and not c.is_dead:
				candidates.append(c)
		candidates.shuffle()
		for j in mini(max_targets - 1, candidates.size()):
			heal_targets.append(candidates[j])

		for h in heal_targets:
			h.play_spell_effect(skill_id)

		var caster_node2 = _current_actor.get_parent()
		if caster_node2 and caster_node2.has_method("play_cast_sequence"):
			await caster_node2.play_cast_sequence(skill_id)

		for h in heal_targets:
			var amt = int(h.stats.max_hp * data.heal_multiplier) + data.flat_heal
			amt = int(amt * _current_actor.metamorphosis_mod)
			# 点天灯：灯累计3个时触发回血，加到本次治疗量里
			if _current_actor and _current_actor.trait_data.has("点天灯"):
				var lantern_heal = _try_add_lantern_to(h)
				if lantern_heal > 0:
					amt += lantern_heal
			var actual = h.heal(amt)
			h.sync_visual()
			damage_floated.emit(h, amt, "heal")
			_push_log(GameData._T("LOG_ITEM_HEAL") % [h.stats.get_display_name(), amt], "system")
		await get_tree().create_timer(action_delay).timeout
		await _finish_player_action()
		return

	# 群体增益：选中目标 + 随机 extra 个队友
	if data and data.skill_type == SkillData.SkillType.BUFF and data.extra_targets > 0:
		var buff_targets: Array[BattleCharacter] = [target]
		var other_allies: Array[BattleCharacter] = []
		for c in party:
			if c != target and not c.is_dead:
				other_allies.append(c)
		other_allies.shuffle()
		for j in mini(data.extra_targets, other_allies.size()):
			buff_targets.append(other_allies[j])

		for bt in buff_targets:
			bt.play_spell_effect(skill_id)

		var caster_node2 = _current_actor.get_parent()
		if caster_node2 and caster_node2.has_method("play_cast_sequence"):
			await caster_node2.play_cast_sequence(skill_id)

		for bt in buff_targets:
			bt.add_buff(data.apply_buff_id, data.apply_buff_turns, data.apply_buff_value, data.skill_id)
			# 金刚护体：额外施加魔防
			if skill_id == "金刚护体":
				bt.add_buff("mdef_up", data.apply_buff_turns, data.apply_buff_value, data.skill_id)
			# 金刚护法：额外施加魔攻
			elif skill_id == "金刚护法":
				bt.add_buff("matk_up", data.apply_buff_turns, data.apply_buff_value, data.skill_id)
		await _finish_player_action()
		return

	# 群体物理/法术：选中目标 + 随机 extra 个其他敌人
	if data and data.extra_targets > 0 and (data.skill_type == SkillData.SkillType.MAGIC or data.skill_type == SkillData.SkillType.PHYSICAL):
		var targets: Array[BattleCharacter] = [target]
		var other_enemies: Array[BattleCharacter] = []
		for e in enemies:
			if e != target and not e.is_dead:
				other_enemies.append(e)
		other_enemies.shuffle()
		for j in mini(data.extra_targets, other_enemies.size()):
			targets.append(other_enemies[j])

		for t in targets:
			var tn = t.get_parent() as Node2D
			if tn:
				if tn.has_method("play_hit_once"):
					tn.play_hit_once()
				if tn.has_method("play_hit_flash"):
					tn.play_hit_flash()
			t.play_spell_effect(skill_id)

		var caster_node = _current_actor.get_parent()
		if caster_node and caster_node.has_method("play_cast_sequence"):
			await caster_node.play_cast_sequence(skill_id)

		var is_magic = data.is_magic_damage
		var eff_atk = _current_actor.get_effective_magic_attack() if is_magic else _current_actor.get_effective_attack()
		var night_mul = _current_actor.get_night_dmg_mul()
		for t in targets:
			var def_val = t.get_effective_magic_defense() if is_magic else t.get_effective_defense()
			var dmg = maxi(1, int(eff_atk * data.damage_multiplier * night_mul) - int(def_val * 0.6) + data.flat_damage)
			dmg = int(dmg * randf_range(0.95, 1.05))
			dmg = SkillManager.apply_marked_bonus(_current_actor, t, dmg)
			t.take_damage(dmg)
			t.sync_visual()
			damage_floated.emit(t, dmg, "normal")
			_push_log("[群体] %s 受到 %d 点伤害" % [t.stats.get_display_name(), dmg], "enemy_action")
			var tn = t.get_parent() as Node2D
			if tn and tn.has_method("play_idle") and not t.is_dead:
				tn.play_idle()
			await get_tree().create_timer(0.3).timeout

		await _finish_player_action()
		return

	# 割喉之战：瞬移到敌人背后背刺
	if skill_id == "割喉之战":
		var nd = _current_actor.get_parent() as Node2D
		if nd:
			var orig_pos = nd.position
			var orig_z = nd.z_index
			var orig_dir = nd.get_node("WASAnimationPlayer").direction if nd.has_node("WASAnimationPlayer") else 0
			_set_ghost_visible(false)
			nd.z_index = 1
			var enemy_nd = target.get_parent() as Node2D
			var local_target = nd.get_parent().to_local(enemy_nd.global_position) if enemy_nd else target.get_parent().position
			# 瞬移到敌人背后（左边）
			nd.position = local_target + Vector2(-60, -30)
			# 朝左（方向1）
			if nd.has_node("WASAnimationPlayer"):
				var was = nd.get_node("WASAnimationPlayer")
				was.direction = 0
				was.play("attack", false)
			elif nd.has_method("play"):
				nd.play("attack", false)
			# 武器方向同步
			var weapon_was = nd.get_node_or_null("WeaponWAS")
			if weapon_was:
				weapon_was.direction = 2
			# 目标受击 + 武器特效
			if enemy_nd and enemy_nd.has_method("play_hit_reaction"):
				enemy_nd.play_hit_reaction()
			if nd.has_method("_spawn_hit_effect"):
				nd._spawn_hit_effect(enemy_nd)
			# 执行技能（伤害计算）
			var result = SkillManager.execute(_current_actor, target, skill_id)
			if result.success:
				for dmg in result.damage_list:
					target.take_damage(dmg)
				target.sync_visual()
				damage_floated.emit(target, result.damage_list[0] if result.damage_list.size() > 0 else 0, "crit" if result.is_crit else "normal")
				_push_log(result.log_text, "player_action")
			# 走回来
			await get_tree().create_timer(1).timeout
			nd.position = orig_pos
			nd.z_index = orig_z
			_set_ghost_visible(true)
			if nd.has_node("WASAnimationPlayer"):
				var was = nd.get_node("WASAnimationPlayer")
				was.direction = orig_dir
				was.play("idle", false)
			# 回到原位后才回血
			if result.success:
				_apply_lifesteal(_current_actor, result.damage_list[0] if result.damage_list.size() > 0 else 0)
		await _finish_player_action()
		return

	# 双生：姐妹协同攻击
	if skill_id == "双生":
		var partner_id = "yingjingling" if _current_actor.member_id == "gujingling" else "gujingling"
		var partner: BattleCharacter = null
		for c in party:
			if c.member_id == partner_id and not c.is_dead:
				partner = c
				break
		if partner == null:
			_push_log("【双生】姐妹不在场，无法使用！", "system")
			_play_error_sound()
			await _finish_player_action()
			return
		# 执行技能计算伤害
		var result = SkillManager.execute(_current_actor, target, skill_id)
		if not result.success:
			_push_log(result.log_text, "system")
			await _finish_player_action()
			return
		# 获取两姐妹的视觉节点
		var nd1 = _current_actor.get_parent() as Node2D
		var nd2 = partner.get_parent() as Node2D
		var enemy_nd = target.get_parent() as Node2D
		if nd1 and nd2 and enemy_nd:
			var orig1 = nd1.position; var z1 = nd1.z_index
			var orig2 = nd2.position; var z2 = nd2.z_index
			# 保存原始朝向
			var dir1 = nd1.get_node("WASAnimationPlayer").direction if nd1.has_node("WASAnimationPlayer") else 0
			var dir2 = nd2.get_node("WASAnimationPlayer").direction if nd2.has_node("WASAnimationPlayer") else 0
			nd1.z_index = 999; nd2.z_index = 998
			var local_target = nd1.get_parent().to_local(enemy_nd.global_position)
			# 两姐妹瞬移到敌人面前
			nd1.position = local_target + Vector2(-40, -20)
			nd2.position = local_target + Vector2(-40, 20)
			# 设置方向朝右（攻击方向）
			for nd_obj in [nd1, nd2]:
				if nd_obj.has_node("WASAnimationPlayer"):
					var w = nd_obj.get_node("WASAnimationPlayer")
					w.direction = 3
					w.play("attack", false)
			# 先后播放音效（间隔0.1s听出两个人）
			for nd_obj in [nd1, nd2]:
				var atk_snd = nd_obj.get_node_or_null("Audio_Attack") as AudioStreamPlayer
				if atk_snd:
					atk_snd.play()
					await get_tree().create_timer(0.1).timeout
			await get_tree().create_timer(0.15).timeout
			# 交叉飞过敌人：一个左上，一个右上 + 画面一闪 + 关灯
			var dlights = []
			if get_tree():
				dlights = get_tree().root.find_children("", "PointLight2D", true, false)
				dlights += get_tree().root.find_children("", "DirectionalLight2D", true, false)
				dlights += get_tree().root.find_children("", "CanvasModulate", true, false)
			for l in dlights: l.visible = false
			var flash = ColorRect.new()
			flash.color = Color(0, 0, 0, 0)
			flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
			get_tree().root.add_child(flash)
			var vs = get_viewport().size if get_viewport() else Vector2(1920, 1080)
			flash.position = Vector2(0, 0)
			flash.size = vs
			var ft = create_tween()
			ft.tween_property(flash, "color:a", 0.8, 0.05)
			ft.tween_property(flash, "color:a", 0.0, 0.15).set_delay(0.1)
			ft.finished.connect(func(): flash.queue_free(); for l in dlights: l.visible = true)
			var tw1 = create_tween()
			tw1.tween_property(nd1, "position", local_target + Vector2(-80, -100), 0.2)
			var tw2 = create_tween()
			tw2.tween_property(nd2, "position", local_target + Vector2(-80, 100), 0.2)
			if enemy_nd and enemy_nd.has_method("play_hit_reaction"):
				enemy_nd.play_hit_reaction()
			# 扣血
			for dmg in result.damage_list:
				target.take_damage(dmg)
			target.sync_visual()
			damage_floated.emit(target, result.damage_list[0] if result.damage_list.size() > 0 else 0, "crit" if result.is_crit else "normal")
			_push_log(result.log_text, "player_action")
			await get_tree().create_timer(1).timeout
			# 归位（恢复位置/朝向/z）
			nd1.position = orig1; nd1.z_index = z1
			nd2.position = orig2; nd2.z_index = z2
			_set_ghost_visible(true)
			for i in range(2):
				var nd_obj = nd1 if i == 0 else nd2
				var orig_dir = dir1 if i == 0 else dir2
				if nd_obj.has_node("WASAnimationPlayer"):
					var w = nd_obj.get_node("WASAnimationPlayer")
					w.direction = orig_dir
					w.play("idle")
			# 归位后才回血
			var total_d = result.damage_list[0] if result.damage_list.size() > 0 else 0
			_apply_lifesteal(_current_actor, total_d)
		await _finish_player_action()
		return

	# 瞬狱影杀阵：全屏黑暗+隐匿+处决
	if skill_id == "瞬狱影杀阵":
		var nd = _current_actor.get_parent()
		if nd:
			var orig_pos = nd.position; var orig_z = nd.z_index
			var orig_dir = nd.get_node("WASAnimationPlayer").direction if nd.has_node("WASAnimationPlayer") else 0
			nd.z_index = 9999
			# 隐藏鬼魂
			_set_ghost_visible(false)
			# 关闭灯光
			var lights = []
			if get_tree():
				lights = get_tree().root.find_children("", "PointLight2D", true, false)
				lights += get_tree().root.find_children("", "DirectionalLight2D", true, false)
				lights += get_tree().root.find_children("", "CanvasModulate", true, false)
			for l in lights:
				l.visible = false
			# 隐藏队友和其他敌人
			var hidden := []
			for c in party + enemies:
				if c == _current_actor or c == target: continue
				var vn = c.get_parent()
				if vn: vn.visible = false; hidden.append(vn)
			# 施法者防御 + 影分身袭击
			var enemy_nd = target.get_parent()
			if nd.has_method("play_guard_cast"):
				nd.play_guard_cast()
			var clone_dirs := [Vector2(100,0), Vector2(-70,70), Vector2(0,100), Vector2(-70,-70), Vector2(70,-70)]
			var clone_exits := [Vector2(-100,0), Vector2(70,-70), Vector2(0,-100), Vector2(70,70), Vector2(-70,70)]
			if enemy_nd:
				# 预载音效
				var se_stream = load("res://Audio/SE/兵器-入肉.ogg")
				# 复制角色精灵用于影分身
				var char_sprite = nd.get_node_or_null("Sprite2D") as Sprite2D
				for ci in range(clone_dirs.size()):
					var clone_spr: Sprite2D
					if char_sprite:
						clone_spr = char_sprite.duplicate() as Sprite2D
						clone_spr.modulate = Color.BLACK
					else:
						clone_spr = Sprite2D.new()
						var img = Image.create(24, 32, false, Image.FORMAT_RGBA8)
						img.fill(Color(0.2, 0.2, 0.2, 0.8))
						clone_spr.texture = ImageTexture.create_from_image(img)
					clone_spr.centered = true
					clone_spr.z_index = 9999
					clone_spr.position = clone_dirs[ci]
					var dv = clone_exits[ci] - clone_dirs[ci]
					clone_spr.rotation = atan2(dv.y, dv.x)
					enemy_nd.add_child(clone_spr)
					if enemy_nd.has_method("play_hit_flash"):
						enemy_nd.play_hit_flash()
					# 兵器音效
					var se = AudioStreamPlayer.new()
					se.stream = se_stream
					se.bus = "SFX"
					get_parent().add_child(se)
					se.play()
					se.finished.connect(se.queue_free)
					# 飞出淡出
					var ct = create_tween().set_parallel()
					ct.tween_property(clone_spr, "position", clone_exits[ci], 0.15)
					ct.tween_property(clone_spr, "modulate:a", 0.0, 0.15)
					ct.finished.connect(clone_spr.queue_free)
					await get_tree().create_timer(0.18).timeout
			# 全屏黑（CanvasLayer 确保全覆盖）
			var flash_cl = CanvasLayer.new()
			flash_cl.layer = 9999
			get_tree().root.add_child(flash_cl)
			var flash = ColorRect.new()
			flash.color = Color(0, 0, 0, 0)
			flash.set_anchors_preset(Control.PRESET_FULL_RECT)
			flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
			flash_cl.add_child(flash)
			var ft = create_tween()
			ft.tween_property(flash, "color:a", 1.0, 0.2)
			await ft.finished
			# 瞬移到敌人面前穿刺 + 屏幕剧烈震动
			var local_t = nd.get_parent().to_local(enemy_nd.global_position) if enemy_nd else Vector2.ZERO
			nd.position = local_t + Vector2(40, 0)
			GameData.hit_stop(0.05, 0.05, 20.0, 0.5)
			if nd.has_node("WASAnimationPlayer"):
				var w = nd.get_node("WASAnimationPlayer")
				w.direction = 1
				w.play("attack", false)
			# 兵器音效
			var se = AudioStreamPlayer.new()
			se.stream = load("res://Audio/SE/兵器-入肉.ogg")
			se.bus = "SFX"
			get_parent().add_child(se)
			se.play()
			se.finished.connect(se.queue_free)
			if enemy_nd and enemy_nd.has_method("play_hit_reaction"):
				enemy_nd.play_hit_reaction()
			if nd.has_method("_spawn_hit_effect"):
				nd._spawn_hit_effect(enemy_nd)
			# 扣血
			var result = SkillManager.execute(_current_actor, target, skill_id)
			if result.success:
				for dmg in result.damage_list:
					target.take_damage(dmg)
				target.sync_visual()
				damage_floated.emit(target, result.damage_list[0] if result.damage_list.size() > 0 else 0, "crit" if result.is_crit else "normal")
				_push_log(result.log_text, "player_action")
			# 处决：低于5%血量的敌人直接死亡
			for e in enemies:
				if not e.is_dead and e.hp_percent() < 0.05:
					e.current_hp = 0
					e.is_dead = true
					e.died.emit()
					_push_log("【瞬狱影杀阵】%s 被处决！" % e.stats.get_display_name(), "system")
			# 恢复
			await get_tree().create_timer(0.5).timeout
			# 恢复可视
			ft = create_tween()
			ft.tween_property(flash, "color:a", 0.0, 0.3)
			await ft.finished
			flash.queue_free()
			flash_cl.queue_free()
			for l in lights:
				l.visible = true
			for vn in hidden:
				vn.visible = true
			nd.position = orig_pos; nd.z_index = orig_z
			_set_ghost_visible(true)
			if nd.has_node("WASAnimationPlayer"):
				var w = nd.get_node("WASAnimationPlayer")
				w.direction = orig_dir
				w.play("idle")
			# 武器恢复 idle
			var weapon_was = nd.get_node_or_null("WeaponWAS")
			if weapon_was:
				weapon_was.direction = orig_dir
				weapon_was.play("idle")
		await _finish_player_action()
		return

	# 阎王令：鬼魂飞击 + 本体攻击
	if skill_id == "阎王令":
		var nd = _current_actor.get_parent()
		var enemy_nd = target.get_parent() as Node2D
		var ghost_count = _current_actor.trait_data.get("_ghost_count", 0)
		# 隐藏鬼魂
		var ghost_node = nd.get_node_or_null("Ghost") if nd else null
		var ghost_tex = null
		if ghost_node:
			var anim_name = ghost_node.animation if ghost_node.animation != "" else "default"
			ghost_tex = ghost_node.sprite_frames.get_frame_texture(anim_name, 0) if ghost_node.sprite_frames and ghost_node.sprite_frames.has_animation(anim_name) else null
			ghost_node.visible = false
		if nd and enemy_nd:
			var orig_pos = nd.position; var orig_z = nd.z_index
			var orig_dir = nd.get_node("WASAnimationPlayer").direction if nd.has_node("WASAnimationPlayer") else 0
			nd.z_index = 9999
			# 远程施法：角色原地不动，鬼魂飞向敌人
			if nd.has_node("WASAnimationPlayer"):
				var w = nd.get_node("WASAnimationPlayer")
				w.direction = 3
				w.play("cast", false)
			var center_local = nd.get_parent().to_local(enemy_nd.global_position)
			for i in range(ghost_count):
				var g = Sprite2D.new()
				if ghost_tex:
					g.texture = ghost_tex
					g.modulate = Color(1, 1, 1, 0.7)
				else:
					var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
					img.fill(Color(0.7, 0.8, 1.0, 0.7))
					g.texture = ImageTexture.create_from_image(img)
				g.centered = true
				g.z_index = 9998
				var start = Vector2(orig_pos.x + randf_range(-30, 30), orig_pos.y + randf_range(-10, 40))
				g.position = start
				nd.get_parent().add_child(g)
				var gt = create_tween().set_parallel()
				gt.tween_property(g, "position", center_local + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.4)
				gt.tween_property(g, "modulate:a", 0.0, 0.4)
				gt.finished.connect(g.queue_free)
			# 鬼魂命中
			await get_tree().create_timer(0.4).timeout
			GameData.hit_stop(0.05, 0.05, 15.0, 0.3)
			# 播放阎王令技能特效
			if target and target.has_method("play_spell_effect"):
				target.play_spell_effect(skill_id)
			if enemy_nd and enemy_nd.has_method("play_hit_reaction"):
				enemy_nd.play_hit_reaction()
			var se = AudioStreamPlayer.new()
			se.stream = load("res://Audio/SE/兵器-入肉.ogg")
			se.bus = "SFX"
			get_parent().add_child(se)
			se.play()
			se.finished.connect(se.queue_free)
			# 扣血
			var result = SkillManager.execute(_current_actor, target, skill_id)
			if result.success:
				for dmg in result.damage_list:
					target.take_damage(dmg)
				target.sync_visual()
				damage_floated.emit(target, result.damage_list[0] if result.damage_list.size() > 0 else 0, "crit" if result.is_crit else "normal")
				_push_log(result.log_text, "player_action")
			# 收招
			await get_tree().create_timer(0.3).timeout
			nd.position = orig_pos; nd.z_index = orig_z
			if nd.has_node("WASAnimationPlayer"):
				var w = nd.get_node("WASAnimationPlayer")
				w.direction = orig_dir
				w.play("idle")
			# 恢复鬼魂显示（归零后保持隐藏）
			if ghost_node:
				ghost_node.visible = _current_actor.trait_data.get("_ghost_count", 0) > 0
		await _finish_player_action()
		return

	var result = SkillManager.execute(_current_actor, target, skill_id)
	await _apply_skill_result(result, _current_actor, target)
	# 阎王令：更新鬼魂标签（计数器已在 _calc_damage 清零）
	if skill_id == "阎王令":
		_update_ghost_label()
	# 鬼影护体 / 鬼煞附体：消耗鬼魂施加效果
	if skill_id == "鬼影护体" or skill_id == "鬼煞附体":
		if data and _current_actor.trait_data.has("驭鬼术"):
			var cost = data.ghost_cost
			var count = _current_actor.trait_data.get("_ghost_count", 0)
			if count < cost:
				_push_log("【%s】鬼魂不足（需要 %d 层，当前 %d 层）！" % [skill_id, cost, count], "system")
			else:
				_current_actor.trait_data["_ghost_count"] = count - cost
				_update_ghost_label()
				if skill_id == "鬼影护体":
					_current_actor.add_buff("ghost_shield", 999, 1.0, skill_id)
					_push_log("【鬼影护体】鬼魂抵挡下一次攻击！", "system")
				elif skill_id == "鬼煞附体":
					_current_actor.add_buff("ghost_boost", data.apply_buff_turns, data.boost_pct, skill_id)
					_push_log("【鬼煞附体】伤害提升 %d%%！" % int(data.boost_pct * 100), "system")
	# 割喉之战：黑雾缠身
	if skill_id == "死亡宣告" and target and not target.is_dead:
		if target.has_method("_show_marked_effect"):
			target._show_marked_effect()
	# 舍生取义：扣除 50% 最大气血 + 降低双抗
	if skill_id == "舍生取义":
	
		if data:
			var hp_cost = int(_current_actor.get_effective_max_hp() * data.sacrifice_hp_pct)
			_current_actor.take_damage(hp_cost)
			_current_actor.sync_visual()
			_push_log("[舍生取义] %s 牺牲 %d 点气血，双抗降低" % [_current_actor.stats.get_display_name(), hp_cost], "player_action")
			_current_actor.add_buff("def_broken", 3, data.sacrifice_def_pct, skill_id)
			_current_actor.add_buff("mdef_broken", 3, data.sacrifice_def_pct, skill_id)
	# 影化：同时加速 + 半透明特效
	if skill_id == "影化":
		_current_actor.add_buff("haste", 3, 1.3, skill_id)
		var nd = _current_actor.get_parent()
		if nd:
			# 渐变为半透明
			var tw = create_tween()
			tw.tween_property(nd, "modulate", Color(1, 1, 1, 0.5), 0.3)
			# buff 结束时恢复（任一 buff 消失即恢复）
			_current_actor.buff_removed.connect(func(_buff_id):
				if is_instance_valid(nd):
					var tw2 = create_tween()
					tw2.tween_property(nd, "modulate", Color(1, 1, 1, 1), 0.3)
			, CONNECT_ONE_SHOT)
	# 点天灯：对队友施法后挂灯笼
	if _current_actor and _current_actor.trait_data.has("点天灯") and target and target.is_player:
		var lh = _try_add_lantern_to(target)
		if lh > 0:
			target.heal(lh)
			target.sync_visual()
	# 嘲讽
	if skill_id == "嘲讽":
		_threat_mgr.taunt(_current_actor)
		_push_log(GameData._T("LOG_TAUNT") % _current_actor.stats.get_display_name(), "player_action")
	# 高级魔法连击：35% 概率再施放一次法术
	if not target.is_dead and _current_actor.has_book_skill("高级魔法连击"):
		if data and (data.is_magic_damage or data.skill_type == SkillData.SkillType.MAGIC):
			if randf() < 0.35:
				_push_log(GameData._T("LOG_MAGIC_COMBO") % _current_actor.stats.get_display_name(), "player_action")
				var result2 = SkillManager.execute(_current_actor, target, skill_id)
				await _apply_skill_result(result2, _current_actor, target)
	await _finish_player_action()

## 使用道具
func player_use_item(item_id: String, target: BattleCharacter) -> void:
	if state != BattleState.PLAYER_TURN:
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

	var result = player_inventory.use_item(item_id, target)
	# 缩地成寸：战后道具不消耗（首次每级一次）
	var free_max := GameData.get_talent_rank("support_free_item")
	if free_max > 0 and _free_items_used < free_max:
		_free_items_used += 1
		
		if slot and slot.get("data") and slot.get("count", 0) < (slot.get("data") as ItemData).max_stack:
			player_inventory.add_item(slot.get("data"), 1)
	_push_log(result.log_text, "heal" if result.heal_amount > 0 else "system")
	if result.heal_amount > 0:
		damage_floated.emit(target, result.heal_amount, "heal")
		target.sync_visual()
	# 治疗量加成（灵石疗伤）
	var heal_bonus := GameData.get_talent_rank("support_heal_power")
	if heal_bonus > 0 and result.heal_amount > 0:
		var extra = int(result.heal_amount * 0.1 * heal_bonus)
		target.heal(extra)
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
		enemy.add_buff("atk_up", 3, 1.2, "time_pref")
		enemy.add_buff("haste", 3, 1.15, "time_pref")
	elif period_name == "day" and pref == "night":
		enemy.add_buff("atk_down", 3, 0.85, "time_pref")
		enemy.add_buff("slow", 3, 0.85, "time_pref")


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
		battle_ended.emit(false, 0, 0, [])
	else:
		_push_log(GameData._T("LOG_FLEE_FAIL"), "system")
		await _finish_player_action()

func _finish_player_action() -> void:
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
		var combo_rank = GameData.get_talent_rank("attack_combo")
		if combo_rank > 0 and _current_actor and not _current_actor.is_dead and _last_target and not _last_target.is_dead:
			var combo_chance = 0.05 * combo_rank
			if randf() < combo_chance:
				_combo_triggered = true
				_push_log("%s 触发连击！" % _current_actor.stats.get_display_name(), "system")
				var result = SkillManager.execute(_current_actor, _last_target, _last_skill_id)
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
		b.add_buff(buff_id, turns, value, skill_id)
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
		main_target.heal(a1)
		main_target.sync_visual()
	var extra = _get_extra_heal_target_count(_current_actor)
	if extra <= 0:
		return
	var cands = party.filter(func(c): return c != main_target and not c.is_dead)
	cands.shuffle()
	for j in mini(extra, cands.size()):
		var a2 = _try_add_lantern_to(cands[j])
		if a2 > 0:
			cands[j].heal(a2)
			cands[j].sync_visual()


## 保护队友 — ally 由 BattleUI 点击选择
func player_guard(ally: BattleCharacter) -> void:
	if state != BattleState.PLAYER_TURN: return
	_change_state(BattleState.PLAYER_ACTION)
	guard_relations[ally] = _current_actor
	# 保护动画：守护者播放防御/守护动画
	var nd = _current_actor.get_parent()
	if nd and nd.has_method("play_guard_cast"):
		nd.play_guard_cast()
	_current_actor.show_trait_float("守护")
	_current_actor.play_dual_spell_effect()
	_push_log(GameData._T("LOG_GUARD_SET") % [_current_actor.stats.get_display_name(), ally.stats.get_display_name()], "player_action")
	await get_tree().create_timer(action_delay).timeout
	# 防御动画播完后切回 idle
	if nd and nd.has_method("play_idle"):
		nd.play_idle()
	await _finish_player_action()

## 召唤宠物上场，宠物会随机攻击一个敌人再归位
func player_summon(pet: PetData, prefer_pos: Vector2 = Vector2.INF) -> void:
	if state != BattleState.PLAYER_TURN: return
	
	# 宠物不能召唤
	if _current_actor.is_summoned_pet:
		_push_log(GameData._T("LOG_PET_CANT"), "system")
		return
	if _count_summoned_pets() >= get_pet_slot_count():
		_push_log("召唤位已满！", "system")
		return
	
	# 只有召系角色能召唤
	if not CharacterStats.has_role(_current_actor.stats.role, CharacterStats.Role.SUMMON):
		_push_log(GameData._T("LOG_ONLY_SUMMONER"), "system")
		return
	
	_change_state(BattleState.PLAYER_ACTION)

	# 施法者播放施法动画
	var caster_node = _current_actor.get_parent()
	if caster_node and caster_node.has_method("play_cast_sequence"):
		caster_node.play_cast_sequence("召唤宠物")

	_push_log(GameData._T("LOG_SUMMON_PET") % [
		_current_actor.stats.get_display_name(), pet.character_name, PetData.apt_name(pet.aptitude)
	], "player_action")

	# 让 BattleScene 创建宠物节点并注册
	var scene = get_parent()
	var pet_node: Node2D = null
	if scene and scene.has_method("summon_pet"):
		pet_node = await scene.summon_pet(pet, prefer_pos)
	else:
		_push_log(GameData._T("LOG_SUMMON_FAIL"), "system")
		await _finish_player_action()
		return

	# 随机选一个存活敌人攻击
	var target = _pick_random_enemy()
	if target == null:
		await _finish_player_action()
		return

	# 灵兽神通：自动施法
	print("[灵兽神通] talent rank=", GameData.get_talent_rank("summon_auto_cast"), " pet skills=", pet.skill_ids, " summoned=", pet.character_name)
	if GameData.get_talent_rank("summon_auto_cast") > 0:
		# 选第一个非普通攻击的技能
		var skill_id = ""
		for sid in pet.skill_ids:
			print("[灵兽神通] pet skill: ", sid, " in db=", SkillManager.get_skill(sid) != null)
			if sid != "普通攻击" and SkillManager.get_skill(sid) != null:
				skill_id = sid
				break
		if skill_id.is_empty() and not pet.skill_ids.is_empty():
			skill_id = pet.skill_ids[0]
		print("[灵兽神通] selected skill_id=", skill_id)
		if not skill_id.is_empty() and SkillManager.get_skill(skill_id) != null:
			_push_log("[灵兽神通] %s 施展 %s！" % [pet.character_name, skill_id], "player_action")
			var bc = pet_node.get_node("BattleCharacter") as BattleCharacter
			var result = SkillManager.execute(bc, target, skill_id)
			if result.success:
				bc = pet_node.get_node("BattleCharacter") as BattleCharacter
				await _apply_skill_result(result, bc, target)
			else:
				await get_tree().create_timer(0.5).timeout
			await _finish_player_action()
			return

	# 执行攻击动画和伤害
	var target_pos = target.get_parent().global_position
	if pet_node and pet_node.has_method("play_attack_sequence"):
		var enemy_nd = target.get_parent() as EnemyNode
		await pet_node.play_attack_sequence(target_pos, enemy_nd)
	else:
		await get_tree().create_timer(0.5).timeout

	_do_pet_attack_damage(pet, target)
	await get_tree().create_timer(action_delay * 0.5).timeout
	await _finish_player_action()


func _do_pet_attack_damage(pet: PetData, target: BattleCharacter) -> void:
	var skill_id = "普通攻击"
	var sk_data = SkillManager.get_skill(skill_id)
	var dmg = maxi(1, pet.attack - int(target.get_effective_defense()))
	dmg = int(dmg * randf_range(0.95, 1.05))
	target.take_damage(dmg)
	target.sync_visual()
	damage_floated.emit(target, dmg, "normal")
	_push_log(GameData._T("LOG_PET_ATK") % [pet.character_name, target.stats.get_display_name(), dmg], "player_action")


## 召唤铁甲兽上场
func player_summon_mech(mech_name: String, replace_bc: BattleCharacter = null) -> void:
	if state != BattleState.PLAYER_TURN: return
	if _current_actor.is_summoned_pet:
		_push_log(GameData._T("LOG_PET_CANT"), "system")
		return
	var mech_data = GameData.mech_db.get(mech_name)
	if mech_data == null:
		_push_log(GameData._T("LOG_MEHC_NOT_FOUND") % mech_name, "system")
		return
	# 消耗 MP 并设置冷却
	var skill_data = SkillManager.get_skill("召唤铁甲兽")
	if skill_data:
		if not _current_actor.use_mp(skill_data.mp_cost):
			_push_log(GameData._T("BATTLE_LOW_MP"), "system")
			return
		if skill_data.cooldown_turns > 0:
			skill_cooldowns[_cd_key(_current_actor, "召唤铁甲兽")] = skill_data.cooldown_turns
	_change_state(BattleState.PLAYER_ACTION)
	# 施法者播放施法动画
	var caster_node = _current_actor.get_parent()
	if caster_node and caster_node.has_method("play_cast_sequence"):
		caster_node.play_cast_sequence("召唤铁甲兽")
	_push_log(GameData._T("LOG_SUMMON_MEHC") % [_current_actor.stats.get_display_name(), mech_data.name], "player_action")
	var stats = CharacterStats.new()
	stats.character_name = mech_data.name; stats.character_class = "铁甲"
	stats.max_hp = 80 + mech_data.level * 15; stats.max_mp = 30
	stats.attack = mech_data.atk; stats.magic_attack = 0
	stats.defense = mech_data.def_; stats.magic_defense = mech_data.def_
	stats.speed = mech_data.spd; stats.level = mech_data.level
	stats.was_base_path = mech_data.was_base_path; stats.role = CharacterStats.Role.SUMMON
	stats.was_direction = 2
	stats.skill_ids = mech_data.get("skills", []).duplicate()
	var scene = get_parent()
	var pet_node: Node2D = null
	if scene and scene.has_method("summon_mech_pet"):
		var prefer_pos = Vector2.INF
		if replace_bc and replace_bc.get_parent():
			prefer_pos = replace_bc.get_parent().position
			var old_node = replace_bc.get_parent() as Node2D
			if old_node:
				var t = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				t.tween_property(old_node, "position:x", old_node.position.x + 300, 0.4)
				t.parallel().tween_property(old_node, "modulate:a", 0.0, 0.35)
				await t.finished
			remove_character(replace_bc)
			if is_instance_valid(old_node): old_node.queue_free()
		pet_node = await scene.summon_mech_pet(stats, prefer_pos)
		summoned_mech_ids.append(mech_name)
		# 在 BattleCharacter 上记录 mech_name，死亡时可回溯清理
		var mech_bc = pet_node.get_node_or_null("BattleCharacter") as BattleCharacter
		if mech_bc:
			mech_bc.pet_id = mech_name
			mech_bc.summoner_member_id = _current_actor.member_id
	else:
		_push_log(GameData._T("LOG_MEHC_FAIL"), "system"); await _finish_player_action(); return
	var target = _pick_random_enemy()
	if target == null: await _finish_player_action(); return
	var target_pos = target.get_parent().global_position
	if pet_node and pet_node.has_method("play_attack_sequence"):
		await pet_node.play_attack_sequence(target_pos, target.get_parent() as EnemyNode)
	var dmg = maxi(1, stats.attack - int(target.get_effective_defense()))
	dmg = int(dmg * randf_range(0.95, 1.05))
	target.take_damage(dmg); target.sync_visual()
	damage_floated.emit(target, dmg, "normal")
	_push_log(GameData._T("LOG_PET_ATK") % [stats.character_name, target.stats.get_display_name(), dmg], "player_action")
	await get_tree().create_timer(action_delay * 0.5).timeout
	await _finish_player_action()

## 召唤宠物槽数量（1 + 天赋加成）
func get_pet_slot_count() -> int:
	return 1 + GameData.get_talent_rank("summon_pet_slot")

func _count_summoned_pets() -> int:
	var count := 0
	for c in party:
		if c.is_summoned_pet and not c.is_dead: count += 1
	return count

## 无宠物时的召唤兜底
func player_summon_fallback() -> void:
	if state != BattleState.PLAYER_TURN: return
	_change_state(BattleState.PLAYER_ACTION)
	# 施法者播放施法动画
	var caster_node = _current_actor.get_parent()
	if caster_node and caster_node.has_method("play_cast_sequence"):
		caster_node.play_cast_sequence("")
	_push_log(GameData._T("LOG_FALLBACK") % _current_actor.stats.get_display_name(), "system")
	var target = _pick_random_enemy()
	if target == null:
		await _finish_player_action()
		return
	_push_log(GameData._T("LOG_FALLBACK_DIRECT"), "system")
	target.take_damage(50)
	target.sync_visual()
	damage_floated.emit(target, 50, "normal")
	await _finish_player_action()


func _do_pet_attack(pet: PetData, target: BattleCharacter) -> void:
	var skill_id = "普通攻击"
	if not pet.skill_ids.is_empty():
		skill_id = pet.skill_ids[randi() % pet.skill_ids.size()]
	var sk_data = SkillManager.get_skill(skill_id)

	if sk_data == null or skill_id == "普通攻击":
		var dmg = maxi(1, pet.attack - int(target.get_effective_defense()))
		dmg = int(dmg * randf_range(0.95, 1.05))
		target.take_damage(dmg)
		target.sync_visual()
		damage_floated.emit(target, dmg, "normal")
		_push_log(GameData._T("LOG_PET_ATK") % [pet.character_name, target.stats.get_display_name(), dmg], "player_action")
	else:
		var mul = sk_data.damage_multiplier if sk_data.damage_multiplier > 0 else 1.0
		var dmg = maxi(1, int(pet.attack * mul) - int(target.get_effective_defense()))
		dmg = int(dmg * randf_range(0.95, 1.05))
		target.take_damage(dmg)
		target.sync_visual()
		damage_floated.emit(target, dmg, "normal")
		_push_log(GameData._T("LOG_PET_SKILL_ATK") % [pet.character_name, skill_id, target.stats.get_display_name(), dmg], "player_action")
	await get_tree().create_timer(action_delay).timeout

## 捕捉
func player_capture(target: BattleCharacter) -> void:
	if state != BattleState.PLAYER_TURN: return
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
		target.is_dead = true
		target.current_hp = 0
		_threat_mgr.clear_threat(target)
		target.hp_changed.emit(target.current_hp, target.current_hp, target.get_effective_max_hp())
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
	var data = SkillManager.get_skill(skill_id)
	if data and not data.sound_path.is_empty() and ResourceLoader.exists(data.sound_path):
		var snd = AudioStreamPlayer.new()
		snd.stream = load(data.sound_path)
		snd.bus = "SFX"
		add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)

	var result = SkillManager.execute(actor, target, skill_id)
	await _apply_skill_result(result, actor, target)

# ──────────────────────────────────────────────
# 公共工具
# ──────────────────────────────────────────────

## 结果应用（动画 + 飘字 + 日志）
func _get_extra_heal_target_count(actor: BattleCharacter) -> int:
	if actor == null or actor.is_dead:
		return 0
	return maxi(0, int(actor.equip_special.get("heal_targets", 0)) + GameData.get_talent_rank("support_wider_heal"))

func _get_heal_side(actor: BattleCharacter) -> Array[BattleCharacter]:
	if actor != null and actor.is_player:
		return party
	return enemies

func _pick_extra_heal_targets(actor: BattleCharacter, used_targets: Array, count: int) -> Array[BattleCharacter]:
	var picked: Array[BattleCharacter] = []
	if count <= 0:
		return picked
	var wounded: Array[BattleCharacter] = []
	var healthy: Array[BattleCharacter] = []
	for c in _get_heal_side(actor):
		if c == null or c.is_dead or c in used_targets:
			continue
		if c.hp_percent() < 1.0:
			wounded.append(c)
		else:
			healthy.append(c)
	wounded.sort_custom(func(a, b): return a.hp_percent() < b.hp_percent())
	for c in wounded:
		if picked.size() >= count:
			return picked
		picked.append(c)
	for c in healthy:
		if picked.size() >= count:
			return picked
		picked.append(c)
	return picked

func _calc_heal_amount_for_target(actor: BattleCharacter, target: BattleCharacter, skill_id: String, fallback_amount: int) -> int:
	var skill_data := SkillManager.get_skill(skill_id)
	if skill_data != null and skill_data.skill_type == SkillData.SkillType.HEAL:
		return maxi(1, int(target.stats.max_hp * skill_data.heal_multiplier * actor.get_effective_heal_rate()) + skill_data.flat_heal)
	if fallback_amount > 0:
		return fallback_amount
	return 0

func _apply_extra_heal_targets(
	actor: BattleCharacter,
	primary_target: BattleCharacter,
	base_amount: int,
	heal_size: String,
	skill_id: String = "",
	already_healed: Array = []
) -> void:
	var extra_count := _get_extra_heal_target_count(actor)
	if extra_count <= 0:
		return
	var used_targets: Array = []
	if primary_target != null:
		used_targets.append(primary_target)
	for t in already_healed:
		if t != null and t not in used_targets:
			used_targets.append(t)
	for extra_target in _pick_extra_heal_targets(actor, used_targets, extra_count):
		var amount := _calc_heal_amount_for_target(actor, extra_target, skill_id, base_amount)
		if amount <= 0:
			continue
		var actual := extra_target.heal(amount)
		if actual <= 0:
			continue
		extra_target.sync_visual()
		damage_floated.emit(extra_target, amount, "heal")
		_push_log(GameData._T("LOG_SPLASH_HEAL") % [extra_target.stats.get_display_name(), amount], "heal")
		if actor != null and _threat_mgr != null:
			_threat_mgr.add_heal_threat(actor, heal_size)

func _apply_skill_result(
	result: SkillManager.SkillResult,
	actor: BattleCharacter,
	target: BattleCharacter
) -> void:
	if not result.success:
		_push_log(result.log_text, "system")
		await get_tree().create_timer(0.3).timeout
		return

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
	# 符能天赋：符咒伤害加成 5%/级
	if is_ranged_attack and CharacterStats.has_role(actor.stats.role, CharacterStats.Role.MAIN):
		var funeng_rank = GameData.get_talent_rank("funeng")
		if funeng_rank > 0:
			meta_mul *= (1.0 + 0.05 * funeng_rank)
	for dmg in result.damage_list:
		var is_aoe = result.skill_type == SkillData.SkillType.AOE
		pending_damage.append({
			"attacker": actor,
			"target": actual_target,
			"amount": int(dmg * meta_mul),
			"type": _damage_float_type(result),
			"is_magic": result.is_magic,
			"is_aoe": is_aoe,
		})
	if result.heal_amount > 0 or result.shield_amount > 0:
		var skill_data = SkillManager.get_skill(result.skill_id)
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

	# 特性：烈焰灼魂 — 技能命中后有概率让目标灼烧（Boss免疫）
	if actor and target and not target.is_dead and target.stats.rank != "boss":
		var burn_trait = actor.trait_data.get("烈焰灼魂", {})
		if burn_trait.size() > 0:
			var chance = burn_trait.get("burn_chance", 0.0)
			if randf() < chance:
				var burn_dmg = burn_trait.get("burn_dmg", 0.05)
				target.add_buff("burn", 2, int(target.stats.max_hp * burn_dmg))
				_push_log("%s 被烈焰灼伤！" % target.stats.get_display_name(), "debuff")

	# 远程攻击：等待投射物命中结算（battleUI 动画回调中 emit ranged_attack_completed）
	if is_ranged_attack:
		await ranged_attack_completed
	else:
		await get_tree().create_timer(action_delay).timeout

	# 兜底：确保 pending damage 已被刷新（正常情况下 battleUI 动画回调已调用）
	flush_pending_damage()

## 显示所有待显示的伤害（动画完成后调用）
func flush_pending_damage() -> void:
	var synced: Dictionary = {}  # 已同步过的角色
	for d in pending_damage:
		if d.type == "shield":
			d.target.set_shield(d.amount)
		elif d.get("is_heal", false) or d.type == "heal":
			d.target.heal(d.amount)
			_apply_extra_heal_targets(d.get("attacker"), d.target, d.amount, d.get("heal_size", "medium"), d.get("skill_id", ""))
		else:
			d.target.last_attacker = d.get("attacker")
			# 闪避 / 魔法吸收检查（在 take_damage 之前）
			var dodged = false
			# 闪避：群攻概率闪避，单体法术必中
			var can_dodge = d.get("is_aoe", false) or not d.get("is_magic", false)
			if can_dodge:
				# 闪避：物理攻击
				var dodge_chance = d.target.trait_data.get("_dodge", 0)
				var equip_dodge = d.target.equip_special.get("dodge", 0)
				dodge_chance = max(dodge_chance, equip_dodge)
				if dodge_chance > 0 and randi() % 100 < dodge_chance:
					dodged = true
			else:
				# 魔法吸收
				var absorb_chance = d.target.trait_data.get("_magic_absorb", 0)
				if absorb_chance > 0 and randi() % 100 < absorb_chance:
					var absorb_pct = 0.3  # 吸收 30% 为治疗
					var heal_amt = maxi(1, int(d.amount * absorb_pct))
					var remain = d.amount - heal_amt
					d.target.heal(heal_amt)
					d.amount = remain
			if dodged:
				d.amount = 0
				damage_floated.emit(d.target, 0, "dodge")
			else:
				# 鬼影护体：抵挡一次攻击
				if d.target.has_buff("ghost_shield"):
					d.target.remove_buff("ghost_shield")
					d.amount = 0
					damage_floated.emit(d.target, 0, "dodge")
					_push_log("【鬼影护体】%s 抵挡了攻击！" % d.target.stats.get_display_name(), "system")
				var actual = d.target.take_damage(d.amount)
				# 反震（原逻辑 + 装备反震）
				if not d.get("is_magic", false):
					var reflect_all = d.target.equip_special.get("reflect", 0)
					if d.target._has_book_type("reflect"):
						reflect_all += int(d.target.get_reflect_ratio() * 100)
					if reflect_all > 0 and d.has("attacker") and d.attacker and not d.attacker.is_dead:
						var reflect_dmg = maxi(1, int(d.amount * reflect_all / 100.0))
						d.attacker.take_damage(reflect_dmg)
						d.attacker.sync_visual()
						damage_floated.emit(d.attacker, reflect_dmg, "normal")
						_push_log(GameData._T("LOG_REFLECT") % [d.target.stats.get_display_name(), d.attacker.stats.get_display_name(), reflect_dmg], "player_action" if d.target.is_player else "enemy_action")
					# 吸血（原逻辑）
					if d.has("attacker") and d.attacker and not d.attacker.is_dead:
						var ls_ratio = d.attacker.get_lifesteal_ratio()
						ls_ratio += d.attacker.equip_special.get("lifesteal", 0) / 100.0
						# 特性吸血（如暗影汲取）
						var drain_trait = d.attacker.trait_data.get("暗影汲取", {})
						if not drain_trait.is_empty():
							ls_ratio += drain_trait.get("drain_pct", 0.0)
						# 吸血提高 buff（lifesteal_up）
						if d.attacker.has_buff("lifesteal_up"):
							var lv = d.attacker.get_buff_value("lifesteal_up")
							if lv != null:
								ls_ratio += lv
						if ls_ratio > 0:
							var heal_amt = maxi(1, int(d.amount * ls_ratio))
							d.attacker.heal(heal_amt)
							damage_floated.emit(d.attacker, heal_amt, "heal")
							_push_log(GameData._T("LOG_LIFESTEAL") % [d.attacker.stats.get_display_name(), heal_amt], "heal")
					# 毒（原逻辑）
					if not d.target.is_dead:
						var venom_chance = d.attacker.get_venom_chance()
						if venom_chance > 0 and randf() < venom_chance and not d.target.is_immune_to_debuffs():
							d.target.add_buff("poison", 3)
							_push_log(GameData._T("LOG_POISON") % d.target.stats.get_display_name(), "debuff")
							d.target.sync_visual()
					# 裂伤天赋：攻击概率附加流血
					if not d.target.is_dead:
						var bleed_rank = GameData.get_talent_rank("attack_bleed")
						if bleed_rank > 0 and randf() < 0.3 * bleed_rank and not d.target.is_immune_to_debuffs():
							var bleed_dmg = int(d.target.stats.max_hp * 0.05 * bleed_rank)
							d.target.add_buff("bleed", 3, bleed_dmg)
							_push_log("%s 裂伤流血！" % d.target.stats.get_display_name(), "debuff")
		# 仇恨
		if d.type == "shield":
			if d.has("attacker") and d.attacker:
				_threat_mgr.add_shield_threat(d.attacker, false)
		elif d.type == "heal" or d.type == "crit":
			if d.has("attacker") and d.attacker:
				_threat_mgr.add_heal_threat(d.attacker, d.get("heal_size", "medium"))
		else:
			if d.has("attacker") and d.attacker:
				_threat_mgr.add_damage_threat(d.attacker, d.amount)
		damage_floated.emit(d.target, d.amount, d.type)
		if not synced.has(d.target):
			synced[d.target] = true
			d.target.sync_visual()
	pending_damage.clear()

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
				target.take_damage(dmg)
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
			# 中毒：单层触发
			var dmg = maxi(1, int(target.stats.max_hp * 0.025))
			target.take_damage(dmg)
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
		target.take_damage(bleed_dmg)
		target.sync_visual()
		damage_floated.emit(target, bleed_dmg, "bleed")
		_push_log("%s 流血 %d 点" % [target.stats.get_display_name(), bleed_dmg], "debuff")

## 处理吸血/暗影汲取（给直接扣血的路径调用）
func _apply_lifesteal(attacker: BattleCharacter, damage_amount: int) -> void:
	if attacker == null or attacker.is_dead: return
	var ls_ratio = attacker.get_lifesteal_ratio()
	ls_ratio += attacker.equip_special.get("lifesteal", 0) / 100.0
	var drain_trait = attacker.trait_data.get("暗影汲取", {})
	if not drain_trait.is_empty():
		ls_ratio += drain_trait.get("drain_pct", 0.0)
	if attacker.has_buff("lifesteal_up"):
		var lv = attacker.get_buff_value("lifesteal_up")
		if lv != null:
			ls_ratio += lv
	if ls_ratio > 0:
		var heal_amt = maxi(1, int(damage_amount * ls_ratio))
		attacker.heal(heal_amt)
		damage_floated.emit(attacker, heal_amt, "heal")
		_push_log(GameData._T("LOG_LIFESTEAL") % [attacker.stats.get_display_name(), heal_amt], "heal")

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
	return skill_cooldowns.get(_cd_key(actor, skill_id), 0)

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

func _check_battle_end() -> void:
	if _battle_ended_flag:
		return
	var all_enemies_dead = enemies.all(func(e): return e.is_dead)
	var all_party_dead   = party.all(func(c): return c.is_dead)

	if all_enemies_dead or all_party_dead:
		_battle_ended_flag = true

	if all_enemies_dead:
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
		for i in party.size():
			var c = party[i]
			if c.is_dead:
				continue
			var old_skills: Array = []
			if not c.member_id.is_empty():
				old_skills = GameData.get_all_skills(c.member_id).duplicate()
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
					"new_level": c.stats.level,
					"new_skills": new_skills,
					"new_hp": c.stats.max_hp,
					"new_mp": c.stats.max_mp,
					"atk_gain": c.stats.attack,
					"def_gain": c.stats.defense,
				})
		GameData.player_gold += total_gold
		# 等死亡动画播放
		await get_tree().create_timer(1.2).timeout
		for e in enemies:
			var nd = e.get_parent()
			if nd: nd.visible = false
		await get_tree().create_timer(0.5).timeout
		battle_ended.emit(true, total_exp, total_gold, level_ups)

	elif all_party_dead:
		_change_state(BattleState.BATTLE_LOSE)
		_push_log(GameData._T("LOG_ALL_DEAD"), "system")
		await get_tree().create_timer(0.5).timeout
		battle_ended.emit(false, 0, 0, [])

func _calc_exp_reward(enemy: BattleCharacter) -> int:
	if enemy.stats.exp_reward > 0:
		return enemy.stats.exp_reward
	var avg_level = 0
	for c in party:
		avg_level += c.stats.level
	avg_level = avg_level / maxi(1, party.size())
	var base = 30 + enemy.stats.level * 15
	var diff = enemy.stats.level - avg_level
	return maxi(5, int(base * (1.0 + diff * 0.1)))

func _calc_gold_reward(enemy: BattleCharacter) -> int:
	var base = 20 + enemy.stats.level * 10
	return maxi(5, base + randi() % maxi(1, base / 3))

# ──────────────────────────────────────────────
# 工具
# ──────────────────────────────────────────────
func _change_state(new_state: BattleState) -> void:
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

## 隐藏/显示骨精灵鬼魂
func _set_ghost_visible(v: bool) -> void:
	for c in party:
		if c.member_id == "gujingling":
			var nd = c.get_parent()
			var ghost = nd.get_node_or_null("Ghost") if nd else null
			if ghost:
				ghost.visible = v and c.trait_data.get("_ghost_count", 0) > 0
			break

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

	var revive_chance_pct = character.trait_data.get("复生", character.trait_data.get("_revive", 0))
	print("[DEBUG 复活] %s 复生概率=%d%%" % [character.stats.get_display_name(), revive_chance_pct])
	if revive_chance_pct > 0 and randi() % 100 < revive_chance_pct:
		# 死亡复活：回满血
		character.is_dead = false
		character.current_hp = character.get_effective_max_hp()
		character.sync_visual()
		_push_log(GameData._T("LOG_REVIVE") % character.stats.get_display_name(), "system")
		damage_floated.emit(character, character.get_effective_max_hp(), "heal")
		character.revived.emit()
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
			character.is_dead = false
			var heal_amt = maxi(1, int(character.stats.max_hp * revive_hp_pct))
			character.current_hp = heal_amt
			character.sync_visual()
			_push_log(GameData._T("LOG_REVIVE") % character.stats.get_display_name(), "system")
			damage_floated.emit(character, heal_amt, "heal")
			character.revived.emit()
			return
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
		var pet_count = 0
		for c in party:
			if c.is_summoned_pet and not c.is_dead: pet_count += 1
		for c in party:
			c.recalc_summon_buffs(pet_count)
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
