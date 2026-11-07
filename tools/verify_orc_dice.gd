extends SceneTree
const Rules = preload("res://Script/Battle/OrcDiceRules.gd")
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	for i in 6:
		assert(Rules.roll(0, (float(i) + 0.5) / 6.0) == i + 1)
	var previous_mean := 0.0
	for luck in [0, 10, 50, 100, 1000]:
		var weights = Rules.weights(luck)
		var total := 0.0
		var weighted := 0.0
		for i in 6:
			total += weights[i]
			weighted += weights[i] * (i + 1)
		assert(weighted / total > previous_mean)
		previous_mean = weighted / total
		assert(Rules.roll(luck, 0.0) == 1)
		assert(Rules.roll(luck, 0.999999) == 6)
	var data = root.get_node("GameData")
	data.talent_ranks = {}
	data.add_party_by_name("半兽人")
	data.party_order.assign(["banshouren"])
	data.pet_team.clear()
	data.set_meta("pending_party", data.party_order.duplicate())
	data.set_meta("pending_enemies", ["火沙虫"])
	var host := Node2D.new()
	host.name = "Fixture"
	root.add_child(host)
	current_scene = host
	var ui := Node.new()
	ui.name = "UI"
	host.add_child(ui)
	var log := RichTextLabel.new()
	log.name = "BattleLog"
	ui.add_child(log)
	var battle = load("res://scenes/Battle/battleField.tscn").instantiate()
	host.add_child(battle)
	await create_timer(1.5).timeout
	var manager = battle.get_node("BattleManager")
	manager.set_process(false)
	manager.action_delay = 0.01
	var actor = manager.party[0]
	var target = manager.enemies[0]
	target.stats.max_hp = 1000000
	target.current_hp = 1000000
	target.trait_data.clear()
	target.equip_special.clear()
	actor.trait_data.clear()
	actor.equip_special.clear()
	var skill = load("res://Script/Battle/SkillManager.gd").get_skill("真身显现")
	assert(skill.initial_wait_actions == 5)
	assert(actor.skill_wait_remaining(skill) == 5)
	var mp: int = actor.current_mp
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	await manager.player_use_skill("真身显现", actor)
	assert(actor.completed_actions == 0)
	assert(actor.current_mp == mp)
	assert(actor.stats.was_base_path == "res://WAS/小二")
	await manager.player_use_skill("扔色子", actor)
	assert(actor.completed_actions == 1)
	assert(actor.dice_has_pending)
	assert(actor.current_mp == mp)
	assert(actor.dice_pending_multiplier in Rules.MULTIPLIERS)
	var rolled: float = actor.dice_pending_multiplier
	manager.state = manager.BattleState.PLAYER_TURN
	await manager.player_use_skill("扔色子", actor)
	assert(actor.completed_actions == 1)
	assert(actor.current_mp == mp)
	assert(actor.dice_pending_multiplier == rolled)
	assert(manager.state == manager.BattleState.PLAYER_TURN)
	# 非攻击行动保留待用倍率，且每完成一次行动只计一次。
	for n in range(1, 5):
		manager._current_actor = actor
		manager.state = manager.BattleState.PLAYER_ACTION
		await manager._finish_player_action()
		assert(actor.completed_actions == n + 1)
		assert(actor.skill_wait_remaining(skill) == 5 - n - 1)
		assert(actor.dice_has_pending)
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	await manager.player_use_skill("真身显现", actor)
	assert(actor.stats.was_base_path == "res://WAS/小二真身")
	assert(actor.current_mp == mp - 30)
	assert(actor.dice_has_pending)
	assert(actor.get_parent().has_node("WeaponWAS"))
	assert(data.party_db["banshouren"].was_base_path == "res://WAS/小二")
	# 落空保留结果；有效命中的无敌、零伤害或护盾吸收均解锁重掷。
	actor.dice_pending_multiplier = 3.0
	actor.dice_has_pending = true
	actor.begin_dice_attack()
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_ACTION
	assert(manager.apply_damage(actor, target, 100, {"missed": true}) == 0)
	assert(actor.dice_has_pending)
	target.add_buff("invincible", 1)
	assert(manager.apply_damage(actor, target, 100) == 0)
	assert(not actor.dice_has_pending)
	target.remove_buff("invincible")
	actor.dice_has_pending = true
	actor.dice_pending_multiplier = 3.0
	var zero_hp: int = target.current_hp
	assert(manager.apply_damage(actor, target, 0) == 0)
	assert(target.current_hp == zero_hp)
	assert(not actor.dice_has_pending)
	actor.dice_has_pending = true
	actor.dice_pending_multiplier = 3.0
	target.set_shield(10000)
	manager.apply_damage(actor, target, 100)
	assert(target.current_hp == zero_hp)
	assert(not actor.dice_has_pending)
	target.set_shield(0)
	await manager._finish_player_action()
	actor.dice_has_pending = true
	actor.dice_pending_multiplier = 3.0
	manager.state = manager.BattleState.PLAYER_TURN
	var hp_before: int = target.current_hp
	await manager.player_use_skill("雷霆诀", target)
	assert(target.current_hp < hp_before)
	assert(not actor.dice_has_pending)
	# 全部六种结果：同次行动多段均生效，下次行动恢复；反射等次级伤害不受影响。
	for i in 6:
		actor.dice_pending_multiplier = Rules.MULTIPLIERS[i]
		actor.dice_has_pending = true
		actor.begin_dice_attack()
		manager._current_actor = actor
		manager.state = manager.BattleState.PLAYER_ACTION
		var expected := int(300 * Rules.MULTIPLIERS[i])
		assert(manager.apply_damage(actor, target, 300) == expected)
		assert(manager.apply_damage(actor, target, 300) == expected)
		assert(manager.apply_damage(actor, target, 300, {"secondary": true}) == 300)
		await manager._finish_player_action()
		assert(not actor.dice_has_pending)
		manager.state = manager.BattleState.PLAYER_ACTION
		assert(manager.apply_damage(actor, target, 300) == 300)
	actor.dice_pending_multiplier = 2.0
	actor.dice_has_pending = true
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	await manager.player_use_normal_attack(target)
	assert(not actor.dice_has_pending)
	assert(actor.dice_action_multiplier == 1.0)
	actor.completed_actions = 2
	actor.initial_skill_wait_reductions["真身显现"] = 2
	assert(actor.skill_wait_remaining(skill) == 1)
	actor.equip_special["initial_skill_wait_reduction"] = 1
	assert(actor.skill_wait_remaining(skill) == 0)
	actor.initial_skill_wait_reductions["真身显现"] = 99
	assert(actor.skill_wait_remaining(skill) == 0)
	print("ORC DICE PASS: six multipliers, multi-hit, secondary damage, one-action consumption, luck weights, animation, five actions, reductions, persistent form")
	host.queue_free()
	await process_frame
	quit()
