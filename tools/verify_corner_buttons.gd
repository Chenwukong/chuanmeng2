extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
func verify() -> void:
	var data = root.get_node("GameData")
	data.set_process(false)
	data.restore_difficulty(1)
	change_scene_to_file("res://scenes/MainScene.tscn")
	await scene_changed
	await load("res://Script/Assets/BattleAssetLoader.gd").scene_ready(self)
	var achievement = current_scene.get_node("UI/AchievementButton")
	var help = current_scene.get_node("HelpUI/HelpButton")
	for view_size in [Vector2i(1100, 740), Vector2i(1600, 900), Vector2i(1024, 768)]:
		root.size = view_size
		achievement.text = "成就 99"
		await process_frame
		await process_frame
		print("CORNER RECTS: ", rect(achievement), " / ", rect(help))
		assert(not rect(achievement).intersects(rect(help)))
		assert(rect(achievement).end.x < rect(help).position.x)
		assert(rect(help).end.x <= root.get_visible_rect().size.x)
		assert(achievement.get_theme_font_size("font_size") == help.get_theme_font_size("font_size"))
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var screenshot = root.get_texture().get_image()
			var area := Rect2i(screenshot.get_width() - 300, 0, 300, 110)
			screenshot.get_region(area).save_png("res://artifacts/corner_buttons_%d.png" % view_size.x)
	achievement.text = "成就"
	current_scene.get_node("HelpUI").toggle()
	assert(current_scene.get_node("HelpUI").is_open())
	current_scene.get_node("HelpUI").close()
	assert(not current_scene.get_node("HelpUI").is_open())
	print("CORNER BUTTONS PASS: matching scene styles, no overlap at 1100/1600/1024 widths, achievement badge 99 fits, help open/close")
	quit()