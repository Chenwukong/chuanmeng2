extends CanvasLayer

signal closed

@export_multiline var empty_hint: String = "暂无新的剧情线索，去四处走走吧。"
var _closing := false

@onready var hint_label: Label = $Panel/Content/Paper/Scroll/hint
@onready var close_btn: Button = $Panel/CloseBtn


func _ready() -> void:
	hint_label.text = GameData.story_hint if not GameData.story_hint.strip_edges().is_empty() else empty_hint
	close_btn.pressed.connect(_close)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if _closing:
		return
	_closing = true
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://Audio/SE/003-System03.ogg")
	snd.bus = "SFX"
	get_tree().root.add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)
	closed.emit()
	queue_free()
