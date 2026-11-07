extends RefCounted
const CONFIG = preload("res://Resources/MechFusion.tres")
const SKILLS: Array[String] = ["普通攻击", "机甲重击", "机甲炮击", "解除合体"]

static func candidates(battle) -> Array:
	return battle.party.filter(func(c): return is_instance_valid(c) and not c.is_dead and c.is_summoned_pet and c.stats.character_class == "铁甲" and c.pet_id in ["机关兽", "机关鸟"])

static func validate(battle, actor, skill_id: String) -> String:
	if actor.member_id != "dingdong": return "只有叮咚可以使用机甲合体技能。"
	if actor.is_dead: return "叮咚已阵亡，无法合体。"
	if skill_id == "机甲合体":
		if not actor.mech_fusion.is_empty(): return "已经处于机甲合体状态。"
		if candidates(battle).is_empty(): return "需要场上至少一只存活的机关兽或机关鸟。"
	elif actor.mech_fusion.is_empty():
		return "需要先进入机甲合体状态。"
	return ""

## 消耗前一次性快照；来自多只机甲的数值相加，同类固定倍率仍只生效一次。
static func inherited_stats(mechs: Array) -> Dictionary:
	var totals := {"hp": 0.0, "speed": 0.0, "attack": 0.0, "magic_attack": 0.0, "defense": 0.0, "magic_defense": 0.0}
	for mech in mechs:
		totals.attack += mech.get_effective_attack() * CONFIG.mech_attack_transfer
		totals.magic_attack += mech.get_effective_magic_attack() * CONFIG.mech_attack_transfer
		totals.defense += mech.get_effective_defense() * CONFIG.mech_defense_transfer
		totals.magic_defense += mech.get_effective_magic_defense() * CONFIG.mech_defense_transfer
		if mech.pet_id == "机关兽": totals.hp += mech.get_effective_max_hp() * CONFIG.beast_hp_transfer
		if mech.pet_id == "机关鸟": totals.speed += mech.get_effective_speed() * CONFIG.bird_speed_transfer
	for key in totals: totals[key] = maxi(0, int(totals[key]))
	return totals

static func enter(battle, actor) -> void:
	var mechs := candidates(battle)
	var beast := false
	var bird := false
	for mech in mechs:
		beast = beast or mech.pet_id == "机关兽"
		bird = bird or mech.pet_id == "机关鸟"
	var original = actor.stats
	var inherited := inherited_stats(mechs)
	actor.mech_fusion = {"original": original, "inherited": inherited}
	actor.stats = original.duplicate(true)
	actor.stats.skill_ids = SKILLS.duplicate()
	actor.stats.is_ranged = false
	actor.stats.attack = maxi(1, int(original.attack * CONFIG.attack_multiplier) + inherited.attack)
	actor.stats.magic_attack = original.magic_attack + inherited.magic_attack
	actor.stats.defense = original.defense + inherited.defense
	actor.stats.magic_defense = original.magic_defense + inherited.magic_defense
	actor.stats.max_hp = maxi(1, int(original.max_hp * (1.0 + (CONFIG.beast_hp_bonus if beast else 0.0))) + inherited.hp)
	actor.stats.speed = maxi(1, int(original.speed * (CONFIG.base_speed_multiplier + (CONFIG.bird_speed_bonus if bird else 0.0))) + inherited.speed)
	var path: String = CONFIG.robot_path
	if not FileAccess.file_exists(path.path_join("待机.was")) and not FileAccess.file_exists(path.path_join("idle.was")):
		path = CONFIG.fallback_path
	actor.stats.was_base_path = path
	actor.mech_durability = maxi(1, int(actor.get_effective_max_hp() * CONFIG.durability_hp_ratio))
	# 消耗战场实例，不触发阵亡、击杀奖励或删除永久机甲。
	for mech in mechs:
		battle.summoned_mech_ids.erase(mech.pet_id)
		battle.remove_character(mech)
		for ally in battle.party: ally.ally_refs.erase(mech)
		for guarded in battle.guard_relations.keys():
			if guarded == mech or battle.guard_relations[guarded] == mech:
				battle.guard_relations.erase(guarded)
		if is_instance_valid(mech.get_parent()): mech.get_parent().queue_free()
	_reload(actor, path)
	actor.sync_visual()
	var hp_note := "，血量上限 +%d%%" % int(CONFIG.beast_hp_bonus * 100) if beast else ""
	var speed_note := "，速度提升至原来的 %d%%" % int((CONFIG.base_speed_multiplier + CONFIG.bird_speed_bonus) * 100) if bird else ""
	battle._push_log("【机甲合体】叮咚消耗场上机甲，获得 %d 点机甲耐久%s%s！" % [actor.mech_durability, hp_note, speed_note], "player_action")
	battle._push_log("【机甲属性继承】额外气血上限 +%d、速度 +%d、物攻 +%d、法攻 +%d、物防 +%d、法防 +%d。" % [inherited.hp, inherited.speed, inherited.attack, inherited.magic_attack, inherited.defense, inherited.magic_defense], "player_action")
	battle.party_changed.emit()

static func leave(actor, visuals: bool = true) -> void:
	if actor.mech_fusion.is_empty(): return
	actor.stats = actor.mech_fusion.original
	actor.mech_fusion.clear()
	actor.mech_durability = 0
	actor.current_hp = mini(actor.current_hp, actor.get_effective_max_hp())
	if visuals and actor.is_inside_tree():
		_reload(actor, actor.stats.was_base_path)
		actor.sync_visual()

static func _reload(actor, path: String) -> void:
	var node = actor.get_parent()
	if node and node.has_method("reload_was"): node.reload_was(path)

static func clear_all(battle) -> void:
	for actor in battle.party: leave(actor)
