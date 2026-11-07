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
	var target = manager.enemies[0]
	var original_team = data.mech_team.duplicate()
	var cases := ["silence", "cooldown", "mana", "unknown_skill", "ghost", "sacrifice", "wait", "dice", "invalid_attack", "invalid_capture", "invalid_item", "revive_alive", "summon_role", "summon_null", "missing_mech", "mech_mana", "empty_mech", "unknown_popup_skill", "unknown_popup_item", "no_revive_target", "cancel_enemy", "cancel_popup", "cancel_summon", "cancel_mech", "empty_pet_replace", "empty_mech_replace", "empty_enemy", "empty_capture"]
	for scenario in cases:
		manager._current_actor = actor
		manager.state = manager.BattleState.PLAYER_TURN
		manager.skill_cooldowns.clear()
		manager._双动_first_type = manager.DoubleActionType.NONE
		manager._双动_second_phase = false
		actor.buffs.clear()
		actor.current_mp = 10000
		actor.current_hp = actor.get_effective_max_hp()
		actor.dice_has_pending = false
		actor.trait_data.clear()
		target.is_dead = false
		data.mech_team.assign(original_team)
		battle_ui._cancel_pending()
		battle_ui.action_panel.visible = false
		battle_ui.action_panel.set_enabled(false)
		var mp_before: int = actor.current_mp
		var turns_before: int = actor.completed_actions
		var count_before := 0
		var revive_id := ""
		match scenario:
			"silence":
				actor.add_buff("silence", 2)
				await manager.player_use_skill("金刚护体", actor)
			"cooldown":
				manager.skill_cooldowns[manager._cd_key(actor,"金刚护体")] = 2
				await manager.player_use_skill("金刚护体", actor)
			"mana":
				actor.current_mp = 0
				mp_before = 0
				await manager.player_use_skill("金刚护体", actor)
				assert(manager.skill_cooldowns.is_empty())
			"unknown_skill": await manager.player_use_skill("不存在的技能", actor)
			"ghost": await manager.player_use_skill("鬼影护体", actor)
			"sacrifice":
				actor.current_hp = 1
				await manager.player_use_skill("舍生取义", teammate)
			"wait": await manager.player_use_skill("真身显现", actor)
			"dice":
				actor.dice_has_pending = true
				await manager.player_use_skill("扔色子", actor)
			"invalid_attack":
				target.is_dead = true
				await manager.player_use_normal_attack(target)
			"invalid_capture":
				target.is_dead = true
				await manager.player_capture(target)
			"invalid_item": await manager.player_use_item("不存在的道具", actor)
			"revive_alive":
				for id in data.item_db:
					if data.item_db[id].item_type == ItemData.ItemType.REVIVE:
						revive_id = id
						break
				if not revive_id.is_empty():
					manager.player_inventory.add_item(data.item_db[revive_id], 1)
					count_before = manager.player_inventory.get_count(revive_id)
					await manager.player_use_item(revive_id, actor)
					assert(manager.player_inventory.get_count(revive_id) == count_before)
			"summon_role": await manager.player_summon(load("res://Script/Data/Models/PetData.gd").new())
			"summon_null": await manager.player_summon(null)
			"missing_mech": await manager.player_summon_mech("不存在的铁甲")
			"mech_mana":
				actor.current_mp = 0
				mp_before = 0
				await manager.player_summon_mech(data.mech_db.keys()[0])
			"empty_mech":
				data.mech_team.clear()
				battle_ui._show_mech_summon_popup()
			"unknown_popup_skill": battle_ui._action_skill("不存在的技能")
			"unknown_popup_item": battle_ui._action_item("不存在的道具")
			"no_revive_target": battle_ui._set_pending_dead_ally(func(_ch): pass)
			"cancel_enemy":
				battle_ui._set_pending(func(_ch): pass)
				var event := InputEventAction.new()
				event.action = "ui_cancel"
				event.pressed = true
				battle_ui._unhandled_input(event)
			"cancel_popup": battle_ui._on_popup_cancelled()
			"cancel_summon": battle_ui._on_summon_cancelled()
			"cancel_mech": battle_ui._on_mech_summon_cancelled()
			"empty_pet_replace":
				battle_ui._pending_summon_pet = load("res://Script/Data/Models/PetData.gd").new()
				battle_ui._enable_pet_replace_selection(true)
			"empty_mech_replace":
				battle_ui._pending_mech_name = "test"
				battle_ui._enable_mech_replace_selection(true)
			"empty_enemy":
				for enemy in manager.enemies: enemy.is_dead = true
				battle_ui._set_pending(func(_ch): pass)
			"empty_capture":
				for enemy in manager.enemies: enemy.is_dead = true
				battle_ui._set_pending_capture(func(_ch): pass)
		await process_frame
		await create_timer(0.25).timeout
		assert(manager.state == manager.BattleState.PLAYER_TURN, scenario)
		assert(actor.current_mp == mp_before, scenario)
		assert(actor.completed_actions == turns_before, scenario)
		assert(battle_ui.action_panel.visible, scenario)
		assert(not battle_ui.action_panel.btn_skill.disabled, scenario)
		assert(not battle_ui.action_panel.btn_attack.disabled, scenario)
		assert(not battle_ui._pending_action.is_valid(), scenario)
		assert(battle_ui._selection_mode == battle_ui.SelectionMode.NONE, scenario)
		assert(battle_ui._ally_pick_btns.is_empty(), scenario)
		print("RECOVERY PASS: ", scenario)
	print("BATTLE ACTION RECOVERY PASS: ", cases.size(), " failure/cancel scenarios")
	host.queue_free()
	await process_frame
	quit()