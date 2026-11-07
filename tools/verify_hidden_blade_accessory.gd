extends SceneTree
var manager
var actor
var target
var notices: Array[String] = []
func _initialize() -> void:
	verify.call_deferred()
func start_turn() -> void:
	manager._current_actor = actor
	await manager._run_actor_turn(actor)
	assert(manager.state == manager.BattleState.PLAYER_TURN)
func action() -> void:
	manager._change_state(manager.BattleState.PLAYER_ACTION)
func verify() -> void:
	var data = root.get_node("GameData")
	data.set_process(false)
	data.talent_ranks = {}
	data.debug_cheats_enabled = false
	data.add_party_by_name("游霄云")
	data.add_party_by_name("叮咚")
	data.party_order.assign(["youxiaoyun", "dingdong"])
	data.pet_team.clear()
	var equipment = load("res://Script/Data/Models/EquipData.gd").get_named("藏锋坠")
	assert(not equipment.is_empty())
	assert(data.get_equip_shop_items(10).any(func(item): return item.name == "藏锋坠"))
	data.player_equipment["youxiaoyun"] = {"项链": equipment}
	data.set_meta("pending_party", data.party_order.duplicate())
	data.set_meta("pending_enemies", ["火沙虫", "火沙虫"])
	var host := Node2D.new()
	root.add_child(host)
	current_scene = host
	var battle = load("res://scenes/Battle/battleField.tscn").instantiate()
	host.add_child(battle)
	await create_timer(1.5).timeout
	manager = battle.get_node("BattleManager")
	manager.set_process(false)
	actor = manager.party[0]
	target = manager.enemies[0]
	for unit in manager.party + manager.enemies:
		unit.trait_data.clear()
		unit.book_skills.clear()
		unit.buffs.clear()
		unit.equip_special = {} if unit != actor else load("res://Script/Battle/AccessoryEffects.gd").equipment_stats(equipment)
		unit.stats.max_hp = 10000
		unit.current_hp = 10000
	manager.log_pushed.connect(func(text, _kind):
		if "【藏锋坠】" in text: notices.append(text)
	)
	await start_turn()
	action()
	assert(manager.apply_damage(actor, target, 100) == 100, "No opening free charge")
	await manager._finish_player_action()
	assert(not actor.hidden_blade_ready)
	await start_turn()
	action()
	actor.current_hp = 9900
	manager.apply_heal(actor, actor, 50)
	await manager._finish_player_action()
	assert(actor.hidden_blade_ready)
	await start_turn()
	action()
	await manager._finish_player_action()
	assert(actor.hidden_blade_ready and actor.hidden_blade_action_multiplier == 1.0, "Repeated preparation does not stack")
	await start_turn()
	action()
	assert(manager.apply_damage(actor, target, 100, {"missed": true}) == 0)
	assert(actor.hidden_blade_ready, "Miss does not release charge")
	target.add_buff("invincible", 2)
	assert(manager.apply_damage(actor, target, 100) == 0)
	assert(actor.hidden_blade_ready)
	target.remove_buff("invincible")
	assert(manager.apply_damage(actor, target, 100, {"secondary": true}) == 100)
	assert(actor.hidden_blade_ready, "Secondary damage neither consumes nor receives bonus")
	assert(manager.apply_damage(actor, target, 100) == 125)
	assert(not actor.hidden_blade_ready)
	assert(manager.apply_damage(actor, target, 100) == 125, "Multi-hit in same action")
	assert(manager.apply_damage(actor, manager.enemies[1], 100, {"is_aoe": true}) == 125, "Other AoE targets in same action")
	manager._change_state(manager.BattleState.PLAYER_TURN)
	action()
	assert(manager.apply_damage(actor, target, 100) == 100, "Second action cannot reuse charge")
	await manager._finish_player_action()
	assert(not actor.hidden_blade_ready)
	assert(notices.any(func(text): return text.contains("蓄势：")))
	await start_turn()
	action()
	await manager._finish_player_action()
	assert(actor.hidden_blade_ready)
	await start_turn()
	action()
	target.set_shield(500)
	assert(manager.apply_damage(actor, target, 100) == 125)
	assert(target.get_shield() == 375)
	await manager._finish_player_action()
	assert(not actor.hidden_blade_ready, "Dealing shield damage must not rearm hidden blade")
	assert(notices.any(func(text): return text.contains("蓄势释放")))
	assert(actor.get_parent().get_children().any(func(child): return child.has_meta("accessory_trigger_notice")))
	print("HIDDEN BLADE PASS: equipped/shop, no free opening bonus, non-damage turn prepares, no stacking, next active attack +25%, multi-hit/AoE, consumed for next action, secondary/miss/invincible excluded, notice/log")
	quit()
