# MapViewerV2.gd — 地图查看器
# 用旧 MapLoader 加载图块（稳定），MapDataV2 只用于障碍物和导航

extends Node2D

const MaskLayer := preload("res://Script/World/MapMaskLayer.gd")

@export var map_path: String = "res://MAP/1001.map"
@export var show_obstacles: bool = true

var _loader: MapLoader = null
var obs_grid: PackedByteArray = PackedByteArray()
var obs_size: Vector2i = Vector2i.ZERO
var obs_cp: int = 20
var astar_grid: AStarGrid2D = null
var astar_cell_size: int = 20
var _map_width: int = 0
var _map_height: int = 0
var _colnum: int = 0
var _rownum: int = 0
var _mapnum: int = 0


func _ready() -> void:
	if map_path.is_empty(): return

	_loader = MapLoader.new()
	if not _loader.open(map_path): return
	_loader.load_all()

	var info: Dictionary = _loader.get_info()
	_map_width = info.width; _map_height = info.height
	_colnum = info.colnum; _rownum = info.rownum; _mapnum = info.mapnum

	_render_base_map()
	if _loader.mask_num > 0:
		var masks := MaskLayer.new()
		add_child(masks)
		masks.setup(_loader)

	# 构建障碍物和A*网格
	var m2 := MapDataV2.new()
	m2.open(map_path)
	m2.load_obstacles()
	var gs := m2.get_obstacle_size()
	var g := m2.get_obstacle_grid()
	print("障碍物网格: %dx%d, 阻挡格: %d" % [gs.x, gs.y, _count_solid(g, gs)])
	# 存到公开变量让 MapWalker 直接读
	obs_grid = g
	obs_size = gs
	obs_cp = 20
	if show_obstacles: _render_obstacle_overlay(g, gs)

	# AStarGrid2D 用于鼠标点击寻路（存到公开变量让 MapWalker 延迟读取）
	astar_grid = AStarGrid2D.new()
	astar_cell_size = 20
	astar_grid.region = Rect2i(0, 0, gs.x, gs.y)
	astar_grid.cell_size = Vector2i(20, 20)
	astar_grid.update()
	for y in gs.y:
		for x in gs.x:
			if g[y * gs.x + x] != 0:
				astar_grid.set_point_solid(Vector2i(x, y), true)



func _render_base_map() -> void:
	# 分块渲染 — 每行一个条带，避免超 GPU 纹理上限
	const BW := 320; const BH := 240
	var rows_per_strip := maxi(1, 16384 / _map_width)
	for row0 in range(0, _rownum, rows_per_strip):
		var rh := mini(rows_per_strip, _rownum - row0) * BH
		var strip := Image.create(_map_width, rh, false, Image.FORMAT_RGBA8)
		strip.fill(Color(0,0,0,0))
		for rid in range(row0, row0 + rows_per_strip):
			if rid >= _rownum: break
			for cid in range(_colnum):
				var bid := rid * _colnum + cid
				var img: Image = _loader.get_block_image(bid)
				if img == null: continue
				if img.get_format() != Image.FORMAT_RGBA8:
					img.convert(Image.FORMAT_RGBA8)
				strip.blit_rect(img, Rect2i(0,0,img.get_width(),img.get_height()),
					Vector2i(cid*BW, (rid-row0)*BH))
		var s := Sprite2D.new()
		s.texture = ImageTexture.create_from_image(strip)
		s.centered = false
		s.position = Vector2(0, row0 * BH)
		s.z_index = -10
		s.name = "MapStrip_%d" % row0
		add_child(s)


func _render_obstacle_overlay(_g: PackedByteArray, _gs: Vector2i) -> void:
	var cp := 20
	var mw := _gs.x * cp; var mh := _gs.y * cp
	var img := Image.create(mw, mh, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y in _gs.y:
		for x in _gs.x:
			if _g[y*_gs.x+x] != 0:
				for py in cp: for px in cp:
					img.set_pixel(x*cp+px, y*cp+py, Color(0,0,1,0.35))
	var c := Node2D.new(); c.name = "ObstacleLayer"; c.z_index = -5; add_child(c)
	var s := Sprite2D.new(); s.texture = ImageTexture.create_from_image(img)
	s.centered = false; c.add_child(s)


func _count_solid(g: PackedByteArray, gs: Vector2i) -> int:
	var n := 0
	for i in g.size(): if g[i] != 0: n += 1
	return n


func _setup_camera() -> void:
	for c in get_children():
		if c is Camera2D:
			c.position = Vector2(_map_width/2.0, _map_height/2.0)
			var ws := DisplayServer.window_get_size()
			if ws.x > 0:
				c.zoom = Vector2.ONE * min(ws.x/float(_map_width), ws.y/float(_map_height)) * 0.9
			return

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_O: _toggle_child("ObstacleLayer")

func _toggle_child(cname: String) -> void:
	for c in get_children():
		if c.name == cname:
			c.visible = not c.visible
			return
