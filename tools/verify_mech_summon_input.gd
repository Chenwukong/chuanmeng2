extends SceneTree
var chosen: Array[String] = []
func _initialize():
	_run.call_deferred()
func key(code):
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
func _run():
	var button = Button.new()
	button.text = "底层战斗按钮"
	root.add_child(button)
	button.grab_focus()
	var popup = load("res://scenes/UI/Mech/MechSummonPopup.tscn").instantiate()
	root.add_child(popup)
	popup.open()
	# 固定两个条目，验证真实 Viewport 输入分发与底层按钮焦点的冲突。
	for child in popup.grid.get_children(): child.free()
	popup._mech_names.assign(["test_beast", "test_bird"])
	for i in 2: popup.grid.add_child(load("res://scenes/UI/Mech/MechSummonEntry.tscn").instantiate())
	popup.mech_selected.connect(func(id): chosen.append(id))
	await process_frame
	popup._update_highlight()
	key(KEY_DOWN)
	assert(popup._selected_idx == 1)
	assert(popup.grid.get_child(1).get_node("Selected").visible)
	key(KEY_UP)
	assert(popup._selected_idx == 0)
	key(KEY_DOWN)
	key(KEY_ENTER)
	key(KEY_ENTER)
	assert(chosen == ["test_bird"])
	await create_timer(0.6).timeout
	assert(not popup.visible)
	popup.open()
	await process_frame
	key(KEY_ESCAPE)
	await create_timer(0.6).timeout
	assert(not popup.visible)
	print("MECH SUMMON INPUT: PASS (down/up/highlight/accept/repeat/cancel)")
	quit()

