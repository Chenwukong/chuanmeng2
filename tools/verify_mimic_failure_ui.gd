extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var data = root.get_node("GameData")
	data.talent_ranks = {}
	data.add_party_by_name("半兽人")
	data.add_party_by_name("叮咚")
	data.party_order.assign(["banshouren", "dingdong"])
	data.pet_team.clear()
	data.set_meta("pending_party", data.party_order.duplicate())
	data.set_meta("pending_enemies", ["火沙虫", "火沙虫", "火沙虫"])
	var host := Node2D.new()
	host.name = "Fixture"
	root.add_child(host)
	current_scene = host
	var ui := Node.new()
	ui.name = "UI"
	host.add_child(ui)
	var log := RichTextLabel.new()
	log.name = "BattleLog"
	ui.add_child(log)
	var battle = load("res://scenes/Battle/battleField.tscn").instantiate()
	host.add_child(battle)
	await create_timer(1.5).timeout
	var manager = battle.get_node("BattleManager")
	manager.set_process(false)
	manager.action_delay = 0.05
	var actor = manager.party[0]
	var teammate = manager.party[1]
	var battle_ui = battle.get_node("BattleUI")
	actor.trait_data.clear()
	var original_mp: int = actor.current_mp
	var original_actions: int = actor.completed_actions
	for failure in ["no_history", "mana", "cooldown", "silence"]:
		for input_mode in ["mouse", "keyboard"]:
			manager._current_actor = actor
			manager.state = manager.BattleState.PLAYER_TURN
			manager.ally_skill_history.clear()
			manager.skill_cooldowns.clear()
			actor.current_mp = original_mp
			actor.remove_buff("silence")
			if failure != "no_history":
				manager.ally_skill_history[teammate] = {"skill": "金刚护体", "target": weakref(teammate)}
			if failure == "mana": actor.current_mp = 0
			if failure == "cooldown": manager.skill_cooldowns[manager._cd_key(actor, "金刚护体")] = 2
			if failure == "silence": actor.add_buff("silence", 3)
			var mp_before: int = actor.current_mp
			battle_ui._on_state_changed(manager.BattleState.PLAYER_TURN)
			battle_ui.action_panel.slide_out()
			battle_ui._action_skill("千机变")
			assert(battle_ui.action_panel.btn_skill.disabled)
			if input_mode == "mouse":
				var index: int = battle_ui._ally_pick_nodes.find(teammate.get_parent())
				assert(index >= 0)
				battle_ui._ally_pick_btns[index].pressed.emit()
			else:
				battle_ui._ally_select_idx = battle_ui._selectable_allies().find(teammate)
				var event := InputEventAction.new()
				event.action = "ui_accept"
				event.pressed = true
				battle_ui._unhandled_input(event)
			await process_frame
			await create_timer(0.3).timeout
			assert(manager.state == manager.BattleState.PLAYER_TURN)
			assert(actor.current_mp == mp_before)
			assert(actor.completed_actions == original_actions)
			assert(not battle_ui._pending_action.is_valid())
			assert(battle_ui._selection_mode == battle_ui.SelectionMode.NONE)
			assert(battle_ui._ally_pick_btns.is_empty())
			assert(battle_ui.action_panel.visible)
			assert(not battle_ui.action_panel.btn_attack.disabled)
			assert(not battle_ui.action_panel.btn_skill.disabled)
			assert(not battle_ui.action_panel.btn_item.disabled)
			assert(battle_ui.action_panel.position.x < 1900)
			assert("选择行动" in battle_ui.actor_indicator.text)
	print("MIMIC FAILURE UI PASS: mouse + keyboard, no history/mana/cooldown/silence, menu restored, targeting cleared, no resource or turn consumed")
	host.queue_free()
	await process_frame
	quit()