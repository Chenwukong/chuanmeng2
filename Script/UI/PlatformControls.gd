extends Node
signal mode_changed
signal fullscreen_changed(enabled: bool)
const SETTINGS_PATH := "user://controls.cfg"
var android_mode := false
var move_vector := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	android_mode = OS.has_feature("android") or bool(ProjectSettings.get_setting("application/config/android_mode", false))
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		android_mode = bool(config.get_value("controls", "android_mode", android_mode))


func is_fullscreen() -> bool:
	var mode := get_tree().root.mode
	return mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN


func set_fullscreen(enabled: bool) -> void:
	var window := get_tree().root
	window.mode = Window.MODE_FULLSCREEN if enabled else Window.MODE_WINDOWED
	if not enabled:
		window.transparent = false
		window.borderless = false
	fullscreen_changed.emit(is_fullscreen())


func _input(event: InputEvent) -> void:
	handle_fullscreen_shortcut(event)


## Modal scenes that handle raw input before the autoload can delegate here first.
func handle_fullscreen_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.alt_pressed or event.ctrl_pressed or event.shift_pressed or event.meta_pressed:
		return false
	if event.keycode != KEY_ENTER and event.keycode != KEY_KP_ENTER:
		return false
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo:
		set_fullscreen(not is_fullscreen())
	return true


func set_android_mode(enabled: bool, persist: bool = true) -> void:
	android_mode = enabled
	move_vector = Vector2.ZERO
	mode_changed.emit()
	if persist:
		var config := ConfigFile.new()
		config.set_value("controls", "android_mode", enabled)
		var error := config.save(SETTINGS_PATH)
		if error != OK: push_warning("无法保存触屏界面设置: %s" % error_string(error))
