extends Node2D
@export var accessory_name: String = "饰品触发"
@export var effect_text: String = "特殊效果生效"

func _ready() -> void:
	$Panel/Title.text = accessory_name
	$Panel/Message.text = effect_text
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	tween.tween_interval(1.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
