extends RefCounted
## 地图加载时后台请求战斗场景及共用特效；保留模板供后续战斗复用。
const SCENE_PATH := "res://scenes/Battle/battleField.tscn"
const PATHS := [SCENE_PATH, "res://scenes/Battle/debuff.tscn", "res://scenes/Battle/buff.tscn", "res://scenes/Battle/animation.tscn"]
static var _requests: Dictionary = {}
static var _scenes: Dictionary = {}

static func request() -> void:
	for path in PATHS:
		if _scenes.has(path) or _requests.has(path): continue
		_requests[path] = ResourceLoader.load_threaded_request(path, "PackedScene")

static func scene_ready(tree: SceneTree) -> PackedScene:
	request()
	for path in PATHS:
		if _scenes.has(path): continue
		if _requests[path] != OK:
			push_error("无法开始后台加载战斗资源：" + path)
			_requests.erase(path)
			return null
		var status := ResourceLoader.load_threaded_get_status(path)
		while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await tree.process_frame
			status = ResourceLoader.load_threaded_get_status(path)
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			push_error("战斗资源后台加载失败：" + path)
			_requests.erase(path)
			return null
		_scenes[path] = ResourceLoader.load_threaded_get(path) as PackedScene
	return _scenes.get(SCENE_PATH) as PackedScene

static func cached_scene(path: String) -> PackedScene:
	if _scenes.has(path): return _scenes[path] as PackedScene
	# 单独运行战斗场景时没有地图预热，保留同步入口，并缓存加载结果。
	var scene := load(path) as PackedScene
	if scene: _scenes[path] = scene
	return scene
