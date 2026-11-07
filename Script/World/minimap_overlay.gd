extends Control

var _map = null
var _navigation_error: bool = false
var _markers: Array[Dictionary] = []
var _route := PackedVector2Array()
var _route_name: String = ""
var _press_position := Vector2.ZERO
var _last_mouse := Vector2.ZERO
var _pressed: bool = false
var _dragging: bool = false
var _route_selected: bool = false
var _marker_timer: float = 0.0
var objective_text: String = ""
var _keyboard_cursor := Vector2(-1, -1)

func setup(map_container) -> void:
	_map = map_container
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func show_navigation_error() -> void:
	_navigation_error = true
	queue_redraw()

func reset_navigation() -> void:
	_keyboard_cursor = Vector2(-1, -1)
	_route.clear()
	_markers.clear()
	_route_name = ""
	_route_selected = false
	_navigation_error = false
	_pressed = false
	_dragging = false
	_marker_timer = 0.0
	objective_text = ""
	tooltip_text = "点击寻路 · 拖动地图 · 滚轮缩放"
	queue_redraw()

func _viewport_position(local_position: Vector2) -> Vector2:
	return local_position * Vector2(_map.map_viewport.size) / size

func _screen_position(world_position: Vector2) -> Vector2:
	return (_map.map_viewport.canvas_transform * world_position) * size / Vector2(_map.map_viewport.size)

func refresh_markers() -> void:
	_markers.clear()
	objective_text = ""
	if _map == null or not is_instance_valid(_map._current_map_root): return
	var map_root = _map._current_map_root
	_collect_markers(map_root)
	for target in GameData.story_map_targets:
		if not target is Dictionary: continue
		var map_id := str(target.get("map_id", ""))
		var title := str(target.get("label", target.get("target_name", "任务")))
		if not objective_text.is_empty(): objective_text += " / "
		objective_text += "任务：%s（%s）" % [title, map_id]
		if map_id != str(map_root.map_id) and map_id != str(map_root.name):
			# Show a known exit toward the objective, without inventing coordinates.
			for marker in _markers:
				if marker.get("destination", "") == map_id:
					marker["quest"] = true
			continue
		var matched := false
		for marker in _markers:
			if marker["label"] == str(target.get("target_name", "")) or marker.get("node_name", "") == str(target.get("target_name", "")):
				marker["quest"] = true
				matched = true
		if matched: continue
		var coords = target.get("position", [])
		if coords is Array and coords.size() == 2 and (coords[0] is float or coords[0] is int) and (coords[1] is float or coords[1] is int):
			_markers.append({"label": title, "position": map_root.to_global(Vector2(coords[0], coords[1])), "kind": "quest", "quest": true})
		else:
			objective_text += " · 暂无位置"
	_markers.sort_custom(func(a, b): return bool(a.get("quest", false)) and not bool(b.get("quest", false)))
	queue_redraw()

func _collect_markers(parent: Node) -> void:
	for child in parent.get_children():
		if child is Node2D and child.is_visible_in_tree():
			if "npc_name" in child and not str(child.npc_name).is_empty():
				_markers.append({"label": str(child.npc_name).trim_suffix("/"), "position": child.global_position, "kind": "npc", "node_name": str(child.name)})
			elif "teleportTo" in child and not str(child.teleportTo).is_empty():
				_markers.append({"label": str(child.teleportTo), "position": child.global_position, "kind": "portal", "destination": str(child.teleportTo), "node_name": str(child.name)})
		_collect_markers(child)

func _process(delta: float) -> void:
	if not visible: return
	_marker_timer += delta
	if _marker_timer >= 0.5:
		_marker_timer = 0
		refresh_markers()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_map.zoom_current_at(_viewport_position(event.position), 1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2)
				queue_redraw()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_dragging = false
				_press_position = event.position
				_last_mouse = event.position
			else:
				var was_pressed := _pressed
				_pressed = false
				if was_pressed and not _dragging:
					_route_selected = true
					_preview_at(event.position)
					if not _route.is_empty(): _map.navigation_requested.emit(_route[-1])
				_dragging = false
	elif event is InputEventMouseMotion:
		accept_event()
		if _pressed:
			if not _dragging and event.position.distance_to(_press_position) > 6.0:
				_dragging = true
				_map.pan_current(_viewport_position(event.position - _press_position))
			elif _dragging:
				_map.pan_current(_viewport_position(event.position - _last_mouse))
		_last_mouse = event.position
		queue_redraw()

