# TitleScreen.gd
# 透明标题场景 — 多重剑光划过 → 游戏名浮现 → 点击关闭
extends CanvasLayer

@onready var _slashes: Node2D = $Slashes
@onready var _title: Label = $TitleLabel
@onready var _subtitle: Label = $SubtitleLabel

signal closed

## 点击标题后进入的游戏场景（当前启动场景；想改入口改这里）
const GAME_SCENE: String = "res://Class/battleField.tscn"

var _dismiss_on_click: bool = false


static func show_at(parent: Node) -> CanvasLayer:
	var scene := load("res://scenes/TitleScreen.tscn")
	if scene == null:
		return null
	var inst = scene.instantiate()
	parent.add_child(inst)
	return inst


func _ready() -> void:
	_apply_transparent_window()
	_play_intro()


## 标题期间：窗口透明 + 无边框（像直接画在桌面上）
func _apply_transparent_window() -> void:
	get_tree().root.transparent_bg = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)


## 进游戏：恢复正常窗口（不透明 + 有边框）
func _restore_window() -> void:
	get_tree().root.transparent_bg = false
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)


func _play_intro() -> void:
	# 剑光组从右侧高速飞过画面
	var start_x := 2400.0
	var mid_x := 300.0
	var end_x := -600.0
	var y := 280.0

	_slashes.position = Vector2(start_x, y)

	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t.tween_property(_slashes, "position:x", mid_x, 0.2)
	t.tween_property(_slashes, "position:x", end_x, 0.45).set_ease(Tween.EASE_IN)

	# 主剑光渐隐
	var sm := _slashes.get_node("SlashMain") as ColorRect
	var su := _slashes.get_node("SlashUp") as ColorRect
	var sd := _slashes.get_node("SlashDown") as ColorRect
	var sg := _slashes.get_node("Glow") as ColorRect

	var f := create_tween()
	f.tween_property(sm, "modulate:a", 0.0, 0.3).set_delay(0.25)
	f.parallel().tween_property(su, "modulate:a", 0.0, 0.25).set_delay(0.25)
	f.parallel().tween_property(sd, "modulate:a", 0.0, 0.25).set_delay(0.25)
	f.parallel().tween_property(sg, "modulate:a", 0.0, 0.3).set_delay(0.25)

	# 标题浮现 — 从下方弹入
	var t2 := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t2.tween_property(_title, "modulate:a", 1.0, 0.55).set_delay(0.35)
	t2.parallel().tween_property(_title, "position:y", 0, 0.55).set_delay(0.35)

	# 副标题淡入
	var t3 := create_tween()
	t3.tween_property(_subtitle, "modulate:a", 1.0, 0.5).set_delay(0.7)

	# 允许点击关闭
	t3.tween_callback(func(): _dismiss_on_click = true).set_delay(0.3)


func _input(event: InputEvent) -> void:
	if not _dismiss_on_click:
		return
	if event is InputEventMouseButton and event.pressed:
		_dismiss()


func _dismiss() -> void:
	_dismiss_on_click = false
	# 内容淡出（CanvasLayer 自身无 modulate，淡子节点）
	var t := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_title, "modulate:a", 0.0, 0.35)
	t.parallel().tween_property(_subtitle, "modulate:a", 0.0, 0.35)
	t.parallel().tween_property(_slashes, "modulate:a", 0.0, 0.35)
	t.tween_callback(_enter_game)


func _enter_game() -> void:
	# 先恢复正常窗口，再切换到游戏场景（避免透明窗口下游戏闪一下）
	_restore_window()
	closed.emit()
	get_tree().change_scene_to_file(GAME_SCENE)
