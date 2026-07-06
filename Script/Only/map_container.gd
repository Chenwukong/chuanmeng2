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
var _player_marker: Sprite2D = null
var _minimap_vp: SubViewport = null
var _saved_world: World2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _current_map_mode:
		_switch_to_current()
	else:
		_update_content_bounds()
		_clamp_content_position()




func switch_to_current() -> void:
	_current_map_mode = true
	_switch_to_current()


func _switch_to_current() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_content.visible = false
	if _saved_world == null:
		_saved_world = map_viewport.world_2d
	var root_scene = get_tree().current_scene
	var map_root = root_scene.get_node_or_null("MapRoot") as Node2D
	if map_root:
		map_viewport.world_2d = map_root.get_world_2d()
	else:
		# fallback: 直接渲染主场景
		map_viewport.world_2d = root_scene.get_world_2d()
	# 俯瞰相机：自动缩放到刚好铺满视口
	var cam = map_viewport.get_node_or_null("_MinimapCam") as Camera2D
	if cam == null:
		cam = Camera2D.new()
		cam.name = "_MinimapCam"
		map_viewport.add_child(cam)
	var vp_size = Vector2(map_viewport.size)
	if map_root and map_root._map_width > 0:
		var map_px = Vector2(map_root._map_width * map_root.obs_cp, map_root._map_height * map_root.obs_cp)
		var z = max(map_px.x / vp_size.x, map_px.y / vp_size.y)
		cam.zoom = Vector2(z, z)
		cam.global_position = map_px * 0.5  # 相机居中
	else:
		cam.zoom = Vector2(4, 4)
		var walker = root_scene.get_node_or_null("MapWalker")
		if walker:
			cam.global_position = walker.global_position


func _process(_delta: float) -> void:
	pass  # 当前地图模式相机居中不动


func switch_to_world() -> void:
	_current_map_mode = false
	# 还原 world_2d
	if _saved_world:
		map_viewport.world_2d = _saved_world
		_saved_world = null
	# 移除 minimap 相机
	var cam = map_viewport.get_node_or_null("_MinimapCam")
	if cam: cam.queue_free()
	# 显示世界地图内容
	map_content.visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_content_bounds()
	_clamp_content_position()


func _restore_world_map_world() -> void:
	if _saved_world:
		map_viewport.world_2d = _saved_world
		_saved_world = null


func create_spot_texture() -> Texture2D:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	if img == null: return null
	img.fill(Color(0, 0, 0, 0))
	for x in range(16):
		for y in range(16):
			var dist = Vector2(x - 7.5, y - 7.5).length()
			if dist < 6:
				img.set_pixel(x, y, Color(1, 0.3, 0.2, 0.8))
	return ImageTexture.create_from_image(img)


func _update_player_position() -> void:
	if not _current_map_mode or _player_marker == null: return
	var player = get_tree().current_scene.get_node_or_null("MapWalker")
	if player == null: return
	var map_root = get_tree().current_scene.get_node_or_null("MapRoot")
	if map_root == null: return
	_player_marker.position = player.position / 20.0  # scale to map coords
	_player_marker.visible = true


func _gui_input(event: InputEvent) -> void:
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
