extends SubViewportContainer

@export var min_zoom: float = 0.75
@export var max_zoom: float = 3.0
@export var zoom_step: float = 1.15
@export var drag_button: MouseButton = MOUSE_BUTTON_LEFT

@onready var map_viewport: SubViewport = $MapViewport
@onready var map_content: Node2D = $MapViewport/MapContent

var _dragging := false
var _last_mouse_position := Vector2.ZERO
var _content_bounds := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_content_bounds()
	_clamp_content_position()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == drag_button:
			_dragging = mouse_button.pressed
			_last_mouse_position = mouse_button.position
			accept_event()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mouse_button.position, zoom_step)
			accept_event()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mouse_button.position, 1.0 / zoom_step)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mouse_motion := event as InputEventMouseMotion
		map_content.position += mouse_motion.position - _last_mouse_position
		_last_mouse_position = mouse_motion.position
		_clamp_content_position()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_clamp_content_position()


func _zoom_at(view_position: Vector2, zoom_factor: float) -> void:
	var old_scale := map_content.scale.x
	var new_scale := clampf(old_scale * zoom_factor, min_zoom, max_zoom)
	if is_equal_approx(old_scale, new_scale):
		return

	var content_point := (view_position - map_content.position) / old_scale
	map_content.scale = Vector2(new_scale, new_scale)
	map_content.position = view_position - content_point * new_scale
	_clamp_content_position()


func _update_content_bounds() -> void:
	var has_bounds := false
	_content_bounds = Rect2()

	for child in map_content.get_children():
		if not child is CanvasItem:
			continue

		var canvas_item := child as CanvasItem
		if not canvas_item.visible and child.name != "MapBounds":
			continue

		var child_rect := _get_child_rect(child)
		if child_rect.size == Vector2.ZERO:
			continue

		_content_bounds = child_rect if not has_bounds else _content_bounds.merge(child_rect)
		has_bounds = true

	if not has_bounds:
		_content_bounds = Rect2(Vector2.ZERO, Vector2.ONE)


func _get_child_rect(child: Node) -> Rect2:
	if child is Control:
		var control := child as Control
		return Rect2(control.position, control.size * control.scale)
	if child is Sprite2D:
		var sprite := child as Sprite2D
		var texture := sprite.texture
		if texture == null:
			return Rect2(sprite.position, Vector2.ZERO)
		var size := texture.get_size() * sprite.scale
		return Rect2(sprite.position - size * 0.5, size)
	if child is Node2D:
		return Rect2((child as Node2D).position, Vector2.ZERO)

	return Rect2()


func _clamp_content_position() -> void:
	if map_content == null:
		return

	var view_size := Vector2(map_viewport.size)
	var scaled_bounds := Rect2(
		_content_bounds.position * map_content.scale,
		_content_bounds.size * map_content.scale
	)

	var min_position := view_size - scaled_bounds.end
	var max_position := -scaled_bounds.position
	var next_position := map_content.position

	if scaled_bounds.size.x <= view_size.x:
		next_position.x = (view_size.x - scaled_bounds.size.x) * 0.5 - scaled_bounds.position.x
	else:
		next_position.x = clampf(next_position.x, min_position.x, max_position.x)

	if scaled_bounds.size.y <= view_size.y:
		next_position.y = (view_size.y - scaled_bounds.size.y) * 0.5 - scaled_bounds.position.y
	else:
		next_position.y = clampf(next_position.y, min_position.y, max_position.y)

	map_content.position = next_position
