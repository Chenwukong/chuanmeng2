extends Node
## 将手柄动作接到已有的键盘导航入口，菜单、对话和战斗共用同一套状态机。
signal mode_changed
const DEADZONE := 0.3
const FIRST_REPEAT := 0.35
const REPEAT_INTERVAL := 0.12
var active := false
var _held: Dictionary = {}
var _repeat: Dictionary = {}
var _stick := Vector2.ZERO
var _stick_device := -1
var move_vector: Vector2:
	get:
		var direction := Vector2.ZERO
		var keys: Array = []
		for source in _held:
			if ":a" in source: continue
			var value: Dictionary = _held[source]
			if value.key not in keys: keys.append(value.key)
		if KEY_LEFT in keys: direction.x -= 1
		if KEY_RIGHT in keys: direction.x += 1
		if KEY_UP in keys: direction.y -= 1
		if KEY_DOWN in keys: direction.y += 1
		if not direction.is_zero_approx(): return direction.limit_length()
		var strength := clampf((_stick.length() - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
		return _stick.normalized() * strength

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_connection_changed)
	get_window().focus_exited.connect(release_all)

func _mode(value: bool) -> void:
	if active == value: return
	active = value
	mode_changed.emit()

func _send(key: int, pressed: bool, alt: bool = false) -> void:
	var event := InputEventKey.new()
	event.device = 0
	event.set_meta("gamepad_synthetic", true)
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	event.alt_pressed = alt
	# 不在原手柄事件的分发栈内重新派发，避免一次按键触发两次确认。
	_dispatch.call_deferred(event)

func _dispatch(event: InputEventKey) -> void:
	# 战斗快捷键先走既有指令入口，避免 W/A/E 被聚焦按钮当作方向键吞掉。
	if event.alt_pressed and GameData.in_battle:
		for child in get_tree().root.get_children():
			if child.has_node("BattleUI"):
				child.get_node("BattleUI")._unhandled_input(event)
				return
	get_viewport().push_input(event)

func _source(source: String, key: int, pressed: bool, alt: bool = false) -> void:
	if pressed:
		if _held.has(source): return
		var already := _held.values().any(func(value): return value.key == key and value.alt == alt)
		_held[source] = {"key": key, "alt": alt}
		if already: return
		_send(key, true, alt)
		if key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]: _repeat[key] = FIRST_REPEAT
	elif _held.has(source):
		var value: Dictionary = _held[source]
		_held.erase(source)
		if _held.values().any(func(other): return other.key == value.key and other.alt == value.alt): return
		_repeat.erase(value.key)
		_send(value.key, false, value.alt)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.has_meta("gamepad_synthetic") and event.pressed:
		_mode(false)
		return
	if event is InputEventMouseMotion and event.relative.length_squared() > 4.0:
		_mode(false)
		return
	if event is InputEventJoypadButton:
		if event.pressed: _mode(true)
		var key := 0
		var alt := false
		match event.button_index:
			JOY_BUTTON_A: key = KEY_ENTER
			JOY_BUTTON_B: key = KEY_ESCAPE
			JOY_BUTTON_X: key = KEY_TAB
			JOY_BUTTON_Y:
				key = KEY_W if GameData.in_battle else KEY_R
				alt = GameData.in_battle
			JOY_BUTTON_START: key = KEY_TAB
			JOY_BUTTON_BACK: key = KEY_F3
			JOY_BUTTON_LEFT_SHOULDER: key = KEY_Q
			JOY_BUTTON_RIGHT_SHOULDER: key = KEY_E
			JOY_BUTTON_DPAD_UP: key = KEY_UP
			JOY_BUTTON_DPAD_DOWN: key = KEY_DOWN
			JOY_BUTTON_DPAD_LEFT: key = KEY_LEFT
			JOY_BUTTON_DPAD_RIGHT: key = KEY_RIGHT
		if key != 0:
			get_viewport().set_input_as_handled()
			_source("%d:b%d" % [event.device, event.button_index], key, event.pressed, alt)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > DEADZONE: _mode(true)
		var prefix := "%d:a%d" % [event.device, event.axis]
		if event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
			get_viewport().set_input_as_handled()
			_stick_device = event.device
			if event.axis == JOY_AXIS_LEFT_X: _stick.x = event.axis_value
			else: _stick.y = event.axis_value
			var negative := KEY_LEFT if event.axis == JOY_AXIS_LEFT_X else KEY_UP
			var positive := KEY_RIGHT if event.axis == JOY_AXIS_LEFT_X else KEY_DOWN
			_source(prefix + "-", negative, event.axis_value < -DEADZONE)
			_source(prefix + "+", positive, event.axis_value > DEADZONE)
		elif event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			get_viewport().set_input_as_handled()
			var key := KEY_E if event.axis == JOY_AXIS_TRIGGER_LEFT else KEY_A
			_source(prefix, key, GameData.in_battle and event.axis_value > 0.6, true)

func _process(delta: float) -> void:
	for key in _repeat.keys():
		_repeat[key] -= delta
		if _repeat[key] <= 0.0:
			_repeat[key] = REPEAT_INTERVAL
			_send(key, true)

func release_all() -> void:
	for source in _held.keys(): _source(source, 0, false)
	_repeat.clear()
	_stick = Vector2.ZERO

func _connection_changed(device: int, connected: bool) -> void:
	if connected: return
	if device == _stick_device: _stick = Vector2.ZERO
	for source in _held.keys():
		if source.begins_with(str(device) + ":"): _source(source, 0, false)
	if Input.get_connected_joypads().is_empty(): _mode(false)
