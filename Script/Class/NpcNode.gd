@tool
# NpcNode.gd — NPC，照搬 MapWalker 逻辑：A* 寻路 + global_position 移动
class_name NpcNode
extends Node2D

@export var npc_name: String = ""
@export var direction: int = 0
@export var walk_speed: float = 120.0
@export var auto_look_at_player: bool = true

@onready var wasp: WASAnimationPlayer = $WASAnimationPlayer

var _was_dir: String = ""
var _dir_idx: int = 0
var lookAtDistance = 100
var lookAtPerson = get_parent().get_node_or_null("Player") if get_parent() else null
# 寻路（和 MapWalker 完全一样）
var _astar: AStarGrid2D = null
var _cell_size: int = 20
var _click_path: PackedVector2Array = PackedVector2Array()
var _click_idx: int = 0
var _is_moving: bool = false
var _end_direction: int = -1   # goto 结束后的朝向，-1 表示不强制


func _ready():
	_load_was()
	set_meta("has_collision", true)
	if Engine.is_editor_hint():
		return
	await get_tree().process_frame
	var p = get_parent()
	if p and "astar_grid" in p:
		_astar = p.astar_grid
		_cell_size = p.get("astar_cell_size") if "astar_cell_size" in p else 20
	
	#goto(Vector2(260,220),3)
	#wasp.play("attack")
func _load_was():
	if npc_name.is_empty():
		return
	# 检查是否有 PNG 行走图（Graphic/Character/{name}/{name}.png）
	var png_path = "res://Graphic/Character/" + npc_name + "/行走.png"
	if FileAccess.file_exists(png_path):
		_load_png_sprite(png_path)
		return
	# 原有 WAS 加载
	_was_dir = "res://WAS/" + npc_name.trim_suffix("/")
	wasp.add_anim("idle",   _was_dir + "/待机.was")
	wasp.add_anim("walk",   _was_dir + "/行走.was")
	wasp.add_anim("move",   _was_dir + "/移动.was")
	wasp.add_anim("attack", _was_dir + "/攻击.was")
	wasp.load_all()
	set_direction(direction)
	wasp.play("idle")
	# 加载武器（如果有武器目录）
	_setup_weapon(_was_dir + "/")


var _png_texture: Texture2D = null
var _png_frame_w: int = 0
var _png_frame_h: int = 0
var _png_dir_map: Array[int] = [0, 1, 3, 2]  # dir index → sprite row
var _png_walk_tick: float = 0.0
var _png_walk_frame: int = 0

func _load_png_sprite(png_path: String) -> void:
	_png_texture = load(png_path) as Texture2D
	if _png_texture == null:
		return
	_png_frame_w = _png_texture.get_width() / 4
	_png_frame_h = _png_texture.get_height() / 4
	# 配置 Sprite2D 使用 region
	var spr = $Sprite2D as Sprite2D
	if spr == null:
		return
	spr.texture = _png_texture
	spr.region_enabled = true
	spr.region_rect = Rect2(0, 0, _png_frame_w, _png_frame_h)
	spr.centered = true
	spr.offset = Vector2.ZERO
	# 设置初始方向
	set_direction(direction)


## 加载武器动画
func _setup_weapon(was_base: String) -> void:
	var weapon_dir := was_base.trim_suffix("/") + "武器"
	if not DirAccess.dir_exists_absolute(weapon_dir):
		return
	var idle_path := weapon_dir + "/待机.was"
	if not FileAccess.file_exists(idle_path):
		return
	var weapon_sprite := Sprite2D.new()
	weapon_sprite.name = "WeaponSprite"
	weapon_sprite.centered = true
	weapon_sprite.z_index = $Sprite2D.z_index + 1
	add_child(weapon_sprite)

	var weapon_was := WASAnimationPlayer.new()
	weapon_was.name = "WeaponWAS"
	weapon_was.target_sprite = NodePath("../WeaponSprite")
	weapon_was.direction = wasp.direction
	weapon_was.frame_time = wasp.frame_time
	add_child(weapon_was)

	var names := {"idle":"待机","walk":"行走","move":"移动"}
	for anim in names:
		var p = weapon_dir + "/" + names[anim] + ".was"
		if FileAccess.file_exists(p):
			weapon_was.add_anim(anim, p)
	weapon_was.load_all()
	weapon_was.play("idle")


