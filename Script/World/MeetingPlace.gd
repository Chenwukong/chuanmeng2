@tool
extends "res://Script/World/MapRoot.gd"
## 只过滤约定之地的可选队友，不影响其他地图上的剧情NPC。
func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint(): return
	GameData.character_locks_changed.connect(refresh_characters)
	refresh_characters()

func refresh_characters() -> void:
	for npc in get_children():
		if not npc is NpcNode: continue
		for id in CharacterDB.CHARACTER_DB:
			if CharacterDB.CHARACTER_DB[id].name == npc.npc_name:
				npc.visible = GameData.is_character_unlocked(id)
				break

func _restore_after_battle(overlay: CanvasLayer) -> void:
	super._restore_after_battle(overlay)
	if is_inside_tree() and not is_queued_for_deletion(): refresh_characters()
