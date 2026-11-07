extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var paths := ["res://scenes/MainScene.tscn", "res://scenes/方寸山.tscn", "res://scenes/MapTemplate.tscn", "res://scenes/UI/AchievementPopup.tscn", "res://Component/AchievementPopup.tscn", "res://Component/map.tscn", "res://Component/MountainMist.tscn"]
	DirAccess.make_dir_recursive_absolute("res://artifacts/dependency_save_check")
	for i in paths.size():
		var original = load(paths[i]) as PackedScene
		assert(original != null and original.can_instantiate(), paths[i])
		var instance = original.instantiate()
		assert(instance != null, paths[i])
		var packed := PackedScene.new()
		assert(packed.pack(instance) == OK, paths[i])
		var output := "res://artifacts/dependency_save_check/scene_%d.tscn" % i
		assert(ResourceSaver.save(packed, output) == OK, paths[i])
		var roundtrip = ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		assert(roundtrip != null and roundtrip.can_instantiate(), paths[i])
		instance.free()
	print("SCENE DEPENDENCY + REPACK + SAVE ROUNDTRIP: PASS (", paths.size(), " scenes)")
	quit()
