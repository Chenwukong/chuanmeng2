@tool
extends Area2D
## 拖入地图填写 NPC，即自动登记到数据库；无需手动填写触发 ID。
const TriggerDatabase = preload("res://Script/Data/Dialogue/StoryTriggerDB.gd")
## 玩家是 Node2D，使用形状相交检测其脚底位置，不依赖物理刚体信号。

signal triggered(npc: String)
signal completed(npc: String)

@export_group("剧情触发")
## NPC 名字或事件 ID，多个区域可以填写同一 NPC。
@export var target_npc: String = "":
	set(value):
		target_npc = value
		update_configuration_warnings()
## 0=当前段，1=只触发第一段，2=只触发第二段。限制阶段，不会跳段。
@export_range(0, 999, 1) var dialogue_stage: int = 0
@export var check_unlock: bool = true
@export var trigger_once: bool = true
@export var enabled: bool = true
@export_node_path("Node2D") var player_path: NodePath
## 仅用于兼容旧场景，编辑器不显示。
@export_storage var trigger_id: String = ""

var _registration_id: String = ""
var _point := CircleShape2D.new()
var _used_this_visit := false
var _running := false

func _ready() -> void:
	_point.radius = 0.1
	set_process(not Engine.is_editor_hint())
	if not Engine.is_editor_hint(): _register_trigger()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if target_npc.strip_edges().is_empty() and trigger_id.is_empty():
		warnings.append("请填写要触发剧情的 NPC 名字，无需填写触发 ID。")
	return warnings

func _register_trigger() -> void:
	if target_npc.is_empty() and not trigger_id.is_empty():
		_registration_id = trigger_id
		return
	var map := get_parent()
	while map != null and not map.is_in_group("map") and map != get_tree().current_scene:
		map = map.get_parent()
	if map == null: map = get_tree().current_scene
	if map == null: return
	# 地图场景路径 + 区域节点路径，自动区分位置并在重进地图时保留标识。
	_registration_id = "自动区域/" + map.scene_file_path + "#" + str(map.get_path_to(self))
	GameData.STORY_TRIGGER_DB[_registration_id] = {
		"target_npc": target_npc, "dialogue_stage": dialogue_stage,
		"check_unlock": check_unlock, "trigger_once": trigger_once, "enabled": enabled,
		"source_scene": map.scene_file_path, "source_node": str(map.get_path_to(self)),
		"instance_id": get_instance_id(),
	}

func _exit_tree() -> void:
	if Engine.is_editor_hint() or _registration_id.is_empty(): return
	var config: Dictionary = GameData.STORY_TRIGGER_DB.get(_registration_id, {})
	if config.get("instance_id", 0) == get_instance_id():
		GameData.STORY_TRIGGER_DB.erase(_registration_id)

func _player() -> Node2D:
	if not player_path.is_empty(): return get_node_or_null(player_path) as Node2D
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_method("get_player_node"): return ancestor.get_player_node() as Node2D
		var player := ancestor.get_node_or_null("Player") as Node2D
		if player != null: return player
		ancestor = ancestor.get_parent()
	return get_tree().get_first_node_in_group("player") as Node2D

func _save_key() -> String:
	return "剧情区域/" + _registration_id

func _contains(player: Node2D) -> bool:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.disabled or collision.shape == null: return false
	return collision.shape.collide(collision.global_transform, _point, Transform2D(0, player.global_position))

func _process(_delta: float) -> void:
	var player := _player()
	if player == null: return
	if not _contains(player):
		_used_this_visit = false
		return
	if not enabled or _running or _used_this_visit: return
	var config: Dictionary = GameData.STORY_TRIGGER_DB.get(_registration_id, {})
	if config.is_empty() or not config.get("enabled", true): return
	var target_npc: String = str(config.get("target_npc", ""))
	if target_npc.is_empty(): return
	if config.get("trigger_once", true) and GameData.story_flag(_save_key()): return
	if GameData.in_battle or GameData.ui_blocked or GameData.is_dialogue_active() or GameData._npc_dialogue_playing: return
	# 被锁时不消耗本次进入机会；在区域内解锁后仍可触发。
	var entry: Dictionary = GameData.get_npc_dialogue(target_npc, bool(config.get("check_unlock", true)))
	if entry.is_empty() or entry.get("is_waiting", false): return
	var stage: int = int(config.get("dialogue_stage", 0))
	if stage > 0 and int(entry.get("index", -1)) != stage - 1: return
	_run_story(config.duplicate(true))

func _run_story(config: Dictionary) -> void:
	var target_npc: String = str(config.get("target_npc", ""))
	_running = true
	_used_this_visit = true
	triggered.emit(target_npc)
	var success: bool = await GameData.play_npc_dialogue(target_npc, bool(config.get("check_unlock", true)), false, true, _save_key() if config.get("trigger_once", true) else "")
	_running = false
	if success:
		completed.emit(target_npc)
	else:
		_used_this_visit = false
