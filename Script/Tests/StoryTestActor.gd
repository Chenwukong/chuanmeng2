extends NpcNode
@export_dir var was_base_path: String = "res://WAS/游霄云"
@onready var animation: WASAnimationPlayer = $WASAnimationPlayer
func _ready() -> void:
	auto_look_at_player = false
	var names = {"idle":"待机.was", "attack":"攻击.was", "walk":"行走.was", "move":"移动.was"}
	for key in names:
		var path: String = was_base_path.path_join(names[key])
		if FileAccess.file_exists(path): animation.add_anim(key,path)
	animation.direction = direction
	animation.load_all()
	animation.play("idle")
	_dir_idx = direction
