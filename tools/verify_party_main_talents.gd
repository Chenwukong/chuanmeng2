extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func character(role: int, player: bool = true, pet: bool = false):
	var c = load("res://Script/Battle/BattleCharacter.gd").new()
	c.stats = load("res://Script/Data/Models/CharacterStats.gd").new()
	c.stats.role = role
	c.stats.character_class = "宠物" if pet else "角色"
	c.stats.character_name = "测试角色"
	c.stats.max_hp = 100
	c.stats.max_mp = 100
	c.stats.speed = 100
	c.current_hp = 100
	c.current_mp = 0
	c.is_player = player
	c.is_summoned_pet = pet
	root.add_child(c)
	c._apply_talent_boosts()
	return c
func verify() -> void:
	var data = root.get_node("GameData")
	data.set_process(false)
	data.talent_ranks = {"main_root": 2, "main_focus": 2, "main_recover": 2, "main_channel": 2, "main_spirit": 2, "baochong": 2, "funeng": 2}
	var m = load("res://Script/Battle/BattleManager.gd").new()
	var ai = load("res://Script/Battle/EnemyAI.gd").new()
	ai.name = "EnemyAI"
	m.add_child(ai)
	root.add_child(m)
	m.set_process(false)
	for role in [1, 2, 4, 8, 16]:
		var c = character(role)
		var bonuses: Dictionary = c.trait_data._talent_boosts
		assert(is_equal_approx(bonuses.hp_up, 0.16))
		assert(is_equal_approx(bonuses.mp_up, 0.16))
		assert(is_equal_approx(bonuses.haste, 0.08))
		assert(c.get_effective_max_hp() > 100 and c.get_effective_max_mp() > 100)
		assert(c.get_effective_speed() > 100)
		assert(c.talent_rank("main_spirit") == 2 and c.talent_rank("baochong") == 2)
		assert(c.talent_rank("funeng") == (2 if role == 1 else 0))
		m.party.append(c)
	var pet = character(16, true, true)
	assert(pet.talent_rank("main_root") == 0)
	m.party.append(pet)
	var enemy = character(1, false)
	assert(enemy.talent_rank("main_root") == 0)
	m.enemies.append(enemy)
	await m.start_battle()
	for c in m.party:
		assert(c.current_mp == (0 if c.is_summoned_pet else 20))
		assert(c.current_sp == (0 if c.is_summoned_pet else 20))
	var tree = load("res://scenes/UI/TalentTree.tscn").instantiate()
	root.add_child(tree)
	assert(tree.get_node("Pages/Page_Main/灵根初醒").description.contains("全体队友"))
	assert(tree.get_node("Pages/Page_Main/凝神").description.contains("全体队友"))
	print("PARTY MAIN TALENTS PASS: five roles HP/MP/speed, initial MP and SP, matching shared stat preview, exclusive talisman talent preserved, enemies and ordinary pets excluded, updated descriptions")
	quit()