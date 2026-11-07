@tool
# MapRoot.gd
# 通用地图根节点脚本 — 挂在场景根节点上
# 合并了 MapViewerV2 的地图加载/渲染/障碍物/A*/遮罩逻辑
extends Node2D

const BattleAssets := preload("res://Script/Assets/BattleAssetLoader.gd")
const MaskLayer := preload("res://Script/World/MapMaskLayer.gd")

# ═══ 预配置战斗数据库 ═══
const BATTLE_PRESETS = {
	"方寸山_守关20": {"enemies": ["方寸山_守关20"], "party": []},
	"方寸山_守关60": {"enemies": ["方寸山_守关60"], "party": []},
	"方寸山_守关100": {"enemies": ["方寸山_守关100"], "party": []},
	"机关人": { "enemies": ["机关人"], "party": [] },
	"赤焰兽": { "enemies": ["超级赤焰兽", "超级赤焰兽", "超级赤焰兽"], "party": [] },
}

## 触发一场预配置的战斗（NPC 对话中用）
func start_preset_battle(preset_id: String, victory_flag: String = "") -> String:
	if _encounter_active or GameData.in_battle:
		return "cancelled"
	var cfg = BATTLE_PRESETS.get(preset_id)
	if cfg == null:
		push_error("未找到战斗预设: %s" % preset_id)
		return "cancelled"
	_encounter_active = true
	_cleanup_chasers()
	var player = get_player_node()
	if player == null:
		_encounter_active = false
		return "cancelled"
	if player.has_method("set_process"):
		player.set_process(false)
		player.set_process_input(false)
	if _bgm_player and is_instance_valid(_bgm_player):
		_bgm_player.stop()
	# 停止所有 BGM 总线播放器
	var root = get_tree().current_scene
	for c in root.get_children():
		if c is AudioStreamPlayer and c.bus == "BGM":
			c.stop()
	$"../BGM".volume_db = -80
	GameData.set_meta("pending_enemies", cfg.get("enemies", []))
	var custom_party = cfg.get("party", [])
	if not custom_party.is_empty():
		GameData.set_meta("pending_party", custom_party)
	else:
		GameData.remove_meta("pending_party")
	var bt = BattleTransition.play(get_tree().root)
	await bt.finished
	var enemies = cfg.get("enemies", [])
	var battle_scene = await _launch_battle(enemies, player)
	# 用可变容器保存信号结果；逃跑/失败均不计为胜利，异常退出保持 cancelled。
	var outcome := {"result": "cancelled"}
	if is_instance_valid(battle_scene):
		var manager = battle_scene.get_node("BattleManager")
		manager.battle_ended.connect(func(won: bool, _exp: int, _gold: int, _levels: Array):
			outcome.result = "won" if won else "lost"
			if won: GameData.grant_first_boss_talent_reward(preset_id)
			# 胜利结算时即提交，关闭奖励窗口前退出也不会丢失守关进度。
			if won and not victory_flag.is_empty(): GameData.complete_story_event(victory_flag)
		, CONNECT_ONE_SHOT)
	await bt.reverse()
	if is_instance_valid(battle_scene):
		BattleTransition.shake_canvas(battle_scene, 14.0, 0.35)
		# 战斗结束信号先于奖励/升级/统计弹窗；必须等整个战斗场景退出。
		await battle_scene.tree_exited
	# 关闭游戏也会销毁战斗并唤醒上述等待，此时地图可能已离开场景树。
	if not is_inside_tree() or is_queued_for_deletion(): return "cancelled"
	while GameData.in_battle or _battle_returning:
		if not is_inside_tree() or is_queued_for_deletion(): return "cancelled"
		await get_tree().process_frame
	return str(outcome.result)

@onready var nav_region: NavigationRegion2D = $Nav
@onready var exits_node: Node2D = $Exits

## 在编辑器中设置，对应 GameData.ENCOUNTER_CONFIG 的key
@export var map_id: String = ""
## 只调整跑图角色与地图的相对大小，角色脚底坐标保持原位。
@export_range(1.0, 1.6, 0.05) var actor_scale_multiplier := 1.25

