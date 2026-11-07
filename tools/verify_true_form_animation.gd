extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func play_once(player, status: Dictionary) -> void:
	await player.play_frames_direct("attack")
	status.done = true
func verify() -> void:
	var host := Node2D.new()
	root.add_child(host)
	var sprite := Sprite2D.new()
	sprite.name = "Body"
	host.add_child(sprite)
	var player = load("res://Script/Assets/WASAnimationPlayer.gd").new()
	player.target_sprite = NodePath("../Body")
	player.frame_time = 0.02
	player.frame_offset = Vector2(-14, 12)
	host.add_child(player)
	player.add_anim("idle", "res://WAS/小二真身/待机.was")
	player.add_anim("attack", "res://WAS/小二真身/攻击.was")
	player.load_all()
	player.play("idle")
	await create_timer(0.03).timeout
	var status := {"done": false}
	play_once(player, status)
	var previous := -1
	while not status.done:
		assert(player._timer.is_stopped())
		assert(player._current_anim == "attack")
		assert(player._current_frame >= previous)
		previous = player._current_frame
		var d = player._readers.attack.decode_frame(player.direction, previous)
		if not d.is_empty():
			var anchor: Vector2 = Vector2(d.width * 0.5 - d.key_x, d.height * 0.5 - d.key_y) + player.frame_offset
			assert(sprite.offset.is_equal_approx(anchor))
		await process_frame
	assert(previous == player._readers.attack.frame_count - 1)
	# 新动画接管后，旧逐帧协程不能再覆盖贴图和锚点。
	status.done = false
	play_once(player, status)
	await create_timer(0.03).timeout
	player.play("idle")
	await create_timer(0.15).timeout
	assert(status.done and player._current_anim == "idle")
	assert(not player._timer.is_stopped())
	print("TRUE FORM ANIMATION PASS: direct attack stops competing timer, frames advance monotonically, corrected anchor retained on every frame, new playback cancels old coroutine, idle resumes normally")
	quit()