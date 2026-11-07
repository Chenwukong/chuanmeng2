extends CanvasLayer

signal closed
signal volume_changed

@onready var music_slider: HSlider = $"系统设置/musicIcon/HSlider"
@onready var volume_slider: HSlider = $"系统设置/soundIcon/HSlider"
@onready var sfx_slider: HSlider = $"系统设置/soundEffectIcon/HSlider"
@onready var fullscreen_cb: CheckBox = $"系统设置/fullScreenIcon/CheckBox"


func _ready() -> void:
	$系统设置/AndroidMode.button_pressed = PlatformControls.android_mode
	$系统设置/AndroidMode.toggled.connect(PlatformControls.set_android_mode)
	_ensure_buses()
	for s in [music_slider, volume_slider, sfx_slider]:
		s.min_value = 0
		s.max_value = 100
		s.step = 1
	
	music_slider.value = GameData.base_vol_bgm * 100
	sfx_slider.value = GameData.base_vol_sfx * 100
	volume_slider.value = GameData.base_vol_master * 100
	for slider: HSlider in [volume_slider, music_slider, sfx_slider]:
		var readout := slider.get_node("../Value") as Label
		readout.text = "%d%%" % roundi(slider.value)
		slider.value_changed.connect(_update_readout.bind(readout))
	fullscreen_cb.set_pressed_no_signal(PlatformControls.is_fullscreen())

	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_cb.toggled.connect(PlatformControls.set_fullscreen)
	PlatformControls.fullscreen_changed.connect(fullscreen_cb.set_pressed_no_signal)



func _update_readout(value: float, readout: Label) -> void:
	readout.text = "%d%%" % roundi(value)

func _ensure_buses() -> void:
	if AudioServer.get_bus_index("BGM") < 0:
		AudioServer.add_bus(-1)
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "BGM")
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus(-1)
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "SFX")


func _on_music_changed(val: float) -> void:
	GameData.base_vol_bgm = val / 100.0
	volume_changed.emit()

func _on_sfx_changed(val: float) -> void:
	GameData.base_vol_sfx = val / 100.0
	volume_changed.emit()

func _on_volume_changed(val: float) -> void:
	GameData.base_vol_master = val / 100.0
	volume_changed.emit()

func _linear_db(val: float) -> float:
	if val <= 0: return -80.0
	return linear_to_db(val / 100.0)


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