# ── MapViewerV2 合并字段 ──
## .map 文件路径（设置了才会用 MapLoader 渲染图块）
@export_file("*.map") var map_path: String = "":
	set(value):
		if map_path == value:
			return
		map_path = value
		_queue_editor_map_refresh()
## 地图没有可读的内置遮罩时，使用这张备用前景图。
@export_file("*.png") var fallback_mask_png: String = ""
## 玩家出生像素坐标（仅在 map_path 有效且场景无 Player 时用作回退）
@export var player_spawn_px: Vector2 = Vector2(2800, 2880)
## 显示障碍物叠加层（蓝色半透明，调试用）
@export var show_obstacles: bool = false
@export var map_bgm: AudioStream

var _editor_map_refresh_pending: bool = false

var _bgm_player: AudioStreamPlayer = null


# 公开给 MapWalker 读取的障碍物/A*变量
var obs_grid: PackedByteArray = PackedByteArray()
var obs_size: Vector2i = Vector2i.ZERO
var obs_cp: int = 20
var astar_grid: AStarGrid2D = null
var astar_cell_size: int = 20

# MapViewerV2 内部
var _loader: MapLoader = null
var _mask_layer: Node2D
var _map_width: int = 0
var _map_height: int = 0
var _colnum: int = 0
var _rownum: int = 0
var _mapnum: int = 0
var _map_layer: Node2D = null  # 地图图块容器，用于时间着色

# 原有遇怪状态
var _encounter_active: bool = false
var _battle_returning: bool = false
var _encounter_step_accum: float = 0.0
var _last_player_pos: Vector2 = Vector2.ZERO

# 追踪怪
var _chase_spawn_timer: Timer = null
var _last_chase_monster: String = ""

func _ready() -> void:
	if not Engine.is_editor_hint(): BattleAssets.request()
	# 先加载 .map 文件（如果设置了路径）
	_init_map_viewer()
	if Engine.is_editor_hint():
		return
	for child in get_children():
		if child is NpcNode or (child is Node2D and child.name == &"Player"):
			child.scale *= actor_scale_multiplier
	_set_camera_limits()
	GameData.unlock_skill("lingfeng", "烈焰诀")
	_setup_chase_monster()
	_start_map_bgm()
	# 记下当前场景路径，存档/读档用
	var host := get_parent()
	GameData.current_scene_path = host.scene_file_path if host != get_tree().root else scene_file_path
#	DialogueManager.showStoryChat(load("res://Dialogue/chapter1.dialogue"),"start")

func _start_map_bgm() -> void:
	# 用 MainScene 的 BGM 节点播放，不自己新建
	_bgm_player = get_parent().get_node_or_null("BGM") as AudioStreamPlayer
	if _bgm_player:
		_bgm_player.bus = "BGM"
		if map_bgm != null:
			_bgm_player.stream = map_bgm
			_bgm_player.autoplay = true
			if not _bgm_player.playing:
				_bgm_player.play()


# ═══════════════════════════════════════
# 追踪怪 — 进图首波 + 定时重生，按地图怪物池选形象
# ═══════════════════════════════════════

@export var chase_monster_count: int = 1
@export var chase_spawn_interval: float = 60.0
@export var chase_min_dist: float = 500.0

func _setup_chase_monster() -> void:
	if chase_monster_count <= 0:
		return
	_spawn_chase_batch()
	_chase_spawn_timer = Timer.new()
	_chase_spawn_timer.one_shot = false
	_chase_spawn_timer.wait_time = chase_spawn_interval
	_chase_spawn_timer.timeout.connect(_spawn_chase_batch)
	add_child(_chase_spawn_timer)
	_chase_spawn_timer.start()