func _preview_at(point: Vector2) -> void:
	if size.x <= 0 or size.y <= 0: return
	var map_root = _map._current_map_root
	var player = map_root.get_player_node()
	if not is_instance_valid(player): return
	var target: Vector2 = _map.map_viewport.canvas_transform.affine_inverse() * _viewport_position(point)
	var kind := "ground"
	_route_name = ""
	for marker in _markers:
		var rect: Rect2 = marker.get("hit_rect", Rect2())
		if rect.has_point(point) or _screen_position(marker["position"]).distance_to(point) <= 10:
			target = marker["position"]
			kind = marker["kind"]
			_route_name = marker["label"]
			break
	var bounds := Vector2(map_root._map_width, map_root._map_height)
	if not Rect2(Vector2.ZERO, bounds).has_point(map_root.to_local(target)):
		_route.clear()
		_navigation_error = false
		queue_redraw()
		return
	_route = player.find_approach_path(target) if kind == "npc" else player.find_navigation_path(target)
	_navigation_error = _route.is_empty()
	tooltip_text = _route_name if not _route_name.is_empty() else "点击寻路 · 拖动地图 · 滚轮缩放"
	queue_redraw()

func _draw() -> void:
	if has_focus() and _keyboard_cursor.x >= 0:
		draw_circle(_keyboard_cursor, 8, Color("ffe475"), false, 2.0)
		draw_line(_keyboard_cursor - Vector2(12, 0), _keyboard_cursor + Vector2(12, 0), Color("ffe475"), 2.0)
		draw_line(_keyboard_cursor - Vector2(0, 12), _keyboard_cursor + Vector2(0, 12), Color("ffe475"), 2.0)
	if _map == null or not is_instance_valid(_map._current_map_root): return
	var player = _map._current_map_root.get_player_node()
	if not is_instance_valid(player): return
	var font := ThemeDB.fallback_font
	var path := PackedVector2Array()
	if _route_selected and not _navigation_error:
		path = player._click_path.slice(player._click_idx)
	if not path.is_empty():
		var screen_path := PackedVector2Array([_screen_position(player.global_position)])
		for position in path: screen_path.append(_screen_position(position))
		if screen_path.size() > 1:
			draw_polyline(screen_path, Color(0.03,0.13,0.21,0.9), 5, true)
			draw_polyline(screen_path, Color("fff184"), 2.5, true)
		var end: Vector2 = screen_path[-1]
		draw_circle(end, 6, Color("ffe56b"))
		draw_string_outline(font, end + Vector2(10,5), "终点", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color("24354b"))
		draw_string(font, end + Vector2(10,5), "终点", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	for marker in _markers:
		var point := _screen_position(marker["position"])
		marker["hit_rect"] = Rect2()
		if not Rect2(Vector2.ZERO, size).grow(-8).has_point(point): continue
		var quest: bool = marker.get("quest", false)
		var color := Color("ffe475") if quest else (Color("7fe9ff") if marker["kind"] == "portal" else Color("fff5d5"))
		var label: String = marker["label"]
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		var rect := Rect2(point - Vector2(text_size.x * 0.5 + 4, 28), Vector2(text_size.x + 8, 22))
		marker["hit_rect"] = rect
		var baseline := rect.position + Vector2(4, 16)
		draw_string_outline(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color("24354b"))
		draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
	var point := _screen_position(player.global_position)
	draw_circle(point, 8.0, Color("213f62"))
	draw_arc(point, 8.0, 0, TAU, 32, Color("e5efff"), 1.5, true)
	draw_circle(point, 4.5, Color("85ffb0"))



func keyboard_move(direction: Vector2) -> void:
	if _keyboard_cursor.x < 0: _keyboard_cursor = size * 0.5
	var next := _keyboard_cursor + direction * 16.0
	if Input.is_key_pressed(KEY_SHIFT) or not Rect2(Vector2(8, 8), size - Vector2(16, 16)).has_point(next):
		_map.pan_current(_viewport_position(-direction * 32.0))
	else:
		_keyboard_cursor = next
	_last_mouse = _keyboard_cursor
	_preview_at(_keyboard_cursor)
	queue_redraw()

func keyboard_activate() -> void:
	if _keyboard_cursor.x < 0: _keyboard_cursor = size * 0.5
	_route_selected = true
	_preview_at(_keyboard_cursor)
	if not _route.is_empty(): _map.navigation_requested.emit(_route[-1])

func keyboard_zoom(factor: float) -> void:
	if _keyboard_cursor.x < 0: _keyboard_cursor = size * 0.5
	_map.zoom_current_at(_viewport_position(_keyboard_cursor), factor)
	queue_redraw()

func keyboard_page(direction: int) -> void:
	refresh_markers()
	if _markers.is_empty(): return
	var nearest := -1
	var distance := INF
	for i in _markers.size():
		var point: Vector2 = _screen_position(_markers[i]["position"])
		var d := point.distance_squared_to(_keyboard_cursor)
		if d < distance:
			distance = d
			nearest = i
	var marker: Dictionary = _markers[posmod(nearest + direction, _markers.size())]
	_keyboard_cursor = _screen_position(marker["position"])
	if not Rect2(Vector2.ZERO, size).has_point(_keyboard_cursor):
		_map.pan_current(_viewport_position(size * 0.5 - _keyboard_cursor))
		_keyboard_cursor = _screen_position(marker["position"])
	_last_mouse = _keyboard_cursor
	_preview_at(_keyboard_cursor)
	queue_redraw()
