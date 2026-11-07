extends Node2D
signal finished(success: bool)
signal released
signal batch_released(batch_index: int)
signal batch_hit(batch_index: int)
const PaperScene = preload("res://scenes/Effects/GoldenTalisman.tscn")
var config: Resource
var _source: Node2D
var _target: Node2D
var _papers: Array[Node2D] = []
var _starts: Array[Vector2] = []
var _launched: Array[bool] = []
var _speeds: Array[float] = []
var _lengths: Array[float] = []
var _time := 0.0
var _released := false
var _done := false
var _shake_camera: Camera2D
var _last_shake := Vector2.ZERO
var _batches_fired: int = 0
var _batches_hit: int = 0
var _last_burst_time: float = -100.0

func _ready() -> void:
	set_process(false)

func play(source: Node2D, target: Node2D, settings: Resource) -> bool:
	_source = source
	_target = target
	config = settings
	if not is_instance_valid(source) or not is_instance_valid(target): return false
	# 只拒绝无法计算的参数，不擅自截断数量、尺寸或速度。
	if config.count < 1 or config.orbit_lanes < 1 or config.batch_count < 1 or config.flight_duration <= 0 or config.burst_shake_duration <= 0 or config.charge_duration < 0 or config.batch_interval < 0 or config.launch_interval < 0:
		push_warning("演出参数无效：数量/轨道/批数必须为正，飞行和震动时长必须大于零，等待时间不能为负。")
		return false
	for i in config.count:
		# 数量由演出配置决定，复用预制符纸场景；没有运行时拼装固定界面。
		var paper = PaperScene.instantiate()
		add_child(paper)
		var rune = paper.get_node("Rune")
		rune.variant = i % 8
		rune.tint = config.gold
		var length := lerpf(config.min_rune_length, config.max_rune_length, fposmod(i * 0.569840291, 1.0))
		_lengths.append(length)
		# 固定的个体长短保存在符文本身，环绕和齐射时均保持，不随透视乱变。
		rune.scale = Vector2(lerpf(0.85, 1.08, fposmod(i * 0.438579, 1.0)), length) * config.paper_height / 50.0
		rune.queue_redraw()
		var lane_count := mini(config.orbit_lanes, config.count)
		_speeds.append(lerpf(minf(config.slow_speed_multiplier, config.fast_speed_multiplier), maxf(config.slow_speed_multiplier, config.fast_speed_multiplier), float(i % lane_count) / maxf(1.0, lane_count - 1)))
		_papers.append(paper)
		_starts.append(Vector2.ZERO)
		_launched.append(false)
	set_process(true)
	var success: bool = await finished
	return success

func _lane_count() -> int:
	return mini(config.orbit_lanes, _papers.size()) # 每条轨道至少有一个符文。

func _height_phase(i: int, time: float) -> float:
	var lanes := _lane_count()
	var lane := i % lanes
	var slot := floori(float(i) / lanes)
	var slots := ceili(float(_papers.size() - lane) / lanes)
	return fposmod((lane + float(slot) / slots) / lanes + time * config.rise_speed, 1.0)

func _phase(i: int, time: float) -> float:
	var lanes := _lane_count()
	var lane := i % lanes
	var slots := ceili(float(_papers.size() - lane) / lanes)
	var slot := floori(float(i) / lanes)
	return TAU * slot / slots + lane * 0.37 + time * config.orbit_speed * _speeds[i]

func _orbit(i: int, time: float) -> Vector2:
	var phase := _phase(i, time)
	var ring: float = lerpf(0.65, 1.15, fposmod((i % _lane_count()) * 0.61803398875, 1.0))
	var appear := smoothstep(0.0, 0.65, time)
	var radius: float = config.radius * ring * (1.4 - appear * 0.4)
	var height_phase := _height_phase(i, time)
	return _source.global_position + config.actor_offset + Vector2(sin(phase) * radius * (1.0 + cos(phase) * config.perspective), 32.0 - height_phase * config.column_height + cos(phase) * radius * config.orbit_depth)