func _spawn_chase_batch() -> void:
	if GameData.in_battle or GameData.ui_blocked or GameData.is_dialogue_active():
		return
	var pool := _get_encounter_pool()
	if pool.is_empty():
		return

	var scene := load("res://scenes/World/chaseMonster.tscn")
	if not scene:
		push_error("无法加载 chaseMonster.tscn")
		return

	var player := get_player_node()
	var map_w := obs_size.x * obs_cp if obs_size.x > 0 else 3000
	var map_h := obs_size.y * obs_cp if obs_size.y > 0 else 3000

	for _i in range(chase_monster_count):
		# 从怪物池选一只（多只时尽量不同）
		var candidates: Array = pool.duplicate()
		if candidates.size() > 1 and _last_chase_monster in candidates:
			candidates.erase(_last_chase_monster)
		var monster_name: String = candidates[randi() % candidates.size()]
		_last_chase_monster = monster_name

		var was_dir := _lookup_was_dir(monster_name)
		if was_dir.is_empty():
			print("[追踪怪] 跳过 %s：无 was_base_path" % monster_name)
			continue

		var pos := _random_walkable_pos(map_w, map_h, player)
		if pos == Vector2.ZERO:
			continue

		var m = scene.instantiate()
		m.set_meta("was_dir", was_dir)
		m.global_position = pos
		m.scale *= actor_scale_multiplier
		add_child(m)


func _get_encounter_pool() -> Array:
	var cfg: Dictionary = GameData.ENCOUNTER_CONFIG.get(map_id, {})
	return cfg.get("pool", [])


func _lookup_was_dir(name: String) -> String:
	for row in EnemyDB.ENEMY_DB:
		if row.get("name", "") == name:
			return row.get("was_base_path", "").trim_suffix("/")
	var s := GameData.create_enemy(name)
	if s:
		return s.was_base_path.trim_suffix("/")
	return ""


func _random_walkable_pos(map_w: int, map_h: int, player: Node2D) -> Vector2:
	for _attempt in range(100):
		var px := randf_range(50, map_w - 50)
		var py := randf_range(50, map_h - 50)
		if player and Vector2(px, py).distance_to(player.global_position) < chase_min_dist:
			continue
		if obs_grid.size() > 0:
			var cx := int(px) / obs_cp
			var cy := int(py) / obs_cp
			if cx >= 0 and cy >= 0 and cx < obs_size.x and cy < obs_size.y:
				if obs_grid[cy * obs_size.x + cx] != 0:
					continue
		return Vector2(px, py)
	return Vector2.ZERO


## 追踪怪碰到主角 → 和暗雷完全一样的战斗
func _on_chase_caught(chaser: Node2D) -> void:
	if _encounter_active or GameData.in_battle or GameData.is_encounter_on_cooldown():
		return
	var cfg := _get_encounter_cfg()
	if cfg.is_empty():
		return
	var pool: Array = cfg.get("pool", [])
	if pool.is_empty():
		return
	# 先清理掉触碰的这一只
	chaser.queue_free()
	_trigger_encounter(pool, cfg)


func _cleanup_chasers() -> void:
	for c in get_children():
		if c is Node2D and c.has_meta("was_dir"):
			c.queue_free()

# ═══════════════════════════════════════
# MapViewerV2 — .map 文件加载与渲染
# ═══════════════════════════════════════

## 属性修改后延迟到安全时机刷新，同一帧的编辑合并为一次。
func _queue_editor_map_refresh() -> void:
	if not Engine.is_editor_hint() or not is_node_ready() or _editor_map_refresh_pending:
		return
	_editor_map_refresh_pending = true
	_refresh_editor_map.call_deferred()


func _refresh_editor_map() -> void:
	_editor_map_refresh_pending = false
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_clear_generated_map()
	_init_map_viewer()


func _clear_generated_map() -> void:
	for layer in [_map_layer, _mask_layer]:
		if is_instance_valid(layer):
			remove_child(layer)
			layer.queue_free()
	_map_layer = null
	_mask_layer = null
	_loader = null
	_map_width = 0
	_map_height = 0
	_colnum = 0
	_rownum = 0
	_mapnum = 0
	var fallback := get_node_or_null("BgShadow") as Sprite2D
	if fallback:
		fallback.hide()


func _init_map_viewer() -> void:
	if map_path.is_empty():
		return

	_loader = MapLoader.new()
	if not _loader.open(map_path):
		return
	_loader.load_all()

	var info: Dictionary = _loader.get_info()
	_map_width = info.width; _map_height = info.height
	_colnum = info.colnum; _rownum = info.rownum; _mapnum = info.mapnum

	_render_base_map()
	_init_map_masks()
	# 编辑器里只渲染地图图块，不跑障碍物/A*（没有 GameData 等 autoload）
	if Engine.is_editor_hint():
		return
	_build_obstacles_and_astar()


