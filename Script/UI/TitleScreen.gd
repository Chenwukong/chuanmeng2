extends CanvasLayer
## 仙雾铺满时装入世界，散完才交还输入。固定视觉节点均在场景中。
signal closed
@export_file("*.tscn") var game_scene := "res://scenes/UI/TitleMenu.tscn"
@export var preview_only := false
@export var impact_shake := 9.0
@export var throw_origin := Vector2(330, -245)
@export var throw_control := Vector2(250, -285)
@export var sword_landing := Vector2(-140, 185)
@export_range(15.0, 70.0) var landing_angle_degrees := 43.0
var elapsed := 0.0
var _transitioning := false
var _impact_played := false
var _chime_played := false
var _fog_played := false
var _window_restored := false
var _old_borderless := false
var _old_transparent := false
var _old_transparent_bg := false
var _startup_intro := false
var _world: Node

static func show_at(parent: Node) -> CanvasLayer:
	var instance = load("res://scenes/TitleScreen.tscn").instantiate()
	parent.add_child(instance)
	return instance

func _ready() -> void:
	var window := get_tree().root
	_startup_intro = not preview_only and get_parent() == window
	_old_borderless = window.borderless
	_old_transparent = window.transparent
	_old_transparent_bg = window.transparent_bg
	if window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		window.transparent_bg = true
		window.transparent = true
		window.borderless = true
	if not preview_only:
		ResourceLoader.load_threaded_request(game_scene)
	$Whoosh.play()
	_render_opening(0.0)

func _process(delta: float) -> void:
	elapsed += delta
	$Mist.material.set_shader_parameter("phase", elapsed)
	if _transitioning: return
	_render_opening(elapsed)
	if elapsed >= 0.65 and not _impact_played:
		_impact_played = true
		$Impact.play()
	if elapsed >= 1.0 and not _chime_played:
		_chime_played = true
		$Chime.play()
	if elapsed >= 1.1 and not _fog_played:
		_fog_played = true
		$Wind.play()
	if elapsed >= 4.2 and not preview_only:
		_enter_game()

func _render_opening(time: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var fit := minf(viewport_size.x / 1300.0, viewport_size.y / 800.0)
	$Composition.position = viewport_size * 0.5
	$Composition.scale = Vector2.ONE * fit
	var flight := clampf((time - 0.15) / 0.5, 0.0, 1.0)
	# 按深度投影放大：最后一段迅速逼近镜头。
	var approach := (1.0 / lerpf(8.0, 1.0, flight) - 0.125) / 0.875
	var sword := $Composition/Sword
	# 以剑尖为落点，先在远处掠出弧线，再加速斜向掷入；落地后围绕剑尖回弹。
	sword.scale = Vector2.ONE * lerpf(0.08, 1.06, approach)
	sword.position = _throw_tip(approach)
	sword.rotation = lerpf(1.18, deg_to_rad(landing_angle_degrees), smoothstep(0.0, 1.0, flight))
	sword.modulate.a = smoothstep(0.0, 0.18, flight)
	sword.material.set_shader_parameter("pitch", lerpf(1.18, 0.18, pow(flight, 2.0)))
	sword.material.set_shader_parameter("roll", lerpf(-1.12, 0.25, smoothstep(0.0, 1.0, flight)))
	sword.material.set_shader_parameter("gleam", smoothstep(0.2, 0.95, flight))
	var trail_points := PackedVector2Array()
	for i in 14:
		var previous := clampf(flight - (13-i) * 0.018, 0.0, 1.0)
		var previous_depth := (1.0 / lerpf(8.0, 1.0, previous) - 0.125) / 0.875
		var previous_scale := lerpf(0.08, 1.06, previous_depth)
		var previous_angle := lerpf(1.18, deg_to_rad(landing_angle_degrees), smoothstep(0.0, 1.0, previous))
		var previous_pitch := lerpf(1.18, 0.18, pow(previous, 2.0))
		var projected_length := -620.0 * cos(previous_pitch) * 550.0 / (550.0 + 620.0 * sin(previous_pitch))
		trail_points.append(_throw_tip(previous_depth) + Vector2(0, projected_length).rotated(previous_angle) * previous_scale)
	$Composition/SwordTrail.points = trail_points
	$Composition/SwordTrail.modulate.a = smoothstep(0.35, 0.8, flight) * (1.0-smoothstep(0.65,0.78,time))
	var hit_age := time - 0.65
	if hit_age >= 0.0:
		sword.rotation += sin(hit_age * 32.0) * exp(-hit_age * 10.0) * 0.065
		sword.material.set_shader_parameter("pitch", 0.18 + sin(hit_age * 35.0) * exp(-hit_age * 12.0) * 0.15)
		var shake := impact_shake * exp(-hit_age * 7.5)
		$Composition.position += Vector2(sin(hit_age * 99.0), cos(hit_age * 83.0)) * shake * fit
		$Composition/Halo.scale = Vector2.ONE * (0.25 + hit_age * 1.65)
		$Composition/Halo.modulate.a = 1.0 - smoothstep(1.8, 3.8, hit_age)
	else:
		$Composition/Halo.modulate.a = 0.0
	$Composition/Halo.position = sword_landing - Vector2(300,300)
	var title_amount := smoothstep(1.0, 1.7, time)
	$Composition/Logo.modulate.a = title_amount * (1.0 - smoothstep(3.5, 4.3, time))
	$Composition/Logo.position.y = lerpf(22.0, 0.0, title_amount)
	$Composition/Logo.scale = Vector2.ONE * lerpf(1.08, 1.0, title_amount)
	$Composition/Sword.modulate.a *= 1.0-smoothstep(3.5,4.3,time)
	# 涟漪仍在扩散时先卷入薄雾，再连续增浓，标题展示期间不留静止空档。
	var mist_coverage := 0.28 * smoothstep(0.9,1.7,time) + 0.72 * smoothstep(1.7,4.2,time)
	$Mist.material.set_shader_parameter("coverage", mist_coverage)

func _throw_tip(amount: float) -> Vector2:
	return throw_origin.lerp(throw_control, amount).lerp(throw_control.lerp(sword_landing, amount), amount)

func _input(event: InputEvent) -> void:
	if PlatformControls.handle_fullscreen_shortcut(event): return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()

func _restore_window() -> void:
	if _window_restored: return
	_window_restored = true
	var window := get_tree().root
	window.transparent_bg = false if _startup_intro else _old_transparent_bg
	window.transparent = false if _startup_intro else _old_transparent
	# 全屏本身没有边框。退出全屏后，系统设置仍能切回普通窗口。
	window.borderless = false if _startup_intro else _old_borderless

func _enter_game() -> void:
	_transitioning = true
	$Mist.material.set_shader_parameter("coverage", 1.0)
	await get_tree().process_frame
	var status := ResourceLoader.load_threaded_get_status(game_scene)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(game_scene)
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		$LoadError.show()
		push_error("开场无法加载主场景：" + game_scene)
		_restore_window()
		return
	var packed := ResourceLoader.load_threaded_get(game_scene) as PackedScene
	_world = packed.instantiate()
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	_restore_window()
	$Composition.hide()
	await get_tree().process_frame
	var reveal := create_tween()
	reveal.tween_method(func(value: float): $Mist.material.set_shader_parameter("coverage", value), 1.0, 0.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal.parallel().tween_property($Wind, "volume_db", -40.0, 2.2)
	await reveal.finished
	_world.process_mode = Node.PROCESS_MODE_INHERIT
	closed.emit()
	queue_free()

func _exit_tree() -> void:
	_restore_window()

