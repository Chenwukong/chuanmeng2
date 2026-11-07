extends SceneTree

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture = load("res://scenes/MainScene.tscn").instantiate()
	var router = fixture.get_node("UI/UISounds")
	router.get_parent().remove_child(router)
	fixture.free()
	var host := Node.new()
	root.add_child(host)
	current_scene = host
	var ui := Node.new()
	ui.name = "UI"
	host.add_child(ui)
	ui.add_child(router)
	var button := Button.new()
	ui.add_child(button)
	router.bind(button)
	router.bind(button)
	button.pressed.emit()
	await process_frame
	check(router.played_count == 1 and router.last_played == &"confirm", "Button feedback plays once even after repeated binding")
	router.request(&"select")
	router.request(&"confirm")
	router.request(&"error")
	await process_frame
	check(router.played_count == 2 and router.last_played == &"error", "Failure feedback takes priority over the generic click")
	var cancel := Button.new()
	cancel.name = "CloseButton"
	ui.add_child(cancel)
	router.bind(cancel)
	cancel.pressed.emit()
	await process_frame
	check(router.last_played == &"cancel", "Closing uses return feedback")
	var slider := HSlider.new()
	ui.add_child(slider)
	router.bind(slider)
	await create_timer(0.08).timeout
	slider.value = 10
	await process_frame
	check(router.last_played == &"adjust", "Slider changes use adjustment feedback")
	var custom := Panel.new()
	ui.add_child(custom)
	router.bind(custom)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	custom.gui_input.emit(click)
	await process_frame
	check(router.last_played == &"confirm", "Custom inventory slots use the same click feedback")
	var before: int = router.played_count
	# 模拟原有界面自己的点击音：补音层应让位，避免叠加。
	var legacy := AudioStreamPlayer.new()
	legacy.stream = load("res://Audio/SE/001-System01.ogg")
	legacy.bus = &"SFX"
	ui.add_child(legacy)
	legacy.play()
	router.request(&"confirm")
	await process_frame
	check(router.played_count == before, "An existing dedicated UI sound suppresses the fallback")
	legacy.stop()
	root.get_node("GameData").in_battle = true
	router.request(&"confirm")
	await process_frame
	check(router.played_count == before, "Battle audio is left unchanged")
	root.get_node("GameData").in_battle = false
	check(router.get_node("Confirm").bus == &"SFX", "UI feedback follows the effects volume bus")
	for player in router.get_children():
		if player is AudioStreamPlayer: player.stop()
	await process_frame
	await process_frame
	host.queue_free()
	await process_frame
	print("UI SOUND TESTS: ", "PASS" if failures.is_empty() else "FAIL: %d" % failures.size())
	quit(0 if failures.is_empty() else 1)