func _batch_total() -> int:
	return mini(config.batch_count, _papers.size()) # 每批至少发射一个符文。

func _launch_delay(i: int) -> float:
	return (i % _batch_total()) * config.batch_interval + floorf(float(i) / _batch_total()) * config.launch_interval

func _last_launch_delay() -> float:
	var last := 0.0
	for i in _papers.size(): last = maxf(last, _launch_delay(i))
	return last

func _process(delta: float) -> void:
	if not is_instance_valid(_source) or not is_instance_valid(_target):
		_end(false)
		return
	_time += delta
	_update_actor_occlusion("Sprite2D", $CasterOcclusion)
	_update_actor_occlusion("WeaponSprite", $WeaponOcclusion)
	if _time >= config.charge_duration and not _released:
		_released = true
		released.emit()
	while _batches_fired < _batch_total() and _time >= config.charge_duration + _batches_fired * config.batch_interval:
		_last_burst_time = _time
		$ReleaseSound.play()
		batch_released.emit(_batches_fired)
		_batches_fired += 1
	# 与命中光圈的起始时刻同步，战斗可按批次结算伤害，剧情无需绑定。
	while _batches_hit < _batch_total() and _time >= config.charge_duration + _batches_hit * config.batch_interval + config.flight_duration * 0.8:
		batch_hit.emit(_batches_hit)
		_batches_hit += 1
	_update_ground_shake()
	for i in _papers.size():
		var paper := _papers[i]
		var flight_time: float = _time - config.charge_duration - _launch_delay(i)
		if flight_time < 0:
			paper.global_position = _orbit(i, _time)
			var phase := _phase(i, _time)
			var depth := cos(phase)
			var near := (depth + 1.0) * 0.5
			# 正面宽、侧面窄；近大远小与椭圆轨道共用相位，形成绕柱旋转而非横移。
			var face_width := lerpf(config.min_side_width, 1.0, absf(depth))
			paper.rotation = sin(phase) * 0.09
			paper.scale = config.rune_stretch * lerpf(0.72, 1.16, near) * Vector2(face_width, 1.0)
			paper.z_index = 3 if depth >= 0.0 else 1
			paper.modulate.a = smoothstep(i * 0.008, 0.6 + i * 0.008, _time) * lerpf(config.far_opacity, 1.0, near)
			var height_phase := _height_phase(i, _time)
			paper.modulate.a *= smoothstep(0.0, 0.06, height_phase) * (1.0 - smoothstep(0.94, 1.0, height_phase))
		else:
			if not _launched[i]:
				paper.z_index = 4
				_starts[i] = _orbit(i, _time)
				_launched[i] = true
			var t := clampf(flight_time / config.flight_duration, 0.0, 1.0)
			var destination: Vector2 = _target.global_position + config.target_offset
			var start := _starts[i]
			var control := start.lerp(destination, 0.5) + Vector2(0, -40.0 - (i % 5) * 12.0)
			var eased := t # 齐射使用匀速推进，避免开头缓慢漂出。
			paper.global_position = start * pow(1.0-eased, 2) + control * 2.0 * (1.0-eased) * eased + destination * eased * eased
			paper.rotation = (destination - paper.global_position).angle() + PI / 2.0
			paper.modulate.a = 1.0 - smoothstep(0.82, 1.0, t)
			paper.scale = config.rune_stretch * Vector2(0.9 - t * 0.35, 1.0 + t * 0.45)
	queue_redraw()
	if _time > config.charge_duration + _last_launch_delay() + config.flight_duration + 0.35:
		_end(true)

