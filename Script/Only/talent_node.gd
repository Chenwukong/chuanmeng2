@tool
class_name TalentNode
extends Button

signal rank_removed

@export var talent_id: String = ""
@export var talent_name: String = ""
@export_multiline var description: String = ""
@export_range(1, 20, 1) var max_rank: int = 1
@export var requirements: Array[Resource] = []

var rank: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(126, 70)
	size = custom_minimum_size
	# 去掉默认灰色背景
	var transparent_bg := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", transparent_bg)
	add_theme_stylebox_override("hover", transparent_bg)
	add_theme_stylebox_override("pressed", transparent_bg)
	add_theme_stylebox_override("disabled", transparent_bg)
	add_theme_stylebox_override("focus", transparent_bg)
	# 黑字
	add_theme_color_override("font_color", Color.BLACK)
	add_theme_color_override("font_hover_color", Color.BLACK)
	add_theme_color_override("font_pressed_color", Color.BLACK)
	add_theme_color_override("font_disabled_color", Color.BLACK)
	add_theme_color_override("font_focus_color", Color.BLACK)
	# 右键扣点
	gui_input.connect(_on_gui_input)
	# 没有天赋点背景则自动创建
	var has_bg := false
	for c in get_children():
		if c.name.begins_with("天赋点背景"):
			has_bg = true
			break
	if not has_bg:
		var bg_scene := load("res://scenes/tcp_sprite.tscn")
		var bg = bg_scene.instantiate()
		bg.name = "天赋点背景"
		add_child(bg)
		move_child(bg, 0)
	# 按钮尺寸覆盖背景 Sprite
	var bg: Node2D = null
	for c in get_children():
		if c.name.begins_with("天赋点背景") and c is Sprite2D:
			bg = c
			break
	if bg and bg is Sprite2D:
		var tex_size := (bg as Sprite2D).get_rect().size * bg.scale
		custom_minimum_size = Vector2(max(126, tex_size.x + 10), max(70, tex_size.y + 10))
		size = custom_minimum_size
	_update_text()


func can_upgrade(points: int) -> bool:
	if points <= 0:
		return false
	if rank >= max_rank:
		return false
	return requirements_met()


func requirements_met() -> bool:
	for requirement in requirements:
		if requirement == null:
			continue

		var path: NodePath = requirement.talent_path
		var rr: int = maxi(1, requirement.rank_required)
		if path.is_empty():
			continue

		var target := _resolve_requirement_talent(path)
		if target == null or not target.has_method("get_rank"):
			return false
		if target.get_rank() < rr:
			return false

	return true


func add_rank() -> void:
	rank = mini(rank + 1, max_rank)
	GameData.set_talent_rank(talent_id, rank)
	_update_text()
	_spawn_float_icon()
	# 音效
	_play_upgrade_sound()
	# 背景缩放动画（查找任意 天赋点背景* 子节点）
	var bg: Node2D = null
	for c in get_children():
		if c.name.begins_with("天赋点背景") and c is Node2D:
			bg = c
			break
	if bg:
		var orig_bg_scale := bg.scale
		var orig_self_scale := scale
		var tw := bg.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD).set_parallel(true)
		tw.tween_property(bg, "scale", orig_bg_scale * 1.2, 0.1)
		tw.tween_property(self, "scale", orig_self_scale * 1.15, 0.1)
		tw.tween_callback(func():
			var tw2 := bg.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD).set_parallel(true)
			tw2.tween_property(bg, "scale", orig_bg_scale, 0.1)
			tw2.tween_property(self, "scale", orig_self_scale, 0.1)
		)


func remove_rank() -> void:
	if rank <= 0: return
	# 检查是否有依赖此天赋的其他天赋（且已加点），新 rank 会不满足需求
	var new_rank = rank - 1
	if not _can_safely_remove_to(new_rank):
		return
	rank = new_rank
	GameData.set_talent_rank(talent_id, rank)
	_update_text()

## 检查降到 new_rank 后是否会让依赖天赋失效
func _can_safely_remove_to(target_rank: int) -> bool:
	var talent_root = get_parent()
	while talent_root and not talent_root.has_method("_get_all_talent_nodes"):
		talent_root = talent_root.get_parent()
	if talent_root == null:
		return true  # 找不到根，允许
	var all_nodes: Array = talent_root._get_all_talent_nodes()
	for node in all_nodes:
		if node == self or node.rank == 0:
			continue
		for req in node.requirements:
			if req == null: continue
			var path: NodePath = req.talent_path
			var rr: int = req.rank_required
			if path.is_empty(): continue
			var target: TalentNode = node._resolve_requirement_talent(path)
			if target == self and rr > target_rank:
				return false  # 有依赖天赋需要更高 rank
	return true

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if rank > 0:
			remove_rank()
			rank_removed.emit()
			_play_cancel_sound()


func _spawn_float_icon() -> void:
	var icon := $"../../../天赋点图标" as Sprite2D
	if icon == null:
		return
	
	var dup := Sprite2D.new()
	dup.texture = icon.texture
	
	dup.centered = icon.centered
	dup.offset = icon.offset
	dup.scale = icon.scale
	dup.modulate = Color(1, 1, 1, 0.35)
	dup.global_position = icon.global_position + Vector2(0, -15)
	dup.z_index = 10
	$"../../..".add_child(dup)
	var tw := dup.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(dup, "position:y", -60.0, 0.7).as_relative()
	tw.parallel().tween_property(dup, "modulate:a", 0.0, 0.7)
	tw.tween_callback(dup.queue_free)


func refresh_state(points: int) -> void:
	disabled = not can_upgrade(points)
	if rank >= max_rank:
		modulate = Color(1.0, 0.86, 0.38, 1.0)
	elif requirements_met():
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		modulate = Color(0.48, 0.48, 0.48, 1.0)
	_update_text()


func get_rank() -> int:
	return rank


func get_detail_text() -> String:
	var requirement_text := "无"
	if not requirements.is_empty():
		var parts: Array[String] = []
		for requirement in requirements:
			if requirement == null:
				continue
			var path: NodePath = requirement.talent_path
			var rr: int = maxi(1, requirement.rank_required)
			if path.is_empty():
				continue
			var target := _resolve_requirement_talent(path)
			var target_name := str(path)
			if target != null and "talent_name" in target:
				target_name = target.talent_name
			parts.append("%s %d级" % [target_name, rr])
		if not parts.is_empty():
			requirement_text = "、".join(parts)

	return "%s\n\n%s\n\n等级：%d/%d\n前置：%s\n\n点击消耗 1 点天赋点升级。" % [
		talent_name,
		description,
		rank,
		max_rank,
		requirement_text,
	]


func _update_text() -> void:
	text = "%s\n%d/%d" % [talent_name, rank, max_rank]


func _resolve_requirement_talent(path: NodePath) -> Node:
	var from_parent := get_parent().get_node_or_null(path)
	if from_parent != null:
		return from_parent
	return get_node_or_null(path)

func _play_upgrade_sound() -> void:
	var snd := AudioStreamPlayer.new()
	snd.stream = load("res://Audio/SE/001-System01.ogg")
	snd.bus = "SFX"
	add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)

func _play_cancel_sound() -> void:
	var snd := AudioStreamPlayer.new()
	snd.stream = load("res://Audio/SE/003-System03.ogg")
	snd.bus = "SFX"
	add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)
