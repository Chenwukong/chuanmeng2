extends SceneTree
func _initialize() -> void:
	call_deferred("preview")
func preview() -> void:
	root.size = Vector2i(1100, 740)
	var data = root.get_node("GameData")
	data.set_process(false)
	data.restore_difficulty(1)
	change_scene_to_file("res://scenes/MainScene.tscn")
	await scene_changed
	await load("res://Script/Assets/BattleAssetLoader.gd").scene_ready(self)
	var button = current_scene.get_node("UI/DebugCheatButton")
	assert(button.visible)
	button._activate()
	assert(button.text.contains("已开启"))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/debug_cheat_button_preview.png")
	print("DEBUG BUTTON PREVIEW SAVED")
	quit()