extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/architecture_paths.json"))
	var failures: Array[String] = []
	for path in manifest.values():
		var resource = load("res://" + str(path))
		if resource == null or (resource is Script and not resource.can_instantiate()) or (resource is PackedScene and not resource.can_instantiate()):
			failures.append(path)
	if not failures.is_empty(): push_error(str(failures))
	print("ARCHITECTURE RESOURCE LOAD: ", manifest.size(), " checked; failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
