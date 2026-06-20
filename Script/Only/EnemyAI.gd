# EnemyAI.gd
# 敌方 AI 决策模块 — 每种策略独立函数，接收 BattleManager 引用直接执行
class_name EnemyAI
extends Node

var battle_manager: BattleManager


func setup(bm: BattleManager) -> void:
	battle_manager = bm


# ── 入口 ──────────────────────────────────────
func execute_turn(actor: BattleCharacter) -> void:
	var strategy = actor.stats.ai_strategy
	match strategy:
		"aggressive":
			await _aggressive(actor)
		"healer":
			await _healer(actor)
		_:
			await _balanced(actor)


# ── 策略：均衡 ─────────────────────────────────
## 低血(<30%)时优先治疗，否则 65% 概率用攻击技能，默认普通攻击
func _balanced(actor: BattleCharacter) -> void:
	var chosen_skill = "普通攻击"
	var target: BattleCharacter = _pick_lowest_hp_target()

	var available = actor.stats.skill_ids.filter(func(id):
		return SkillManager.get_skill(id) != null
	)
	available = available.filter(func(id): return _can_use(actor, id))

	if available.size() > 0:
		# 残血优先治疗
		if actor.hp_percent() < 0.3:
			var heal_skills = available.filter(func(id):
				var d = SkillManager.get_skill(id)
				return d and d.skill_type == SkillData.SkillType.HEAL
			)
			if heal_skills.size() > 0:
				chosen_skill = heal_skills[0]
				target = actor
		else:
			if randf() < 0.65:
				var atk_skills = available.filter(func(id):
					var d = SkillManager.get_skill(id)
					return d and d.skill_type in [
						SkillData.SkillType.PHYSICAL,
						SkillData.SkillType.MAGIC,
						SkillData.SkillType.MULTI_HIT,
						SkillData.SkillType.DEBUFF,
					]
				)
				if atk_skills.size() > 0:
					chosen_skill = atk_skills[randi() % atk_skills.size()]

	# 修正目标（SELF 类技能对自己）
	var skill_data = SkillManager.get_skill(chosen_skill)
	if skill_data and skill_data.target_type == SkillData.TargetType.SELF:
		target = actor

	await battle_manager.execute_enemy_skill(actor, chosen_skill, target)


# ── 策略：激进 ─────────────────────────────────
## 永远不治疗，只使用攻击技能，默认普通攻击
func _aggressive(actor: BattleCharacter) -> void:
	var chosen_skill = "普通攻击"
	var target: BattleCharacter = _pick_lowest_hp_target()

	var available = actor.stats.skill_ids.filter(func(id):
		return SkillManager.get_skill(id) != null
	)
	available = available.filter(func(id): return _can_use(actor, id))

	if available.size() > 0:
		var atk_skills = available.filter(func(id):
			var d = SkillManager.get_skill(id)
			return d and d.skill_type in [
				SkillData.SkillType.PHYSICAL,
				SkillData.SkillType.MAGIC,
				SkillData.SkillType.MULTI_HIT,
				SkillData.SkillType.DEBUFF,
			]
		)
		if atk_skills.size() > 0:
			chosen_skill = atk_skills[randi() % atk_skills.size()]

	var skill_data = SkillManager.get_skill(chosen_skill)
	if skill_data and skill_data.target_type == SkillData.TargetType.SELF:
		target = actor

	await battle_manager.execute_enemy_skill(actor, chosen_skill, target)


# ── 策略：治疗者 ───────────────────────────────
## 优先治疗受伤的敌人，没有需要治疗的队友时才攻击
func _healer(actor: BattleCharacter) -> void:
	var chosen_skill = "普通攻击"
	var target: BattleCharacter = _pick_lowest_hp_target()

	var available = actor.stats.skill_ids.filter(func(id):
		return SkillManager.get_skill(id) != null
	)
	available = available.filter(func(id): return _can_use(actor, id))

	if available.size() > 0:
		var heal_skills = available.filter(func(id):
			var d = SkillManager.get_skill(id)
			return d and d.skill_type == SkillData.SkillType.HEAL
		)

		# 检查是否有受伤的队友
		var injured_allies = battle_manager.alive_enemies().filter(func(e):
			return e != actor and e.hp_percent() < 0.7
		)

		if heal_skills.size() > 0 and (actor.hp_percent() < 0.7 or injured_allies.size() > 0):
			chosen_skill = heal_skills[0]
			# 优先治疗血量最低的队友，其次自己
			if injured_allies.size() > 0:
				injured_allies.sort_custom(func(a, b): return a.hp_percent() < b.hp_percent())
				target = injured_allies[0]
			else:
				target = actor
		else:
			# 没人需要治疗，攻击
			var atk_skills = available.filter(func(id):
				var d = SkillManager.get_skill(id)
				return d and d.skill_type in [
					SkillData.SkillType.PHYSICAL,
					SkillData.SkillType.MAGIC,
					SkillData.SkillType.MULTI_HIT,
					SkillData.SkillType.DEBUFF,
				]
			)
			if atk_skills.size() > 0:
				chosen_skill = atk_skills[randi() % atk_skills.size()]

	var skill_data = SkillManager.get_skill(chosen_skill)
	if skill_data and skill_data.target_type == SkillData.TargetType.SELF:
		target = actor

	await battle_manager.execute_enemy_skill(actor, chosen_skill, target)


func _can_use(actor: BattleCharacter, skill_id: String) -> bool:
	var d = SkillManager.get_skill(skill_id)
	if d == null: return false
	return actor.current_mp >= d.mp_cost
## 选择存活玩家中血量百分比最低的
func _pick_lowest_hp_target() -> BattleCharacter:
	var alive = battle_manager.alive_party()
	if alive.is_empty():
		return battle_manager.party[0] if battle_manager.party.size() > 0 else null
	alive.sort_custom(func(a, b): return a.hp_percent() < b.hp_percent())
	return alive[0]
