extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var data = root.get_node("GameData")
	data.set_process(false)
	data.restore_difficulty(1)
	data.character_locks = {}
	assert(data.is_character_unlocked("aobai"))
	assert(not data.is_character_unlocked("xiaoer"))
	assert(not data.is_character_unlocked("unknown"))
	assert(not data.unlock_character("unknown"))
	assert(data.set_character_locked("aobai", true))
	assert(not data.is_character_unlocked("aobai"))
	change_scene_to_file("res://scenes/MainScene.tscn")
	await scene_changed
	await load("res://Script/Assets/BattleAssetLoader.gd").scene_ready(self)
	var meeting = load("res://scenes/约定之地.tscn").instantiate()
	current_scene.add_child(meeting)
	var aobai = meeting.get_node("敖白")
	assert(not aobai.visible)
	assert(data.character_roster.has("aobai"))
	assert(data.unlock_character("aobai"))
	assert(aobai.visible)
	data.add_party_by_name("敖白")
	data.set_character_locked("aobai", true)
	assert(not aobai.visible)
	assert(data.party_db.has("aobai"))
	var saved = load("res://Script/Save/SaveService.gd").serialize_state(data)
	assert(saved.character_locks.aobai)
	saved.vol_master = -1
	saved.vol_music = -1
	saved.vol_sfx = -1
	data.unlock_character("aobai")
	assert(aobai.visible)
	assert(load("res://Script/Save/SaveService.gd").restore_state(data, saved))
	assert(not aobai.visible and data.party_db.has("aobai"))
	saved.erase("character_locks")
	assert(load("res://Script/Save/SaveService.gd").restore_state(data, saved))
	assert(data.is_character_unlocked("aobai") and aobai.visible)
	assert(data._auto_save_pending)
	print("CHARACTER LOCK PASS: bool defaults, invalid/story-only IDs rejected, real meeting-place hides locked NPCs, live unlock and relock, roster/party preserved, saved state restored, old save compatible")
	quit()