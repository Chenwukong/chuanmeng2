@tool
# MapWalker.gd — 键盘 + A* 鼠标寻路，自动避开障碍物 + 遇怪步数统计 + 按R骑乘
extends Node2D

@onready var _wasp: WASAnimationPlayer = $WASAnimationPlayer
@onready var _mount_node: Node2D = $Mount
@onready var _mount_wasp: WASAnimationPlayer = $Mount/WASAnimationPlayer

@export var speed: float = 200.0
@export var mount_speed: float = 300.0
## 点击远处 NPC 时，走到这个距离后自动交谈。
@export_range(40.0, 100.0, 1.0) var talk_distance: float = 80.0
var _pending_npc: Node2D
var _npc_repath_timer: float = 0.0
var _npc_last_position := Vector2.ZERO

var _astar: AStarGrid2D = null
var _cell_size: int = 0

var _dir_idx: int = 0
const FACING_DIRS: Array[Vector2] = [
	Vector2( 0.707,  0.707),  # 0: 右下
	Vector2(-0.707,  0.707),  # 1: 左下
	Vector2(-0.707, -0.707),  # 2: 左上
	Vector2( 0.707, -0.707),  # 3: 右上
]
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
	# 游霄云专用衣料索引，不影响武器和坐骑播放器。
	_wasp.set_dye("res://Resources/Dye/游霄云白衣/{file}.wpal", _white_clothes_choices())
	_wasp.add_anim("idle",   "res://WAS/游霄云/待机.was")
	_wasp.add_anim("move",   "res://WAS/游霄云/移动.was")
	_wasp.add_anim("attack", "res://WAS/游霄云/攻击.was")
	_wasp.add_anim("ride_idle", "res://WAS/坐骑/羽灵神-坐骑-宝贝葫芦/站立.was")
	_wasp.add_anim("ride_move", "res://WAS/坐骑/羽灵神-坐骑-宝贝葫芦/行走.was")
	_wasp.load_all()
	_wasp.play("idle")  # 初始化不走 _play_hero，避免误触骑行状态

	# 加载武器（如果有武器目录）
	_setup_weapon("res://WAS/游霄云/")

	# 坐骑动画
	_mount_wasp.add_anim("move", "res://WAS/坐骑/坐骑-宝贝葫芦/行走.was")
	_mount_wasp.add_anim("idle", "res://WAS/坐骑/坐骑-宝贝葫芦/站立.was")
	_mount_wasp.load_all()
	_mount_wasp.play("idle")
	_mount_node.z_index = 0
	move_child(_mount_node, 0)  # 坐骑先于角色绘制，两者按同一个脚底坐标排序
	_mount_node.visible = false
	_mount_node.position = Vector2(0, 0)

	# 从父节点读 AStarGrid2D（延迟一帧确保已创建）
	await get_tree().process_frame
	var p = get_parent()
	if p and "astar_grid" in p:
		_astar = p.astar_grid
		_cell_size = p.get("astar_cell_size") if "astar_cell_size" in p else 20
		if _astar:
			_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES


## 加载武器动画（如果武器目录存在）
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
	# Keep weapon and body in the same Y-sort group. The later child draws on top.
	weapon_sprite.z_index = $Sprite2D.z_index
	add_child(weapon_sprite)

	var weapon_was := WASAnimationPlayer.new()
	weapon_was.name = "WeaponWAS"
	weapon_was.target_sprite = NodePath("../WeaponSprite")
	weapon_was.direction = _wasp.direction
	weapon_was.frame_time = _wasp.frame_time
	add_child(weapon_was)

	var names := {"idle":"待机","move":"移动","walk":"行走"}
	for anim in names:
		var p = weapon_dir + "/" + names[anim] + ".was"
		if FileAccess.file_exists(p):
			weapon_was.add_anim(anim, p)
	weapon_was.load_all()
	weapon_was.play("idle")


func setup_astar(a: AStarGrid2D, cs: int) -> void:
	_astar = a; _cell_size = cs
	if _astar:
		_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES


func dismount_for_story() -> void:
	_riding = false
	_mount_node.hide()
	$Sprite2D.position.y = 0
	_wasp.play("idle")

func _play_hero(anim):
	if _riding and anim == "idle":
		_wasp.play("ride_idle", true)
	else:
		_wasp.play(anim, true)


