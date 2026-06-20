@tool
extends Control

signal talent_hovered(talent: TalentNode)
signal talent_pressed(talent: TalentNode)

@export var locked_line_color: Color = Color(0.28, 0.28, 0.28, 1.0)
@export var unlocked_line_color: Color = Color(0.92, 0.72, 0.28, 1.0)
@export var line_width: float = 4.0


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
	else:
		for talent in get_talents():
			talent.mouse_entered.connect(func(t := talent): talent_hovered.emit(t))
			talent.pressed.connect(func(t := talent): talent_pressed.emit(t))
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


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

			var start := _talent_center(from_talent)
			var end := _talent_center(talent)
			var color := unlocked_line_color if from_talent.get_rank() >= required_rank else locked_line_color
			draw_line(start, end, color, line_width, true)


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
