extends RefCounted
const Assets = preload("res://Script/Assets/AssetLoader.gd")
const Cache = preload("res://Script/Assets/AssetCache.gd")

## 兼容“游霄云喜：台词”和省略冒号后空格的写法；只识别已有角色，保留普通旁白。
static func prepare_line(line: DialogueLine) -> void:
	if not line.character.is_empty(): return
	var separator := line.text.find("：")
	var ascii_separator := line.text.find(":")
	if ascii_separator >= 0 and (separator < 0 or ascii_separator < separator): separator = ascii_separator
	if separator <= 0: return
	var speaker := line.text.left(separator).strip_edges()
	var name: String = speaker_info(speaker).name
	var known := DirAccess.dir_exists_absolute("res://WAS/" + name) or DirAccess.dir_exists_absolute("res://Graphic/Character/" + name)
	for entry in CharacterDB.CHARACTER_DB.values():
		if entry.get("name", "") == name: known = true
	if not known:
		for entry in GameData._enemy_db_cache.values():
			if entry.get("name", "") == name: known = true
	if known:
		line.character = speaker
		line.text = line.text.substr(separator + 1).strip_edges()

## 表情只作用于当前一句；不带后缀或写“正常”都会恢复正常立绘。
static func speaker_info(speaker: String) -> Dictionary:
	var name := speaker.strip_edges()
	for expression in ["正常", "喜", "怒", "哀"]:
		if name.length() > expression.length() and name.ends_with(expression):
			return {"name": name.trim_suffix(expression), "expression": expression}
	return {"name": name, "expression": "正常"}

static func _expression_texture(speaker: String, expression: String, was: String, png: String) -> Texture2D:
	var folders: Array[String] = []
	if not was.is_empty(): folders.append(was.trim_suffix("/"))
	if not png.is_empty(): folders.append(png.trim_suffix("/"))
	folders.append("res://WAS/" + speaker)
	folders.append("res://Graphic/Character/" + speaker)
	for folder in folders:
		for file in [expression + ".png", "头像" + expression + ".png", "头像/" + expression + ".png"]:
			var path := folder.path_join(file)
			if ResourceLoader.exists(path, "Texture2D"):
				var texture := load(path) as Texture2D
				if texture != null: return texture
			elif FileAccess.file_exists(path):
				var image := Image.load_from_file(path)
				if image != null: return ImageTexture.create_from_image(image)
	return null

static func texture_for(speaker: String) -> Texture2D:
	if speaker.is_empty(): return null
	var info := speaker_info(speaker)
	speaker = info.name
	var key := "chat_portrait:" + speaker + ":" + str(info.expression)
	if Cache.has(key): return Cache.fetch(key) as Texture2D
	var was := ""
	var png := ""
	for entry in CharacterDB.CHARACTER_DB.values():
		if entry.get("name", "") == speaker:
			was = entry.get("was_base_path", "")
			png = entry.get("portrait_path", "")
			break
	if was.is_empty():
		for entry in GameData._enemy_db_cache.values():
			if entry.get("name", "") == speaker:
				was = entry.get("was_base_path", "")
				png = entry.get("portrait_path", "")
				break
	if was.is_empty():
		for npc in Engine.get_main_loop().get_nodes_in_group("npc"):
			if npc is NpcNode and npc.npc_name == speaker and not npc.appearance_path.is_empty():
				was = npc.appearance_path
				break
	var result := _expression_texture(speaker, info.expression, was, png)
	# 没有对应表情素材时回退正常脸，避免空白或沿用上一句表情。
	if result == null and info.expression != "正常":
		return texture_for(speaker)
	if result == null: result = Assets.root_portrait(was, png, speaker)
	for candidate in [png.path_join(speaker + ".png") if not png.is_empty() else "", "res://Graphic/Character/" + speaker + "/" + speaker + ".png"]:
		if result != null: break
		if not candidate.is_empty() and ResourceLoader.exists(candidate):
			result = load(candidate) as Texture2D
			if result: break
	if result == null:
		if was.is_empty(): was = "res://WAS/" + speaker
		for file in ["头像/头像.was", "头像/x44.was", "头像/x32.was"]:
			var candidate := was.trim_suffix("/").path_join(file)
			if FileAccess.file_exists(candidate):
				result = Assets.was_frame(candidate).get("texture") as Texture2D
				if result: break
	Cache.store(key, result, result.get_width() * result.get_height() * 4 if result else 0)
	return result
