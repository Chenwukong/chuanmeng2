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
	actor.stats.max_hp = 1000
	actor.current_hp = 1000
	actor.stats.max_mp = 10000
	actor.current_mp = 10000
	actor.stats.magic_attack = 100
	actor.trait_data.clear()
	actor.equip_special.clear()
	for foe in manager.enemies:
		foe.stats.max_hp = 100000
		foe.current_hp = 100000
		foe.trait_data.clear()
		foe.equip_special.clear()
	data.talent_points = 20
	var tree = load("res://scenes/UI/TalentTree.tscn").instantiate()
	host.add_child(tree)
	tree.show_page("Page_Main")
	var love = tree.get_node("Pages/Page_Main/爱屋及乌")
	var legion = tree.get_node("Pages/Page_Main/兵多将广")
	assert(legion.max_rank == 3)
	assert(not legion.requirements_met())
	tree._try_upgrade_talent(legion)
	assert(legion.rank == 0)
	assert(data.talent_points == 20)
	tree._try_upgrade_talent(love)
	assert(legion.requirements_met())
	var enemy = manager.enemies[0]
	for rank in 4:
		if rank > 0: tree._try_upgrade_talent(legion)
		assert(legion.rank == rank)
		manager._current_actor = actor
		manager.state = manager.BattleState.PLAYER_TURN
		manager.skill_cooldowns.clear()
		var hp_before: int = enemy.current_hp
		await manager.player_use_skill("撒豆成兵", actor)
		var army = actor.get_meta("bean_army")
		assert(army.units.size() == 3 + rank)
		assert(manager.bean_soldiers.size() == 3 + rank)
		assert(manager._count_summoned_pets() == 0)
		assert(enemy.current_hp == hp_before - (3 + rank) * 30)
		for unit in army.units:
			assert(not unit.materializing)
			assert(unit.home.x > actor.get_parent().global_position.x)
			for other in army.units:
				if unit != other: assert(unit.home.distance_to(other.home) >= 42.0)
	assert(not legion.can_upgrade(20))
	# 有后置时右键退前置必须失败，也不能凭空退还点数。
	var refund := InputEventMouseButton.new()
	refund.pressed = true
	refund.button_index = MOUSE_BUTTON_RIGHT
	var points: int = data.talent_points
	love._on_gui_input(refund)
	assert(love.rank == 1)
	assert(data.talent_points == points)
	# 六名豆兵逐段挡伤，全部耗尽后才伤到主角。
	var army = actor.get_meta("bean_army")
	manager._current_actor = enemy
	manager.state = manager.BattleState.ENEMY_TURN
	var owner_hp: int = actor.current_hp
	for hit in 6:
		manager.apply_damage(enemy, actor, 9999)
		assert(actor.current_hp == owner_hp)
	assert(army.get_guardian() == null)
	manager.apply_damage(enemy, actor, 1)
	assert(actor.current_hp == owner_hp - 1)
	# 满级补员依然最多6名。
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	manager.skill_cooldowns.clear()
	await manager.player_use_skill("撒豆成兵", actor)
	assert(manager.bean_soldiers.size() == 6)
	# 逐级退点后重施，按当前数量上限清掉超额豆兵。
	for rank in [2, 1, 0]:
		legion._on_gui_input(refund)
		assert(legion.rank == rank)
		manager._current_actor = actor
		manager.state = manager.BattleState.PLAYER_TURN
		manager.skill_cooldowns.clear()
		await manager.player_use_skill("撒豆成兵", actor)
		assert(manager.bean_soldiers.size() == 3 + rank)
		assert(army.units.size() == 3 + rank)
	love._on_gui_input(refund)
	assert(love.rank == 0)
	assert(data.talent_points == 20)
	print("BEAN LEGION PASS: prerequisite, 3 ranks, 3-6 soldiers, no overlap, materialize-before-attack, wave damage, 6 guards, refill cap, downgrade cleanup, dependent refund cannot grant free points")
	host.queue_free()
	await process_frame
	quit()