extends Node
## The cumulative patch belongs next to the exported executable.
## Keep this autoload first so resources are replaced before game scripts load.


func _init() -> void:
	# Editor play sessions must use the working project, never a release patch.
	if OS.has_feature("editor"):
		return
	var patch_path := OS.get_executable_path().get_base_dir().path_join("update.pck")
	if not FileAccess.file_exists(patch_path):
		return
	if not ProjectSettings.load_resource_pack(patch_path, true):
		OS.alert("更新包读取失败，请移走游戏目录中的 update.pck，或重新下载更新包。", "传梦之路：更新失败")
		# Do not continue with an unreadable or partially mounted patch.
		OS.kill(OS.get_process_id())
		return
	print("Loaded cumulative patch: ", patch_path)
