@tool
extends Control

signal talent_hovered(talent: TalentNode)
signal talent_unhovered
signal talent_pressed(talent: TalentNode)
signal talent_rank_removed(talent: TalentNode)

@export var locked_line_color: Color = Color(0.36, 0.46, 0.64, 0.45)
@export var unlocked_line_color: Color = Color(0.73, 0.57, 0.28, 0.92)
@export var line_width: float = 2.0


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
	else:
		for talent in get_talents():
			talent.mouse_entered.connect(func(t := talent): talent_hovered.emit(t))
			talent.mouse_exited.connect(func(): talent_unhovered.emit())
			talent.pressed.connect(func(t := talent): talent_pressed.emit(t))
			talent.rank_removed.connect(func(t := talent): talent_rank_removed.emit(t))
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


@export var line_offset: float = 50.0


func _draw() -> void:
	for talent in get_talents():
		for requirement in talent.requirements:
			if requirement == null:
				continue

			var path := requirement.get("talent_path") as NodePath
			var required_rank := int(requirement.get("rank_required"))
			if path.is_empty():
				continue

			var from_talent := _resolve_requirement_talent(talent, path)
			if from_talent == null or not from_talent.has_method("get_rank"):
				continue
			# 跨页前置在详情中显示，不向隐藏页面绘制连线。
			if from_talent.get_parent() != self:
				continue

			var start := _talent_center(from_talent)
			var end := _talent_center(talent)
			var dir := (end - start).normalized()
			var from_radius := _edge_distance(from_talent, dir) + 7.0
			var to_radius := _edge_distance(talent, dir) + 7.0
			if start.distance_to(end) <= from_radius + to_radius: continue
			start += dir * from_radius
			end -= dir * to_radius
			var color := unlocked_line_color if from_talent.get_rank() >= required_rank else locked_line_color
			# A soft underlay and fine light core give the path depth without overpowering text.
			draw_line(start, end, Color(color, color.a * 0.14), line_width + 4.0, true)
			draw_line(start, end, color, line_width, true)
			if from_talent.get_rank() >= required_rank:
				draw_line(start, end, Color(1.0, 0.92, 0.66, 0.75), 0.7, true)
				draw_circle(start, 2.3, Color(0.95, 0.84, 0.54, 0.95), true, -1.0, true)
				draw_circle(end, 2.3, Color(0.95, 0.84, 0.54, 0.95), true, -1.0, true)


func refresh(points: int) -> void:
	for talent in get_talents():
		talent.refresh_state(points)
	queue_redraw()


func get_talents() -> Array[TalentNode]:
	var result: Array[TalentNode] = []
	for child in get_children():
		if child is TalentNode:
			result.append(child)
	return result


func _talent_center(talent: Control) -> Vector2:
	return talent.position + talent.size * 0.5


func _resolve_requirement_talent(talent: TalentNode, path: NodePath) -> Node:
	var from_page := get_node_or_null(path)
	if from_page != null:
		return from_page
	return talent.get_node_or_null(path)

func _edge_distance(talent: Control, direction: Vector2) -> float:
	# Clip to each node's actual bounds, including its TCP-derived dimensions.
	var half := talent.size * 0.5
	return minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