func _process(delta: float) -> void:
	
	if _click_path.is_empty() or _click_idx >= _click_path.size():
		if _is_moving:
			_is_moving = false
			if _end_direction >= 0:
				set_direction(_end_direction)
				_end_direction = -1
			wasp.play("idle")
			if _png_texture:
				var row = _png_dir_map[_dir_idx]
				$Sprite2D.region_rect = Rect2(0, row * _png_frame_h, _png_frame_w, _png_frame_h)
			var ww = get_node_or_null("WeaponWAS") as WASAnimationPlayer
			if ww: ww.play("idle", true)
		if auto_look_at_player:
			var p = get_parent().get_node_or_null("Player") if get_parent() else null
			if p and global_position.distance_to(p.global_position) < lookAtDistance:
				look_at_target(p.global_position)
		return

	if not _is_moving:
		_is_moving = true
		wasp.play("walk", true)
		_png_walk_frame = 0
		var ww = get_node_or_null("WeaponWAS") as WASAnimationPlayer
		if ww: ww.play("walk", true)

	var next_pt: Vector2 = _click_path[_click_idx]
	var to: Vector2 = next_pt - global_position
	var dist: float = to.length()

	if dist < 3.0:
		_click_idx += 1
		if _click_idx >= _click_path.size():
			global_position = next_pt
			_click_path = PackedVector2Array(); _click_idx = 0
			_is_moving = false
			if _end_direction >= 0:
				set_direction(_end_direction)
				_end_direction = -1
			wasp.play("idle")
			if _png_texture:
				var row = _png_dir_map[_dir_idx]
				$Sprite2D.region_rect = Rect2(0, row * _png_frame_h, _png_frame_w, _png_frame_h)
			var ww = get_node_or_null("WeaponWAS") as WASAnimationPlayer
			if ww: ww.play("idle", true)
		return

	var dir: Vector2 = to / dist
	look_at_dir(dir)
	global_position += dir * walk_speed * delta
	_png_walk_tick += delta
	if _png_texture and _png_walk_tick > 0.15:
		_png_walk_tick = 0.0
		_png_walk_frame = (_png_walk_frame + 1) % 4
		var row = _png_dir_map[_dir_idx]
		$Sprite2D.region_rect = Rect2(_png_walk_frame * _png_frame_w, row * _png_frame_h, _png_frame_w, _png_frame_h)
	

## 和 MapWalker 的 _navigate_to 完全一样
func goto(target_pos: Vector2, end_dir: int = -1):
	_end_direction = end_dir
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
	for _r in range(20):
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


func is_moving() -> bool:
	return _is_moving


func look_at_dir(dir: Vector2):
	if dir.length() < 0.01: return
	var a = rad_to_deg(atan2(dir.y, dir.x))
	var n = 0
	if a > 0 and a <= 90:       n = 0
	elif a > 90:                n = 1
	elif a <= -90:              n = 2
	else:                       n = 3
	set_direction(n)


func set_direction(dir: int):
	direction = clamp(dir, 0, 3)
	_dir_idx = direction
	if _png_texture:
		var row = _png_dir_map[dir]
		$Sprite2D.region_rect = Rect2(0, row * _png_frame_h, _png_frame_w, _png_frame_h)
	else:
		wasp.direction = _dir_idx
	var ww = get_node_or_null("WeaponWAS") as WASAnimationPlayer
	if ww: ww.direction = _dir_idx


func look_at_target(target_pos: Vector2):
	look_at_dir(target_pos - global_position)


func play_idle():
	wasp.play("idle", true)


func play_walk():
	wasp.play("walk", true)


func play_move():
	wasp.play("move", true)


func play_attack():
	wasp.play("attack", false)
	await wasp.animation_finished
	wasp.play("idle", true)
