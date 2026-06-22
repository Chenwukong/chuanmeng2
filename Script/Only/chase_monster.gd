# chase_monster.gd — 全图追踪主角，A* 绕障碍，碰到触发战斗
extends Node2D

@onready var _wasp: WASAnimationPlayer = $WASAnimationPlayer

@export var speed: float = 400.0
@export var repath_interval: float = 0.8
@export var catch_distance: float = 40.0

var _player: Node2D = null
var _astar: AStarGrid2D = null
var _cell_size: int = 20

var _dir_idx: int = 0
var _moving: bool = false
var _path: PackedVector2Array = PackedVector2Array()
var _path_idx: int = 0
var _repath_tick: float = 0.0
var _caught: bool = false


func _ready() -> void:
	# 从 metadata 读 WAS 目录
	var was_dir: String = get_meta("was_dir", "res://WAS/超级赤焰兽").trim_suffix("/")
	_wasp.add_anim("idle",   was_dir + "/待机.was")
	_wasp.add_anim("move",   was_dir + "/移动.was")
	_wasp.add_anim("attack", was_dir + "/攻击.was")
	_wasp.load_all()
	_wasp.play("idle")

	await get_tree().process_frame
	var p := get_parent()
	if p:
		_player = p.get_node_or_null("Player") as Node2D
		_astar = p.get("astar_grid") if "astar_grid" in p else null
		_cell_size = p.get("astar_cell_size") if "astar_cell_size" in p else 20

	if not _player:
		for node in get_tree().get_nodes_in_group("player"):
			_player = node as Node2D
			break


func _process(delta: float) -> void:
	if _caught or GameData.in_battle or GameData.ui_blocked or get_tree().current_scene.is_dialogue_active():
		return
	if not _player or not is_instance_valid(_player):
		return

	# 碰到主角 → 触发战斗
	if global_position.distance_to(_player.global_position) < catch_distance:
		_on_catch_player()
		return

	# 如果没了 AStar，每帧尝试重新从父节点拿
	if _astar == null:
		var p := get_parent()
		if p:
			_astar = p.get("astar_grid") if "astar_grid" in p else null
			_cell_size = p.get("astar_cell_size") if "astar_cell_size" in p else 20

	_repath_tick -= delta
	if _repath_tick <= 0.0:
		_repath_tick = repath_interval
		_repath()

	if _path.is_empty() or _path_idx >= _path.size():
		_direct_chase(delta)
		return

	if not _moving:
		_moving = true
		_wasp.play("move", true)

	var next_pt: Vector2 = _path[_path_idx]
	var to: Vector2 = next_pt - global_position
	var dist: float = to.length()

	if dist < 3.0:
		_path_idx += 1
		if _path_idx >= _path.size():
			global_position = next_pt
			_path = PackedVector2Array()
			_path_idx = 0
			_moving = false
			_wasp.play("idle")
		return

	var dir: Vector2 = to / dist
	_set_dir(dir)
	global_position += dir * speed * delta


func _repath() -> void:
	if _astar == null or _cell_size == 0:
		return
	var s := _world_to_cell(global_position)
	var e := _world_to_cell(_player.global_position)
	if not _astar.is_in_boundsv(e) or not _astar.is_in_boundsv(s):
		return
	if _astar.is_point_solid(e):
		e = _nearest_walkable(e)
		if not _astar.is_in_boundsv(e):
			return
	var pts := _astar.get_point_path(s, e)
	if pts.is_empty():
		return
	_path = pts
	_path_idx = 0


func _nearest_walkable(cell: Vector2i) -> Vector2i:
	var q: Array = [cell]
	var v := {}
	for _r in range(20):
		if q.is_empty(): break
		var c: Vector2i = q.pop_front()
		if v.has(c): continue
		v[c] = true
		if _astar.is_in_boundsv(c) and not _astar.is_point_solid(c):
			return c
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0: continue
				var n := c + Vector2i(dx, dy)
				if not v.has(n): q.append(n)
	return cell


func _world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / _cell_size), int(pos.y / _cell_size))


func _direct_chase(delta: float) -> void:
	var to := _player.global_position - global_position
	if to.length() < 0.01:
		return
	if _repath_tick <= -2.0:
		_repath_tick = 0.0
	var dir: Vector2 = to.normalized()
	global_position += dir * speed * delta
	_set_dir(dir)
	if not _moving:
		_moving = true
		_wasp.play("move", true)


func _on_catch_player() -> void:
	_caught = true
	_wasp.play("idle")
	var parent := get_parent()
	if parent and parent.has_method("_on_chase_caught"):
		parent._on_chase_caught(self)


func _set_dir(dir: Vector2) -> void:
	if dir.length() < 0.01:
		return
	var a := rad_to_deg(atan2(dir.y, dir.x))
	var n := 0
	if a > 0 and a <= 90:
		n = 0
	elif a > 90:
		n = 1
	elif a <= -90:
		n = 2
	else:
		n = 3
	if n != _dir_idx:
		_dir_idx = n
		_wasp.direction = _dir_idx
