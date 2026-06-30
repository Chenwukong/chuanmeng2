# WASAnimationPlayer.gd
# 在 Sprite2D 上播放 .was 动画文件的帧
@tool
class_name WASAnimationPlayer
extends Node

@export var target_sprite: NodePath
@onready var _sprite: Sprite2D = get_node(target_sprite)

var direction: int = 0
var anim_files: Dictionary = {}
@export var frame_time: float = 0.1

var _readers: Dictionary = {}
var _current_anim: String = ""
var _current_frame: int = 0
var _loop: bool = true
var _timer: Timer

signal animation_finished(anim_name: String)

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = frame_time
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	if _sprite:
		_sprite.centered = true

func add_anim(anim_name: String, was_path: String) -> void:
	if was_path.is_empty(): return
	anim_files[anim_name] = was_path

func load_all() -> void:
	for k in anim_files.keys():
		_load_one(k)

func _load_one(anim_name: String) -> bool:
	var path = anim_files.get(anim_name, "")
	if path.is_empty(): return false
	var reader = WASReader.new()
	if not reader.load_from_file(path):
		return false
	_readers[anim_name] = reader
	return true

## 播放一次性动画并逐帧 await（不依赖 Timer）
func play_frames_direct(anim_name: String) -> void:
	var r = _readers.get(anim_name)
	if r == null:
		if not _load_one(anim_name): return
		r = _readers.get(anim_name)
		if r == null: return
	for f in range(r.frame_count):
		_current_anim = anim_name
		_current_frame = f
		_loop = false
		var d = r.decode_frame(direction, f)
		if not d.is_empty():
			_sprite.texture = d["texture"]
			_sprite.offset = Vector2(d["width"] * 0.5 - d["key_x"], d["height"] * 0.5 - d["key_y"])
		await get_tree().create_timer(frame_time).timeout


## 开始播放（循环/一次性，依赖 Timer）
func play(anim_name: String, loop: bool = true) -> void:
	var r = _readers.get(anim_name)
	if r == null:
		if not _load_one(anim_name): return
		r = _readers.get(anim_name)
		if r == null: return
	_current_anim = anim_name
	_current_frame = 0
	_loop = loop
	_timer.wait_time = frame_time
	_apply_frame(r)
	_timer.start()

## 停止
func stop() -> void:
	_timer.stop()

## 是否正在播放（Timer 运行中）
func is_playing() -> bool:
	return not _timer.is_stopped()

func _on_timer_timeout() -> void:
	var r = _readers.get(_current_anim)
	if r == null: return
	_current_frame += 1
	if _current_frame >= r.frame_count:
		if _loop:
			_current_frame = 0
		else:
			_current_frame = r.frame_count - 1
			_timer.stop()
			animation_finished.emit(_current_anim)
			return
	_apply_frame(r)

func _apply_frame(r: WASReader) -> void:
	var d = r.decode_frame(direction, _current_frame)
	if d.is_empty(): return
	_sprite.texture = d["texture"]
	_sprite.offset = Vector2(
		d["width"] * 0.5 - d["key_x"],
		d["height"] * 0.5 - d["key_y"]
	)