## 将施术者当前动画帧夹在远侧和近侧符文之间，不改变角色原本的层级或可见性。
func _update_actor_occlusion(node_name: String, proxy: Sprite2D) -> void:
	var original := _source.get_node_or_null(node_name) as Sprite2D
	if original == null or not original.is_visible_in_tree() or original.texture == null:
		proxy.hide()
		return
	proxy.texture = original.texture
	proxy.centered = original.centered
	proxy.offset = original.offset
	proxy.region_enabled = original.region_enabled
	proxy.region_rect = original.region_rect
	proxy.hframes = original.hframes
	proxy.vframes = original.vframes
	proxy.frame = original.frame
	proxy.flip_h = original.flip_h
	proxy.flip_v = original.flip_v
	proxy.modulate = original.modulate * original.self_modulate
	proxy.global_transform = original.global_transform
	proxy.show()

func _draw() -> void:
	if config == null or not is_instance_valid(_source) or not is_instance_valid(_target): return
	var center := to_local(_source.global_position + config.actor_offset)
	var gold: Color = config.gold
	var charge := smoothstep(0.0, 0.7, _time) * (1.0 - smoothstep(config.charge_duration, config.charge_duration + 0.5, _time))
	for i in range(6, 0, -1):
		draw_circle(center, 14.0 + i * 8.0, Color(gold, charge * 0.018))
	var ring := PackedVector2Array()
	for i in range(65):
		var angle := TAU * i / 64.0
		ring.append(to_local(_source.global_position) + Vector2(cos(angle) * config.radius, sin(angle) * config.radius * 0.38))
	draw_polyline(ring, Color(gold, charge * 0.4), 1.4, true)
	for i in _papers.size():
		if _launched[i] and _papers[i].modulate.a > 0.01:
			var point := to_local(_papers[i].global_position)
			var direction := (to_local(_target.global_position + config.target_offset) - point).normalized()
			draw_line(point - direction * 28.0, point, Color(gold, 0.35 * _papers[i].modulate.a), 2.0, true)
	for batch in _batch_total():
		var hit_time: float = _time - config.charge_duration - batch * config.batch_interval - config.flight_duration * 0.8
		if hit_time < 0 or hit_time > 0.22: continue
		var destination := to_local(_target.global_position + config.target_offset)
		var alpha := sin(hit_time / 0.22 * PI)
		for i in range(5, 0, -1): draw_circle(destination, 8.0 + i * 7.0, Color(1, 0.82, 0.3, alpha * 0.045))
		draw_arc(destination, 20.0 + hit_time * 120.0, 0, TAU, 48, Color(1, 0.87, 0.4, alpha * 0.65), 2.0, true)

## 仅叠加摄像机偏移，地图、碰撞和人物坐标保持原样，UI 不参与震动。
func _update_ground_shake() -> void:
	if not config.shake_enabled:
		_restore_camera()
		return
	var current := get_viewport().get_camera_2d()
	if current != _shake_camera:
		_restore_camera()
		_shake_camera = current
	if not is_instance_valid(_shake_camera): return
	var amplitude: float
	if _time < config.charge_duration:
		amplitude = config.charge_shake * smoothstep(0.0, config.charge_duration, _time)
	else:
		var since_release: float = _time - _last_burst_time
		amplitude = config.release_shake * pow(maxf(0.0, 1.0 - since_release / config.burst_shake_duration), 2.0)
	var phase: float = (_time if _time < config.charge_duration else _time - _last_burst_time) * TAU * config.shake_frequency + PI / 2.0
	var wave := Vector2(sin(phase * 0.83) * 0.6, (sin(phase) + sin(phase * 1.37) * 0.35) * 0.74)
	var next := wave * amplitude
	_shake_camera.offset += next - _last_shake
	_last_shake = next

func _restore_camera() -> void:
	if is_instance_valid(_shake_camera): _shake_camera.offset -= _last_shake
	_last_shake = Vector2.ZERO
	_shake_camera = null

func _exit_tree() -> void:
	_restore_camera()

func cancel() -> void:
	_end(false)

func _end(success: bool) -> void:
	if _done: return
	_done = true
	_restore_camera()
	set_process(false)
	finished.emit(success)
