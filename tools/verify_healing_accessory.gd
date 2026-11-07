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
	var accessory = load("res://Script/Data/Models/EquipData.gd").get_named("回春玉佩")
	assert(not accessory.is_empty() and accessory.slot == 2)
	assert(data.get_equip_shop_items(10).any(func(item): return item.name == "回春玉佩"))
	data.player_equipment["dingdong"] = {"项链": accessory}
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
	manager.log_pushed.connect(func(text, _kind):
		if "【回春玉佩】" in text: notices.append(text)
	)
	var healer = manager.party[1]
	var target = manager.party[0]
	assert(is_equal_approx(float(healer.equip_special.get("outgoing_heal_bonus", 0)), 0.3), "Equipped accessory loads into battle")
	target.stats.max_hp = 2000
	target.buffs.clear()
	target.current_hp = 100
	assert(manager.apply_heal(healer, target, 100) == 130)
	assert(target.current_hp == 230)
	assert(notices.size() == 1 and notices[0].contains("额外恢复30气血"))
	assert(healer.get_parent().get_children().any(func(child): return child.has_meta("accessory_trigger_notice")), "Visible accessory notice")
	target.current_hp = target.get_effective_max_hp() - 5
	assert(manager.apply_heal(healer, target, 100) == 5)
	assert(notices.size() == 1, "No false bonus notice when baseline already fills HP")
	target.current_hp = 0
	target.is_dead = true
	assert(manager.apply_heal(healer, target, 100) == 0)
	assert(manager.apply_heal(healer, target, 100, true) == 130 and not target.is_dead)
	# Receiving a heal does not activate the recipient's accessory.
	healer.current_hp = 1
	assert(manager.apply_heal(target, healer, 100) == 100)
	target.current_hp = 1
	assert(manager.apply_heal(null, target, 100) == 100)
	# Item healing uses the same settlement entry.
	var potion = load("res://Script/Data/Models/ItemData.gd").new()
	potion.item_id = "test_healing_accessory_potion"
	potion.item_name = "测试药品"
	potion.hp_restore = 100
	manager.player_inventory.add_item(potion, 1)
	var before: int = target.current_hp
	var result = manager.player_inventory.use_item(potion.item_id, target, func(recipient, amount, revive): return manager.apply_heal(healer, recipient, amount, revive))
	assert(result.success and target.current_hp - before == 130)
	print("HEALING ACCESSORY PASS: registration/shop, equipped battle stats, 30% outgoing heal, visible notice/log, HP cap, revival, recipient exclusion and item healing")
	quit()
