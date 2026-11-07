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
	actor.stats.max_hp = 1000
	actor.current_hp = 1000
	actor.stats.max_mp = 10000
	actor.current_mp = 10000
	actor.trait_data.clear()
	actor.equip_special.clear()
	ally.trait_data.clear()
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
	for unit in army.units:
		assert(unit.home.x > actor.get_parent().global_position.x)
		assert(unit.get_node("Health").visible)
		assert(unit.character.current_hp == 180)
	manager._current_actor = enemy
	manager.state = manager.BattleState.ENEMY_TURN
	var first = army.units[0].character
	var second = army.units[1].character
	var third = army.units[2].character
	manager.apply_damage(enemy, actor, 20)
	assert(actor.current_hp == 1000)
	assert(first.current_hp == 160)
	assert(army.units[0].get_node("GuardText").visible)
	manager.apply_damage(enemy, actor, 30, {"is_magic": true})
	assert(actor.current_hp == 1000)
	assert(first.current_hp == 130)
	manager.apply_damage(enemy, actor, 20, {"missed": true})
	assert(first.current_hp == 130)
	manager.apply_damage(enemy, actor, 0)
	assert(first.current_hp == 130)
	# DOT 不拦截；不会错误保护其他队友。
	manager.apply_damage(enemy, actor, 10, {"secondary": true})
	assert(actor.current_hp == 990)
	assert(first.current_hp == 130)
	var ally_hp: int = ally.current_hp
	manager.apply_damage(enemy, ally, 12)
	assert(ally.current_hp == ally_hp - 12)
	actor.add_buff("invincible", 1)
	manager.apply_damage(enemy, actor, 99)
	assert(first.current_hp == 130)
	actor.remove_buff("invincible")
	# 每段自动换存活豆兵；致死一击无溢出，耗尽后主角正常承伤。
	manager.apply_damage(enemy, actor, 9999)
	assert(first.is_dead)
	assert(actor.current_hp == 990)
	manager.apply_damage(enemy, actor, 5, {"is_magic": true})
	assert(second.current_hp == 175)
	manager.apply_damage(enemy, actor, 9999)
	assert(second.is_dead)
	manager.apply_damage(enemy, actor, 9999)
	assert(third.is_dead)
	assert(actor.current_hp == 990)
	assert(army.get_guardian() == null)
	manager.apply_damage(enemy, actor, 7)
	assert(actor.current_hp == 983)
	# 重施补齐并恢复护主；存活豆兵退回身后原位。
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	manager.skill_cooldowns.clear()
	await manager.player_use_skill("撒豆成兵", actor)
	assert(manager.bean_soldiers.size() == 3)
	manager._current_actor = enemy
	manager.state = manager.BattleState.ENEMY_TURN
	manager.apply_damage(enemy, actor, 10)
	assert(actor.current_hp == 983)
	await create_timer(0.45).timeout
	assert(army.units[0].global_position.is_equal_approx(army.units[0].home))
	assert(not army.units[0].get_node("GuardShield").visible)
	print("BEAN GUARD PASS: rear positions, visible independent HP, physical/magic interception, miss/zero/invincibility, DOT exclusion, correct owner, lethal no-overflow, multi-hit succession, exhaustion, refill, return home")
	host.queue_free()
	await process_frame
	quit()