func _input(event: InputEvent):
	if GameData.in_battle or GameData.ui_blocked or GameData.is_dialogue_active():
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
	if get_tree().current_scene and get_tree().current_scene.get_meta("keyboard_menu_open", false): return
	
	if GameData.in_battle or GameData.ui_blocked or GameData.is_dialogue_active():
		return
	if event.is_action_pressed("ui_accept"):
		_try_talk_to_nearest_npc()
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos := get_global_mouse_position()
		# 优先检查是否点中 NPC
		for child in get_parent().get_children():
			if (child is NpcNode or child.has_method("interact")) and child.is_visible_in_tree() and click_pos.distance_to(child.global_position) < 50:
				_talk_to_npc(child)
				return
		_pending_npc = null
		if _nav_cd > 0.0:
			return
		_nav_cd = 0.5
		_spawn_click_ripple(click_pos)
		_navigate_to(click_pos)


func _talk_to_npc(npc: Node2D) -> void:
	if not is_instance_valid(npc) or not npc.is_visible_in_tree(): return
	if GameData.in_battle or GameData.ui_blocked or GameData.is_dialogue_active() or GameData._npc_dialogue_playing: return
	_pending_npc = null
	var reach := _interaction_range(npc)
	if global_position.distance_to(npc.global_position) > reach:
		var points := find_approach_path(npc.global_position, reach)
		if points.is_empty():
			_click_path = PackedVector2Array()
			return
		_pending_npc = npc
		_npc_last_position = npc.global_position
		_npc_repath_timer = 0.35
		_click_path = points
		_click_idx = 0
		return
	_click_path = PackedVector2Array()
	_click_idx = 0
	_is_moving = false
	_play_hero("idle")
	if _riding: _mount_wasp.play("idle", true)
	var weapon = get_node_or_null("WeaponWAS") as WASAnimationPlayer
	if weapon: weapon.play("idle", true)
	_set_dir(npc.global_position - global_position)
	if npc.has_method("interact"):
		npc.interact(self)
		return
	npc.look_at_target(global_position)
	if npc.has_method("challenge"):
		await npc.challenge()
		return
	var event_id: String = npc.event_id if not npc.event_id.is_empty() else npc.npc_name
	await GameData.play_npc_dialogue(event_id)


func _interaction_range(target: Node2D) -> float:
	var reach = target.get("interaction_distance")
	return minf(talk_distance, float(reach)) if reach != null else talk_distance

func _update_npc_approach(delta: float) -> bool:
	if _pending_npc == null: return false
	if not is_instance_valid(_pending_npc) or not _pending_npc.is_visible_in_tree():
		_pending_npc = null
		_click_path = PackedVector2Array()
		return false
	if global_position.distance_to(_pending_npc.global_position) <= _interaction_range(_pending_npc):
		var npc := _pending_npc
		_pending_npc = null
		_talk_to_npc(npc)
		return true
	_npc_repath_timer -= delta
	if _npc_repath_timer <= 0.0 and (_pending_npc.global_position.distance_to(_npc_last_position) > 20.0 or _click_path.is_empty()):
		var npc := _pending_npc
		_pending_npc = null
		_talk_to_npc(npc)
	return false


## 按空格/回车时，找面前最近的 NPC 触发对话
func _try_talk_to_nearest_npc() -> void:
	var facing := FACING_DIRS[_dir_idx]
	for child in get_parent().get_children():
		if not (child is NpcNode or child.has_method("interact")) or not child.is_visible_in_tree():
			continue
		var to_npc = child.global_position - global_position
		if to_npc.length() > 50.0:
			continue
		if to_npc.normalized().dot(facing) < 0.5:
			continue
		_talk_to_npc(child)
		return


