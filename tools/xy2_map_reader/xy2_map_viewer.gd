extends Node2D

const MapReaderScript := preload("res://tools/xy2_map_reader/xy2_map_reader.gd")
const BLOCK_W := 320
const BLOCK_H := 240
const CELL_COLS := 16
const CELL_ROWS := 12

@export_file("*.map") var map_path := "res://MAP/1012.map"
@export var render_limit := 0
@export_range(1, 8, 1) var chunk_cols := 4
@export_range(1, 8, 1) var chunk_rows := 4
@export_range(0, 3, 1) var visible_margin_chunks := 1
@export_range(1, 4, 1) var chunks_per_frame := 1
@export var fit_to_window := false
@export var show_collision_cells := false

var _reader: RefCounted = MapReaderScript.new()
var _camera: Camera2D
var _status: Label
var _dragging := false
var _last_mouse := Vector2.ZERO
var _loaded_chunks: Dictionary = {}
var _queued_chunks: Dictionary = {}
var _load_queue: Array[Vector2i] = []
var _visible_chunks: Dictionary = {}
var _chunk_count_x := 0
var _chunk_count_y := 0
var _loaded_block_count := 0
var _mask_rects: Array[Rect2i] = []


func _ready() -> void:
	_camera = $Camera2D
	_status = $CanvasLayer/Status
	_camera.make_current()
	load_map(map_path)


func _process(_delta: float) -> void:
	if _reader.mapnum <= 0:
		return
	_update_visible_chunks()
	for _i in range(chunks_per_frame):
		if _load_queue.is_empty():
			break
		var chunk_key: Vector2i = _load_queue.pop_front()
		_queued_chunks.erase(chunk_key)
		if _loaded_chunks.has(chunk_key):
			continue
		_load_chunk(chunk_key)
	_unload_far_chunks()
	_update_status()


func load_map(file_path: String) -> void:
	for child in $Tiles.get_children():
		child.queue_free()
	for child in $Cells.get_children():
		child.queue_free()
	_loaded_chunks.clear()
	_queued_chunks.clear()
	_load_queue.clear()
	_visible_chunks.clear()
	_loaded_block_count = 0

	if not _reader.open_map(file_path):
		_status.text = "Map load failed: %s" % file_path
		return
	_reader.clear_image_cache()

	var info: Dictionary = _reader.get_info()
	_status.text = "Opened %s  %dx%d  blocks=%d" % [
		info.flag,
		info.width,
		info.height,
		info.mapnum,
	]

	if show_collision_cells:
		_draw_collision_cells()

	# 加载遮罩
	_load_masks()

	# 触发 _draw 绘制遮罩
	queue_redraw()

	_chunk_count_x = ceili(float(_reader.colnum) / float(chunk_cols))
	_chunk_count_y = ceili(float(_reader.rownum) / float(chunk_rows))
	_camera.position = Vector2(_reader.width, _reader.height) * 0.5
	_camera.zoom = Vector2.ONE
	var viewport_size: Vector2 = get_viewport_rect().size
	if fit_to_window and _reader.width > 0 and _reader.height > 0:
		var zoom_value: float = min(viewport_size.x / float(_reader.width), viewport_size.y / float(_reader.height)) * 0.92
		_camera.zoom = Vector2(max(zoom_value, 0.05), max(zoom_value, 0.05))
	_update_visible_chunks()
	_update_status()


func _update_visible_chunks() -> void:
	var view_size: Vector2 = get_viewport_rect().size / _camera.zoom
	var top_left: Vector2 = _camera.position - view_size * 0.5
	var bottom_right: Vector2 = _camera.position + view_size * 0.5
	var chunk_w: int = chunk_cols * BLOCK_W
	var chunk_h: int = chunk_rows * BLOCK_H
	var min_x: int = clampi(floori(top_left.x / float(chunk_w)) - visible_margin_chunks, 0, max(_chunk_count_x - 1, 0))
	var max_x: int = clampi(floori(bottom_right.x / float(chunk_w)) + visible_margin_chunks, 0, max(_chunk_count_x - 1, 0))
	var min_y: int = clampi(floori(top_left.y / float(chunk_h)) - visible_margin_chunks, 0, max(_chunk_count_y - 1, 0))
	var max_y: int = clampi(floori(bottom_right.y / float(chunk_h)) + visible_margin_chunks, 0, max(_chunk_count_y - 1, 0))

	var wanted: Dictionary = {}
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var key := Vector2i(x, y)
			wanted[key] = true
			if not _loaded_chunks.has(key) and not _queued_chunks.has(key):
				_load_queue.append(key)
				_queued_chunks[key] = true
	_visible_chunks = wanted


