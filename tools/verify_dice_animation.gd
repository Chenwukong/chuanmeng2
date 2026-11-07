extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var scene = load("res://scenes/UI/BattleDiceRoll.tscn")
	var dice = scene.instantiate()
	root.add_child(dice)
	dice.roll_duration = 0.15
	dice.result_duration = 0.03
	var normals := [Vector3.BACK, Vector3.UP, Vector3.RIGHT, Vector3.LEFT, Vector3.DOWN, Vector3.FORWARD]
	for face in range(1,7):
		var basis: Basis = dice.face_basis(face)
		assert((basis * normals[face-1]).z > 0.9999)
		await dice.roll(face)
		assert(dice.settled_face == face)
		assert(dice.result_label.text.begins_with("%d 点" % face))
		var final_basis: Basis = dice.die.material.get_shader_parameter("cube_basis")
		assert(final_basis.is_equal_approx(basis))
		await create_timer(0.05).timeout
		assert(dice.die.material.get_shader_parameter("cube_basis").is_equal_approx(final_basis))
	print("DICE ANIMATION PASS: six face orientations, animation lands on result, settled orientation remains stable")
	dice.queue_free()
	await process_frame
	quit()
