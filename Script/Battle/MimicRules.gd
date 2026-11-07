extends RefCounted

static func record(battle, actor: BattleCharacter, skill_id: String, target: BattleCharacter) -> void:
	if actor not in battle.party or actor.is_frozen or skill_id in ["普通攻击", "千机变"]: return
	battle.ally_skill_history[actor] = {"skill": skill_id, "target": weakref(target) if target else null}

static func resolve(battle, actor: BattleCharacter, teammate: BattleCharacter) -> Dictionary:
	if actor.member_id != "banshouren": return {"error": "只有半兽人可以使用千机变！"}
	if teammate == null or teammate == actor or teammate not in battle.party or teammate.is_dead:
		return {"error": "请选择一名存活的其他队友。"}
	var entry: Dictionary = battle.ally_skill_history.get(teammate, {})
	if entry.is_empty(): return {"error": "这名队友本场尚未施放可模仿的技能。"}
	var skill_id: String = entry.get("skill", "")
	var data: SkillData = SkillManager.get_skill(skill_id)
	if data == null or skill_id in ["普通攻击", "千机变"]:
		return {"error": "该技能无法模仿。"}
	var target: BattleCharacter = entry.target.get_ref() if entry.get("target") else null
	var candidates: Array = []
	match data.target_type:
		SkillData.TargetType.SELF:
			target = actor
		SkillData.TargetType.SINGLE_ALLY, SkillData.TargetType.ALL_ALLIES:
			for ally in battle.party:
				if ally.is_dead == (data.heal_size == "revive"): candidates.append(ally)
		_:
			for enemy in battle.enemies:
				if not enemy.is_dead: candidates.append(enemy)
	if data.target_type != SkillData.TargetType.SELF:
		if target not in candidates: target = candidates[0] if not candidates.is_empty() else null
	if target == null: return {"error": "没有可供模仿技能作用的有效目标。"}
	return {"skill": skill_id, "target": target}
