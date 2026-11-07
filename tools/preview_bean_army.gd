extends SceneTree
func _initialize() -> void:
	call_deferred("preview")
func preview() -> void:
	root.size = Vector2i(960, 640)
	var data = root.get_node("GameData")
	data.talent_ranks = {"main_bean_legion": 3, "summon_love_allies": 1}
	data.add_party_by_name("游霄云")
	data.add_party_by_name("叮咚")
	data.add_party_by_name("半兽人")
	data.add_party_by_name("神天兵")
	data.party_order.assign(["youxiaoyun", "dingdong", "banshouren", "shentianbing"])
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
	await manager.player_use_skill("三才阵", manager.party[0])
	manager.state = manager.BattleState.PLAYER_TURN
	await manager.player_use_skill("撒豆成兵", manager.party[0])
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/bean_army_preview.png")
	print("BEAN_ARMY_PREVIEW_SAVED")
	quit()
