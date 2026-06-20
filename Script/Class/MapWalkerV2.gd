extends Node2D

@export var speed: float = 200.0

var _obs: PackedByteArray = PackedByteArray()
var _obs_size: Vector2i = Vector2i.ZERO
var _obs_cp: int = 20

var _astar: AStarGrid2D = null
var _cell_size: int = 20

var _path: PackedVector2Array = PackedVector2Array()
var _path_idx: int = 0
var _dir_idx: int = 0
var _wasp = null


func _ready() -> void:
	var w := get_node_or_null("WASAnimationPlayer")
	if w:
		_wasp = w
		w.add_anim("idle",  "res://WAS/队员/羽灵神-弓/待机.was")
		w.add_anim("move",  "res://WAS/队员/羽灵神-弓/移动.was")
		w.add_anim("attack","res://WAS/队员/羽灵神-弓/攻击.was")
		w.load_all()
		w.play("idle")


func setup_astar(a: AStarGrid2D, cs: int) -> void: _astar = a; _cell_size = cs


func setup_obstacles(g: PackedByteArray, size: Vector2i, cp: int) -> void:
	_obs = g; _obs_size = size; _obs_cp = cp


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_walk_to(get_global_mouse_position())


var _move_dir: Vector2 = Vector2.ZERO
var _moving: bool = false


func _process(delta: float) -> void:
	var dx: float = 0.0; var dy: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  dx = -1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dx = 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    dy = -1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  dy = 1

	if dx != 0 or dy != 0:
		_move_dir = Vector2(dx, dy).normalized()
		_set_dir(_move_dir)
		var target: Vector2 = global_position + _move_dir * speed * delta
		if _can_walk(target):
			global_position = target
			_path = PackedVector2Array()
			_path_idx = 0
			_moving = true
			if _wasp: _wasp.play("move", true)
		return

	# 键盘没按 → 走 A* 路径
	if _moving:
		_moving = false
		if _wasp: _wasp.play("idle")

	if _path.is_empty() or _path_idx >= _path.size():
		return

	_moving = true
	if _wasp: _wasp.play("move", true)

	var target: Vector2 = _path[_path_idx]
	var to: Vector2 = target - global_position
	var d: float = to.length()
	if d < 3.0:
		_path_idx += 1
		if _path_idx >= _path.size():
			global_position = target
			_path = PackedVector2Array()
			_moving = false
			if _wasp: _wasp.play("idle")
	else:
		var dir: Vector2 = to / d
		global_position += dir * speed * delta
		if not _moving: _set_dir(dir)


func _can_walk(pos: Vector2) -> bool:
	if _obs.size() > 0:
		var cx: int = int(pos.x) / _obs_cp
		var cy: int = int(pos.y) / _obs_cp
		if cx < 0 or cy < 0 or cx >= _obs_size.x or cy >= _obs_size.y: return false
		return _obs[cy * _obs_size.x + cx] == 0
	if _astar:
		var c: Vector2i = Vector2i(int(pos.x / _cell_size), int(pos.y / _cell_size))
		return _astar.is_in_boundsv(c) and not _astar.is_point_solid(c)
	return true


func _walk_to(target_pos: Vector2) -> void:
	if _astar == null: return
	var s: Vector2i = Vector2i(int(global_position.x / _cell_size), int(global_position.y / _cell_size))
	var e: Vector2i = Vector2i(int(target_pos.x / _cell_size), int(target_pos.y / _cell_size))
	if not _astar.is_in_boundsv(e): return
	if _astar.is_point_solid(e):
		e = _nearest_walkable(e)
		if not _astar.is_in_boundsv(e): return
	var pts := _astar.get_point_path(s, e)
	if pts.is_empty(): return
	_path = pts; _path_idx = 0


func _nearest_walkable(cell: Vector2i) -> Vector2i:
	var q: Array = [cell]; var v := {}
	for _r in range(12):
		var c: Vector2i = q.pop_front()
		if v.has(c): continue
		v[c] = true
		if _astar.is_in_boundsv(c) and not _astar.is_point_solid(c): return c
		for dy in [-1,0,1]:
			for dx in [-1,0,1]:
				if dx==0 and dy==0: continue
				var n: Vector2i = c + Vector2i(dx, dy)
				if not v.has(n): q.append(n)
	return cell


func _set_dir(dir: Vector2) -> void:
	if dir.length() < 0.01: return
	var a := rad_to_deg(atan2(dir.y, dir.x))
	var n := 0
	if a <= 90 and a > 0:    n = 0
	elif a > 90:             n = 1
	elif a <= -90:           n = 2
	else:                    n = 3
	if n != _dir_idx:
		_dir_idx = n
		if _wasp: _wasp.direction = _dir_idx
