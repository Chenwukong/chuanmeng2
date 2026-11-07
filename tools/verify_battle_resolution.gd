extends SceneTree
var manager
var actor
var target
var other
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("verify")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func character(id: String, player: bool):
	var ch = load("res://Script/Battle/BattleCharacter.gd").new()
	ch.stats = load("res://Script/Data/Models/CharacterStats.gd").new()
	ch.stats.role = 1
	ch.stats.max_hp = 10000
	ch.current_hp = 10000
	ch.is_player = player
	ch.member_id = id
	return ch
func verify() -> void:
	root.get_node("GameData").talent_ranks = {}
	manager = load("res://Script/Battle/BattleManager.gd").new()
	var ai = load("res://Script/Battle/EnemyAI.gd").new()
	ai.name = "EnemyAI"
	manager.add_child(ai)
	root.add_child(manager)
	manager._threat_mgr = load("res://Script/Battle/ThreatManager.gd").new()
	actor = character("source", true)
	other = character("current", true)
	target = character("enemy", false)
	manager._current_actor = other
	manager.pending_damage.append({"attacker": actor, "target": target, "amount": 100, "type": "crit"})
	manager.flush_pending_damage()
	check(target.current_hp == 9900, "critical hit applies once")
	check(manager._threat_mgr.get_threat_value(actor) == 100, "critical damage is not healing threat")
	check(manager.damage_stats.get("source") == 100 and not manager.damage_stats.has("current"), "attribution uses source not current turn")
	manager.flush_pending_damage()
	check(target.current_hp == 9900, "flush is idempotent")
	manager.apply_talisman_damage(actor, target, 100)
	check(manager.damage_stats.source == 200, "talisman uses same stats pipeline")
	target.add_buff("invincible", 1)
	var hp_before = target.current_hp
	manager.apply_damage(actor, target, 100)
	check(target.current_hp == hp_before and manager.damage_stats.source == 200, "immunity gives zero threat and stats")
	target.remove_buff("invincible")
	manager.pending_damage.append({"attacker": actor, "target": target, "amount": 100, "type": "normal", "missed": true})
	manager.flush_pending_damage()
	check(target.current_hp == hp_before, "miss never applies damage")
	actor.current_hp = 9000
	actor.equip_special["lifesteal"] = 10
	manager.apply_damage(actor, target, 100, {"is_magic": true})
	check(actor.current_hp == 9010 and manager.healing_stats.source == 10, "lifesteal resolved once")
	actor.is_summoned_pet = true
	actor.summoner_member_id = "owner"
	manager.apply_damage(actor, target, 100, {"is_magic": true})
	check(manager.damage_stats.owner == 100, "summon attributed to owner")
	actor.is_summoned_pet = false
	other.current_hp = 9995
	var actual = manager.apply_heal(actor, other, 100)
	check(actual == 5, "heal statistics use effective amount")
	other.current_hp = 0
	other.is_dead = true
	check(manager.apply_heal(actor, other, 100) == 0, "ordinary heal cannot revive")
	check(manager.apply_heal(actor, other, 100, true) == 100 and not other.is_dead, "explicit revive shares pipeline")
	# Zero damage cannot trigger weapon true damage or on-hit effects.
	actor.equip_special["true_dmg"] = 100
	check(manager.apply_damage(actor, target, 0) == 0, "zero damage stays zero")
	var skill = load("res://Script/Battle/SkillManager.gd")
	var result = skill.execute(actor, other, "金刚护体")
	if result.success and not result.effects.is_empty():
		var effect_id = result.effects[0].id
		check(not other.has_buff(effect_id), "skill calculation does not mutate buffs")
		manager._resolve_skill_effects(result, actor, other)
		check(other.has_buff(effect_id) and result.effects.is_empty(), "effect applied once by resolution")
	for id in skill.list_all_skills():
		var calculation = skill.execute(actor, other, id)
		var seen: Dictionary = {}
		for effect in calculation.effects:
			check(not seen.has(effect.id), "skill effects resolve once: " + id)
			seen[effect.id] = true
	actor.free()
	target.free()
	other.free()
	manager.queue_free()
	if failures.is_empty(): print("BATTLE RESOLUTION: PASS")
	quit(0 if failures.is_empty() else 1)
