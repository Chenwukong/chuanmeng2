extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var data = root.get_node("GameData")
	data.talent_ranks = {}
	data.add_party_by_name("游霄云")
	data.add_party_by_name("叮咚")
	data.party_order.assign(["youxiaoyun", "dingdong"])
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
	var ally = manager.party[1]
	actor.trait_data.clear()
	actor.equip_special = load("res://Script/Battle/AccessoryEffects.gd").equipment_stats(load("res://Script/Data/Models/EquipData.gd").get_named("节灵佩"))
	assert(is_equal_approx(actor.get_mp_cost_reduction(), 0.3))
	assert(actor.get_skill_mp_cost(30) == 21)
	assert(actor.get_skill_mp_cost(0) == 0)
	assert(actor.get_skill_mp_cost(1) == 1)
	actor.equip_special.mp_cost_reduction = 0.95
	assert(is_equal_approx(actor.get_mp_cost_reduction(), 0.8))
	assert(actor.get_skill_mp_cost(30) == 6)
	actor.equip_special.mp_cost_reduction = 0.3
	actor.stats.max_mp = 1000
	actor.current_mp = 21
	actor.stats.skill_ids.assign(["三才阵"])
	var popup = battle.get_node("BattleUI")._skill_popup
	popup.open(actor, func(_actor, _skill): return 0)
	assert(popup._buttons.size() == 1)
	assert(not popup._buttons[0].disabled)
	popup._on_cancel()
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	await manager.player_use_skill("三才阵", actor)
	assert(actor.current_mp == 0)
	assert(actor.has_buff("sancai"))
	# 辅助天赋与饰品相加，并在80%封顶。
	actor.stats.role = 4
	data.set_talent_rank("support_mp_save", 2)
	assert(is_equal_approx(actor.get_mp_cost_reduction(), 0.5))
	data.set_talent_rank("support_mp_save", 5)
	assert(is_equal_approx(actor.get_mp_cost_reduction(), 0.8))
	assert(load("res://Script/UI/StatusDetails.gd") != null)
	print("MANA ACCESSORY PASS: effect mapping, 30% saving, zero/minimum cost, 80% cap and rounding, popup available at discounted MP, actual skill charges 21 instead of 30, support talent stacking")
	quit()