extends RefCounted
const Cache = preload("res://Script/Assets/AssetCache.gd")

## 小头像独立配置裁切区域，立绘仍使用完整的 头像.png。
static func portrait_icon(was_base: String = "", png_base: String = "", character_name: String = "") -> Texture2D:
	var folders: Array[String] = [was_base.trim_suffix("/"), png_base.trim_suffix("/")]
	if not character_name.is_empty():
		folders.append("res://WAS/" + character_name)
		folders.append("res://Graphic/Character/" + character_name)
	for folder in folders:
		if folder.is_empty(): continue
		var path := folder.path_join("头像icon.tres")
		if ResourceLoader.exists(path, "Texture2D"):
			return load(path) as Texture2D
	return null

## 角色根目录的 头像.png 为统一优先立绘；无图时由调用方沿用旧回退。
static func root_portrait(was_base: String = "", png_base: String = "", character_name: String = "") -> Texture2D:
	var folders: Array[String] = []
	if not was_base.is_empty(): folders.append(was_base.trim_suffix("/"))
	if not png_base.is_empty(): folders.append(png_base.trim_suffix("/"))
	if not character_name.is_empty():
		folders.append("res://WAS/" + character_name)
		folders.append("res://Graphic/Character/" + character_name)
	for folder in folders:
		var path := folder.path_join("头像.png")
		var key := "root_portrait:" + path
		if Cache.has(key): return Cache.fetch(key) as Texture2D
		var texture: Texture2D
		if ResourceLoader.exists(path, "Texture2D"):
			texture = load(path) as Texture2D
		elif FileAccess.file_exists(path):
			# 新加入、尚未导入的本地图片也可预览；导出后优先走导入资源。
			var img := Image.load_from_file(path)
			if img != null: texture = ImageTexture.create_from_image(img)
		if texture != null:
			Cache.store(key, texture, texture.get_width() * texture.get_height() * 4)
			return texture
	return null

static func tcp_texture(path: String) -> Texture2D:
	if path.is_empty(): return null
	var key := "tcp:" + path.simplify_path()
	if Cache.has(key): return Cache.fetch(key) as Texture2D
	var texture: Texture2D
	if FileAccess.file_exists(path):
		var reader := TcpReader.new()
		if reader.load_from_file(path):
			texture = reader.decode_frame(0).get("texture") as Texture2D
		if texture == null:
			var was := WASReader.shared_from_file(path)
			if was: texture = was.decode_frame(0, 0).get("texture") as Texture2D
	Cache.store(key, texture, texture.get_width() * texture.get_height() * 4 if texture else 0)
	return texture

## 大批量图标可在打开页面前预热；控件刷新仍可使用同步缓存接口。
static func prepare_tcp(paths: Array, tree: SceneTree) -> void:
	var started := Time.get_ticks_usec()
	for path in paths:
		tcp_texture(str(path))
		if Time.get_ticks_usec() - started >= 3000:
			await tree.process_frame
			started = Time.get_ticks_usec()

static var _queue: Array[String] = []
static var _waiters: Dictionary = {}
static var _scheduled: bool = false

## 只保存控件弱引用；快速翻页或窗口关闭时，过期请求不会回填图标。
static func request_tcp(icon: TextureRect, path: String) -> void:
	icon.set_meta("asset_tcp_path", path)
	var key := "tcp:" + path.simplify_path()
	icon.texture = Cache.fetch(key) as Texture2D if not path.is_empty() else null
	if path.is_empty() or Cache.has(key): return
	if not _waiters.has(path):
		_waiters[path] = {}
		_queue.append(path)
	_waiters[path][icon.get_instance_id()] = weakref(icon)
	var tree := Engine.get_main_loop() as SceneTree
	if tree and not _scheduled:
		_scheduled = true
		tree.process_frame.connect(_pump.bind(tree), CONNECT_ONE_SHOT)

static func _pump(tree: SceneTree) -> void:
	_scheduled = false
	var started := Time.get_ticks_usec()
	while not _queue.is_empty():
		var path: String = _queue.pop_front()
		var waiting: Dictionary = _waiters.get(path, {})
		_waiters.erase(path)
		var active: Array[TextureRect] = []
		for reference in waiting.values():
			var icon := reference.get_ref() as TextureRect
			if icon and icon.get_meta("asset_tcp_path", "") == path: active.append(icon)
		if not active.is_empty():
			var texture := tcp_texture(path)
			for icon in active: icon.texture = texture
		if Time.get_ticks_usec() - started >= 3000: break
	if not _queue.is_empty() and not _scheduled:
		_scheduled = true
		tree.process_frame.connect(_pump.bind(tree), CONNECT_ONE_SHOT)

static func was_frame(path: String, direction: int = 0, frame: int = 0) -> Dictionary:
	var key := "was_frame:%s:%d:%d" % [path.simplify_path(), direction, frame]
	if Cache.has(key): return Cache.fetch(key)
	var reader := WASReader.shared_from_file(path)
	var decoded: Dictionary = reader.decode_frame(direction, frame) if reader else {}
	var texture := decoded.get("texture") as Texture2D
	Cache.store(key, decoded, texture.get_width() * texture.get_height() * 4 if texture else 0)
	return decoded