func _process(delta: float) -> void:
	if get_tree().current_scene and get_tree().current_scene.get_meta("keyboard_menu_open", false): return
	if Engine.is_editor_hint():
		return
	_nav_cd = maxf(0.0, _nav_cd - delta)
	if GameData.in_battle or GameData.is_dialogue_active() or _mounting:
		if _pending_npc != null:
			_pending_npc = null
			_click_path = PackedVector2Array()
		return
	if GameData.ui_blocked:
		var main_scene = get_tree().current_scene
		if main_scene == null or not main_scene.has_method("can_navigate_with_minimap_open") or not main_scene.can_navigate_with_minimap_open():
			if _pending_npc != null:
				_pending_npc = null
				_click_path = PackedVector2Array()
			return
	var dx: float = 0.0; var dy: float = 0.0
	var input_strength := 1.0
	if not GameData.ui_blocked:
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):   dx = -1; dy = -1
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):  dx = 1;  dy = 1
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):     dx = 1;  dy = -1
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):   dx = -1; dy = 1
		if GamepadInput.active and not GamepadInput.move_vector.is_zero_approx():
			var stick := GamepadInput.move_vector
			dx = stick.x - stick.y
			dy = stick.x + stick.y
			input_strength = stick.length()
		if PlatformControls.android_mode and not PlatformControls.move_vector.is_zero_approx():
			dx = PlatformControls.move_vector.x
			dy = PlatformControls.move_vector.y
			input_strength = PlatformControls.move_vector.length()

	if dx == 0 and dy == 0 and _update_npc_approach(delta): return
	if dx != 0 or dy != 0:
		_pending_npc = null
		_click_path = PackedVector2Array(); _click_idx = 0
		var dir = Vector2(dx, dy).normalized()
		_set_dir(dir)
		var cur_speed = (mount_speed if _riding else speed) * input_strength
		var target = global_position + dir * cur_speed * delta
		if not _is_blocked(target):
			GameData.record_walk_distance(global_position.distance_to(target))
			global_position = target
			if not _is_moving:
				_is_moving = true
				if _riding:
					_play_hero("idle")
					_mount_wasp.play("move", true)
				else:
					_play_hero("move")
				var ww = get_node_or_null("WeaponWAS") as WASAnimationPlayer
				if ww: ww.play("move", true)
		_report_encounter_step()

	elif _click_path.is_empty() or _click_idx >= _click_path.size():
		if _is_moving:
			_is_moving = false
			_play_hero("idle")
			if _riding:
				_mount_wasp.play("idle")
			var ww = get_node_or_null("WeaponWAS") as WASAnimationPlayer
			if ww: ww.play("idle", true)

	else:
		if not _is_moving:
			_is_moving = true
			if _riding:
				_play_hero("idle")
				_mount_wasp.play("move", true)
			else:
				_play_hero("move")
			var ww = get_node_or_null("WeaponWAS") as WASAnimationPlayer
			if ww: ww.play("move", true)

		var next_pt: Vector2 = _click_path[_click_idx]
		var to: Vector2 = next_pt - global_position
		var dist: float = to.length()

		if dist < 3.0:
			# 到达拐点时落在准确坐标，避免残差让下一段短暂反向。
			GameData.record_walk_distance(dist)
			global_position = next_pt
			_click_idx += 1
			if _click_idx >= _click_path.size():
				GameData.record_walk_distance(global_position.distance_to(next_pt))
				global_position = next_pt
				_click_path = PackedVector2Array(); _click_idx = 0
				_is_moving = false
				_play_hero("idle")
				if _riding:
					_mount_wasp.play("idle")
				var ww = get_node_or_null("WeaponWAS") as WASAnimationPlayer
				if ww: ww.play("idle", true)
		else:
			var dir: Vector2 = to / dist
			_set_dir(dir)
			var cur_speed = mount_speed if _riding else speed
			GameData.record_walk_distance(minf(cur_speed * delta, dist))
			global_position += dir * minf(cur_speed * delta, dist)
			_report_encounter_step()

	# ── 骑乘浮动（每帧，不管是否移动） ──
	if _riding:
		_bob_t += delta * 8.0
		var bob = sin(_bob_t) * 2.0
		_mount_node.position = Vector2(0, 0 + bob)
		$Sprite2D.position.y = - 10 + bob


## A* 寻路到目标
func _navigate_to(target_pos: Vector2) -> void:
	navigate_to(target_pos)


## 世界坐标寻路入口，同时供主地图点击和小地图使用。
func navigate_to(target_pos: Vector2) -> bool:
	_pending_npc = null
	var pts := find_navigation_path(target_pos)
	if pts.is_empty(): return false
	_click_path = pts
	_click_idx = 0
	return true


