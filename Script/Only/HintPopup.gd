extends CanvasLayer

signal closed

@onready var hint_label: Label = $hint
@onready var close_btn: TextureButton = $CloseBtn


func _ready() -> void:
	hint_label.text = GameData.story_hint
	close_btn.pressed.connect(_close)


func _close() -> void:
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://Audio/SE/003-System03.ogg")
	snd.bus = "SFX"
	get_tree().root.add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)
	closed.emit()
	queue_free()
