extends SceneTree
func _initialize() -> void:
	call_deferred("preview")
func preview() -> void:
	root.size = Vector2i(1100, 740)
	var data = root.get_node("GameData")
	data.talent_ranks = {}
	data.talent_points = 15
	var tree = load("res://scenes/UI/TalentTree.tscn").instantiate()
	root.add_child(tree)
	current_scene = tree
	tree.show_page("Page_Main")
	var love = tree.get_node("Pages/Page_Main/爱屋及乌")
	tree._try_upgrade_talent(love)
	await create_timer(0.5).timeout
	love.set_meta("keyboard_selected", true)
	tree._show_talent_detail(love)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/love_allies_talent_preview.png")
	print("LOVE TALENT PREVIEW SAVED")
	quit()