## Preview shares the movement pathfinder, without changing the current route.
func find_navigation_path(target_pos: Vector2) -> PackedVector2Array:
	if _astar == null or _cell_size <= 0: return PackedVector2Array()
	var map_root = get_parent() as Node2D
	var local_start: Vector2 = map_root.to_local(global_position)
	var local_target: Vector2 = map_root.to_local(target_pos).snapped(Vector2(0.001, 0.001))
	var s := Vector2i((local_start / _cell_size).floor())
	var e := Vector2i((local_target / _cell_size).floor())
	if not _astar.is_in_boundsv(s) or not _astar.is_in_boundsv(e): return PackedVector2Array()
	var start_was_solid := _astar.is_point_solid(s)
	if start_was_solid: s = _nearest_walkable(s)
	if _astar.is_point_solid(e): e = _nearest_walkable(e)
	if _astar.is_point_solid(s) or _astar.is_point_solid(e): return PackedVector2Array()
	var pts: PackedVector2Array = _astar.get_point_path(s, e)
	if pts.is_empty(): return PackedVector2Array()
	# A* 首点是格子原点，不应让角色先回头走到该点。
	if not start_was_solid:
		if pts.size() == 1:
			pts.append(local_target)
		pts[0] = local_start
	for i in pts.size():
		pts[i] = map_root.to_global(pts[i])
	return pts


## Stop beside an NPC instead of overlapping their sprite.
func find_approach_path(target_pos: Vector2, max_distance: float = -1.0) -> PackedVector2Array:
	if max_distance < 0.0: max_distance = talk_distance
	var best := PackedVector2Array()
	var best_length := INF
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1,-1).normalized(), Vector2(1,-1).normalized(), Vector2(-1,1).normalized(), Vector2(1,1).normalized()]:
		var points := find_navigation_path(target_pos + direction * minf(55.0, max_distance * 0.8))
		if points.is_empty() or points[-1].distance_to(target_pos) < 32.0 or points[-1].distance_to(target_pos) > max_distance: continue
		var length := global_position.distance_to(points[0])
		for i in range(1, points.size()): length += points[i-1].distance_to(points[i])
		if length < best_length:
			best_length = length
			best = points
	return best


func _nearest_walkable(cell: Vector2i) -> Vector2i:
	# 按距离逐圈搜索，避免原本仅检查十五个队列项而漏掉附近道路。
	for radius in range(1, 17):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if absi(x) != radius and absi(y) != radius: continue
				var candidate := cell + Vector2i(x, y)
				if _astar.is_in_boundsv(candidate) and not _astar.is_point_solid(candidate):
					return candidate
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
		if child is NpcNode and not child.is_visible_in_tree(): continue
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
	# 四方向素材在坐标轴附近保留原朝向侧，过滤浮点及细微横向偏差。
	var facing := dir.normalized()
	if absf(facing.x) < 0.05:
		facing.x = signf(FACING_DIRS[_dir_idx].x) * 0.05
	if absf(facing.y) < 0.05:
		facing.y = signf(FACING_DIRS[_dir_idx].y) * 0.05
	var a = rad_to_deg(atan2(facing.y, facing.x))
	var n = 0
	if a <= 90 and a > 0:    n = 0
	elif a > 90:             n = 1
	elif a <= -90:           n = 2
	else:                    n = 3
	if n != _dir_idx:
		_dir_idx = n
		_wasp.direction = _dir_idx
		_mount_wasp.direction = _dir_idx
		var weapon_was = get_node_or_null("WeaponWAS") as WASAnimationPlayer
		if weapon_was:
			weapon_was.direction = _dir_idx

## 鼠标点击水面波纹特效
func _spawn_click_ripple(pos: Vector2) -> void:
	# 生成圆形环纹理
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in 48:
		for y in 48:
			var dx := x - 24; var dy := y - 24
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= 22 and dist >= 18:
				img.set_pixel(x, y, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.global_position = pos
	sprite.z_index = 100
	sprite.modulate = Color(0.5, 0.75, 1, 0.8)
	get_parent().add_child(sprite)
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(sprite, "scale", Vector2(2.5, 2.5), 0.5)
	tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
	tw.tween_callback(sprite.queue_free)

func _white_clothes_choices() -> PackedInt32Array:
	var choices := PackedInt32Array()
	choices.resize(256)
	choices.fill(1)
	return choices

