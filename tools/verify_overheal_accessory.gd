extends SceneTree
var notices: Array[String] = []
func _initialize() -> void:
	verify.call_deferred()
func verify() -> void:
	var data = root.get_node("GameData")
	data.set_process(false)
	data.talent_ranks = {}
	data.debug_cheats_enabled = false
	data.add_party_by_name("游霄云")
	data.add_party_by_name("叮咚")
	data.party_order.assign(["youxiaoyun", "dingdong"])
	data.pet_team.clear()
	var equipment = load("res://Script/Data/Models/EquipData.gd").get_named("余春瓶")
	assert(not equipment.is_empty())
	assert(data.get_equip_shop_items(10).any(func(item): return item.name == "余春瓶"))
	data.player_equipment["dingdong"] = {"项链": equipment}
	data.set_meta("pending_party", data.party_order.duplicate())
	data.set_meta("pending_enemies", ["火沙虫"])
	var host := Node2D.new()
	root.add_child(host)
	current_scene = host
	var battle = load("res://scenes/Battle/battleField.tscn").instantiate()
	host.add_child(battle)
	await create_timer(1.5).timeout
	var manager = battle.get_node("BattleManager")
	manager.set_process(false)
	var actor = manager.party[1]
	var target = manager.party[0]
	for unit in manager.party + manager.enemies:
		unit.trait_data.clear()
		unit.book_skills.clear()
		unit.buffs.clear()
		unit.stats.max_hp = 1000
		unit.current_hp = 1000
		unit.equip_special = {} if unit != actor else load("res://Script/Battle/AccessoryEffects.gd").equipment_stats(equipment)
	manager._current_actor = actor
	manager._change_state(manager.BattleState.PLAYER_ACTION)
	manager.log_pushed.connect(func(text, _kind):
		if "【余春瓶】" in text: notices.append(text)
	)
	target.current_hp = 900
	assert(manager.apply_heal(actor, target, 300) == 100)
	assert(target.get_shield() == 100, "200 overflow -> 100 shield")
	assert(notices.size() == 1 and notices[0].contains("转化100点护盾"))
	assert(actor.get_parent().get_children().any(func(child): return child.has_meta("accessory_trigger_notice")))
	assert(manager.apply_heal(actor, target, 300) == 0)
	assert(target.get_shield() == 200, "Full HP conversion and 20% cap")
	manager.apply_heal(actor, target, 1000)
	assert(target.get_shield() == 200)
	target.set_shield(350)
	manager.apply_heal(actor, target, 1000)
	assert(target.get_shield() == 350, "Preserve stronger existing shields")
	target.set_shield(0)
	target.current_hp = 500
	manager.apply_heal(actor, target, 100)
	assert(target.current_hp == 600 and target.get_shield() == 0)
	target.current_hp = 1000
	manager.apply_heal(actor, target, 300, false, {"secondary": true})
	manager.apply_heal(null, target, 300)
	assert(target.get_shield() == 0, "Passive/automatic healing excluded")
	manager._current_actor = target
	manager.apply_heal(actor, target, 300)
	assert(target.get_shield() == 0, "Off-turn passive healing excluded")
	manager._current_actor = actor
	actor.equip_special.lifesteal = 50
	manager.apply_damage(actor, manager.enemies[0], 100)
	assert(actor.get_shield() == 0, "Life steal overflow excluded")
	target.mech_durability = 500
	manager.apply_heal(actor, target, 300)
	assert(target.get_shield() == 650 and target.mech_durability == 500, "Iron durability is preserved, not duplicated")
	target.mech_durability = 0
	target.set_shield(0)
	var potion = load("res://Script/Data/Models/ItemData.gd").new()
	potion.item_id = "test_overheal_potion"
	potion.hp_restore = 300
	manager.player_inventory.add_item(potion)
	manager.player_inventory.use_item(potion.item_id, target, func(recipient, amount, revive): return manager.apply_heal(actor, recipient, amount, revive))
	assert(target.get_shield() == 150, "Active item heal overflow")
	manager.apply_heal(actor, actor, 200)
	assert(actor.get_shield() == 100, "Each group-heal target has independent shield")
	print("OVERHEAL ACCESSORY PASS: equipped/shop, 50% overflow, full HP, 20% cap, no overwrite, passive/lifesteal exclusions, iron durability, active items, separate targets, notice/log")
	quit()
