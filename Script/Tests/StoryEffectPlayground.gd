extends Node2D
## 测试选单来自 StoryEffectDB.PREVIEWS，调用独立 StoryDirector，复用正式演出实现。
@export var effect_settings: Resource = preload("res://Resources/StoryEffects/GoldenTalismanBurst.tres")
@export var initial_preview: String = "金符蓄力"
@export var playground_settings: Resource = preload("res://Resources/StoryEffects/PlaygroundSettings.tres")
@export var auto_play: bool = true
const Registry = preload("res://Script/Data/Dialogue/StoryEffectDB.gd")
const DirectorScene = preload("res://scenes/World/StoryDirector.tscn")
const FIELDS = {"Count":"count", "Charge":"charge_duration", "Height":"column_height", "Radius":"radius", "Speed":"orbit_speed", "Batches":"batch_count", "Interval":"batch_interval", "Shake":"release_shake", "Short":"min_rune_length", "Long":"max_rune_length"}
var _playing := false
var _director: Node2D
var _effect: Node2D:
	get: return _director._active_effect if is_instance_valid(_director) else null
var _generation := 0
var _stopped := false
var _closed := false
var _preview_keys: Array = []
var _selected: String = ""
@onready var controls: GridContainer = $UI/Panel/Body/ParameterScroll/Fields
@onready var status: Label = $UI/Panel/Body/Status
@onready var selector: OptionButton = $UI/Panel/Body/Selector

func _ready() -> void:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0,0,65,40)
	grid.cell_size = Vector2(20,20)
	grid.update()
	$Player._astar = grid
	$Target._astar = grid
	$Player._cell_size = 20
	$Target._cell_size = 20
	$UI/Panel/Body/Buttons/Play.pressed.connect(play_effect)
	$UI/Panel/Body/Buttons/Stop.pressed.connect(stop_effect)
	$UI/Panel/Body/Reset.pressed.connect(reset_settings)
	$UI/Panel/Body/Save.pressed.connect(save_settings)
	controls.get_node("Distance").value_changed.connect(_set_distance)
	_preview_keys = Registry.PREVIEWS.keys()
	for key in _preview_keys: selector.add_item(str(key))
	selector.item_selected.connect(select_preview)
	reset_settings()
	var saved_preview: String = playground_settings.preview
	var index := maxi(0, _preview_keys.find(saved_preview if _preview_keys.has(saved_preview) else initial_preview))
	selector.select(index)
	select_preview(index)
	if auto_play: play_effect.call_deferred()

func select_preview(index: int) -> void:
	if _playing or index < 0 or index >= _preview_keys.size(): return
	_selected = str(_preview_keys[index])
	selector.select(index)
	_generation += 1
	var data: Dictionary = Registry.PREVIEWS[_selected]
	var golden: bool = data.get("parameters", "") == "golden"
	for field in FIELDS:
		controls.get_node(field).visible = golden
		controls.get_node(field + "Label").visible = golden
	$UI/Panel/Body/ParameterScroll.custom_minimum_size.y = 280 if golden else 45
	$UI/Panel/Body/Shaking.visible = golden
	$UI/Panel/Body/Description.text = data.get("description", "")
	status.text = "已选择：" + _selected

func reset_settings() -> void:
	for field in FIELDS: controls.get_node(field).value = effect_settings.get(FIELDS[field])
	controls.get_node("Distance").value = playground_settings.target_distance
	$UI/Panel/Body/Swap.button_pressed = playground_settings.swap_actors
	$UI/Panel/Body/Loop.button_pressed = playground_settings.loop_playback
	$UI/Panel/Body/Shaking.button_pressed = effect_settings.shake_enabled
	if not _playing: _reset_positions()

## 显式写回独立资源，运行中的一轮演出仍使用其原来的副本。
func _write_resource(candidate: Resource, destination: Resource) -> Error:
	var path := destination.resource_path
	if not path.begins_with("res://") or not path.ends_with(".tres") or path.contains("::"):
		return ERR_INVALID_PARAMETER
	return ResourceSaver.save(candidate, path)

