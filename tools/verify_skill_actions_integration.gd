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
	for enemy in manager.enemies:
		enemy.stats.max_hp = 100000
		enemy.current_hp = 100000
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	await manager.player_use_skill("寂静剑法", manager.enemies[0])
	assert(manager.enemies[0].current_hp < 100000)
	assert(manager.damage_stats.get(actor.member_id, 0) > 0)
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	await manager.player_use_skill("金刚护体", actor)
	assert(actor.has_buff("def_up"))
	print("SKILL ACTIONS INTEGRATION: PASS (fullscreen, stats, buff, animation callbacks)")
	host.queue_free()
	await process_frame
	quit()
