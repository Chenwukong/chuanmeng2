extends Sprite2D
## Loads just the tiles needed by a fixed shot, in the map's native coordinates.

@export_file("*.map") var map_path: String
@export var shot_bounds: Rect2i


func _ready() -> void:
	var loader := MapLoader.new()
	if not loader.open(map_path):
		push_error("演出地图无法打开：" + map_path)
		return
	var info := loader.get_info()
	var bounds := shot_bounds.intersection(Rect2i(0, 0, info.width, info.height))
	if not bounds.has_area():
		push_error("演出镜头超出地图范围：" + map_path)
		return
	loader.preload_all_raw()
	var image := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	var tile := Vector2i(MapLoader.BLOCK_W, MapLoader.BLOCK_H)
	var first := bounds.position / tile
	var last := (bounds.end - Vector2i.ONE) / tile
	for row in range(first.y, last.y + 1):
		for column in range(first.x, last.x + 1):
			var block := loader.decode_raw(row * int(info.colnum) + column)
			if block == null: continue
			block.convert(Image.FORMAT_RGBA8)
			var origin := Vector2i(column, row) * tile
			var overlap := bounds.intersection(Rect2i(origin, block.get_size()))
			image.blit_rect(block, Rect2i(overlap.position - origin, overlap.size), overlap.position - bounds.position)
	texture = ImageTexture.create_from_image(image)
	position = Vector2(bounds.position)
	var masks = get_node_or_null("../MapMasks")
	if masks != null:
		masks.setup(loader)
