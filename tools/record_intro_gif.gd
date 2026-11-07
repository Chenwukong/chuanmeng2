extends SceneTree
func _initialize():
	_run.call_deferred()
func _run():
	root.size = Vector2i(780,480)
	var intro = load("res://scenes/TitleScreen.tscn").instantiate()
	root.add_child(intro)
	current_scene = intro
	for i in 240:
		await process_frame
		await RenderingServer.frame_post_draw
		var shot = root.get_texture().get_image()
		shot.resize(780,480,Image.INTERPOLATE_LANCZOS)
		shot.convert(Image.FORMAT_RGBA8)
		var background = Image.create(780,480,false,Image.FORMAT_RGBA8)
		background.fill(Color(0.035,0.065,0.105,1))
		background.blend_rect(shot,Rect2i(0,0,780,480),Vector2i.ZERO)
		background.save_png("C:/Godot/传梦之路2/artifacts/intro-gif-frames/%04d.png" % i)
	print("INTRO RECORD PASS")
	quit()
