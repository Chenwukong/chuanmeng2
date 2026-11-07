extends SubViewportContainer

@export var min_zoom: float = 0.75
@export var max_zoom: float = 3.0
@export var zoom_step: float = 1.15
@export var drag_button: MouseButton = MOUSE_BUTTON_LEFT

@onready var map_viewport: SubViewport = $MapViewport
@onready var map_content: Node2D = $MapViewport/MapContent

var _dragging = false
var _last_mouse_position = Vector2.ZERO
var _content_bounds = Rect2()
var _current_map_mode: bool = false  # true=当前地图, false=世界地图
signal navigation_requested(world_position: Vector2)

var _current_map_root: Node2D = null
@onready var _minimap_overlay: Control = $"../MinimapOverlay"
var _minimap_preview: Node2D = null
var _player_visuals: Array[Dictionary] = []
var _current_fit_zoom: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_minimap_overlay.setup(self)
	if _current_map_mode:
		_switch_to_current()
	else:
		_update_content_bounds()
		_clamp_content_position()




func switch_to_current() -> void:
	_current_map_mode = true
	_switch_to_current()


func _find_live_map_root() -> Node2D:
	var scene = get_tree().current_scene
	if scene == null: return null
	for child in scene.get_children():
		if child is Node2D and child.has_method("get_player_node") and not child.is_queued_for_deletion() and child.is_node_ready():
			return child
	return null


func _switch_to_current() -> void:
	_dragging = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	map_content.visible = false
	map_viewport.gui_disable_input = true
	_current_map_root = _find_live_map_root()
	_clear_minimap_preview()
	_minimap_overlay.reset_navigation()
	if _current_map_root == null:
		_minimap_overlay.hide()
		return
	# Keep the viewport's own World2D: preview visuals never inherit the live night tint.
	_minimap_preview = _copy_minimap_visual(_current_map_root)
	map_viewport.add_child(_minimap_preview)
	_minimap_preview.global_transform = _current_map_root.global_transform
	var cam = map_viewport.get_node_or_null("_MinimapCam") as Camera2D
	if cam == null:
		cam = Camera2D.new()
		cam.name = "_MinimapCam"
		map_viewport.add_child(cam)
	cam.enabled = true
	_fit_current_map()
	_minimap_overlay.refresh_markers()
	_minimap_overlay.show()


func _fit_current_map() -> void:
	if not is_instance_valid(_current_map_root): return
	var cam = map_viewport.get_node_or_null("_MinimapCam") as Camera2D
	if cam == null: return
	# 地图宽高已经是像素，不再乘障碍网格尺寸。
	var map_px = Vector2(_current_map_root._map_width, _current_map_root._map_height)
	if map_px.x <= 0 or map_px.y <= 0:
		map_px = Vector2(_current_map_root.obs_size) * _current_map_root.obs_cp
	if map_px.x <= 0 or map_px.y <= 0: return
	var vp_size = Vector2(map_viewport.size)
	var fit_zoom: float = minf(vp_size.x / map_px.x, vp_size.y / map_px.y) * 0.94
	_current_fit_zoom = fit_zoom
	cam.zoom = Vector2.ONE * fit_zoom
	cam.global_position = _current_map_root.to_global(map_px * 0.5)
	cam.position_smoothing_enabled = false
	cam.make_current()
	cam.force_update_scroll()


func zoom_current_at(view_position: Vector2, factor: float) -> void:
	var cam = map_viewport.get_node_or_null("_MinimapCam") as Camera2D
	if cam == null: return
	var before: Vector2 = map_viewport.canvas_transform.affine_inverse() * view_position
	var zoom_value := clampf(cam.zoom.x * factor, _current_fit_zoom, _current_fit_zoom * 6.0)
	cam.zoom = Vector2.ONE * zoom_value
	cam.force_update_scroll()
	var after: Vector2 = map_viewport.canvas_transform.affine_inverse() * view_position
	cam.global_position += before - after
	_clamp_current_camera()

func pan_current(delta_pixels: Vector2) -> void:
	var cam = map_viewport.get_node_or_null("_MinimapCam") as Camera2D
	if cam == null: return
	cam.global_position -= delta_pixels / cam.zoom
	_clamp_current_camera()

