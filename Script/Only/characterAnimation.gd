extends Node2D          # 或 Control，只要包含 Sprite2D 即可

@onready var sprite: Sprite2D = $Sprite2D   # 场景中唯一的 Sprite2D 节点

# WAS 播放相关
var _reader: WASReader = WASReader.new()
var _current_direction: int = 0          # 当前播放的方向（由你在代码中设置）
var _current_frame: int = 0
var _is_loaded: bool = false

# 动画定时器
var _timer: Timer


func _ready() -> void:
	# 在这里配置你的 .was 文件路径和想要的方向
	var was_path: String = "res://攻击.was"   # 改成实际路径
	var target_direction: int = 0                  # 方向索引，从 0 开始
	
	_load_was(was_path)
	set_direction(target_direction)
	_start_playback()


# 加载 WAS 文件
func _load_was(path: String) -> void:
	if not _reader.load_from_file(path):
		print("加载失败: ", _reader.get_last_error())
		return
	_is_loaded = true
	print("加载成功，方向数: ", _reader.group_count, "，每方向帧数: ", _reader.frame_count)


# 设置方向并重置到第0帧
func set_direction(dir: int) -> void:
	if not _is_loaded:
		return
	_current_direction = clampi(dir, 0, _reader.group_count - 1)
	_current_frame = 0
	_update_sprite()


# 更新 Sprite2D 显示当前帧
func _update_sprite() -> void:
	if not _is_loaded:
		return
	var decoded := _reader.decode_frame(_current_direction, _current_frame)
	if decoded.is_empty():
		print("解码失败")
		return
	sprite.texture = decoded["texture"]
	# 可选：打印当前帧信息
	# print("方向 %d 帧 %d，尺寸 %dx%d" % [_current_direction, _current_frame, decoded["width"], decoded["height"]])


# 开始播放当前方向的动画（循环播放）
func _start_playback() -> void:
	if not _is_loaded:
		return
	_timer = Timer.new()
	_timer.wait_time = 0.1   # 每帧间隔（秒），可调整
	_timer.one_shot = false
	_timer.timeout.connect(_next_frame)
	add_child(_timer)
	_timer.start()


# 播放下一帧
func _next_frame() -> void:
	if not _is_loaded:
		return
	_current_frame += 1
	if _current_frame >= _reader.frame_count:
		_current_frame = 0   # 循环
	_update_sprite()


# 停止播放（如果需要）
func stop_playback() -> void:
	if _timer and _timer.is_inside_tree():
		_timer.stop()


# 清理定时器
func _exit_tree() -> void:
	stop_playback()
