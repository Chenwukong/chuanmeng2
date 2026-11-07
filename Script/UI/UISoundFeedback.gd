extends Node
## 播放器固定在 MainScene/UI/UISounds；补齐界面反馈，不覆盖已有专用音效。

var _pending: StringName = &""
var _players: Array[WeakRef] = []
var _last_kind: StringName = &""
var _last_at: int = -1000
var played_count := 0
var last_played: StringName = &""

static func play_ui(kind: StringName = &"confirm") -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null: return
	var router := tree.current_scene.get_node_or_null("UI/UISounds")
	if router: router.request(kind)

static func bind_control(control: Control) -> void:
	var tree := control.get_tree()
	if tree.current_scene == null: return
	var router := tree.current_scene.get_node_or_null("UI/UISounds")
	if router: router.bind(control)

func _ready() -> void:
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "SFX")
	for player in get_children():
		if player is AudioStreamPlayer: player.bus = &"SFX"
	for player in get_tree().root.find_children("*", "AudioStreamPlayer", true, false): _track(player)
	get_tree().node_added.connect(_track)

func _track(node: Node) -> void:
	if node is AudioStreamPlayer and not is_ancestor_of(node): _players.append(weakref(node))

func bind(control: Control) -> void:
	if control.get_meta("ui_sound_bound", false): return
	control.set_meta("ui_sound_bound", true)
	# 悬停仅更新视觉反馈，不播放音效。
	if control is BaseButton:
		var title := str(control.name).to_lower()
		var kind: StringName = &"confirm"
		if title.contains("close") or title.contains("cancel") or title in ["no", "btnno"]: kind = &"cancel"
		elif title.contains("prev") or title.contains("next") or title.contains("page") or title.contains("tab"): kind = &"select"
		control.pressed.connect(request.bind(kind))
	elif control is Range:
		control.value_changed.connect(func(_value): request(&"adjust"))
	elif control is LineEdit:
		control.text_submitted.connect(func(_value): request(&"confirm"))
	else:
		control.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT: request(&"confirm")
				elif event.button_index == MOUSE_BUTTON_RIGHT: request(&"cancel")
				elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and control.has_method("keyboard_zoom"): request(&"adjust")
		)

func request(kind: StringName = &"confirm") -> void:
	if GameData.in_battle: return
	if _pending.is_empty(): _flush.call_deferred()
	var ranks := {&"select": 0, &"adjust": 0, &"confirm": 1, &"cancel": 2, &"error": 3, &"success": 3}
	if _pending.is_empty() or int(ranks.get(kind, 1)) >= int(ranks.get(_pending, 1)): _pending = kind

func _has_new_legacy_sound() -> bool:
	_players = _players.filter(func(reference: WeakRef): return is_instance_valid(reference.get_ref()))
	for reference in _players:
		var player := reference.get_ref() as AudioStreamPlayer
		if not player.playing or player.stream == null: continue
		var filename := player.stream.resource_path.get_file()
		if filename in ["001-System01.ogg", "002-System02.ogg", "003-System03.ogg", "005-System05.ogg", "006-System06.ogg", "057-Wrong01.ogg"]:
			if player.get_playback_position() < 0.06: return true
	return false

func _flush() -> void:
	var kind := _pending
	_pending = &""
	if kind.is_empty() or GameData.in_battle or _has_new_legacy_sound(): return
	var now := Time.get_ticks_msec()
	if kind in [&"select", &"adjust"] and now - _last_at < 65: return
	var paths := {&"select": "Select", &"adjust": "Adjust", &"confirm": "Confirm", &"cancel": "Cancel", &"error": "Error", &"success": "Success"}
	var player := get_node(str(paths.get(kind, "Confirm"))) as AudioStreamPlayer
	player.play()
	_last_kind = kind
	_last_at = now
	last_played = kind
	played_count += 1
