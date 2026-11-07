@tool
extends "res://Script/World/MapRoot.gd"
const AFTERMATH_FLAG := "方寸山/菩提/事变完成"

func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint(): return
	GameData.story_progress_committed.connect(apply_story_state)
	apply_story_state()

func apply_story_state() -> void:
	if not GameData.story_flag(AFTERMATH_FLAG): return
	if is_instance_valid(_chase_spawn_timer): _chase_spawn_timer.stop()
	_cleanup_chasers()
	for child in get_children():
		if child.get("target_npc") == "菩提祖师": child.set_process(false)
		if child is NpcNode or child.name == "Player":
			child.hide()
			child.set_process(false)
			child.set_process_input(false)
			child.set_process_unhandled_input(false)

func _spawn_chase_batch() -> void:
	if GameData.story_flag(AFTERMATH_FLAG): return
	super._spawn_chase_batch()

func _restore_after_battle(overlay: CanvasLayer) -> void:
	super._restore_after_battle(overlay)
	if is_inside_tree() and not is_queued_for_deletion(): apply_story_state()