func _clamp_current_camera() -> void:
	var cam = map_viewport.get_node_or_null("_MinimapCam") as Camera2D
	if cam == null or not is_instance_valid(_current_map_root): return
	var map_size := Vector2(_current_map_root._map_width, _current_map_root._map_height)
	if map_size.x <= 0 or map_size.y <= 0: map_size = Vector2(_current_map_root.obs_size) * _current_map_root.obs_cp
	var half_view: Vector2 = Vector2(map_viewport.size) / cam.zoom * 0.5
	var center: Vector2 = _current_map_root.to_local(cam.global_position)
	for axis in 2:
		center[axis] = map_size[axis] * 0.5 if half_view[axis] * 2 >= map_size[axis] else clampf(center[axis], half_view[axis], map_size[axis] - half_view[axis])
	cam.global_position = _current_map_root.to_global(center)
	cam.force_update_scroll()

func _process(_delta: float) -> void:
	if _current_map_mode:
		var live_map := _find_live_map_root()
		if not is_instance_valid(_current_map_root):
			if live_map != null or is_instance_valid(_minimap_preview):
				_switch_to_current()
		elif live_map != _current_map_root:
			_switch_to_current()
	if _current_map_mode and is_instance_valid(_minimap_overlay):
		for pair in _player_visuals:
			var source = pair.source
			var copy = pair.copy
			if not is_instance_valid(source) or not is_instance_valid(copy): continue
			copy.transform = source.transform
			copy.visible = source.visible
			copy.modulate = source.modulate
			copy.self_modulate = source.self_modulate
			if source is Sprite2D and copy is Sprite2D:
				copy.texture = source.texture
				copy.hframes = source.hframes
				copy.vframes = source.vframes
				copy.frame = source.frame
				copy.offset = source.offset
				copy.region_enabled = source.region_enabled
				copy.region_rect = source.region_rect
				copy.flip_h = source.flip_h
				copy.flip_v = source.flip_v
			elif source is AnimatedSprite2D and copy is AnimatedSprite2D:
				copy.animation = source.animation
				copy.frame = source.frame
		_minimap_overlay.queue_redraw()


func switch_to_world() -> void:
	_current_map_mode = false
	_dragging = false
	if is_instance_valid(_minimap_overlay): _minimap_overlay.hide()
	map_viewport.gui_disable_input = false
	_clear_minimap_preview()
	# 移除 minimap 相机
	var cam = map_viewport.get_node_or_null("_MinimapCam")
	if cam:
		cam.enabled = false
		map_viewport.remove_child(cam)
		cam.queue_free()
	# 显示世界地图内容
	map_content.visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_content_bounds()
	_clamp_content_position()


func _clear_minimap_preview() -> void:
	_player_visuals.clear()
	if is_instance_valid(_minimap_preview):
		map_viewport.remove_child(_minimap_preview)
		_minimap_preview.queue_free()
	_minimap_preview = null


## Copy only rendering data; no gameplay scripts, cameras, collisions or timers.
## Textures remain shared, and only the two layers tinted by set_day_tint are reset.
func _copy_minimap_visual(source: Node2D, follows_player: bool = false) -> Node2D:
	follows_player = follows_player or source == _current_map_root.get_player_node()
	var copy: Node2D
	if source is Sprite2D:
		var sprite := Sprite2D.new()
		sprite.texture = source.texture
		sprite.centered = source.centered
		sprite.offset = source.offset
		sprite.hframes = source.hframes
		sprite.vframes = source.vframes
		sprite.frame = source.frame
		sprite.flip_h = source.flip_h
		sprite.flip_v = source.flip_v
		sprite.region_enabled = source.region_enabled
		sprite.region_rect = source.region_rect
		sprite.region_filter_clip_enabled = source.region_filter_clip_enabled
		copy = sprite
	elif source is AnimatedSprite2D:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = source.sprite_frames
		sprite.animation = source.animation
		sprite.frame = source.frame
		sprite.centered = source.centered
		sprite.offset = source.offset
		sprite.flip_h = source.flip_h
		sprite.flip_v = source.flip_v
		copy = sprite
	else:
		copy = Node2D.new()
	copy.name = source.name
	copy.transform = source.transform
	copy.z_index = source.z_index
	copy.z_as_relative = source.z_as_relative
	copy.y_sort_enabled = source.y_sort_enabled
	copy.show_behind_parent = source.show_behind_parent
	copy.texture_filter = source.texture_filter
	copy.modulate = source.modulate
	copy.self_modulate = source.self_modulate
	copy.visible = source.visible
	if follows_player:
		_player_visuals.append({"source": source, "copy": copy})
	if source in [_current_map_root._map_layer, _current_map_root._mask_layer, _current_map_root.get_node_or_null("BgShadow")]:
		copy.modulate = Color.WHITE
	for child in source.get_children():
		if child is Node2D and (child.visible or follows_player) and not child is Camera2D:
			copy.add_child(_copy_minimap_visual(child, follows_player))
	return copy