func _load_chunk(chunk_key: Vector2i) -> void:
	var start_col: int = chunk_key.x * chunk_cols
	var start_row: int = chunk_key.y * chunk_rows
	var cols: int = mini(chunk_cols, _reader.colnum - start_col)
	var rows: int = mini(chunk_rows, _reader.rownum - start_row)
	if cols <= 0 or rows <= 0:
		return

	var max_blocks: int = _reader.mapnum if render_limit <= 0 else min(render_limit, _reader.mapnum)
	var result: Dictionary = _reader.build_chunk_image(start_col, start_row, cols, rows, max_blocks)
	if result.is_empty():
		return
	var chunk_img: Image = result["image"] as Image
	var blocks_drawn: int = result["blocks"] as int

	if blocks_drawn == 0:
		return

	var texture: ImageTexture = ImageTexture.create_from_image(chunk_img)
	var sprite := Sprite2D.new()
	sprite.name = "Chunk_%d_%d" % [chunk_key.x, chunk_key.y]
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.position = Vector2(start_col * BLOCK_W, start_row * BLOCK_H)
	$Tiles.add_child(sprite)
	_loaded_chunks[chunk_key] = sprite
	_loaded_block_count += blocks_drawn


func _unload_far_chunks() -> void:
	for key in _loaded_chunks.keys():
		if _visible_chunks.has(key):
			continue
		var node: Node = _loaded_chunks[key]
		if is_instance_valid(node):
			node.queue_free()
		_loaded_chunks.erase(key)


func _update_status() -> void:
	_status.text = "%s  %dx%d  chunks %d/%d  queue=%d  blocks=%d" % [
		_reader.get_info().flag,
		_reader.width,
		_reader.height,
		_loaded_chunks.size(),
		_chunk_count_x * _chunk_count_y,
		_load_queue.size(),
		_loaded_block_count,
	]


func _draw_collision_cells() -> void:
	var cells: PackedByteArray = _reader.get_cells()
	if cells.is_empty():
		return

	var grid_width: int = _reader.colnum * CELL_COLS
	var grid_height: int = _reader.rownum * CELL_ROWS
	var overlay := Image.create(grid_width, grid_height, false, Image.FORMAT_RGBA8)
	overlay.fill(Color.TRANSPARENT)

	for i in range(cells.size()):
		if cells[i] != 0:
			overlay.set_pixel(i % grid_width, int(i / grid_width), Color(1.0, 0.08, 0.02, 0.42))

	var texture := ImageTexture.create_from_image(overlay)
	var sprite := Sprite2D.new()
	sprite.name = "CollisionCells"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.scale = Vector2(20, 20)
	$Cells.add_child(sprite)


func _draw() -> void:
	for r in _mask_rects:
		draw_rect(r, Color(0, 0, 0, 0.4))


func _load_masks() -> void:
	_mask_rects.clear()
	if _reader.masknum <= 0:
		return
	for i in range(_reader.masknum):
		var info: Dictionary = _reader.get_mask_info(i)
		if info.is_empty():
			continue
		_mask_rects.append(info.rect)
	print("遮罩: %d 个" % _mask_rects.size())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			_last_mouse = event.position
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom *= 1.12
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom /= 1.12
	elif event is InputEventMouseMotion and _dragging:
		var delta: Vector2 = event.position - _last_mouse
		_camera.position -= delta / _camera.zoom
		_last_mouse = event.position