func _init_map_masks() -> void:
	if _loader.mask_num == 0:
		_show_fallback_mask()
		return

	var masks := MaskLayer.new()
	masks.name = "MapMasks"
	_mask_layer = masks
	add_child(masks)
	var fallback := get_node_or_null("BgShadow") as Sprite2D
	if fallback:
		fallback.hide()
		if fallback.texture or not fallback_mask_png.is_empty():
			masks.decode_failed.connect(_show_fallback_mask)
	masks.setup(_loader)


func _show_fallback_mask() -> void:
	var fallback := get_node_or_null("BgShadow") as Sprite2D
	if not fallback:
		return
	if not fallback.texture and not fallback_mask_png.is_empty() and ResourceLoader.exists(fallback_mask_png):
		fallback.texture = load(fallback_mask_png) as Texture2D
	if fallback.texture:
		if _mask_layer:
			_mask_layer.hide()
			_mask_layer.set_process(false)
		fallback.show()


## 分块渲染 — 每行一个条带，避免超 GPU 纹理上限
func _render_base_map() -> void:
	# 创建地图图层容器（独立 modulate，不影响 Player/Nav 等）
	if not _map_layer:
		_map_layer = Node2D.new()
		_map_layer.name = "MapLayer"
		_map_layer.z_index = -10
		add_child(_map_layer)

	const BW := 320; const BH := 240
	var rows_per_strip := maxi(1, 16384 / _map_width)
	for row0 in range(0, _rownum, rows_per_strip):
		var rh := mini(rows_per_strip, _rownum - row0) * BH
		var strip := Image.create(_map_width, rh, false, Image.FORMAT_RGBA8)
		strip.fill(Color(0, 0, 0, 0))
		for rid in range(row0, row0 + rows_per_strip):
			if rid >= _rownum: break
			for cid in range(_colnum):
				var bid := rid * _colnum + cid
				var img: Image = _loader.get_block_image(bid)
				if img == null: continue
				if img.get_format() != Image.FORMAT_RGBA8:
					img.convert(Image.FORMAT_RGBA8)
				strip.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()),
					Vector2i(cid * BW, (rid - row0) * BH))
		var s := Sprite2D.new()
		s.texture = ImageTexture.create_from_image(strip)
		s.centered = false
		s.position = Vector2(0, row0 * BH)
		s.name = "MapStrip_%d" % row0
		_map_layer.add_child(s)


## 构建障碍物网格 + AStarGrid2D（公开变量，MapWalker 通过 parent 读取）
func _build_obstacles_and_astar() -> void:
	var m2 := MapDataV2.new()
	m2.open(map_path)
	m2.load_obstacles()
	var gs := m2.get_obstacle_size()
	var g := m2.get_obstacle_grid()


	obs_grid = g
	obs_size = gs
	obs_cp = 20

	if show_obstacles:
		_render_obstacle_overlay(g, gs)

	# AStarGrid2D 用于鼠标点击寻路
	astar_grid = AStarGrid2D.new()
	astar_cell_size = 20
	astar_grid.region = Rect2i(0, 0, gs.x, gs.y)
	astar_grid.cell_size = Vector2i(20, 20)
	astar_grid.update()
	for y in gs.y:
		for x in gs.x:
			if g[y * gs.x + x] != 0:
				astar_grid.set_point_solid(Vector2i(x, y), true)


