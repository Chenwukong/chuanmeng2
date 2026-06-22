# CursorController.gd — 自定义动画鼠标光标
extends CanvasLayer
class_name CursorController

const IDLE_FRAMES: Array[String] = [
	"res://Graphic/UI/cursor/5-5.png",
	"res://Graphic/UI/cursor/5-6.png",
	"res://Graphic/UI/cursor/5-7.png",
	"res://Graphic/UI/cursor/5-8.png",
	"res://Graphic/UI/cursor/5-9.png",
	"res://Graphic/UI/cursor/5-10.png",
	"res://Graphic/UI/cursor/5-11.png",
]

const CLICK_FRAMES: Array[String] = [
	"res://Graphic/UI/cursor/5-1.png",
	"res://Graphic/UI/cursor/5-2.png",
	"res://Graphic/UI/cursor/5-3.png",
	"res://Graphic/UI/cursor/5-4.png",
]

const SWORD_TEXTURE: String = "res://Graphic/UI/cursor/龙泉剑.png"
const ARROW_SHEET: String = "res://Graphic/UI/cursor/fightArrow.png"
const ARROW_FRAME_COUNT: int = 9

var _sprite: AnimatedSprite2D
var _battle_manager = null  # 由 BattleScene 注入


func _ready() -> void:
	layer = 256

	_sprite = AnimatedSprite2D.new()
	_sprite.name = "CursorSprite"
	add_child(_sprite)
	_sprite.centered = false
	_sprite.scale = Vector2(0.5, 0.5)

	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	for p in IDLE_FRAMES:
		if ResourceLoader.exists(p):
			frames.add_frame(&"idle", load(p), 0.25)
	frames.set_animation_loop(&"idle", true)

	frames.add_animation(&"click")
	for p in CLICK_FRAMES:
		if ResourceLoader.exists(p):
			frames.add_frame(&"click", load(p), 0.12)
	frames.set_animation_loop(&"click", false)

	# 龙泉剑 — 单帧动画
	frames.add_animation(&"sword")
	if ResourceLoader.exists(SWORD_TEXTURE):
		frames.add_frame(&"sword", load(SWORD_TEXTURE), 1.0)
	frames.set_animation_loop(&"sword", true)

	# 战斗箭头 — 225x26 精灵表，11帧水平排列
	frames.add_animation(&"arrow")
	if ResourceLoader.exists(ARROW_SHEET):
		var sheet: Texture2D = load(ARROW_SHEET)
		var fw: float = float(sheet.get_width()) / ARROW_FRAME_COUNT
		var fh: float = float(sheet.get_height())
		for i in ARROW_FRAME_COUNT:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(i * fw, 0, fw, fh)
			frames.add_frame(&"arrow", at, 0.4)
	frames.set_animation_loop(&"arrow", true)

	_sprite.sprite_frames = frames
	_sprite.play(&"idle")

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _process(_delta: float) -> void:
	_sprite.global_position = get_viewport().get_mouse_position()

	# 非战斗中不检测
	if _battle_manager == null or not is_instance_valid(_battle_manager):
		return

	# 战斗中鼠标悬停敌人 → 龙泉剑
	if _is_over_enemy():
		if _sprite.animation != &"sword":
			_sprite.scale = Vector2(0.2, 0.2)
			_sprite.play(&"sword")
		return
	# 悬停队友 → 战斗箭头
	if _is_over_ally():
		if _sprite.animation != &"arrow":
			_sprite.scale = Vector2(1, 1)
			_sprite.play(&"arrow")
		return

	# 非悬停时恢复 idle / click
	_sprite.scale = Vector2(0.5, 0.5)
	if _sprite.animation == &"sword" or _sprite.animation == &"arrow":
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_sprite.play(&"click")
		else:
			_sprite.play(&"idle")


func _is_over_enemy() -> bool:
	if _battle_manager == null or not is_instance_valid(_battle_manager):
		return false
	if _battle_manager.state != _battle_manager.BattleState.PLAYER_TURN:
		return false
	var mouse_pos = get_viewport().get_mouse_position()
	for ch in _battle_manager.enemies:
		if ch.is_dead:
			continue
		var nd = ch.get_parent()
		if nd and nd is Node2D:
			var rect = Rect2(nd.global_position - Vector2(50, 60), Vector2(100, 120))
			if rect.has_point(mouse_pos):
				return true
	return false


func _is_over_ally() -> bool:
	if _battle_manager == null or not is_instance_valid(_battle_manager):
		return false
	if _battle_manager.state != _battle_manager.BattleState.PLAYER_TURN:
		return false
	var mouse_pos = get_viewport().get_mouse_position()
	for ch in _battle_manager.party:
		if ch.is_dead:
			continue
		var nd = ch.get_parent()
		if nd and nd is Node2D:
			var rect = Rect2(nd.global_position - Vector2(50, 60), Vector2(100, 120))
			if rect.has_point(mouse_pos):
				return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# 战斗中悬停敌人/队友时不切换 click 动画
		if _is_over_enemy() or _is_over_ally():
			return
		_sprite.play(&"click") if event.pressed else _sprite.play(&"idle")


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
