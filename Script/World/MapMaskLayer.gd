@tool
extends Node2D

signal decode_failed

var _loader: MapLoader
var _rects: Array[Rect2i] = []
var _sprites: Dictionary = {}
var _failed: Dictionary = {}
var _last_tiles := Rect2i()


func setup(loader: MapLoader) -> void:
	_loader = loader
	y_sort_enabled = true
	get_parent().y_sort_enabled = true
	for id in range(loader.mask_num):
		_rects.append(loader.get_mask_rect(id))
	_update_visible_masks()


func _process(_delta: float) -> void:
	if _loader:
		_update_visible_masks()


func _update_visible_masks() -> void:
	# Snap the view to map tiles so walking a pixel doesn't rescan every mask.
	var view := get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	var tile := Vector2(MapLoader.BLOCK_W, MapLoader.BLOCK_H)
	var first := Vector2i((view.position / tile).floor())
	var end := Vector2i((view.end / tile).ceil())
	var tiles := Rect2i(first, end - first)
	if tiles == _last_tiles:
		return
	_last_tiles = tiles
	var area := Rect2i(tiles.position * Vector2i(tile), tiles.size * Vector2i(tile))
	for id in range(_rects.size()):
		var rect := _rects[id]
		if not area.intersects(rect):
			if _sprites.has(id):
				_sprites[id].queue_free()
				_sprites.erase(id)
			continue
		if _sprites.has(id) or _failed.has(id):
			continue
		var img := _loader.get_mask_image(id)
		if img == null:
			_failed[id] = true
			push_warning("无法读取地图遮罩 %d" % id)
			decode_failed.emit()
			if not visible:
				return
			continue
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(img)
		_loader.release_mask_image(id)
		# 图片仍在原始坐标绘制，下边缘用作与人物脚底比较的排序点。
		sprite.centered = false
		sprite.position = Vector2(rect.position.x, rect.end.y)
		sprite.offset.y = -rect.size.y
		add_child(sprite)
		_sprites[id] = sprite
