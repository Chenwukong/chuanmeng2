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
	var enemy = manager.enemies[0]
	data.talent_ranks = {"summon_pet_hp": 2, "summon_pet_damage": 2, "summon_pet_defense": 2, "summon_pet_speed": 2, "main_bean_damage": 3, "main_bean_hp": 3}
	actor.stats.max_hp = 1000
	actor.current_hp = 1000
	actor.stats.max_mp = 10000
	actor.current_mp = 10000
	actor.stats.magic_attack = 100
	actor.stats.defense = 80
	actor.stats.magic_defense = 40
	actor.stats.speed = 100
	actor.trait_data.clear()
	actor.equip_special.clear()
	ally.stats.max_hp = 1000
	ally.current_hp = 1000
	ally.trait_data.clear()
	ally.trait_data["兽王血脉"] = {"hp_pct": 0.1}
	ally.equip_special.clear()
	for foe in manager.enemies:
		foe.stats.max_hp = 100000
		foe.current_hp = 100000
		foe.trait_data.clear()
		foe.equip_special.clear()
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	await manager.player_use_skill("撒豆成兵", actor)
	var army = actor.get_meta("bean_army")
	assert(manager._count_summoned_pets() == 0)
	assert(manager.active_summon_count() == 3)
	assert(ally.trait_data.get("_summon_pet_count", 0) == 0)
	assert(enemy.current_hp == 99814)
	assert(manager.damage_stats[actor.member_id] == 186)
	for unit in army.units:
		assert(unit.character.stats.max_hp == 444)
		assert(unit.character.stats.defense == 26)
		assert(unit.character.stats.magic_defense == 13)
		assert(unit.character.stats.speed == 120)
		assert(unit.character.is_summoned_pet)
		assert(unit.character.talent_rank("main_root") == 0)
	assert(army.get_guardian(ally) == null)
	manager._current_actor = enemy
	manager.state = manager.BattleState.ENEMY_TURN
	var hp_before: int = ally.current_hp
	manager.apply_damage(enemy, ally, 10)
	assert(ally.current_hp == hp_before - 10)
	# 通过真实天赋页解锁，消费1点，旧存档默认未学。
	data.talent_points = 10
	var tree = load("res://scenes/UI/TalentTree.tscn").instantiate()
	host.add_child(tree)
	tree.show_page("Page_Main")
	var root_talent = tree.get_node("Pages/Page_Main/灵根初醒")
	var love = tree.get_node("Pages/Page_Main/爱屋及乌")
	assert(love.max_rank == 1)
	assert(not tree.has_node("Pages/Page_Summon/爱屋及乌"))
	assert(love.has_node("天赋点背景2"))
	assert(love.has_node("Typography"))
	assert(love.can_upgrade(10))
	assert(love.requirements.is_empty())
	tree._try_upgrade_talent(love)
	assert(data.get_talent_rank("summon_love_allies") == 1)
	assert(data.talent_points == 9)
	assert(not love.can_upgrade(8))
	assert(army.get_guardian(ally) != null)
	var bean_hp: int = army.units[0].character.current_hp
	var protected_hp: int = ally.current_hp
	manager.apply_damage(enemy, ally, 10, {"is_magic": true})
	assert(ally.current_hp == protected_hp)
	assert(army.units[0].character.current_hp == bean_hp - 10)
	# 重新载入天赋页恢复已学状态；退点后恢复仅护主。
	var reloaded = load("res://scenes/UI/TalentTree.tscn").instantiate()
	host.add_child(reloaded)
	assert(reloaded.get_node("Pages/Page_Main/爱屋及乌").rank == 1)
	reloaded.queue_free()
	love.remove_rank()
	assert(data.get_talent_rank("summon_love_allies") == 0)
	assert(army.get_guardian(ally) == null)
	manager.apply_damage(enemy, ally, 5)
	assert(ally.current_hp == protected_hp - 5)
	var owner_hp: int = actor.current_hp
	manager.apply_damage(enemy, actor, 5)
	assert(actor.current_hp == owner_hp)
	var damage_talent = tree.get_node("Pages/Page_Main/豆兵强攻")
	var hp_talent = tree.get_node("Pages/Page_Main/豆兵壮体")
	assert(damage_talent.rank == 3 and hp_talent.rank == 3)
	assert(damage_talent.max_rank == 3 and hp_talent.max_rank == 3)
	# 退到0级后必须先学前置，每级准确消耗1点，满级不能继续升级。
	for talent in [damage_talent, hp_talent]:
		for i in 3: assert(talent.remove_rank())
		assert(not talent.can_upgrade(10))
	var legion = tree.get_node("Pages/Page_Main/兵多将广")
	tree._try_upgrade_talent(love)
	tree._try_upgrade_talent(legion)
	var before: int = data.talent_points
	for talent in [damage_talent, hp_talent]:
		for i in 3:
			assert(talent.can_upgrade(data.talent_points))
			tree._try_upgrade_talent(talent)
		assert(not talent.can_upgrade(data.talent_points))
	assert(data.talent_points == before - 6)
	assert(not legion.remove_rank())
	for talent in [damage_talent, hp_talent]:
		for i in 3: assert(talent.remove_rank())
	assert(legion.remove_rank())
	assert(love.remove_rank())
	# 恢复满级供后续补员测试；既有豆兵不因退点获得治疗。
	data.set_talent_rank("main_bean_damage", 3)
	data.set_talent_rank("main_bean_hp", 3)
	# 击破与补员即时更新召唤物联动，加成不重复累乘。
	manager.apply_damage(enemy, army.units[0].character, 9999, {"secondary": true})
	assert(manager.active_summon_count() == 2)
	assert(ally.trait_data.get("_summon_pet_count", 0) == 0)
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	manager.skill_cooldowns.clear()
	await manager.player_use_skill("撒豆成兵", actor)
	assert(manager.active_summon_count() == 3)
	assert(manager._count_summoned_pets() == 0)
	assert(ally.trait_data.get("_summon_pet_count", 0) == 0)
	for unit in army.units: assert(unit.character.stats.max_hp == 444)
	# 兽王仍正常计算正式宠物，豆兵增减不改变其计数。
	var pet = load("res://Script/Battle/BattleCharacter.gd").new()
	pet.stats = load("res://Script/Data/Models/CharacterStats.gd").new()
	pet.stats.character_class = "宠物"
	pet.is_player = true
	pet.is_summoned_pet = true
	pet.current_hp = 50
	host.add_child(pet)
	manager.party.append(pet)
	manager.refresh_summon_synergies()
	assert(ally.trait_data.get("_summon_pet_count", 0) == 1)
	assert(manager._count_summoned_pets() == 1)
	manager.apply_damage(enemy, army.units[0].character, 9999, {"secondary": true})
	assert(ally.trait_data.get("_summon_pet_count", 0) == 1)
	pet.is_dead = true
	manager.refresh_summon_synergies()
	assert(ally.trait_data.get("_summon_pet_count", 0) == 0)
	print("BEAN STRENGTH PASS: +60% damage and +90% HP stack with summon bonuses; summon HP/damage/dual defense/speed, role isolation, no beast-king count, no slot use, independent main talent/purchase/rank restore/refund, ally protection on/off, owner protection, replacement no double scaling")
	host.queue_free()
	await process_frame
	quit()