extends RefCounted
## 战斗功能模块；状态和动画宿主由 BattleManager 显式传入。

static func _get_extra_heal_target_count(_battle, actor: BattleCharacter) -> int:
	if actor == null or actor.is_dead:
		return 0
	return maxi(0, int(actor.equip_special.get("heal_targets", 0)) + actor.talent_rank("support_wider_heal"))


static func _get_heal_side(_battle, actor: BattleCharacter) -> Array[BattleCharacter]:
	if actor != null and actor.is_player:
		return _battle.party
	return _battle.enemies


static func _pick_extra_heal_targets(_battle, actor: BattleCharacter, used_targets: Array, count: int) -> Array[BattleCharacter]:
	var picked: Array[BattleCharacter] = []
	if count <= 0:
		return picked
	var wounded: Array[BattleCharacter] = []
	var healthy: Array[BattleCharacter] = []
	for c in _battle._get_heal_side(actor):
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


static func _calc_heal_amount_for_target(_battle, actor: BattleCharacter, target: BattleCharacter, skill_id: String, fallback_amount: int) -> int:
	var skill_data = SkillManager.get_skill(skill_id)
	if skill_data != null and skill_data.skill_type == SkillData.SkillType.HEAL:
		return maxi(1, int(target.stats.max_hp * skill_data.heal_multiplier * actor.get_effective_heal_rate()) + skill_data.flat_heal)
	if fallback_amount > 0:
		return fallback_amount
	return 0


static func _apply_extra_heal_targets(_battle, 
	actor: BattleCharacter,
	primary_target: BattleCharacter,
	base_amount: int,
	heal_size: String,
	skill_id: String = "",
	already_healed: Array = []
) -> void:
	var extra_count = _battle._get_extra_heal_target_count(actor)
	if extra_count <= 0:
		return
	var used_targets: Array = []
	if primary_target != null:
		used_targets.append(primary_target)
	for t in already_healed:
		if t != null and t not in used_targets:
			used_targets.append(t)
	for extra_target in _battle._pick_extra_heal_targets(actor, used_targets, extra_count):
		var amount = _battle._calc_heal_amount_for_target(actor, extra_target, skill_id, base_amount)
		if amount <= 0:
			continue
		var actual = _battle.apply_heal(actor, extra_target, amount)
		if actual <= 0:
			continue
		extra_target.sync_visual()
		_battle.damage_floated.emit(extra_target, amount, "heal")
		_battle._push_log(GameData._T("LOG_SPLASH_HEAL") % [extra_target.stats.get_display_name(), amount], "heal")


