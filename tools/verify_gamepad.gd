extends SceneTree
class Recorder extends Node:
	var keys: Array = []
	func _input(event: InputEvent) -> void:
		if event is InputEventKey: keys.append([event.keycode, event.pressed, event.alt_pressed])
func _initialize() -> void:
	call_deferred("verify")
func button(index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame
	await process_frame
func axis(index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = index
	event.axis_value = value
	Input.parse_input_event(event)
	await process_frame
	await process_frame
func verify() -> void:
	var data = root.get_node("GameData")
	data.set_process(false)
	data.restore_difficulty(1)
	var pad = root.get_node("GamepadInput")
	var recorder := Recorder.new()
	root.add_child(recorder)
	await button(JOY_BUTTON_A, true)
	assert(recorder.keys.count([KEY_ENTER, true, false]) == 1)
	await button(JOY_BUTTON_A, false)
	assert(recorder.keys.count([KEY_ENTER, false, false]) == 1)
	await axis(JOY_AXIS_LEFT_X, 0.8)
	assert(pad.move_vector.x > 0.0)
	await axis(JOY_AXIS_LEFT_X, 0.1)
	assert(pad.move_vector.is_zero_approx())
	await button(JOY_BUTTON_DPAD_LEFT, true)
	assert(pad.move_vector.x < 0.0)
	pad._connection_changed(0, false)
	await process_frame
	await process_frame
	assert(pad.move_vector.is_zero_approx())
	assert(pad._held.is_empty())
	data.in_battle = true
	await button(JOY_BUTTON_Y, true)
	assert([KEY_W, true, true] in recorder.keys)
	await button(JOY_BUTTON_Y, false)
	await axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	assert([KEY_A, true, true] in recorder.keys)
	await axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	data.in_battle = false
	change_scene_to_file("res://scenes/MainScene.tscn")
	await scene_changed
	await load("res://Script/Assets/BattleAssetLoader.gd").scene_ready(self)
	var nav = current_scene.get_node("UI/UIKeyboardNavigator")
	await button(JOY_BUTTON_START, true)
	assert(nav.menu_open)
	await button(JOY_BUTTON_START, false)
	await button(JOY_BUTTON_A, true)
	await button(JOY_BUTTON_A, false)
	assert(data.ui_blocked)
	await button(JOY_BUTTON_B, true)
	await button(JOY_BUTTON_B, false)
	assert(not data.ui_blocked)
	# 真实战斗界面：Y打开技能、B返回、十字键换目标、A确认。
	data.in_battle = true
	data.set_meta("pending_enemies", ["火沙虫", "火沙虫", "火沙虫"])
	data.set_meta("pending_party", data.party_order.duplicate())
	var battle = load("res://scenes/Battle/battleField.tscn").instantiate()
	root.add_child(battle)
	await create_timer(1.5).timeout
	var manager = battle.get_node("BattleManager")
	manager.set_process(false)
	manager._current_actor = manager.party[0]
	manager.state = manager.BattleState.PLAYER_TURN
	var battle_ui = battle.get_node("BattleUI")
	battle_ui._on_actor_turn_started(manager.party[0], true)
	await button(JOY_BUTTON_Y, true)
	await button(JOY_BUTTON_Y, false)
	assert(battle_ui._skill_popup.visible)
	await button(JOY_BUTTON_B, true)
	await button(JOY_BUTTON_B, false)
	await create_timer(0.3).timeout
	assert(not battle_ui._skill_popup.visible)
	battle_ui.action_panel.set_enabled(false)
	battle_ui._selection_mode = battle_ui.SelectionMode.ENEMY
	battle_ui._enemy_select_idx = 0
	var selected_target := {"target": null}
	battle_ui._pending_action = func(target): selected_target.target = target
	await button(JOY_BUTTON_DPAD_RIGHT, true)
	await button(JOY_BUTTON_DPAD_RIGHT, false)
	assert(battle_ui._enemy_select_idx == 2)
	await button(JOY_BUTTON_A, true)
	await button(JOY_BUTTON_A, false)
	assert(selected_target.target == manager.enemies[2])
	pad.release_all()
	print("GAMEPAD PASS: one confirm event, button release, analog deadzone, movement vector, disconnect releases, battle skill/attack shortcuts, real world menu open/confirm/back, real battle skill popup and target confirm")
	quit()