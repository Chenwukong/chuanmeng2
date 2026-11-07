extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var scene = load("res://scenes/UI/HelpUI.tscn")
	assert(scene != null)
	var ui = scene.instantiate()
	root.add_child(ui)
	await process_frame
	var pages = ui.get_node("Overlay/Panel/Layout/Body/Pages")
	assert(pages.get_child_count() == 7)
	for i in 7:
		ui._select(i)
		assert(pages.current_tab == i)
		assert(ui.categories.get_child(i).button_pressed)
		assert(pages.get_child(i).text.length() > 100)
	assert(load("res://scenes/MainScene.tscn").can_instantiate())
	print("HELP UI: PASS — seven populated categories and selection")
	ui.queue_free()
	await process_frame
	quit()
