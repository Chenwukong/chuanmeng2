extends SceneTree
var intro: CanvasLayer
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	intro = load("res://scenes/TitleScreen.tscn").instantiate()
	if "--autoplay" in OS.get_cmdline_user_args():
		root.add_child(intro)
		current_scene = intro
		if DisplayServer.get_name() != "headless":
			assert(root.mode == Window.MODE_FULLSCREEN)
			assert(root.borderless and root.transparent and root.transparent_bg)
			assert(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND)
		await intro.closed
		assert(current_scene.scene_file_path == "res://scenes/UI/TitleMenu.tscn")
		assert(not root.transparent_bg and not root.transparent)
		print("INTRO PLAYBACK PASS ", OS.get_cmdline_user_args())
		quit()
		return
	intro.preview_only = true
	root.transparent_bg = false
	root.add_child(intro)
	current_scene = intro
	intro.set_process(false)
	for sample in [0.8, 1.5, 3.3, 5.25, 6.25]:
		intro._render_opening(sample)
		intro.get_node("Mist").material.set_shader_parameter("phase", sample)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Godot/传梦之路2/artifacts/intro-%.2f.png" % sample)
	assert(intro.get_node("Mist").material.get_shader_parameter("coverage") == 1.0)
	intro.preview_only = false
	ResourceLoader.load_threaded_request(intro.game_scene)
	intro._enter_game()
	await intro.closed
	assert(current_scene.scene_file_path == "res://scenes/UI/TitleMenu.tscn")
	assert(not root.transparent_bg)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Godot/传梦之路2/artifacts/intro-main.png")
	print("INTRO PASS: full mist, title menu transition, window restored")
	quit()