func _render_obstacle_overlay(_g: PackedByteArray, _gs: Vector2i) -> void:
	var cp := 20
	var mw := _gs.x * cp; var mh := _gs.y * cp
	var img := Image.create(mw, mh, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y in _gs.y:
		for x in _gs.x:
			if _g[y * _gs.x + x] != 0:
				for py in cp:
					for px in cp:
						img.set_pixel(x * cp + px, y * cp + py, Color(0, 0, 1, 0.35))
	var c := Node2D.new(); c.name = "ObstacleLayer"; c.z_index = 5; add_child(c)
	var s := Sprite2D.new(); s.texture = ImageTexture.create_from_image(img)
	s.centered = false; c.add_child(s)


func _count_solid(g: PackedByteArray, gs: Vector2i) -> int:
	var n := 0
	for i in g.size():
		if g[i] != 0: n += 1
	return n


## 根据时辰着色地图图层和遮罩图（MainScene 调用）
func set_day_tint(color: Color, immediate: bool = false) -> void:
	for layer: Node2D in [_map_layer, _mask_layer, get_node_or_null("BgShadow")]:
		if not layer:
			continue
		if immediate:
			layer.modulate = color
		else:
			var tw := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			tw.tween_property(layer, "modulate", color, 1.5)


# ═══════════════════════════════════════
# 出生点 / 相机
# ═══════════════════════════════════════

func get_spawn_point() -> Vector2:
	var marker = get_node_or_null("SpawnMarker") as Marker2D
	return marker.global_position if marker else Vector2.ZERO


func _set_camera_limits() -> void:
	var cam: Camera2D = _find_camera()
	if cam == null: return

	var tl = get_node_or_null("CameraLimitTL") as Marker2D
	var br = get_node_or_null("CameraLimitBR") as Marker2D
	if tl == null or br == null: return
	cam.limit_left = roundi(tl.global_position.x); cam.limit_top = roundi(tl.global_position.y)
	cam.limit_right = roundi(br.global_position.x); cam.limit_bottom = roundi(br.global_position.y)
	cam.reset_smoothing()
	cam.force_update_scroll()


func _find_camera() -> Camera2D:
	# 由宿主选择玩家 / 场景相机，单独运行地图时使用玩家相机。
	var host := get_parent()
	while host != null:
		if host.has_method("get_camera"):
			var host_camera: Camera2D = host.get_camera()
			if host_camera:
				return host_camera
		host = host.get_parent()
	var player = get_node_or_null("Player")
	if player:
		var cam = player.get_node_or_null("Camera2D") as Camera2D
		if cam: return cam
	# 从场景根开始找第一个 Camera2D
	var root := get_tree().current_scene
	if root:
		for c in root.find_children("*", "Camera2D", true, false):
			return c as Camera2D
	return null


func get_player_node() -> Node2D:
	var p = get_node_or_null("Player") as Node2D
	if p: return p
	for c in get_tree().get_nodes_in_group("player"): return c as Node2D
	return null


func add_encounter_step(dist: float) -> void:
	if _encounter_active or GameData.in_battle or GameData.is_encounter_on_cooldown():
		_encounter_step_accum = 0.0
		return
	var cfg = _get_encounter_cfg()
	if cfg.is_empty(): return
	var pool: Array = cfg.get("pool", [])
	if pool.is_empty(): return

	_encounter_step_accum += dist
	if _encounter_step_accum < GameData.ENCOUNTER_INTERVAL:
		return
	_encounter_step_accum = 0

	if _has_avoid_talent(): return
	if randf() >= GameData.ENCOUNTER_CHANCE: return

	_trigger_encounter(pool, cfg)


func _get_encounter_cfg() -> Dictionary:
	# 优先用导出变量 map_id
	if not map_id.is_empty():
		return GameData.ENCOUNTER_CONFIG.get(map_id, {})
	# 回退：通过场景文件名匹配
	var path = get_tree().current_scene.scene_file_path
	var name = path.get_file().trim_suffix(".tscn")
	return GameData.ENCOUNTER_CONFIG.get(name, {})


func _has_avoid_talent() -> bool:
	return GameData.talent_ranks.get("avoid_encounter", 0) > 0


func _trigger_encounter(pool: Array, cfg: Dictionary) -> void:
	if _encounter_active or GameData.in_battle or GameData.is_encounter_on_cooldown():
		return
	_encounter_active = true

	# 立即清除所有追踪怪
	_cleanup_chasers()

	var player = get_player_node()
	if player and player.has_method("set_process"):
		player.set_process(false)
		player.set_process_input(false)

	# 暂停地图 BGM
	if _bgm_player and is_instance_valid(_bgm_player):
		_bgm_player.stop()
	for c in get_tree().current_scene.get_children():
		if c is AudioStreamPlayer and c.bus == "BGM":
			c.stop()

	var min_count: int = cfg.get("min", 3)
	var max_count: int = min_count + 2
	var count = randi_range(min_count, max_count)
	count = clampi(count, 1, 8)

	var picked: Array[String] = []
	for i in count:
		picked.append(pool[randi() % pool.size()])

	# 入场特效 0→1 → 偷偷建战斗 → 同一实例反向 1→0 → 震屏冲击
	var bt := BattleTransition.play(get_tree().root)
	await bt.finished
	await _launch_battle(picked, player)
	await bt.reverse()
	# 找战斗场景，震它的 CanvasLayer offset
	var battle_scene := _find_battle_scene()
	if battle_scene:
		BattleTransition.shake_canvas(battle_scene, 14.0, 0.35)


func _launch_battle(picked, player: Node2D) -> CanvasLayer:
	GameData.in_battle = true
	var packed: PackedScene = await BattleAssets.scene_ready(get_tree())
	if packed == null:
		_restore_after_battle(null)
		return null
	player.visible = false
	# 隐藏地图上的 NPC
	for c in get_children():
		if c is NpcNode:
			c.visible = false

	var overlay = preload("res://scenes/Battle/BattleReturnOverlay.tscn").instantiate()
	get_tree().root.add_child(overlay)
	
	GameData.set_meta("pending_enemies", picked)
	if not GameData.has_meta("pending_party"):
		GameData.set_meta("pending_party", ["youxiaoyun", "dingdong"])
	var battle = packed.instantiate()
	battle.set_meta("return_overlay", overlay)
	get_tree().root.add_child(battle)

	battle.tree_exiting.connect(func():
		_battle_exit_transition(overlay)
	)
	battle.tree_exited.connect(func():
		if GameData.in_battle and not _battle_returning:
			_restore_after_battle(overlay)
	)
	return battle


func _find_battle_scene() -> CanvasLayer:
	for c in get_tree().root.get_children():
		if c.has_method("_ready") and c.get("battle_manager"):
			return c as CanvasLayer
	return null


func _battle_exit_transition(overlay: CanvasLayer) -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	_battle_returning = true
	# 保留原黑幕跨过战斗场景销毁，既不露出未恢复的地图，也不再播放第二次淡出。
	if is_instance_valid(overlay): overlay.hold_black()
	await get_tree().process_frame
	if not is_inside_tree() or is_queued_for_deletion(): return
	_restore_after_battle(null)
	if is_instance_valid(overlay): await overlay.reveal()
	_battle_returning = false


func _restore_after_battle(overlay: CanvasLayer) -> void:
	# 战斗节点在应用退出时同样会发出 tree_exited，无需恢复正在销毁的地图。
	if not is_inside_tree() or is_queued_for_deletion(): return
	GameData.start_encounter_cooldown()
	_encounter_step_accum = 0.0
	GameData.in_battle = false
	_encounter_active = false
	GameData.remove_meta("pending_enemies")
	_cleanup_chasers()
	$"../BGM".volume_db = 0
	# 恢复地图 BGM（重启所有被停止的 BGM 播放器）
	if _bgm_player and is_instance_valid(_bgm_player) and not _bgm_player.playing:
		_bgm_player.play()
	#for c in get_tree().current_scene.get_children():
		#if c is AudioStreamPlayer and c.bus == "BGM" and not c.playing:
			#c.play()
			
	# 恢复 BGM 总线音量
	var bgm_bus = AudioServer.get_bus_index("BGM")
	if bgm_bus >= 0:
		AudioServer.set_bus_volume_db(bgm_bus, 0)

	# 重新获取 player 引用，不依赖 lambda 捕获（可能已失效）
	var player := get_player_node()
	if player:
		player.set_process(true)
		player.set_process_input(true)
		player.visible = true
		# 恢复地图上的 NPC
		for c in get_children():
			if c is NpcNode:
				c.visible = true
	else:
		push_error("[战斗] 找不到 Player 节点！")

	if is_instance_valid(overlay):
		overlay.queue_free()

	# 通知自动存档
	GameData.battle_ended_for_save.emit()
