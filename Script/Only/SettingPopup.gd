extends CanvasLayer

signal closed

@onready var music_slider: HSlider = $"系统设置/musicIcon/HSlider"
@onready var volume_slider: HSlider = $"系统设置/soundIcon/HSlider"
@onready var sfx_slider: HSlider = $"系统设置/soundEffectIcon/HSlider"
@onready var fullscreen_cb: CheckBox = $"系统设置/fullScreenIcon/CheckBox"


func _ready() -> void:
	_ensure_buses()
	# 设置滑块范围：-80dB（静音）到 0dB（最大）
	for s in [music_slider, volume_slider, sfx_slider]:
		s.min_value = -80
		s.max_value = 0
		s.step = 1
	
	# 加载设置（默认 0dB = 最大音量）
	var bv = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM"))
	music_slider.value = bv if bv > -79 else 0
	bv = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	sfx_slider.value = bv if bv > -79 else 0
	bv = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	volume_slider.value = bv if bv > -79 else 0
	var fs = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_cb.button_pressed = fs

	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_cb.toggled.connect(_on_fullscreen_toggled)


func _ensure_buses() -> void:
	if AudioServer.get_bus_index("BGM") < 0:
		AudioServer.add_bus(AudioServer.get_bus_index("Master"))
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "BGM")
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus(AudioServer.get_bus_index("Master"))
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "SFX")


func _on_music_changed(val: float) -> void:
	var bus = AudioServer.get_bus_index("BGM")
	if bus < 0: bus = AudioServer.get_bus_index("Master")
	if bus >= 0: AudioServer.set_bus_volume_db(bus, val)


func _on_sfx_changed(val: float) -> void:
	var bus = AudioServer.get_bus_index("SFX")
	if bus < 0: bus = AudioServer.get_bus_index("Master")
	if bus >= 0: AudioServer.set_bus_volume_db(bus, val)


func _on_volume_changed(val: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), val)


func _on_fullscreen_toggled(on: bool) -> void:
	if on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func close() -> void:
	# 关闭音效
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://Audio/SE/003-System03.ogg")
	snd.bus = "SFX"
	get_tree().root.add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)
	closed.emit()
	queue_free()


func _on_close_btn_pressed() -> void:
	close()