func save_settings() -> bool:
	var saved_effect := false
	if Registry.PREVIEWS.get(_selected, {}).get("parameters", "") == "golden":
		var candidate = effect_settings.duplicate(true)
		for field in FIELDS: candidate.set(FIELDS[field], controls.get_node(field).value)
		candidate.shake_enabled = $UI/Panel/Body/Shaking.button_pressed
		var error := _write_resource(candidate,effect_settings)
		if error != OK:
			status.text = "演出参数保存失败：" + error_string(error)
			return false
		# 同步本进程的已加载资源；未在面板显示的参数保持不变。
		for field in FIELDS: effect_settings.set(FIELDS[field],candidate.get(FIELDS[field]))
		effect_settings.shake_enabled = candidate.shake_enabled
		effect_settings.emit_changed()
		saved_effect = true
	var layout = playground_settings.duplicate(true)
	layout.preview = _selected
	layout.target_distance = controls.get_node("Distance").value
	layout.swap_actors = $UI/Panel/Body/Swap.button_pressed
	layout.loop_playback = $UI/Panel/Body/Loop.button_pressed
	var error := _write_resource(layout,playground_settings)
	if error != OK:
		status.text = ("演出参数已保存；" if saved_effect else "") + "测试设置保存失败：" + error_string(error)
		return false
	for key in ["preview","target_distance","swap_actors","loop_playback"]:
		playground_settings.set(key,layout.get(key))
	playground_settings.emit_changed()
	status.text = "已写入演出资源和测试设置，下次打开继续使用" if saved_effect else "测试设置已保存"
	return true

func _set_distance(value: float) -> void:
	if _playing: return
	$Target.position = $Player.position + Vector2(value,0)
	$DistanceLine.points = PackedVector2Array([$Player.position + Vector2(0,16), $Target.position + Vector2(0,16)])

func _reset_positions() -> void:
	$Player.position = $CasterStart.position
	_set_distance(controls.get_node("Distance").value)

func _args(values: Array, settings: Resource) -> Array:
	var args: Array = []
	for value in values:
		if value is String and value == "$施术者": args.append("施术者")
		elif value is String and value == "$目标": args.append("目标")
		elif value is String and value == "$参数": args.append(settings)
		else: args.append(value)
	return args

func _run_steps(steps: Array, settings: Resource) -> bool:
	for step in steps:
		if _stopped or _closed: return false
		var method: String = step.get("method", "")
		if not _director.has_method(method): return false
		status.text = "播放：%s" % _selected
		var result = await _director.callv(method, _args(step.get("args", []),settings))
		if _stopped or (result is bool and not result): return false
	return true

func play_effect() -> void:
	if _playing or _closed or _selected.is_empty(): return
	_reset_positions()
	_playing = true
	_stopped = false
	_generation += 1
	var generation := _generation
	var settings = effect_settings.duplicate(true)
	for field in FIELDS: settings.set(FIELDS[field], controls.get_node(field).value)
	settings.shake_enabled = $UI/Panel/Body/Shaking.button_pressed
	$UI/Panel/Body/Buttons/Play.disabled = true
	$UI/Panel/Body/Buttons/Stop.disabled = false
	selector.disabled = true
	_director = DirectorScene.instantiate()
	$Effects.add_child(_director)
	var swapped: bool = $UI/Panel/Body/Swap.button_pressed
	_director.actor_overrides = {"施术者": $Target if swapped else $Player, "目标": $Player if swapped else $Target}
	_director.effect_batch_released.connect(func(batch: int): status.text = "第 %d / %d 批发射" % [batch+1,settings.batch_count])
	var previous_block: bool = GameData.ui_blocked
	var success := await _run_steps(Registry.PREVIEWS[_selected].get("steps", []),settings)
	if _closed: return
	GameData.ui_blocked = previous_block
	for actor in [$Player,$Target]:
		actor.set("_click_path",PackedVector2Array())
		actor.get_node("Sprite2D").modulate = Color.WHITE
		actor.get_node("WASAnimationPlayer").play("idle")
	_director.queue_free()
	_director = null
	_playing = false
	selector.disabled = false
	$UI/Panel/Body/Buttons/Play.disabled = false
	$UI/Panel/Body/Buttons/Stop.disabled = true
	status.text = "播放结束：" + _selected if success else "已停止，镜头已复位"
	if $UI/Panel/Body/Loop.button_pressed and not _stopped:
		await get_tree().create_timer(0.6).timeout
		if not _closed and generation == _generation and not _stopped and $UI/Panel/Body/Loop.button_pressed:
			play_effect.call_deferred()

func stop_effect() -> void:
	_stopped = true
	_generation += 1
	if is_instance_valid(_director): _director.cancel_test_action()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.keycode == KEY_SPACE:
			play_effect()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			stop_effect()
			get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	_closed = true
	stop_effect()
