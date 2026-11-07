extends SceneTree
func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var data = root.get_node("GameData")
	data.talent_ranks = {}
	data.add_party_by_name("游霄云")
	data.add_party_by_name("敖白")
	var ids: Array = data.party_db.keys()
	assert(ids.size() >= 2)
	var hero = data.party_db[ids[0]]
	hero.luck = 10
	hero.crit_mult = 1.75
	hero.potential_left = 100
	hero.attack = 100
	hero.magic_attack = 80
	hero.magic_defense = 35
	hero.max_mp = 100
	data.player_equipment = {ids[0]: {"weapon": {"slot": 0, "base": {"atk": 20, "mdef": 7, "luck": 2}, "luck": 3, "dodge": 8, "lifesteal": 12, "true_dmg": 15}}}
	var popup = load("res://scenes/UI/StatusPopup.tscn").instantiate()
	root.add_child(popup)
	popup._setup()
	var details = popup._details
	assert(details._values["气运"] == "15")
	assert(details._values["基础暴击率"] == "15.0%")
	assert(details._values["暴击伤害"] == "175%")
	assert(details._values["物理攻击"] == "120")
	assert(details._values["法术防御"] == "42")
	assert(details._values["闪避"] == "8%")
	assert(details._values["吸血"] == "12%")
	assert(details._values["额外真实伤害"] == "15")
	popup._add_step("atk")
	assert(hero.attack == 100)
	assert(details._values["物理攻击"] == "121")
	assert(details._values["剩余可分配点"] == "99")
	popup._cancel()
	assert(details._values["物理攻击"] == "120")
	popup._add_magic_step()
	assert(details._values["法术攻击"] == "81")
	assert(details._values["灵力上限"] == "101")
	popup._confirm()
	assert(hero.magic_attack == 81)
	assert(hero.max_mp == 101)
	assert(details._values["法术攻击"] == "81")
	data.party_db[ids[1]].luck = 2
	popup._current_idx = 1
	popup._refresh()
	assert(details._values["气运"] == "2")
	assert(details._values["闪避"] == "0%")
	popup._current_idx = 0
	popup._refresh()
	assert(details._values["气运"] == "15")
	assert(details._values.size() > 20)
	print("STATUS DETAILS PASS: luck/equipment/crit, defense, preview/cancel/confirm, character switching")
	if "--preview" in OS.get_cmdline_user_args():
		await create_timer(0.3).timeout
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/status_details_preview.png")
	popup.queue_free()
	quit()
