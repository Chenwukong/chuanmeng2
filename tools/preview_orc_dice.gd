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
	battle.get_node("BattleManager").set_process(false)
	var overlay = load("res://scenes/UI/BattleDiceRoll.tscn").instantiate()
	host.add_child(overlay)
	overlay.roll(6)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/dice_throw_air.png")
	await create_timer(0.65).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/dice_throw_bounce.png")
	await create_timer(1.15).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/orc_dice_preview.png")
	print("DICE_PREVIEW_SAVED")
	quit()
