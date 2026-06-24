# FullscreenAnimation.gd
# 把 SeparateAnimation 下的逐帧 PNG 序列做成全屏动画直接播放，无需手动建 AnimationPlayer / SpriteFrames。
#
# 用法：
#   FullscreenAnimation.play("地狱烈火")          # 按技能名播放（文件夹=SeparateAnimation/地狱烈火）
#   FullscreenAnimation.play_folder("res://...")  # 按文件夹路径播放
#   var a = FullscreenAnimation.play("龙吟"); await a.finished   # 等播完
#   if FullscreenAnimation.has_animation("奔雷"): ...            # 判断某技能有没有全屏动画
#
# 文件命名约定：<任意前缀> (n).png/.jpg，n 从 1 开始、不补零（前缀/帧数/格式可不同，自动识别）。
class_name FullscreenAnimation
extends CanvasLayer

signal finished()

## 序列帧根目录
const BASE_DIR: String = "res://Graphic/BattleAnimation/SeparateAnimation"
## 叠在最上层（盖住战斗 UI）
const OVERLAY_LAYER: int = 200

var _frames: Array[Texture2D] = []
var _idx: int = 0
var _loop: bool = false
var _rect: TextureRect
var _timer: Timer
## jpg 帧无 alpha（黑底），需要叠加(add)混合
var _additive: bool = false


## 按技能名播放（文件夹 = SeparateAnimation/<skill_name>）
static func play(skill_name: String, fps: float = 15.0, loop: bool = false) -> FullscreenAnimation:
	return play_folder(BASE_DIR.path_join(skill_name), fps, loop)


## 按文件夹路径播放，返回实例（可 await inst.finished）
static func play_folder(folder: String, fps: float = 15.0, loop: bool = false) -> FullscreenAnimation:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var inst := FullscreenAnimation.new()
	inst.layer = OVERLAY_LAYER
	var host: Node = tree.current_scene if tree.current_scene else tree.root
	host.add_child(inst)
	inst._setup(folder, fps, loop)
	return inst


## 某技能名是否有全屏序列帧文件夹（可用于判断技能是否走全屏）
static func has_animation(skill_name: String) -> bool:
	return DirAccess.dir_exists_absolute(BASE_DIR.path_join(skill_name))


func _setup(folder: String, fps: float, loop: bool) -> void:
	_loop = loop
	_frames = _load_frames(folder)
	if _frames.is_empty():
		push_warning("FullscreenAnimation: 没有找到帧 -> " + folder)
		# 延迟发射，确保调用方的 await 已挂上
		finished.emit.call_deferred()
		queue_free()
		return

	_rect = TextureRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 铺满屏幕、保持比例、超出裁掉（最适合全屏特效）
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.texture = _frames[0]
	# jpg 帧是黑底无透明，用叠加混合让黑色透出
	if _additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_rect.material = mat
	add_child(_rect)

	_timer = Timer.new()
	_timer.wait_time = 1.0 / maxf(1.0, fps)
	_timer.one_shot = false
	_timer.timeout.connect(_advance)
	add_child(_timer)
	_timer.start()


func _advance() -> void:
	_idx += 1
	if _idx >= _frames.size():
		if _loop:
			_idx = 0
		else:
			_timer.stop()
			finished.emit()
			queue_free()
			return
	_rect.texture = _frames[_idx]


## 提前停止并移除
func stop() -> void:
	if _timer:
		_timer.stop()
	finished.emit()
	queue_free()


## 扫描文件夹里的 png，按文件名括号内数字升序加载
func _load_frames(folder: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	_additive = false
	var dir := DirAccess.open(folder)
	if dir == null:
		return result

	var entries: Array = []  # [{ n:int, path:String }]
	var re := RegEx.new()
	re.compile("\\((\\d+)\\)")

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		var lower := fname.to_lower()
		var is_jpg := lower.ends_with(".jpg") or lower.ends_with(".jpeg")
		var is_img := lower.ends_with(".png") or is_jpg or lower.ends_with(".webp")
		if not dir.current_is_dir() and is_img and not lower.ends_with(".import"):
			if is_jpg:
				_additive = true  # 检测到 jpg → 叠加混合
			var n := 0
			var m := re.search(fname)
			if m:
				n = m.get_string(1).to_int()
			entries.append({ "n": n, "path": folder.path_join(fname) })
		fname = dir.get_next()
	dir.list_dir_end()

	entries.sort_custom(func(a, b): return a.n < b.n)
	for e in entries:
		var tex := load(e.path) as Texture2D
		if tex:
			result.append(tex)
	return result
