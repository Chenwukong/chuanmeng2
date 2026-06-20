@tool
# MapWalker.gd — 键盘 + A* 鼠标寻路，自动避开障碍物 + 遇怪步数统计 + 按R骑乘
extends Node2D

@onready var _wasp: WASAnimationPlayer = $WASAnimationPlayer
@onready var _mount_node: Node2D = $Mount
@onready var _mount_wasp: WASAnimationPlayer = $Mount/WASAnimationPlayer

@export var speed: float = 200.0
@export var mount_speed: float = 300.0

var _astar: AStarGrid2D = null
var _cell_size: int = 0

var _dir_idx: int = 0
var _is_moving: bool = false
var _click_path: PackedVector2Array = PackedVector2Array()
var _click_idx: int = 0
var _last_pos: Vector2 = Vector2.ZERO

# 骑乘状态
var _riding = false
var _mounting = false
var _bob_t = 0.0
var _nav_cd: float = 0.0


func _ready() -> void:
	_wasp.add_anim("idle",   "res://WAS/队员/羽灵神-弓/待机.was")
	_wasp.add_anim("move",   "res://WAS/队员/羽灵神-弓/移动.was")
	_wasp.add_anim("attack", "res://WAS/队员/羽灵神-弓/攻击.was")
	_wasp.add_anim("ride_idle", "res://WAS/坐骑/羽灵神-坐骑-宝贝葫芦/站立.was")
	_wasp.add_anim("ride_move", "res://WAS/坐骑/羽灵神-坐骑-宝贝葫芦/行走.was")
	_wasp.load_all()
	_wasp.play("idle")  # 初始化不走 _play_hero，避免误触骑行状态

	# 坐骑动画
	_mount_wasp.add_anim("move", "res://WAS/坐骑/坐骑-宝贝葫芦/行走.was")
	_mount_wasp.add_anim("idle", "res://WAS/坐骑/坐骑-宝贝葫芦/站立.was")
	_mount_wasp.load_all()
	_mount_wasp.play("idle")
	_mount_node.z_index = -1
	_mount_node.visible = false
	_mount_node.position = Vector2(0, 0)

	# 从父节点读 AStarGrid2D（延迟一帧确保已创建）
	await get_tree().process_frame
	var p = get_parent()
	if p and "astar_grid" in p:
		_astar = p.astar_grid
		_cell_size = p.get("astar_cell_size") if "astar_cell_size" in p else 20


func setup_astar(a: AStarGrid2D, cs: int) -> void:
	_astar = a; _cell_size = cs


func _play_hero(anim):
	if _riding and anim == "idle":
		_wasp.play("ride_idle", true)
	else:
		_wasp.play(anim, true)


func _input(event: InputEvent):
	if GameData.in_battle or GameData.ui_blocked:
		return
	if not (event is InputEventKey and event.pressed and event.keycode == KEY_R and not event.echo):
		return
	if _riding:
		# 下马
		_riding = false
		_mounting = false
		_mount_node.visible = false
		_bob_t = 0.0
		$Sprite2D.position.y = 0
		if _is_moving:
			_play_hero("move")
		else:
			_play_hero("idle")
	elif not _mounting:
		# 开始召唤坐骑
		_mounting = true
		_play_hero("idle")
		_mount_node.modulate.a = 0.0
		_mount_node.visible = true
		_mount_wasp.play("idle")
		var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.tween_callback(func():
			_mounting = false
			_riding = true
			_play_hero("idle")
		)
		
		t.tween_property(_mount_node, "modulate:a", 1.0, 1)
		t.parallel().tween_property($Sprite2D, "position:y", -10, 0.8)



