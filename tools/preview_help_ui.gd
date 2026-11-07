extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1300, 800)
	var main = load("res://scenes/MainScene.tscn").instantiate()
	main.tree_entered.connect(func(): current_scene = main)
	root.add_child(main)
	await create_timer(0.5).timeout
	var help = main.get_node("HelpUI")
	help.toggle()
	assert(root.get_node("GameData").ui_blocked)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Godot/传梦之路2/artifacts/help_ui_preview.png")
	help.close()
	assert(not root.get_node("GameData").ui_blocked)
	print("HELP OPEN/CLOSE + PREVIEW: PASS")
	quit()
