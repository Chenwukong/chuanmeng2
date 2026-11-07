extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var data = root.get_node("GameData")
	data.talent_ranks = {}
	data.add_party_by_name("游霄云")
	data.add_party_by_name("叮咚")
	data.party_order.assign(["youxiaoyun", "dingdong"])
	data.pet_team.clear()
	data.set_meta("pending_party", data.party_order.duplicate())
	data.set_meta("pending_enemies", ["火沙虫", "火沙虫", "火沙虫"])
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
	manager.action_delay = 0.05
	var actor = manager.party[0]
	actor.stats.max_mp = 10000
	actor.current_mp = 10000
	actor.stats.magic_attack = 100
	actor.trait_data.clear()
	var target = manager.enemies[0]
	for enemy in manager.enemies:
		enemy.stats.max_hp = 100000
		enemy.current_hp = 100000
		enemy.equip_special.clear()
		enemy.trait_data.clear()
	assert("撒豆成兵" in data.get_all_skills("youxiaoyun"))
	var party_count: int = manager.party.size()
	var pet_count: int = manager._count_summoned_pets()
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	await manager.player_use_skill("撒豆成兵", actor)
	assert(actor.current_mp == 9970)
	assert(manager.party.size() == party_count)
	assert(manager._count_summoned_pets() == pet_count)
	assert(manager.bean_soldiers.size() == 3)
	assert(actor.has_meta("bean_army"))
	var army = actor.get_meta("bean_army")
	assert(army.rounds_left == 3)
	assert(target.current_hp == 99910)
	assert(manager.damage_stats[actor.member_id] == 90)
	var selected_bean := false
	for attempt in 200:
		if manager.enemy_ai._pick_threat_target() in manager.bean_soldiers: selected_bean = true
	assert(selected_bean)
	manager._threat_mgr.taunt(actor)
	for attempt in 20: assert(manager.enemy_ai._pick_threat_target() == actor)
	manager._threat_mgr._taunt_map.clear()
	# 被敌方击破，随后重施只补齐缺员、不新增第四名。
	var victim = army.units[0].character
	manager._current_actor = target
	manager.state = manager.BattleState.ENEMY_TURN
	target.stats.attack = 9999
	await manager.execute_enemy_skill(target, "普通攻击", victim)
	assert(victim.is_dead)
	assert(army.units[0].get_node("Body").visible == false)
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	manager.skill_cooldowns.clear()
	await manager.player_use_skill("撒豆成兵", actor)
	assert(manager.bean_soldiers.size() == 3)
	assert(army.rounds_left == 3)
	for unit in army.units: assert(not unit.character.is_dead)
	assert(manager.party.size() == party_count)
	# 三才阵内敌人优先；原目标仍在阵外也不影响优先级。
	manager.state = manager.BattleState.PLAYER_TURN
	manager.skill_cooldowns.clear()
	await manager.player_use_skill("三才阵", actor)
	var field = manager.get_meta("sancai_domain")
	field.set_process(false)
	manager.enemies[0].get_parent().global_position = field.global_position + Vector2(field.radius + 150, 0)
	manager.enemies[1].get_parent().global_position = field.global_position
	manager._last_target = manager.enemies[0]
	assert(army.choose_target() == manager.enemies[0])
	data.set_talent_rank("main_bean_formation", 1)
	assert(army.choose_target() == manager.enemies[1])
	# 4轮到期消失，不残留目标或占用队伍位置。
	while is_instance_valid(army) and army.rounds_left > 0:
		manager._current_actor = actor
		manager.state = manager.BattleState.PLAYER_ACTION
		await army.after_owner_action()
	await process_frame
	await process_frame
	assert(not actor.has_meta("bean_army"))
	assert(manager.bean_soldiers.is_empty())
	assert(manager.party.size() == party_count)
	# 豆兵出击中被打散，不得因为 Tween 被终止而卡住整个行动。
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	manager.skill_cooldowns.clear()
	await manager.player_use_skill("撒豆成兵", actor)
	var last_army = actor.get_meta("bean_army")
	last_army.rounds_left = 1
	var interrupted = last_army.units[0]
	create_timer(0.08).timeout.connect(interrupted.disperse)
	manager.state = manager.BattleState.PLAYER_ACTION
	await last_army.after_owner_action()
	await process_frame
	await process_frame
	assert(not actor.has_meta("bean_army"))
	assert(manager.bean_soldiers.is_empty())
	print("BEAN ARMY PASS: innate skill, 3 soldiers, 30% magic attack, owner damage stats, 4 waves, targetable/destructible, refill no stacking, no party/pet slots, formation priority, expiration cleanup")
	host.queue_free()
	await process_frame
	quit()