func _unhandled_input(event: InputEvent) -> void:
	if GameData.in_battle or GameData.ui_blocked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _nav_cd > 0.0:
			return
		_nav_cd = 0.5
		_navigate_to(get_global_mouse_position())


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_nav_cd = maxf(0.0, _nav_cd - delta)
	if GameData.in_battle or GameData.ui_blocked or _mounting:
		return
	var dx: float = 0.0; var dy: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):   dx = -1; dy = -1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):  dx = 1;  dy = 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):     dx = 1;  dy = -1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):   dx = -1; dy = 1

	if dx != 0 or dy != 0:
		_click_path = PackedVector2Array(); _click_idx = 0
		var dir = Vector2(dx, dy).normalized()
		_set_dir(dir)
		var cur_speed = mount_speed if _riding else speed
		var target = global_position + dir * cur_speed * delta
		if not _is_blocked(target):
			global_position = target
			if not _is_moving:
				_is_moving = true
				if _riding:
					_play_hero("idle")
					_mount_wasp.play("move", true)
				else:
					_play_hero("move")
		_report_encounter_step()

	elif _click_path.is_empty() or _click_idx >= _click_path.size():
		if _is_moving:
			_is_moving = false
			_play_hero("idle")
			if _riding:
				_mount_wasp.play("idle")

	else:
		if not _is_moving:
			_is_moving = true
			if _riding:
				_play_hero("idle")
				_mount_wasp.play("move", true)
			else:
				_play_hero("move")

		var next_pt: Vector2 = _click_path[_click_idx]
		var to: Vector2 = next_pt - global_position
		var dist: float = to.length()

		if dist < 3.0:
			_click_idx += 1
			if _click_idx >= _click_path.size():
				global_position = next_pt
				_click_path = PackedVector2Array(); _click_idx = 0
				_is_moving = false
				_play_hero("idle")
				if _riding:
					_mount_wasp.play("idle")
		else:
			var dir: Vector2 = to / dist
			_set_dir(dir)
			var cur_speed = mount_speed if _riding else speed
			global_position += dir * cur_speed * delta
			_report_encounter_step()

	# ── 骑乘浮动（每帧，不管是否移动） ──
	if _riding:
		_bob_t += delta * 8.0
		var bob = sin(_bob_t) * 2.0
		_mount_node.position = Vector2(0, 0 + bob)
		$Sprite2D.position.y = - 10 + bob


## A* 寻路到目标
func _navigate_to(target_pos: Vector2) -> void:
	if _astar == null or _cell_size == 0: return
	var s: Vector2i = Vector2i(int(global_position.x / _cell_size), int(global_position.y / _cell_size))
	var e: Vector2i = Vector2i(int(target_pos.x / _cell_size), int(target_pos.y / _cell_size))
	if not _astar.is_in_boundsv(e): return
	if _astar.is_point_solid(e):
		e = _nearest_walkable(e)
		if not _astar.is_in_boundsv(e): return
	var pts = _astar.get_point_path(s, e)
	if pts.is_empty(): return
	_click_path = pts; _click_idx = 0


func _nearest_walkable(cell: Vector2i) -> Vector2i:
	var q: Array = [cell]; var v = {}
	for _r in range(15):
		if q.is_empty(): break
		var c: Vector2i = q.pop_front()
		if v.has(c): continue; v[c] = true
		if _astar.is_in_boundsv(c) and not _astar.is_point_solid(c): return c
		for dy in [-1,0,1]:
			for dx in [-1,0,1]:
				if dx == 0 and dy == 0: continue
				var n: Vector2i = c + Vector2i(dx, dy)
				if not v.has(n): q.append(n)
	return cell


## 障碍物检查（从父节点直接读公开变量 + NPC 体积）
func _is_blocked(pos: Vector2) -> bool:
	var parent = get_parent()
	if parent == null: return false
	var g = parent.get("obs_grid") if "obs_grid" in parent else null
	var gs = parent.get("obs_size") if "obs_size" in parent else null
	var cp: int = parent.get("obs_cp") if "obs_cp" in parent else 20
	if g != null and g.size() > 0:
		var cx: int = int(pos.x) / cp
		var cy: int = int(pos.y) / cp
		if cx < 0 or cy < 0 or cx >= gs.x or cy >= gs.y: return true
		if g[cy * gs.x + cx] != 0: return true

	# 检查 NPC 体积（32px 判定半径）
	var margin = 32
	for child in parent.get_children():
		if child == self: continue
		if child is NpcNode or child.has_meta("has_collision"):
			if pos.distance_to(child.global_position) < margin:
				return true
	return false


## 向父节点（MapRoot）报告移动步数，用于暗雷遇怪
func _report_encounter_step() -> void:
	var dist = global_position.distance_to(_last_pos)
	_last_pos = global_position
	if dist <= 0.0:
		return
	var p = get_parent()
	if p and p.has_method("add_encounter_step"):
		p.add_encounter_step(dist)


## WAS 方向
func _set_dir(dir: Vector2) -> void:
	if dir.length() < 0.01: return
	var a = rad_to_deg(atan2(dir.y, dir.x))
	var n = 0
	if a <= 90 and a > 0:    n = 0
	elif a > 90:             n = 1
	elif a <= -90:           n = 2
	else:                    n = 3
	if n != _dir_idx:
		_dir_idx = n
		_wasp.direction = _dir_idx
		_mount_wasp.direction = _dir_idx
