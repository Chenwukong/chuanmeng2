extends Button
@export var ready_text := "作弊（调试）"
@export var active_text := "作弊已开启 · 补齐"
func _ready() -> void:
	pressed.connect(_activate)
	_refresh()
func _process(_delta: float) -> void:
	visible = not GameData.in_battle and not GameData.ui_blocked and not GameData.is_dialogue_active() and not GameData._npc_dialogue_playing
func _activate() -> void:
	GameData.enable_debug_cheats()
	_refresh()
	var scene := get_tree().current_scene
	if is_instance_valid(scene) and scene.has_method("_refresh_btn_visuals"): scene._refresh_btn_visuals()
func _refresh() -> void:
	text = active_text if GameData.debug_cheats_enabled else ready_text
