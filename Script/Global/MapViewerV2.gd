# MapViewerV2.gd — 地图查看器
# 用旧 MapLoader 加载图块（稳定），MapDataV2 只用于障碍物和导航

extends Node2D

@export var map_path: String = "res://MAP/1001.map"
@export var player_spawn_px: Vector2 = Vector2(2800, 2880)
@export var show_obstacles: bool = true

var _loader: MapLoader = null
var _player: Node2D = null
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
	_load_mask_rects()

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

	_build_player(g, gs)


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
		s.name = "MapStrip_%d" % row0
		add_child(s)


var _mask_rects: Array = []   # Rect2i 数组

func _load_mask_rects() -> void:
	var m := MapDataV2.new()
	if not m.open(map_path): return
	if m.mask_count <= 0: print("遮罩矩形: 0 个"); return

	var f := FileAccess.open(map_path, FileAccess.READ)
	if f == null: return
	for mid in range(m.mask_count):
		var off := m._mask_offsets[mid]; f.seek(off)
		var rx:=f.get_32(); var ry:=f.get_32()
		var rw:=f.get_32(); var rh:=f.get_32()
		var _ds:=f.get_32()  # skip data_size
		if rw>0 and rh>0:
			_mask_rects.append(Rect2i(rx, ry, rw, rh))
	f.close()
	print("遮罩矩形: %d 个" % _mask_rects.size())


func _process(_delta: float) -> void:
	if _mask_rects.is_empty() or _player == null: return
	var spr: Sprite2D = _player.get_node_or_null("Sprite2D") as Sprite2D
	if spr == null: return
	var pos: Vector2 = _player.global_position
	var player_rect := Rect2i(int(pos.x)-24, int(pos.y)-48, 48, 96)
	var overlapped := false
	for _r in _mask_rects:
		var r: Rect2i = _r
		if r.intersects(player_rect):
			overlapped = true
			break
	spr.modulate.a = 0.35 if overlapped else 1.0


func _build_player(g: PackedByteArray, gs: Vector2i) -> void:
	var cp := 20
	var sx: int = clampi(int(player_spawn_px.x) / cp, 0, gs.x - 1)
	var sy: int = clampi(int(player_spawn_px.y) / cp, 0, gs.y - 1)
	var found := false
	for r in range(50):
		for _dxi in range(-r, r + 1):
			var cx: int = sx + _dxi
			for _dyi_val in [-r, r]:
				var cy: int = sy + _dyi_val
				if cx >= 0 and cy >= 0 and cx < gs.x and cy < gs.y:
					if g[cy * gs.x + cx] == 0:
						player_spawn_px = Vector2(cx * cp + cp/2, cy * cp + cp/2)
						found = true; break
			if found: break
		if found: break

	# 先创建子节点，再 set_script（否则 _ready 找不到子节点）
	var p := Node2D.new(); p.name = "Player"
	p.position = player_spawn_px; p.z_index = 20
	var na := NavigationAgent2D.new(); na.name = "NavigationAgent2D"; p.add_child(na)
	var spr := Sprite2D.new(); spr.name = "Sprite2D"; p.add_child(spr)
	var w := Node.new(); w.name = "WASAnimationPlayer"
	w.set_script(load("res://Script/Class/WASAnimationPlayer.gd"))
	w.set("target_sprite", NodePath("../Sprite2D")); p.add_child(w)
	var cam := Camera2D.new(); cam.name = "Camera2D"; p.add_child(cam)
	add_child(p)
	# set_script 触发的 _ready 现在能正确找到子节点
	p.set_script(load("res://Script/Class/MapWalker.gd"))
	_player = p


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
	var c := Node2D.new(); c.name = "ObstacleLayer"; c.z_index = 5; add_child(c)
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
