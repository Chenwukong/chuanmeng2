# tcp_sprite.gd — 极简 TCP 精灵自动播放
extends Sprite2D

## 硬编码 TCP 文件路径（改成你自己的路径）
@export var tcp_path: String = "res://TCP/0001.tcp"

## 播放帧率
@export var fps: float = 10.0

## 播放方向（0 = 第一组）
@export var direction: int = 0

var _reader: TcpReader
var _frame: int = 0
var _timer: float = 0.0
var _frame_textures: Array[Texture2D] = []


func _ready() -> void:
	centered = true
	_load_tcp()


func _process(delta: float) -> void:
	if _frame_textures.is_empty():
		return
	_timer += delta
	if _timer >= 1.0 / fps:
		_timer = 0.0
		_next_frame()


func _load_tcp() -> void:
	if not FileAccess.file_exists(tcp_path):
		push_warning("TcpSprite: 文件不存在 — %s" % tcp_path)
		return

	_reader = TcpReader.new()
	if not _reader.load_from_file(tcp_path):
		push_error("TcpSprite: 加载失败 — %s" % _reader.get_last_error())
		return

	print("TcpSprite: 加载成功 %s | %d 组 × %d 帧 = %d 帧 | 画布 %dx%d" % [
		_reader.format_name, _reader.group_count, _reader.frame_count,
		_reader.total_frames, _reader.canvas_width, _reader.canvas_height
	])

	# 预解码选定方向的全部帧
	var start_idx := direction * _reader.frame_count
	var end_idx := start_idx + _reader.frame_count
	_frame_textures.clear()
	for i in range(start_idx, end_idx):
		if i >= _reader.total_frames:
			break
		var d := _reader.decode_frame(i)
		if not d.is_empty():
			_frame_textures.append(d["texture"])
			# 用第一帧设置偏移
			if _frame_textures.size() == 1:
				offset = Vector2(d["width"] * 0.5 - d["key_x"], d["height"] * 0.5 - d["key_y"])

	if _frame_textures.is_empty():
		push_error("TcpSprite: 没有可解码的帧")
		return

	_show_frame(0)


func _next_frame() -> void:
	if _frame_textures.is_empty():
		return
	_frame = (_frame + 1) % _frame_textures.size()
	_show_frame(_frame)


func _show_frame(idx: int) -> void:
	texture = _frame_textures[idx]
