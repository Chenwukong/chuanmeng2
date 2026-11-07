extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var data = root.get_node("GameData")
	data.talent_ranks = {}
	data.add_party_by_name("半兽人")
	data.party_order.assign(["banshouren"])
	data.pet_team.clear()
	data.set_meta("pending_party", data.party_order.duplicate())
	data.set_meta("pending_enemies", ["火沙虫", "火沙虫"])
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
	assert("火域" in data.get_all_skills("banshouren"))
	var other = manager.enemies[1]
	other.stats.max_hp = 1000000
	other.current_hp = 1000000
	other.trait_data.clear()
	other.equip_special.clear()
	actor.get_parent().global_position = Vector2(500, 400)
	target.get_parent().global_position = Vector2(800, 400)
	other.get_parent().global_position = Vector2(800, 650)
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	var mp_before: int = actor.current_mp
	await manager.player_use_skill("火域", actor)
	assert(actor.current_mp == mp_before - 30)
	assert(actor.completed_actions == 1)
	var domain = actor.get_meta("fire_domain")
	domain.set_process(false)
	assert(domain.get_index() < battle.get_node("EnemyGroup").get_index())
	assert(domain.get_index() < battle.get_node("PartyGroup").get_index())
	domain.check_contacts()
	assert(target.current_hp == 1000000)
	assert(other.current_hp == 1000000)
	manager.state = manager.BattleState.PLAYER_TURN
	await manager.player_use_skill("火域", actor)
	assert(actor.current_mp == mp_before - 30)
	assert(actor.completed_actions == 1)
	# 自身主动移动靠近敌人。
	manager.state = manager.BattleState.PLAYER_ACTION
	actor.get_parent().global_position = Vector2(765, 400)
	domain.check_contacts()
	assert(target.current_hp < 1000000)
	assert(other.current_hp == 1000000)
	assert(domain.global_position == actor.get_parent().global_position)
	var after_first: int = target.current_hp
	for i in 10: domain.check_contacts()
	assert(target.current_hp == after_first)
	actor.get_parent().global_position = Vector2(500, 400)
	domain.check_contacts()
	actor.get_parent().global_position = Vector2(765, 400)
	domain.check_contacts()
	assert(target.current_hp < after_first)
	var after_second: int = target.current_hp
	for i in 10: domain.check_contacts()
	assert(target.current_hp == after_second)
	# 敌人主动进入，敌人回合也结算法术伤害和骰子结果。
	actor.dice_has_pending = true
	actor.dice_pending_multiplier = 3.0
	manager._current_actor = other
	manager.state = manager.BattleState.ENEMY_TURN
	var skill = load("res://Script/Battle/SkillManager.gd").get_skill("火域")
	var expected := maxi(1, int(actor.get_effective_magic_attack() * skill.damage_multiplier) - int(other.get_effective_magic_defense() * 0.6)) * 3
	other.get_parent().global_position = Vector2(765, 410)
	domain.check_contacts()
	assert(other.current_hp == 1000000 - expected)
	assert(not actor.dice_has_pending)
	assert(manager.damage_stats["banshouren"] > 0)
	assert(domain.contact_enemies.size() == 2)
	# 低帧率下单帧穿过整个火圈也触发，随后停在圈外不重复扣血。
	other.get_parent().global_position = Vector2(965, 400)
	domain.check_contacts()
	var before_cross: int = other.current_hp
	other.get_parent().global_position = Vector2(565, 400)
	domain.check_contacts()
	assert(other.current_hp < before_cross)
	var after_cross: int = other.current_hp
	for i in 10: domain.check_contacts()
	assert(other.current_hp == after_cross)
	actor.is_dead = true
	domain.check_contacts()
	await process_frame
	assert(not actor.has_meta("fire_domain"))
	print("FIRE DOMAIN PASS: cost, duplicate guard, repeated entry, stay guard, single-frame crossing, caster/enemy movement, follow, layering, off-turn dice, damage stats, death cleanup")
	host.queue_free()
	await process_frame
	quit()
