extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var data = root.get_node("GameData")
	data.set_process(false)
	data.restore_difficulty(1)
	data.talent_ranks = {}
	var host := Node2D.new()
	root.add_child(host)
	current_scene = host
	var button = load("res://scenes/UI/DebugCheatButton.tscn").instantiate()
	host.add_child(button)
	button._activate()
	assert(data.debug_cheats_enabled)
	var skills: Dictionary = load("res://Script/Data/SkillDB.gd").SKILL_DB
	for id in data.character_roster:
		var stats = data.character_roster[id]
		assert(stats.level >= 100)
		for skill in skills: assert(skill in data.get_all_skills(id))
	var main = data.character_roster.youxiaoyun
	var hp: int = main.max_hp
	var potential: int = main.potential_left
	var equips: int = data.equip_bag.size()
	var materials: int = data.material_bag.size()
	button._activate()
	assert(main.max_hp == hp and main.potential_left == potential)
	assert(data.equip_bag.size() == equips and data.material_bag.size() == materials)
	data.player_gold -= 123456
	assert(data.player_gold == data.DEBUG_GOLD)
	var tree = load("res://scenes/UI/TalentTree.tscn").instantiate()
	host.add_child(tree)
	for talent in tree._get_all_talent_nodes(): assert(talent.rank == talent.max_rank)
	for id in load("res://Script/Data/Models/EquipData.gd").named_db:
		assert(data.equip_bag.any(func(eq): return eq.get("id", "") == id))
	# 真实配方窗口连续制作，金币材料不扣、成品正常增加。
	var recipes = load("res://scenes/UI/TalismanRecipes.tscn").instantiate()
	host.add_child(recipes)
	var recipe = recipes.selected_recipe()
	data.player_inventory.remove_item(recipe.output, data.player_inventory.get_count(recipe.output))
	var old: int = data.player_inventory.get_count(recipe.output)
	recipes.make_selected()
	recipes.make_selected()
	assert(data.player_inventory.get_count(recipe.output) == old + 6)
	assert(data.material_bag.size() == materials)
	assert(data.player_gold == data.DEBUG_GOLD)
	var mech = load("res://scenes/UI/Mech/MechPopup.tscn").instantiate()
	host.add_child(mech)
	assert(mech._consume_gears(100000))
	assert(data.material_bag.size() == materials)
	var service = load("res://Script/Save/SaveService.gd")
	var saved = service.serialize_state(data)
	saved.vol_master = -1
	saved.vol_music = -1
	saved.vol_sfx = -1
	data.debug_cheats_enabled = false
	assert(service.restore_state(data, saved))
	assert(data.debug_cheats_enabled)
	data.player_gold -= 999
	assert(data.player_gold == data.DEBUG_GOLD)
	saved.erase("debug_cheats_enabled")
	assert(service.restore_state(data, saved))
	assert(not data.debug_cheats_enabled)
	assert(load("res://Script/UI/BuildPopup.gd") != null)
	assert(load("res://Script/UI/ShopPopup.gd") != null)
	print("DEBUG CHEATS PASS: button, entire roster 100 with growth, every skill and talent, all equipment/accessories, idempotent refill, infinite gold, repeated recipe crafts and mech materials not consumed, persisted mode and legacy save default")
	quit()