func _gui_input(event: InputEvent) -> void:
	if _current_map_mode:
		accept_event()
		return
	if event is InputEventMouseButton:
		var mouse_button = event as InputEventMouseButton
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
		var mouse_motion = event as InputEventMouseMotion
		map_content.position += mouse_motion.position - _last_mouse_position
		_last_mouse_position = mouse_motion.position
		_clamp_content_position()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		if _current_map_mode:
			_fit_current_map.call_deferred()
		else:
			_clamp_content_position()


func _zoom_at(view_position: Vector2, zoom_factor: float) -> void:
	var old_scale = map_content.scale.x
	var new_scale = clampf(old_scale * zoom_factor, min_zoom, max_zoom)
	if is_equal_approx(old_scale, new_scale):
		return

	var content_point = (view_position - map_content.position) / old_scale
	map_content.scale = Vector2(new_scale, new_scale)
	map_content.position = view_position - content_point * new_scale
	_clamp_content_position()


func _update_content_bounds() -> void:
	var has_bounds = false
	_content_bounds = Rect2()

	for child in map_content.get_children():
		if not child is CanvasItem:
			continue

		var canvas_item = child as CanvasItem
		if not canvas_item.visible and child.name != "MapBounds":
			continue

		var child_rect = _get_child_rect(child)
		if child_rect.size == Vector2.ZERO:
			continue

		_content_bounds = child_rect if not has_bounds else _content_bounds.merge(child_rect)
		has_bounds = true

	if not has_bounds:
		_content_bounds = Rect2(Vector2.ZERO, Vector2.ONE)


func _get_child_rect(child: Node) -> Rect2:
	if child is Control:
		var control = child as Control
		return Rect2(control.position, control.size * control.scale)
	if child is Sprite2D:
		var sprite = child as Sprite2D
		var texture = sprite.texture
		if texture == null:
			return Rect2(sprite.position, Vector2.ZERO)
		var size = texture.get_size() * sprite.scale
		return Rect2(sprite.position - size * 0.5, size)
	if child is Node2D:
		return Rect2((child as Node2D).position, Vector2.ZERO)

	return Rect2()


func _clamp_content_position() -> void:
	if map_content == null:
		return

	var view_size = Vector2(map_viewport.size)
	var scaled_bounds = Rect2(
		_content_bounds.position * map_content.scale,
		_content_bounds.size * map_content.scale
	)

	var min_position = view_size - scaled_bounds.end
	var max_position = -scaled_bounds.position
	var next_position = map_content.position

	if scaled_bounds.size.x <= view_size.x:
		next_position.x = (view_size.x - scaled_bounds.size.x) * 0.5 - scaled_bounds.position.x
	else:
		next_position.x = clampf(next_position.x, min_position.x, max_position.x)

	if scaled_bounds.size.y <= view_size.y:
		next_position.y = (view_size.y - scaled_bounds.size.y) * 0.5 - scaled_bounds.position.y
	else:
		next_position.y = clampf(next_position.y, min_position.y, max_position.y)

	map_content.position = next_position


func keyboard_move(direction: Vector2) -> void:
	if _current_map_mode: return
	map_content.position -= direction * 40.0
	_clamp_content_position()

func keyboard_zoom(factor: float) -> void:
	if _current_map_mode: return
	_zoom_at(size * 0.5, factor)
