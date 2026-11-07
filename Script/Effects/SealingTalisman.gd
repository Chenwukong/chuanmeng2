extends Node2D
## 定身视觉与暂停状态随场景实例管理，释放特效时恢复尚存活的演员。
var _actor: NpcNode
var _was_processing := true
var _auto_look := true
var _color := Color.WHITE

func bind_actor(actor: NpcNode) -> void:
	_actor = actor
	_was_processing = actor.is_processing()
	_auto_look = actor.auto_look_at_player
	var sprite := actor.get_node("Sprite2D") as Sprite2D
	_color = sprite.modulate
	actor.set("_click_path", PackedVector2Array())
	actor.set("_is_moving", false)
	actor.auto_look_at_player = false
	actor.set_process(false)
	actor.wasp.pause()
	sprite.modulate = Color(0.65, 0.85, 1.0)
	$Paper.texture = preload("res://Script/Assets/AssetLoader.gd").tcp_texture("res://TCP/符咒/3290.tcp")

func cancel() -> void:
	queue_free()

func _exit_tree() -> void:
	if not is_instance_valid(_actor) or not _actor.is_inside_tree() or _actor.is_queued_for_deletion(): return
	_actor.auto_look_at_player = _auto_look
	_actor.set_process(_was_processing)
	var sprite := _actor.get_node_or_null("Sprite2D") as Sprite2D
	if sprite: sprite.modulate = _color
	if is_instance_valid(_actor.wasp) and _actor.wasp.is_inside_tree(): _actor.wasp.play("idle")
