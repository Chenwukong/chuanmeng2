@tool
extends NpcNode
## 固定守关怪：场景编辑外观与拦截范围，存档标记控制永久移除。
@export var battle_preset: String = ""
@export var defeat_flag: String = ""
@export var enemy_level: int = 20
@export var encounter_name: String = "守关敌人"

var _running := false
var _must_leave := false
var _player_point := CircleShape2D.new()

func _ready() -> void:
	if not Engine.is_editor_hint() and GameData.story_flag(defeat_flag):
		hide()
		queue_free()
		return
	_player_point.radius = 0.1
	$Level.text = "%s · %d级" % [encounter_name, enemy_level]
	# 在拦截范围外沿就面向来人，不能沿用普通 NPC 的 100px 转向距离。
	lookAtDistance = 340
	super._ready()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	super._process(delta)
	if _running or is_queued_for_deletion(): return
	var player := get_parent().get_node_or_null("Player") as Node2D
	if player == null: return
	var shape := $Intercept/CollisionShape2D as CollisionShape2D
	var inside := shape.shape.collide(shape.global_transform, _player_point, Transform2D(0, player.global_position))
	if not inside:
		_must_leave = false
		return
	if _must_leave: return
	if GameData.in_battle or GameData.ui_blocked or GameData.is_dialogue_active() or GameData._npc_dialogue_playing: return
	challenge()

## 点击交互与路过拦截使用同一入口，战败/逃跑后须离开范围才会再拦截。
func challenge() -> void:
	if _running or is_queued_for_deletion(): return
	if GameData.in_battle or GameData.ui_blocked or GameData.is_dialogue_active(): return
	_running = true
	_must_leave = true
	var player := get_parent().get_node_or_null("Player") as Node2D
	if player != null:
		look_at_target(player.global_position)
		if player.has_method("_set_dir"):
			player.set("_click_path", PackedVector2Array())
			player.set("_pending_npc", null)
			player.set("_is_moving", false)
			player.call("_set_dir", global_position - player.global_position)
			player.call("_play_hero", "idle")
	await GameData.play_npc_dialogue(event_id, true, true, true)
	if not is_inside_tree() or is_queued_for_deletion(): return
	_running = false
	if GameData.story_flag(defeat_flag):
		hide()
		queue_free()
