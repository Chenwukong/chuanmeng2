extends Node2D

@export var map_path: String = "res://Script/Only/1250.map"

func _ready() -> void:
	if map_path.is_empty():
		return

	# 清理旧节点
	for c in get_children().duplicate():
		if c is Sprite2D:
			c.free()

	var loader := MapLoader.new()
	if not loader.open(map_path):
		push_error("打开地图失败")
		return

	# ★ 一次性加载所有块（只打开文件一次）
	var t := Time.get_ticks_msec()
	loader.load_all()
	print("加载耗时: %dms" % [Time.get_ticks_msec() - t])

	# 拼合为一张图
	var full := Image.create(loader.map_width, loader.map_height, false, Image.FORMAT_RGBA8)
	full.fill(Color(0, 0, 0, 0))

	var n := 0
	for id in range(loader.mapnum):
		var img := loader.get_block_image(id)
		if img == null:
			continue
		n += 1
		var col := id % loader.colnum
		var row := id / loader.colnum
		full.blit_rect(img, Rect2i(0, 0, 320, 240), Vector2i(col * 320, row * 240))

	print("拼合 %d/%d 块 → %dx%d" % [n, loader.mapnum, loader.map_width, loader.map_height])

	var tex := ImageTexture.create_from_image(full)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = true
	spr.position = Vector2(loader.map_width / 2.0, loader.map_height / 2.0)
	add_child(spr)

	# 相机居中缩放
	for c in get_children():
		if c is Camera2D:
			c.position = Vector2(loader.map_width / 2.0, loader.map_height / 2.0)
			var ws := DisplayServer.window_get_size()
			if ws.x > 0 and ws.y > 0:
				var z := min(ws.x / float(loader.map_width), ws.y / float(loader.map_height)) * 0.9
				c.zoom = Vector2(z, z)
			break
