extends SceneTree
var saves := 0
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var data = root.get_node("GameData")
	data.set_process(false)
	data.restore_difficulty(1)
	var existed := FileAccess.file_exists(data.SAVE_PATH)
	var original := FileAccess.get_file_as_bytes(data.SAVE_PATH) if existed else PackedByteArray()
	data.auto_saved.connect(func(): saves += 1)
	data.current_scene_path = ""
	data._process(60.0)
	assert(saves == 0)
	data.current_scene_path = "res://scenes/MainScene.tscn"
	data.player_gold = 12345
	data._auto_save_elapsed = 0.0
	data._process(59.0)
	assert(saves == 0)
	data._process(1.0)
	assert(saves == 1)
	var saved = JSON.parse_string(FileAccess.get_file_as_string(data.SAVE_PATH))
	assert(saved.player_gold == 12345)
	# 弹窗关闭后，战后和计时仍生效；打开弹窗只刷新，不重复保存。
	var popup = load("res://scenes/UI/Save/SavePopup.tscn").instantiate()
	root.add_child(popup)
	data.battle_ended_for_save.emit()
	data._process(0.0)
	assert(saves == 2)
	popup.queue_free()
	await process_frame
	data.player_gold = 23456
	data.battle_ended_for_save.emit()
	data._process(0.0)
	assert(saves == 3)
	data._process(60.0)
	assert(saves == 4)
	# 战斗中到点不写半成品，返回地图后只写一次最终奖励和剧情状态。
	data.in_battle = true
	data._process(60.0)
	data.story_progress_committed.emit()
	data._process(60.0)
	assert(saves == 4)
	data.player_gold = 34567
	data.game_flags["autosave_test_reward"] = true
	data.in_battle = false
	data.battle_ended_for_save.emit()
	data._process(0.0)
	assert(saves == 5)
	saved = JSON.parse_string(FileAccess.get_file_as_string(data.SAVE_PATH))
	assert(saved.player_gold == 34567 and saved.game_flags.autosave_test_reward)
	data.story_progress_committed.emit()
	data._process(0.0)
	assert(saves == 6)
	# 剧情入口、对话气泡和独立演出锁定均阻止落盘，结束后补存一次。
	data._npc_dialogue_playing = true
	data._process(60.0)
	data.story_progress_committed.emit()
	data._process(0.0)
	assert(saves == 6)
	data._npc_dialogue_playing = false
	var balloon := Node.new()
	root.add_child(balloon)
	balloon.add_to_group(&"ballon")
	data._process(0.0)
	assert(saves == 6)
	balloon.remove_from_group(&"ballon")
	balloon.queue_free()
	data.ui_blocked = true
	data._process(0.0)
	assert(saves == 6)
	data.ui_blocked = false
	data.game_flags["autosave_story_complete"] = true
	data._process(0.0)
	assert(saves == 7)
	saved = JSON.parse_string(FileAccess.get_file_as_string(data.SAVE_PATH))
	assert(saved.game_flags.autosave_story_complete)
	data._process(0.0)
	assert(saves == 7)
	# 还原测试目录的自动存档。
	if existed:
		var file = FileAccess.open(data.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
	else:
		DirAccess.remove_absolute(data.SAVE_PATH)
	print("AUTOSAVE PASS: 60-second cadence without popup, post-battle signal, popup refresh without duplicate writes, closed popup, battle/dialogue/story-effect deferral, final rewards/flags, story save, no idle duplicate")
	quit()
