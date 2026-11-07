extends Node2D
## 旧外观保留上半部，新外观从脚到头扫入；按同一世界高度裁切，兼容两套素材尺寸。
var _materials: Dictionary = {}

func _snapshot(source: Sprite2D, target: Sprite2D) -> void:
	target.texture = source.texture
	target.transform = source.transform
	target.offset = source.offset
	target.centered = source.centered
	target.flip_h = source.flip_h
	target.flip_v = source.flip_v
	target.hframes = source.hframes
	target.vframes = source.vframes
	target.frame = source.frame
	target.region_enabled = source.region_enabled
	target.region_rect = source.region_rect
	target.modulate = source.modulate
	target.show()

func _mask(sprite: Sprite2D, new_form: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://Shader/TrueFormWipe.gdshader")
	material.set_shader_parameter("new_form", new_form)
	if new_form: _materials[sprite] = sprite.material
	sprite.material = material
	return material

func play(reveal: Callable) -> void:
	var shader = $Aura.material
	var ground = $Ground.material
	var tween := create_tween()
	tween.tween_method(func(value: float):
		shader.set_shader_parameter("progress", value)
		ground.set_shader_parameter("progress", value)
	, 0.0, 1.0, 1.45)
	await get_tree().create_timer(0.30).timeout
	var hero = get_parent()
	var body := hero.get_node("Sprite2D") as Sprite2D
	_snapshot(body, $OldBody)
	var masks: Array[ShaderMaterial] = [_mask($OldBody, false)]
	var old_weapon := hero.get_node_or_null("WeaponSprite") as Sprite2D
	if is_instance_valid(old_weapon):
		_snapshot(old_weapon, $OldWeapon)
		masks.append(_mask($OldWeapon, false))
	if reveal.is_valid(): reveal.call()
	masks.append(_mask(body, true))
	var weapon := hero.get_node_or_null("WeaponSprite") as Sprite2D
	if is_instance_valid(weapon): masks.append(_mask(weapon, true))
	var bounds: Rect2 = body.global_transform * body.get_rect()
	bounds = bounds.merge($OldBody.global_transform * $OldBody.get_rect())
	if is_instance_valid(weapon): bounds = bounds.merge(weapon.global_transform * weapon.get_rect())
	var wipe := create_tween()
	wipe.tween_method(func(height: float):
		for material in masks: material.set_shader_parameter("cut_y", height)
	, bounds.end.y + 8.0, bounds.position.y - 8.0, 0.90)
	# 首帧先完全遮住真身，避免先闪出整个人再开始扫。
	for material in masks: material.set_shader_parameter("cut_y", bounds.end.y + 8.0)
	await wipe.finished
	$OldBody.hide()
	$OldWeapon.hide()
	_restore_materials()
	$Sparks.restart()
	$Sparks.emitting = true
	GameData.screen_shake_requested.emit(3.0, 0.14)
	await tween.finished
	queue_free()

func _restore_materials() -> void:
	for sprite in _materials:
		if is_instance_valid(sprite): sprite.material = _materials[sprite]
	_materials.clear()

func _exit_tree() -> void:
	_restore_materials()
