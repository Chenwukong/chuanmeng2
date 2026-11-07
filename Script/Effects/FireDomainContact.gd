extends Node2D

func _on_lifetime_timeout() -> void:
	queue_free()
