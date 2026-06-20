extends Area2D

@export var teleportTo: String = ""

var _triggered = false


func _process(_delta):
	if _triggered:
		return
	var p = get_parent()
	if p == null:
		return
	var player = p.get_node_or_null("Player") as Node2D
	if player == null:
		# 找 MapWalker 类型的子节点
		for child in p.get_children():
			if child is Node2D and child.has_method("_navigate_to"):
				player = child
				break
	if player == null:
		return
	if global_position.distance_to(player.global_position) < 40:
		_triggered = true
		print("[传送] 玩家进入: %s -> %s" % [name, teleportTo])
		if not teleportTo.is_empty():
			get_tree().change_scene_to_file(teleportTo)
