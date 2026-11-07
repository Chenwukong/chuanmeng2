extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var data = root.get_node("GameData")
	data.talent_ranks = {}
	data.add_party_by_name("半兽人")
	data.add_party_by_name("游霄云")
	data.party_order.assign(["banshouren", "youxiaoyun"])
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
	var actor = manager.party.filter(func(member): return member.member_id == "banshouren")[0]
	actor.stats.max_mp = 10000
	actor.current_mp = 10000
	actor.trait_data.clear()

	actor.completed_actions = 5
	manager._current_actor = actor
	manager.state = manager.BattleState.PLAYER_TURN
	var original_material = actor.get_parent().get_node("Sprite2D").material
	manager.player_use_skill.call("真身显现", actor)
	await create_timer(0.15).timeout
	assert(actor.get_parent().has_node("TrueFormBurst"))
	assert(not actor.trait_data.get("_xiaoer_true_form", false))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/true_form_charge_preview.png")
	await create_timer(0.55).timeout
	assert(actor.trait_data.get("_xiaoer_true_form", false))
	assert(actor.stats.was_base_path == "res://WAS/小二真身")
	var effect = actor.get_parent().get_node("TrueFormBurst")
	assert(effect.get_node("OldBody").visible)
	assert(effect.get_node("OldBody").texture != actor.get_parent().get_node("Sprite2D").texture)
	assert(actor.get_parent().get_node("Sprite2D").material.get_shader_parameter("new_form"))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/true_form_burst_preview.png")
	await create_timer(1.5).timeout
	assert(not actor.get_parent().has_node("TrueFormBurst"))
	assert(actor.get_parent().get_node("Sprite2D").material == original_material)
	assert(actor.current_mp == 14955)
	assert(actor.completed_actions == 6)
	assert(manager.state == manager.BattleState.CHECK_BATTLE_END)
	var visual = actor.get_parent()
	var home: Vector2 = visual.position
	var hits := {"count": 0}
	await visual.play_attack_sequence(manager.enemies[0].get_parent().global_position, manager.enemies[0].get_parent(), func(): hits.count += 1)
	assert(hits.count == 1)
	assert(visual.position.is_equal_approx(home))
	assert(visual.was_player._current_anim == "idle")
	assert(visual.was_player.frame_offset == Vector2(-14, 12))
	assert(visual._weapon_was.frame_offset == visual.was_player.frame_offset)
	assert(visual._weapon_was._current_anim == "idle")
	print("TRUE FORM FX PASS: charge before reveal, bottom-to-top old/new masking and material restoration, effect cleanup, one MP cost and one action, returns to battle wait")
	quit()