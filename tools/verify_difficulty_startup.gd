extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	root.size = Vector2i(1100, 740)
	var data = root.get_node("GameData")
	data.set_process(false)
	data._difficulty_locked = false
	change_scene_to_file("res://scenes/MainScene.tscn")
	await scene_changed
	var main = current_scene
	var choice = main.get_node("DifficultySelection")
	assert(paused and data.ui_blocked)
	choice._select(0)
	choice._confirm()
	assert(data.difficulty == 0 and data.difficulty_locked)
	assert(not paused)
	assert(main.get_node("UI/UIKeyboardNavigator").host == main)
	await process_frame
	await process_frame
	assert(not main.has_node("DifficultySelection"))
	change_scene_to_file("res://scenes/MainScene.tscn")
	await scene_changed
	var next = current_scene
	assert(not next.has_node("DifficultySelection"))
	assert(not paused and data.difficulty == 0)
	print("DIFFICULTY STARTUP PASS: mandatory before world initialization, initialization resumes on confirm, reload never asks again")
	await load("res://Script/Assets/BattleAssetLoader.gd").scene_ready(self)
	quit()