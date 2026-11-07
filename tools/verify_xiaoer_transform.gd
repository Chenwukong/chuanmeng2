extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var data = root.get_node("GameData")
	data.talent_ranks = {}
	data.add_party_by_name("小二")
	data.party_order.assign(["xiaoer"])
	data.party_db["xiaoer"].skill_ids.assign(["普通攻击"])
	assert("真身显现" in data.get_all_skills("xiaoer"))
	data.pet_team.clear()
	data.set_meta("pending_party", data.party_order.duplicate())
	data.set_meta("pending_enemies", ["火沙虫"])
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
	actor.initial_skill_wait_reductions["真身显现"] = 5
	var mp_before: int = actor.current_mp
	var hp_before: int = actor.current_hp
	var skills_before = actor.stats.skill_ids.duplicate()
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	await manager.player_use_skill("真身显现", actor)
	assert(actor.stats.was_base_path == "res://WAS/小二真身")
	assert(actor.current_mp == mp_before - 30)
	assert(actor.current_hp == hp_before)
	assert(actor.stats.skill_ids == skills_before)
	assert(data.party_db["xiaoer"].was_base_path == "res://WAS/小二")
	var hero = actor.get_parent()
	assert(hero.get_node("WeaponWAS").anim_files["attack"] == "res://WAS/小二真身/饰品/攻击_2.was")
	assert(hero.was_player.anim_files["defend"] == "res://WAS/小二真身/防御.was")
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	await manager.player_use_skill("真身显现", actor)
	assert(actor.current_mp == mp_before - 30)
	assert(manager.state == manager.BattleState.PLAYER_TURN)
	print("XIAOER TRANSFORM: PASS (old save, transform, weapon, cost, repeat guard, persistent appearance unchanged)")
	host.queue_free()
	await process_frame
	quit()
