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
	actor.trait_data.clear()
	for enemy in manager.enemies:
		enemy.stats.max_hp = 100000
		enemy.current_hp = 100000
		enemy.get_parent().global_position = Vector2(-1000, -1000)
	data.talent_points = 10
	var tree = load("res://scenes/UI/TalentTree.tscn").instantiate()
	host.add_child(tree)
	var love = tree.get_node("Pages/Page_Main/爱屋及乌")
	var legion = tree.get_node("Pages/Page_Main/兵多将广")
	var formation = tree.get_node("Pages/Page_Main/豆兵阵")
	assert(formation.max_rank == 1)
	assert(not formation.can_upgrade(10))
	tree._try_upgrade_talent(formation)
	assert(data.talent_points == 10)
	tree._try_upgrade_talent(love)
	assert(not formation.can_upgrade(9))
	tree._try_upgrade_talent(legion)
	assert(formation.can_upgrade(8))
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	await manager.player_use_skill("撒豆成兵", actor)
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	await manager.player_use_skill("三才阵", actor)
	var army = actor.get_meta("bean_army")
	var field = manager.get_meta("sancai_domain")
	field.set_process(false)
	var outside = manager.enemies[0]
	var inside = manager.enemies[1]
	outside.get_parent().global_position = field.global_position + Vector2(field.radius + 100, 0)
	inside.get_parent().global_position = field.global_position
	manager._last_target = outside
	assert(army.choose_target() == outside)
	tree._try_upgrade_talent(formation)
	assert(data.talent_points == 7)
	assert(army.choose_target() == inside)
	# 没有阵地、阵内敌人死亡时，正常回退原目标。
	manager.remove_meta("sancai_domain")
	assert(army.choose_target() == outside)
	manager.set_meta("sancai_domain", field)
	inside.is_dead = true
	assert(army.choose_target() == outside)
	inside.is_dead = false
	assert(army.choose_target() == inside)
	# 后置已学时不能退前置；退豆兵阵后立即关闭联动。
	var refund := InputEventMouseButton.new()
	refund.pressed = true
	refund.button_index = MOUSE_BUTTON_RIGHT
	legion._on_gui_input(refund)
	assert(legion.rank == 1)
	assert(data.talent_points == 7)
	formation._on_gui_input(refund)
	assert(data.talent_points == 8)
	assert(army.choose_target() == outside)
	legion._on_gui_input(refund)
	love._on_gui_input(refund)
	assert(data.talent_points == 10)
	assert(actor.has_buff("sancai"))
	assert(manager.party[1].has_buff("sancai"))
	print("BEAN FORMATION TALENT PASS: prerequisite, point cost, unlearned no linkage, learned formation priority, missing field/dead enemy fallback, refund disables linkage, dependent refund blocked, formation buffs unaffected")
	host.queue_free()
	await process_frame
	quit()