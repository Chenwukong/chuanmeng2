extends Node2D
## 在编辑器中运行 DyePreview.tscn，检查原色与三组分段染色。
func _ready() -> void:
	for name in ["Original", "Scheme1", "Scheme2", "Scheme3"]:
		var player: WASAnimationPlayer = get_node(str(name) + "/WASAnimationPlayer")
		player.add_anim("idle", "res://WAS/虎头怪/站立.was")
		player.play("idle")
