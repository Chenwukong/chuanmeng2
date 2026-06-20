@tool
extends Node2D

const MapConnectionScript := preload("res://Script/Only/map_connection.gd")

@export var background_texture: Texture2D
@export var background_rect: Rect2 = Rect2(Vector2(-300, -240), Vector2(1200, 960))
@export var background_color: Color = Color(0.95, 0.9, 0.72, 1.0)
@export var connections: Array[Resource] = []
@export var line_color: Color = Color(0, 0, 0, 1)
@export var line_width: float = 1.0


func _ready() -> void:
	child_order_changed.connect(queue_redraw)
	for child in get_children():
		if child is Control:
			var control := child as Control
			control.resized.connect(queue_redraw)
			control.item_rect_changed.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if background_texture != null:
		draw_texture_rect(background_texture, background_rect, false)
	else:
		draw_rect(background_rect, background_color, true)

	var pairs := connections
	if pairs.is_empty() and has_node("长安") and has_node("建邺"):
		var default_connection := MapConnectionScript.new()
		default_connection.from_place = NodePath("长安")
		default_connection.to_place = NodePath("建邺")
		pairs = [default_connection]

	for connection in pairs:
		if connection == null:
			continue

		var from_place := connection.get("from_place") as NodePath
		var to_place := connection.get("to_place") as NodePath
		if from_place.is_empty() or to_place.is_empty():
			continue
		if not has_node(from_place) or not has_node(to_place):
			continue

		var from_node := get_node(from_place)
		var to_node := get_node(to_place)

		var start := _place_center(from_node)
		var end := _place_center(to_node)

		var dir := (end - start).normalized()

		start += dir * _node_radius(from_node)
		end -= dir * _node_radius(to_node)

		draw_line(start, end, line_color, line_width, true)


func _place_center(place: Node) -> Vector2:
	if place is Control:
		var control := place as Control
		return control.position + control.size * control.scale * 0.5
	if place is Node2D:
		return (place as Node2D).position
	return Vector2.ZERO

func _node_radius(node: Node) -> float:
	if node is Control:
		var control := node as Control
		return max(control.size.x, control.size.y) * 0.5 + 4.0

	return 1.0
