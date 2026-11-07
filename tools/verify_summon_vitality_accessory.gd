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
	var accessory = load("res://Script/Data/Models/EquipData.gd").get_named("御灵佩")
	assert(not accessory.is_empty())
	assert(data.get_equip_shop_items(10).any(func(item): return item.name == "御灵佩"))
	data.player_equipment["youxiaoyun"] = {"项链": accessory}
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
		if "【御灵佩】" in text: notices.append(text)
	)
	var owner = manager.party[0]
	var other = manager.party[1]
	assert(is_equal_approx(float(owner.equip_special.get("summon_hp_bonus", 0)), 0.2))
	manager._current_actor = owner
	var pet = load("res://Script/Data/Models/PetData.gd").new()
	pet.pet_id = "summon_vitality_test"
	pet.character_name = "测试灵兽"
	pet.max_hp = 100
	var pet_node = await battle.summon_pet(pet)
	var summoned = pet_node.get_node("BattleCharacter")
	assert(summoned.stats.max_hp == 120 and summoned.current_hp == summoned.get_effective_max_hp())
	assert(pet.max_hp == 100, "Permanent pet data unchanged")
	var effects = load("res://Script/Battle/AccessoryEffects.gd")
	effects.empower_summon(owner, summoned, manager)
	assert(summoned.stats.max_hp == 120, "Cannot apply twice")
	var mech_stats = load("res://Script/Data/Models/CharacterStats.gd").new()
	mech_stats.character_name = "测试铁甲"
	mech_stats.character_class = "铁甲"
	mech_stats.max_hp = 200
	var mech_node = await battle.summon_mech_pet(mech_stats)
	var mech = mech_node.get_node("BattleCharacter")
	assert(mech.stats.max_hp == 240 and mech.current_hp == mech.get_effective_max_hp())
	assert(mech_stats.max_hp == 200, "Input iron stats unchanged")
	owner.stats.max_hp = 1000
	owner.buffs.clear()
	var soldier = load("res://scenes/Effects/BeanSoldier.tscn").instantiate()
	host.add_child(soldier)
	soldier.configure(manager, owner, Vector2(300,500), 0)
	assert(soldier.character.stats.max_hp == 216 and soldier.character.current_hp == 216)
	assert(soldier.get_node("Health").max_value == 216)
	assert(owner.stats.max_hp == 1000)
	manager._current_actor = other
	var other_pet = await battle.summon_pet(pet)
	assert(other_pet.get_node("BattleCharacter").stats.max_hp == 100, "Only wearer's summons benefit")
	assert(notices.size() >= 1 and notices[0].contains("气血+20%"))
	assert(owner.get_parent().get_children().any(func(child): return child.has_meta("accessory_trigger_notice")))
	print("SUMMON VITALITY ACCESSORY PASS: equipped stats, pets 100->120, iron 200->240, beans 180->216, current HP/bar, ownership, no double application, source data unchanged, notice/log")
	quit()
