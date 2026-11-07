extends Control

const WORLD_PATH := "res://scenes/MainScene.tscn"
const SAVE_POPUP := preload("res://scenes/UI/Save/SavePopup.tscn")
const SETTINGS_POPUP := preload("res://scenes/UI/SettingPopup.tscn")
const DIFFICULTY_POPUP := preload("res://scenes/UI/DifficultySelection.tscn")
const UI_SOUND := preload("res://Script/UI/UISoundFeedback.gd")
const SAVE_PANEL := preload("res://Script/UI/SavePopup.gd")

## 键为存档中的 chapter_id。未配置新章节时沿用最近一章的背景。
@export var chapter_backgrounds: Dictionary[int, Texture2D] = {}

var _popup: CanvasLayer
var _starting := false

@onready var _menu: VBoxContainer = $Layout/Buttons

func _ready() -> void:
	_refresh_landscape()
	$Layout/Buttons/NewGame.pressed.connect(_new_game)
	$Layout/Buttons/LoadGame.pressed.connect(_open_load)
	$Layout/Buttons/Settings.pressed.connect(_open_settings)
	$Layout/Buttons/Quit.pressed.connect(func(): get_tree().quit())
	get_viewport().size_changed.connect(_center_popup)
	$Layout/Buttons/NewGame.grab_focus()

func _refresh_landscape() -> void:
	var autosave := SAVE_PANEL._get_slot_info(SAVE_PANEL.AUTO_SLOT)
	var chapter := maxi(1, int(autosave.get("chapter_id", 1)))
	var chosen := 0
	for entry in chapter_backgrounds:
		if entry > chosen and entry <= chapter and chapter_backgrounds[entry] != null:
			chosen = entry
	if chosen > 0:
		$Landscape.texture = chapter_backgrounds[chosen]

func _new_game() -> void:
	if _starting or is_instance_valid(_popup): return
	_starting = true
	_menu.hide()
	if GameData.difficulty_locked:
		_start_world()
		return
	var selection := DIFFICULTY_POPUP.instantiate()
	selection.confirmed.connect(_start_world, CONNECT_ONE_SHOT)
	add_child(selection)

func _start_world() -> void:
	await create_tween().tween_property($StartFade, "color:a", 1.0, 0.4).finished
	var packed := load(WORLD_PATH) as PackedScene
	if packed:
		var world := packed.instantiate()
		world.prepare_new_game()
		if get_tree().change_scene_to_node(world) == OK: return
		world.free()
	_starting = false
	$StartFade.color.a = 0.0
	_menu.show()
	$Layout/Buttons/NewGame.grab_focus()
	$Status.text = "加载失败，请重试。"
	UI_SOUND.play_ui(&"error")

func _open_load() -> void:
	if _starting or is_instance_valid(_popup): return
	var popup := SAVE_POPUP.instantiate()
	popup.load_only = true
	_show_popup(popup, $Layout/Buttons/LoadGame)

func _open_settings() -> void:
	if _starting or is_instance_valid(_popup): return
	var popup := SETTINGS_POPUP.instantiate()
	popup.volume_changed.connect(_apply_volume)
	_show_popup(popup, $Layout/Buttons/Settings)
	popup.get_node("系统设置/musicIcon/HSlider").grab_focus()

func _show_popup(popup: CanvasLayer, opener: Button) -> void:
	_popup = popup
	_menu.hide()
	popup.closed.connect(func():
		if not popup.is_queued_for_deletion(): popup.queue_free()
		_popup = null
		_menu.show()
		opener.grab_focus()
	, CONNECT_ONE_SHOT)
	add_child(popup)
	_center_popup()

func _center_popup() -> void:
	if is_instance_valid(_popup):
		_popup.offset = (get_viewport_rect().size - Vector2(1300, 800)) * 0.5

func _apply_volume() -> void:
	var levels := {"Master": GameData.base_vol_master, "BGM": GameData.base_vol_bgm, "SFX": GameData.base_vol_sfx}
	for bus_name in levels:
		var bus := AudioServer.get_bus_index(bus_name)
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(levels[bus_name], 0.0001)))

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_popup) or not event.is_action_pressed("ui_cancel"): return
	get_viewport().set_input_as_handled()
	if _popup.has_method("close"):
		_popup.close()
	else:
		_popup.get_node("CloseBtn").pressed.emit()
