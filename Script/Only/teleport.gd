extends Area2D

@export var teleportTo: String = ""

var _was_player_inside: bool = false  # 玩家已经在圈内（抵达后需离开才能再触发）


func _process(_delta):
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
		_was_player_inside = false
		return

	var inside := global_position.distance_to(player.global_position) < 40
	if inside and not _was_player_inside:
		_was_player_inside = true
		print("[传送] 玩家进入: %s -> %s" % [name, teleportTo])
		if not teleportTo.is_empty():
			_do_teleport()
	elif not inside:
		_was_player_inside = false


func _do_teleport() -> void:
	var main_scene := get_tree().current_scene
	if main_scene == null:
		return

	var old_map := get_parent()  # 当前地图的根节点
	if old_map == null:
		return

	var source_map_name := old_map.name  # 记下旧地图名，在新地图里找对应传送圈

	# 锁定玩家输入
	GameData.ui_blocked = true

	# 创建黑幕 CanvasLayer（盖在所有东西上面）
	var canvas := CanvasLayer.new()
	canvas.layer = 128  # 最高层
	main_scene.add_child(canvas)

	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.modulate.a = 0.0
	canvas.add_child(fade)

	# 渐黑 → 替换地图 → 渐亮
	var tween := canvas.create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(fade, "modulate:a", 1.0, 0.35)
	tween.tween_callback(func():
		# 删旧地图
		old_map.queue_free()

		# 加载新地图
		print("res://scenes/" + teleportTo + ".tscn")
		var new_map := load("res://scenes/" + name + ".tscn").instantiate() as Node2D
		if new_map == null:
			return
		main_scene.add_child(new_map)

		# 找新地图里名字与旧地图名匹配的传送圈
		var target_tp: Area2D = null
		for child in new_map.get_children():
			if child is Area2D and child.name == source_map_name:
				target_tp = child
				break

		# 把玩家放到对应传送圈上
		var new_player := new_map.get_node_or_null("Player") as Node2D
		if target_tp and new_player:
			new_player.global_position = target_tp.global_position
			# 标记目标圈"玩家已在圈内"，防止落地立刻被传走
			target_tp._was_player_inside = true

		# 更新当前场景路径，确保存档正确
		GameData.current_scene_path = main_scene.scene_file_path
	)
	tween.tween_property(fade, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func():
		GameData.ui_blocked = false
		canvas.queue_free()
	)
