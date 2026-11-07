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
	ally.trait_data.clear()
	actor.stats.defense = 100
	actor.stats.magic_defense = 100
	ally.stats.defense = 100
	ally.stats.magic_defense = 100
	actor.stats.max_mp = 1000
	ally.stats.max_mp = 1000
	actor.current_mp = 300
	ally.current_mp = 0
	assert("三才阵" in data.get_all_skills("youxiaoyun"))
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	for distant_enemy in manager.enemies: distant_enemy.get_parent().global_position = Vector2(-1500, -1500)
	await manager.player_use_skill("三才阵", actor)
	assert(actor.current_mp == 270)
	for member in [actor, ally]:
		assert(member.has_buff("sancai"))
		assert(member.get_effective_defense() == 130)
		assert(member.get_effective_magic_defense() == 130)
		assert(member.buffs["sancai"].layers[0].turns == 4)
		assert(not member.has_meta("sancai_aura"))
	assert(manager.has_meta("sancai_domain"))
	var field = manager.get_meta("sancai_domain")
	field.set_process(false)
	var fixed_center: Vector2 = field.global_position
	var enemy = manager.enemies[0]
	enemy.stats.max_hp = 100000
	enemy.current_hp = 100000
	enemy.trait_data.clear()
	enemy.equip_special.clear()
	# 初始只有双抗；分别通过真实天赋页解锁两个互不依赖的功能。
	var tree = load("res://scenes/UI/TalentTree.tscn").instantiate()
	host.add_child(tree)
	data.talent_points = 4
	var mana_talent = tree.get_node("Pages/Page_Main/三才回元")
	var damage_talent = tree.get_node("Pages/Page_Main/三才诛邪")
	assert(mana_talent.max_rank == 1 and damage_talent.max_rank == 1)
	assert(mana_talent.requirements.is_empty() and damage_talent.requirements.is_empty())
	enemy.get_parent().global_position = fixed_center
	field.check_contacts()
	assert(enemy.current_hp == 100000)
	await manager._apply_dot(ally)
	assert(ally.current_mp == 0)
	tree._try_upgrade_talent(mana_talent)
	assert(data.talent_points == 3)
	assert(not mana_talent.can_upgrade(3))
	await manager._apply_dot(ally)
	assert(ally.current_mp == 100)
	field.check_contacts()
	assert(enemy.current_hp == 100000)
	var refund := InputEventMouseButton.new()
	refund.pressed = true
	refund.button_index = MOUSE_BUTTON_RIGHT
	mana_talent._on_gui_input(refund)
	await manager._apply_dot(ally)
	assert(ally.current_mp == 100 and data.talent_points == 4)
	tree._try_upgrade_talent(damage_talent)
	field.check_contacts()
	assert(enemy.current_hp < 100000)
	var hp_after_unlock: int = enemy.current_hp
	await manager._apply_dot(ally)
	assert(ally.current_mp == 100)
	damage_talent._on_gui_input(refund)
	enemy.get_parent().global_position = fixed_center + Vector2(field.radius + 100, 0)
	field.check_contacts()
	enemy.get_parent().global_position = fixed_center
	field.check_contacts()
	assert(enemy.current_hp == hp_after_unlock)
	assert(ally.get_effective_defense() == 130)
	assert(ally.get_effective_magic_defense() == 130)
	tree._try_upgrade_talent(mana_talent)
	tree._try_upgrade_talent(damage_talent)
	assert(data.talent_points == 2)
	# 已学状态重新加载正确恢复，后续复用原有完整阵地回归检查。
	var reloaded = load("res://scenes/UI/TalentTree.tscn").instantiate()
	host.add_child(reloaded)
	assert(reloaded.get_node("Pages/Page_Main/三才回元").rank == 1)
	assert(reloaded.get_node("Pages/Page_Main/三才诛邪").rank == 1)
	reloaded.queue_free()
	actor.current_mp = 270
	ally.current_mp = 0
	enemy.current_hp = 100000
	var outside := fixed_center + Vector2(field.radius + 100, 0)
	enemy.get_parent().global_position = outside
	field.check_contacts()
	assert(enemy.current_hp == 100000)
	enemy.get_parent().global_position = fixed_center
	field.check_contacts()
	var after_entry: int = enemy.current_hp
	assert(after_entry < 100000)
	for frame in 12: field.check_contacts()
	assert(enemy.current_hp == after_entry)
	enemy.get_parent().global_position = outside
	field.check_contacts()
	assert(enemy.current_hp == after_entry)
	enemy.get_parent().global_position = fixed_center
	field.check_contacts()
	assert(enemy.current_hp < after_entry)
	# 单帧从一侧穿到另一侧仍触发，移动离开本身不触发。
	enemy.get_parent().global_position = outside
	field.check_contacts()
	var before_cross: int = enemy.current_hp
	enemy.get_parent().global_position = fixed_center - Vector2(field.radius + 100, 0)
	field.check_contacts()
	assert(enemy.current_hp < before_cross)
	# 主角上前攻击，不移动阵地。
	var actor_home: Vector2 = actor.get_parent().global_position
	actor.get_parent().global_position += Vector2(-300, 0)
	field.check_contacts()
	assert(field.global_position == fixed_center)
	actor.get_parent().global_position = actor_home
	# 刷新不叠层、四次回蓝和第四次结束时移除双抗。
	for member in [actor, ally]:
		member.add_buff("sancai", 4, 1.3, "三才阵")
		assert(member.get_buff_layer_count("sancai") == 1)
	for turn in 4:
		var old_actor: int = actor.current_mp
		var old_ally: int = ally.current_mp
		await manager._apply_dot(actor)
		await manager._apply_dot(ally)
		assert(actor.current_mp == old_actor + 100)
		assert(ally.current_mp == old_ally + 100)
		actor.tick_buffs()
		ally.tick_buffs()
		if turn < 3: assert(ally.has_buff("sancai"))
	assert(not actor.has_buff("sancai"))
	assert(not ally.has_buff("sancai"))
	assert(ally.get_effective_defense() == 100)
	assert(ally.get_effective_magic_defense() == 100)
	field.check_contacts()
	var mp_after: int = ally.current_mp
	await manager._apply_dot(ally)
	assert(ally.current_mp == mp_after)
	await process_frame
	await process_frame
	assert(not manager.has_meta("sancai_domain"))
	# 回蓝封顶，阵亡单位不受益。
	manager._current_actor = actor
	manager.skill_cooldowns.clear()
	manager.state = manager.BattleState.PLAYER_TURN
	ally.is_dead = true
	for distant_enemy in manager.enemies: distant_enemy.get_parent().global_position = Vector2(-1500, -1500)
	await manager.player_use_skill("三才阵", actor)
	assert(not ally.has_buff("sancai"))
	actor.current_mp = 990
	await manager._apply_dot(actor)
	assert(actor.current_mp == 1000)
	print("SANCAI PASS: defense only by default, independent mana/damage talent purchase and refund gates, saved ranks; shared fixed field, entry damage, stay guard, reentry, swept crossing, +30% defense, four mana ticks, expiry, no stack, MP cap, dead exclusion")
	host.queue_free()
	await process_frame
	quit()