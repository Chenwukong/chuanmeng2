extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var data = root.get_node("GameData")
	data.set_process(false)
	data.restore_difficulty(1)
	data.game_flags = {}
	data.dialogue_progress = {}
	data.ui_blocked = true
	change_scene_to_file("res://scenes/MainScene.tscn")
	await scene_changed
	await load("res://Script/Assets/BattleAssetLoader.gd").scene_ready(self)
	var map = current_scene.get_node("方寸山")
	var player = map.get_node("Player")
	var bodhi = map.get_node("菩提祖师")
	var trigger = map.get_node("菩提剧情触发")
	assert(not data.story_flag("方寸山/菩提/事变完成"))
	player.global_position = bodhi.global_position + Vector2(400, 400)
	assert(not trigger._contains(player))
	data.ui_blocked = false
	player.global_position = bodhi.global_position + Vector2(0, 110)
	assert(trigger._contains(player))
	trigger._process(0.0)
	assert(data._npc_dialogue_playing)
	var saw_control := false
	var saw_apology := false
	for frame in 400:
		await create_timer(0.05).timeout
		for balloon in get_nodes_in_group("ballon"):
			if not is_instance_valid(balloon.get("dialogue_line")): continue
			var line: String = balloon.dialogue_line.text
			if balloon.visible and player.has_node("BodhiBinding") and line.contains("动不了了"):
				saw_control = true
				assert(not player.is_processing())
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://artifacts/bodhi_binding_preview.png")
			if balloon.visible and balloon.is_waiting_for_input and line.contains("对不起"):
				saw_apology = true
				assert(not player.has_node("BodhiBinding"))
				assert(player.visible)
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://artifacts/bodhi_faint_preview.png")
			if balloon.dialogue_label.is_typing: balloon.dialogue_label.skip_typing()
			elif balloon.is_waiting_for_input: balloon.next.call(balloon.dialogue_line.next_id)
		if data.story_flag("方寸山/菩提/事变完成") and not data._npc_dialogue_playing: break
	assert(saw_control and saw_apology)
	assert(data.story_flag("方寸山/菩提/事变完成"))
	assert(data.story_flag(trigger._save_key()))
	assert(not player.visible and not player.is_processing())
	for npc in map.get_children():
		if npc.has_method("look_at_target"): assert(not npc.visible)
	assert(not data.ui_blocked)
	var saved = load("res://Script/Save/SaveService.gd").serialize_state(data)
	assert(saved.game_flags["方寸山/菩提/事变完成"])
	change_scene_to_file("res://scenes/MainScene.tscn")
	await scene_changed
	map = current_scene.get_node("方寸山")
	assert(not map.get_node("Player").visible)
	assert(not map.get_node("菩提祖师").visible)
	assert(not map.get_node("菩提剧情触发").is_processing())
	print("BODHI STORY PASS: approach trigger, actual dialogue and spell mutation, binding locks player, faint before apology, all map people hidden, one-time flag and serialized state, re-entry stays hidden")
	quit()