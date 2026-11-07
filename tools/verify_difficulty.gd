extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	root.size = Vector2i(1100, 740)
	var data = root.get_node("GameData")
	data.set_process(false)
	for bus in ["BGM", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	data._difficulty_locked = false
	assert(not data.select_difficulty(-1))
	assert(not data.select_difficulty(3))
	assert(not data.difficulty_locked)
	var ui = load("res://scenes/UI/DifficultySelection.tscn").instantiate()
	root.add_child(ui)
	current_scene = ui
	assert(paused and data.ui_blocked)
	assert(ui.selected == 1)
	ui._select(2)
	assert(ui.cards.get_child(2).get_node("Select").button_pressed)
	assert(not ui.cards.get_child(1).get_node("Select").button_pressed)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/difficulty_preview.png")
	ui._confirm()
	assert(not paused and not data.ui_blocked)
	assert(data.difficulty_locked and data.difficulty == 2)
	assert(not data.select_difficulty(0))
	assert(data.difficulty == 2)
	# 固定等级的首领确保三档只改变战斗属性，不改变等级与经验。
	data.restore_difficulty(1)
	var normal = data.create_enemy("方寸山_守关20")
	for level in 3:
		data.restore_difficulty(level)
		var enemy = data.create_enemy("方寸山_守关20")
		for property in ["max_hp", "max_mp", "attack", "magic_attack", "defense", "magic_defense", "speed"]:
			assert(enemy.get(property) == maxi(1 if property == "max_hp" else 0, int(normal.get(property) * data.DifficultyDB.enemy_multiplier(level, property))))
		assert(enemy.level == normal.level and enemy.exp_reward == normal.exp_reward)
		assert(data._enemy_db_cache.has("方寸山_守关20"))
	var service = load("res://Script/Save/SaveService.gd")
	var save = service.serialize_state(data)
	assert(save.difficulty == 2)
	data.restore_difficulty(0)
	assert(service.restore_state(data, save))
	assert(data.difficulty == 2 and data.difficulty_locked)
	assert(not data.select_difficulty(1))
	save.erase("difficulty")
	assert(service.restore_state(data, save))
	assert(data.difficulty == 1 and data.difficulty_locked)
	data.restore_difficulty(100)
	assert(data.difficulty == 1)
	assert(load("res://Script/World/MainScene.gd") != null)
	print("DIFFICULTY PASS: three options, exclusive choice, mandatory confirmation, pause restored, locked once, seven independent enemy stat multipliers, rewards unchanged, save/load, legacy normal locked")
	quit()
