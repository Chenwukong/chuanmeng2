extends SceneTree
func _initialize() -> void:
	call_deferred("preview")
func preview() -> void:
	root.size = Vector2i(960, 640)
	var data = root.get_node("GameData")
	data.talent_ranks = {}
	data.add_party_by_name("半兽人")
	data.party_order.assign(["banshouren"])
	data.pet_team.clear()
	data.set_meta("pending_party", data.party_order.duplicate())
	data.set_meta("pending_enemies", ["火沙虫"])
	var host := Node2D.new()
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
	await create_timer(1.0).timeout
	var manager = battle.get_node("BattleManager")
	manager.set_process(false)
	manager.action_delay = 0.01
	manager._current_actor = manager.party[0]
	manager.state = manager.BattleState.PLAYER_TURN
	await manager.player_use_skill("火域", manager.party[0])
	if "--crowded" in OS.get_cmdline_user_args():
		var actor = manager.party[0]
		actor.get_parent().reload_was("res://WAS/小二真身")
		manager.enemies[0].get_parent().global_position = actor.get_parent().global_position + Vector2(76, -26)
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/fire_domain_crowded.png" if "--crowded" in OS.get_cmdline_user_args() else "res://artifacts/fire_domain_preview.png")
	print("FIRE_DOMAIN_PREVIEW_SAVED")
	quit()
