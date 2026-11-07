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
## 素材锚点修正，每个动画帧都应用，避免播放后回跳。
@export var frame_offset: Vector2 = Vector2.ZERO
## 与动画素材匹配的 GGE 调色板；留空使用原色。
@export_file("*.wpal") var dye_palette: String = ""
@export var dye_choices: PackedInt32Array = PackedInt32Array()

var _readers: Dictionary = {}
var _playback_serial := 0
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

## 保留当前帧，用于剧情定身等效果。
func pause() -> void:
	_playback_serial += 1
	if is_instance_valid(_timer): _timer.stop()

func load_all() -> void:
	for k in anim_files.keys():
		_load_one(k)

func _load_one(anim_name: String) -> bool:
	var path = anim_files.get(anim_name, "")
	if path.is_empty(): return false
	var reader: WASReader
	if Engine.is_editor_hint():
		reader = WASReader.new()
		if not reader.load_from_file(path): return false
	else:
		reader = WASReader.shared_from_file(path)
		if reader == null: return false
	if not dye_palette.is_empty():
		var dyed := reader.with_dye(_palette_for_file(dye_palette, path), dye_choices)
		if dyed == null:
			push_warning("染色失败：" + reader.get_last_error())
			return false
		reader = dyed
	_readers[anim_name] = reader
	return true

## 对已加载和后续加载的所有动作生效；失败时保留原外观。
func set_dye(palette_path: String, choices: PackedInt32Array = PackedInt32Array()) -> bool:
	var prepared: Dictionary = {}
	for anim in _readers:
		var original := WASReader.shared_from_file(str(anim_files[anim]))
		if original == null: return false
		var next := original if palette_path.is_empty() else original.with_dye(_palette_for_file(palette_path, str(anim_files[anim])), choices)
		if next == null:
			push_warning("染色失败：" + original.get_last_error())
			return false
		prepared[anim] = next
	# 尚未加载动画时也验证配置，防止存入无效的延迟加载参数。
	if not palette_path.is_empty():
		var dye := preload("res://Script/Assets/WpalDye.gd").new()
		if not dye.load_file(_palette_for_file(palette_path, "待机.was")): return false
		var dummy := PackedInt32Array()
		dummy.resize(256)
		if dye.apply(dummy, choices).is_empty(): return false
	dye_palette = palette_path
	dye_choices = choices.duplicate()
	_readers = prepared
	if _sprite and _readers.has(_current_anim):
		_apply_frame(_readers[_current_anim])
	return true

func clear_dye() -> void:
	set_dye("")

## 部分素材每个动作的调色板不同，模板按源文件名选择对应调色板。
func _palette_for_file(template: String, source: String) -> String:
	return template.replace("{file}", source.get_file().get_basename())

## 播放一次性动画并逐帧 await（不依赖 Timer）
func play_frames_direct(anim_name: String) -> void:
	var r = _readers.get(anim_name)
	if r == null:
		if not _load_one(anim_name): return
		r = _readers.get(anim_name)
		if r == null: return
	# 逐帧播放必须独占贴图；不能让上一个待机/移动 Timer 同时写入帧和锚点。
	_timer.stop()
	_playback_serial += 1
	var serial := _playback_serial
	_current_anim = anim_name
	_loop = false
	for f in range(r.frame_count):
		if serial != _playback_serial: return
		_current_frame = f
		r = _readers.get(anim_name, r)
		_apply_frame(r)
		await get_tree().create_timer(frame_time).timeout


## 开始播放（循环/一次性，依赖 Timer）
func play(anim_name: String, loop: bool = true) -> void:
	var r = _readers.get(anim_name)
	if r == null:
		if not _load_one(anim_name): return
		r = _readers.get(anim_name)
		if r == null: return

	# 冻结守卫：角色被冰封/失魂时，不允许回 idle
	if anim_name == "idle":
		var parent = get_parent()
		if parent and parent.has_node("BattleCharacter"):
			var bc = parent.get_node("BattleCharacter") as Node
			if bc and bc.has_method("has_buff") and (bc.has_buff("freeze") or bc.has_buff("失魂")):
				return  # 封印中拒绝 idle，停在当前帧

	_current_anim = anim_name
	_current_frame = 0
	_playback_serial += 1
	_loop = loop
	_timer.wait_time = frame_time
	_apply_frame(r)
	_timer.start()

## 停止
func stop() -> void:
	_playback_serial += 1
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


## 显示指定动画的第一帧（用于快速更新朝向）
func show_frame(anim_name: String) -> void:
	var r = _readers.get(anim_name)
	if r == null:
		if not _load_one(anim_name): return
		r = _readers.get(anim_name)
		if r == null: return
	_current_anim = anim_name
	_current_frame = 0
	_apply_frame(r)


func _apply_frame(r: WASReader) -> void:
	var d = r.decode_frame(direction, _current_frame)
	if d.is_empty(): return
	_sprite.texture = d["texture"]
	_sprite.offset = Vector2(
		d["width"] * 0.5 - d["key_x"],
		d["height"] * 0.5 - d["key_y"]
	) + frame_offset
