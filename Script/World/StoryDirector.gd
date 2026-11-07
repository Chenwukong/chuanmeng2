extends Node2D
## 所有剧情共用的演出接口。对白编排顺序，这里实现可等待的通用动作。
## 角色参数使用“主角”、NPC 名字或事件 ID，无需给每个角色另写脚本。

const DialogueDatabase = preload("res://Script/Data/Dialogue/DialogueDB.gd")

## 独立舞台与测试可注入演员，不依赖地图或修改剧情数据。
var actor_overrides: Dictionary = {}
var _cancel_requested := false
var _active_tween: Tween
var _active_effect: Node2D
var _moving_actor: NpcNode
signal effect_batch_released(index: int)

func cancel_test_action() -> void:
	_cancel_requested = true
	if is_instance_valid(_moving_actor): _moving_actor.set("_click_path", PackedVector2Array())
	if is_instance_valid(_active_tween) and _active_tween.is_valid():
		var tween := _active_tween
		tween.kill()
		tween.finished.emit()
	if is_instance_valid(_active_effect): _active_effect.cancel()
	if is_instance_valid(notice_mark): notice_mark.hide()
	if is_instance_valid(talisman): talisman.hide()

@onready var notice_mark: Label = $Notice
@onready var talisman: Sprite2D = $Talisman
@onready var hit_sound: AudioStreamPlayer = $HitSound
@onready var roar_sound: AudioStreamPlayer = $RoarSound

func _hide_dialogue_balloons() -> Array:
	var saved: Array = []
	for balloon in get_tree().get_nodes_in_group("ballon"):
		if balloon is CanvasLayer:
			saved.append({"node": weakref(balloon), "visible": balloon.visible})
			balloon.hide()
	return saved

func _restore_dialogue_balloons(saved: Array) -> void:
	for entry in saved:
		var balloon = entry.node.get_ref()
		if is_instance_valid(balloon) and balloon.is_inside_tree(): balloon.visible = entry.visible

## 通用兽吼动作，使用项目已有叫声音效。
func roar(actor_id: String) -> void:
	var source := actor(actor_id) as NpcNode
	if source == null: return
	var saved := _hide_dialogue_balloons()
	source.wasp.play("attack", false)
	roar_sound.play()
	await get_tree().create_timer(0.45).timeout
	if is_instance_valid(source) and source.is_inside_tree(): source.play_idle()
	_restore_dialogue_balloons(saved)

## 通用突袭反制：沿地图路径冲向目标，目标立即发符，命中时暂停袭击者。
func rush_and_seal(attacker_id: String, defender_id: String = "主角", rush_speed: float = 520.0) -> bool:
	var attacker := actor(attacker_id) as NpcNode
	var defender := actor(defender_id)
	if attacker == null or defender == null: return false
	var saved := _hide_dialogue_balloons()
	_stop(defender)
	_face(attacker, defender)
	_face(defender, attacker)
	var old_speed := attacker.walk_speed
	var old_auto := attacker.auto_look_at_player
	attacker.walk_speed = maxf(120.0, rush_speed)
	attacker.auto_look_at_player = false
	var offset := (attacker.global_position - defender.global_position).normalized() * 72.0
	attacker.goto(defender.global_position + offset)
	_moving_actor = attacker
	await get_tree().create_timer(0.1).timeout
	if not is_inside_tree() or _cancel_requested or not is_instance_valid(attacker) or not is_instance_valid(defender):
		if is_instance_valid(attacker):
			attacker.walk_speed = old_speed
			attacker.auto_look_at_player = old_auto
			attacker.set("_click_path", PackedVector2Array())
		_moving_actor = null
		_restore_dialogue_balloons(saved)
		return false
	var animation := defender.get_node_or_null("WASAnimationPlayer") as WASAnimationPlayer
	if animation: animation.play("attack", false)
	talisman.texture = preload("res://Script/Assets/AssetLoader.gd").tcp_texture("res://TCP/符咒/3290.tcp")
	var start := defender.global_position + Vector2(0, -40)
	talisman.global_position = start
	talisman.show()
	var tween := create_tween()
	tween.tween_method(func(progress: float):
		if not is_instance_valid(attacker): return
		var destination := attacker.global_position + Vector2(0, -40)
		talisman.global_position = start.lerp(destination, progress)
		talisman.rotation = (destination - start).angle() + PI / 2.0
	, 0.0, 1.0, 0.18)
	_active_tween = tween
	await tween.finished
	_active_tween = null
	talisman.hide()
	_moving_actor = null
	if animation and animation.is_inside_tree(): animation.play("idle")
	if not is_instance_valid(attacker) or not attacker.is_inside_tree():
		_restore_dialogue_balloons(saved)
		return false
	attacker.walk_speed = old_speed
	attacker.auto_look_at_player = old_auto
	attacker.set("_click_path", PackedVector2Array())
	if _cancel_requested:
		_restore_dialogue_balloons(saved)
		return false
	var seal = preload("res://scenes/Effects/SealingTalisman.tscn").instantiate()
	attacker.add_child(seal)
	seal.bind_actor(attacker)
	hit_sound.play()
	_restore_dialogue_balloons(saved)
	return true

func actor(id: String) -> Node2D:
	if actor_overrides.has(id): return actor_overrides[id] as Node2D
	var map := get_tree().get_first_node_in_group("map")
	if map == null: return null
	if id == "主角" or id == "Player": return map.get_node_or_null("Player") as Node2D
	return story_npc(id)

func _face(source: Node2D, target: Node2D) -> void:
	if source is NpcNode:
		source.look_at_target(target.global_position)
	elif source.has_method("_set_dir"):
		source.call("_set_dir", target.global_position - source.global_position)

func _stop(source: Node2D) -> void:
	# MapWalker 的剧情暂停保留旧路径，这里清除它，防止演出结束后继续走。
	if source.has_method("_play_hero"):
		source.set("_click_path", PackedVector2Array())
		source.set("_pending_npc", null)
		source.set("_is_moving", false)
		source.call("_play_hero", "idle")

## do StoryDirector.notice("主角", "机关人")
func notice(source_id: String, target_id: String) -> void:
	var source := actor(source_id)
	var target := actor(target_id)
	if source == null or target == null: return
	_stop(source)
	_face(source, target)
	_face(target, source)
	notice_mark.global_position = source.global_position + Vector2(-12, -110)
	notice_mark.show()
	var tween := create_tween()
	tween.tween_property(notice_mark, "position:y", notice_mark.position.y - 12, 0.18)
	tween.tween_interval(0.45)
	_active_tween = tween
	await tween.finished
	_active_tween = null
	notice_mark.hide()

## NPC 主动迎上目标，在其面前停下。沿用地图寻路，失败或超时返回 false。
func block(source_id: String, target_id: String = "主角", distance: float = 58.0) -> bool:
	var source := actor(source_id) as NpcNode
	var target := actor(target_id)
	if source == null or target == null: return false
	_stop(target)
	var offset := (source.global_position - target.global_position).normalized() * maxf(distance, 20.0)
	_moving_actor = source
	var moved := await source.move_for_story(target.global_position + offset, -1, 5.0)
	_moving_actor = null
	_face(source, target)
	_face(target, source)
	return moved and not _cancel_requested

## 通用 NPC 走位，可供后续对白直接调用。
func move(source_id: String, x: float, y: float, end_direction: int = -1) -> bool:
	var source := actor(source_id) as NpcNode
	if source == null: return false
	return await source.move_for_story(Vector2(x, y), end_direction)

## 固定舞台的坐标使用演员父节点的本地坐标。
func stage_walk(actor_id: String, x: float, y: float, direction: int = -1, exit_after := false) -> void:
	var npc := actor(actor_id) as NpcNode
	if npc == null: return
	npc.show()
	var stage := npc.get_parent() as Node2D
	var moved := await npc.move_in_line_for_story(stage.to_global(Vector2(x, y)), direction)
	if moved and exit_after and is_instance_valid(npc):
		npc.hide()

## 改变舞台演员和其道具的不透明度。
func stage_fade_actor(actor_id: String, opacity: float, duration: float) -> void:
	var source := actor(actor_id)
	if source == null: return
	var tween := source.create_tween()
	tween.tween_property(source, "modulate:a", clampf(opacity, 0.0, 1.0), duration)
	await tween.finished


## 默认以演员当前帧的身体中心为锚点，也可指定道具或落点节点。
func stage_animation(actor_id: String, cue: String, anchor_path: NodePath = ^"") -> void:
	var source := actor(actor_id)
	if source == null: return
	var effect := source.get_parent().get_node_or_null(NodePath(cue)) as AnimatedSprite2D
	if effect == null: return
	var anchor := source.get_node_or_null(anchor_path) as Node2D if not anchor_path.is_empty() else null
	var body := source.get_node_or_null("Sprite2D") as Sprite2D
	if anchor != null:
		effect.global_position = anchor.global_position
	elif body != null:
		effect.global_position = body.to_global(body.get_rect().get_center())
	else:
		effect.global_position = source.global_position
	effect.show()
	effect.set_frame_and_progress(0, 0.0)
	effect.play()
	var sound := effect.get_node_or_null("Sound") as AudioStreamPlayer
	if sound: sound.play()
	await effect.animation_finished
	if is_instance_valid(effect): effect.hide()

## 对话只引用演出配置名，临时剧情接入可独立关闭或删除。
func play_effect(cue_id: String) -> bool:
	var db = preload("res://Script/Data/Dialogue/StoryEffectDB.gd")
	var cue: Dictionary = db.CUES.get(cue_id, {})
	if cue.is_empty() or not cue.get("enabled", true): return false
	return await talisman_burst(str(cue.source), str(cue.target), db.EFFECTS.get(cue.effect))

## 可供任意剧情复用，角色和时长等均不写死在特效场景中。
func talisman_burst(source_id: String, target_id: String, settings: Resource = null) -> bool:
	var source := actor(source_id)
	var target := actor(target_id)
	if source == null or target == null: return false
	if settings == null: settings = preload("res://Resources/StoryEffects/GoldenTalismanBurst.tres")
	_stop(source)
	_face(source, target)
	var previous_block: bool = GameData.ui_blocked
	GameData.ui_blocked = true
	var animation := source.get_node_or_null("WASAnimationPlayer") as WASAnimationPlayer
	var old_frame_time: float = animation.frame_time if animation else 0.1
	if animation:
		animation.frame_time = maxf(settings.charge_duration, 0.1)
		animation.play(settings.charge_animation, false)
	var effect = preload("res://scenes/Effects/GoldenTalismanBurst.tscn").instantiate()
	add_child(effect)
	_active_effect = effect
	effect.batch_released.connect(func(_batch: int):
		effect_batch_released.emit(_batch)
		if is_instance_valid(animation):
			animation.frame_time = old_frame_time
			animation.play(settings.release_animation, false)
	)
	var success: bool = await effect.play(source, target, settings)
	if is_instance_valid(animation):
		animation.frame_time = old_frame_time
		if animation.is_inside_tree(): animation.play("idle")
	GameData.ui_blocked = previous_block
	effect.queue_free()
	_active_effect = null
	return success

## 地图飞符只表演视觉与音效，不消耗物品、不造成战斗伤害。
func cast(source_id: String, target_id: String) -> void:
	var source := actor(source_id)
	var target := actor(target_id)
	if source == null or target == null: return
	_stop(source)
	_face(source, target)
	var animation := source.get_node_or_null("WASAnimationPlayer") as WASAnimationPlayer
	if animation != null: animation.play("attack", false)
	await get_tree().create_timer(0.25).timeout
	if _cancel_requested: return
	if not is_instance_valid(source) or not is_instance_valid(target): return
	talisman.texture = preload("res://Script/Assets/AssetLoader.gd").tcp_texture("res://TCP/符咒/3290.tcp")
	talisman.global_position = source.global_position + Vector2(0, -40)
	var destination := target.global_position + Vector2(0, -40)
	talisman.rotation = (destination - talisman.global_position).angle() + PI / 2.0
	talisman.show()
	var tween := create_tween()
	tween.tween_property(talisman, "global_position", destination, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween = tween
	await tween.finished
	_active_tween = null
	talisman.hide()
	if _cancel_requested or not is_instance_valid(target): return
	hit_sound.play()
	var sprite := target.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		var original := sprite.modulate
		tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(2.5, 2.2, 1.5), 0.08)
		tween.tween_property(sprite, "modulate", original, 0.18)
		_active_tween = tween
		await tween.finished
		_active_tween = null
		sprite.modulate = original
	if is_instance_valid(source) and animation != null: animation.play("idle")
	await get_tree().create_timer(0.15).timeout

## 演出入口保持轻量：Dialogue Manager 负责调用次序和等待。
func story_npc(event_id: String) -> NpcNode:
	if actor_overrides.has(event_id): return actor_overrides[event_id] as NpcNode
	var map = get_tree().get_first_node_in_group("map")
	if map == null: return null
	var id: String = str(DialogueDatabase.LEGACY_IDS.get(event_id, event_id))
	for child in map.get_children():
		if child is NpcNode:
			var child_id: String = child.event_id if not child.event_id.is_empty() else str(DialogueDatabase.LEGACY_IDS.get(child.npc_name, child.npc_name))
			if child_id == id: return child
	return null

## do StoryDirector.move_story_npc("方寸山_机关人", 1746, 2597, 2)
func move_story_npc(event_id: String, x: float, y: float, end_direction: int = -1) -> bool:
	return await move(event_id, x, y, end_direction)

func face_story_npc(event_id: String, direction: int) -> void:
	var npc := story_npc(event_id)
	if npc != null: npc.set_direction(direction)

var last_story_battle_result: String = "cancelled"
var _bodhi_binding: Node2D

func bodhi_bind_player() -> void:
	var source := actor("菩提祖师") as NpcNode
	var target := actor("主角")
	if source == null or target == null: return
	var balloons := _hide_dialogue_balloons()
	_stop(target)
	_face(source, target)
	_face(target, source)
	if target.has_method("dismount_for_story"): target.dismount_for_story()
	target.set_process(false)
	target.set_process_unhandled_input(false)
	source.wasp.add_anim("bodhi_cast", "res://WAS/菩提祖师/施法.was")
	source.wasp.play("bodhi_cast", false)
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(target): return
	hit_sound.play()
	if not is_instance_valid(target): return
	_bodhi_binding = preload("res://scenes/Effects/BodhiBinding.tscn").instantiate()
	target.add_child(_bodhi_binding)
	_bodhi_binding.scale = Vector2(0.35, 0.35)
	_bodhi_binding.modulate.a = 0.0
	var binding_tween := create_tween().set_parallel(true)
	binding_tween.tween_property(_bodhi_binding, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	binding_tween.tween_property(_bodhi_binding, "modulate:a", 1.0, 0.2)
	var animation := target.get_node_or_null("WASAnimationPlayer") as WASAnimationPlayer
	if animation: animation.pause()
	await get_tree().create_timer(0.9).timeout
	if is_instance_valid(source): source.play_idle()
	_restore_dialogue_balloons(balloons)

func bodhi_faint_player() -> void:
	var target := actor("主角")
	if target == null: return
	var balloons := _hide_dialogue_balloons()
	var animation := target.get_node_or_null("WASAnimationPlayer") as WASAnimationPlayer
	# 失去意识时保持被束缚的姿势，不播放死亡或倒地动作。
	if animation: animation.pause()
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(_bodhi_binding): _bodhi_binding.queue_free()
	_bodhi_binding = null
	_restore_dialogue_balloons(balloons)

func finish_bodhi_scene() -> void:
	GameData.complete_story_event("方寸山/菩提/事变完成")

## do StoryDirector.start_story_battle("机关人") 会等待结算窗口关闭并恢复地图。
func start_story_battle(preset_id: String, victory_flag: String = "") -> String:
	last_story_battle_result = "cancelled"
	if GameData.in_battle: return "cancelled"
	var map = get_tree().get_first_node_in_group("map")
	if map == null or not map.has_method("start_preset_battle"):
		return last_story_battle_result
	# 对话实例保留，临时隐藏并释放输入给战斗，战后继续同一段剧情。
	var suspended: Array = []
	for balloon in get_tree().get_nodes_in_group("ballon"):
		if balloon is CanvasLayer:
			suspended.append({"node": weakref(balloon), "visible": balloon.visible, "block": balloon.get("will_block_other_input")})
			balloon.hide()
			balloon.set("will_block_other_input", false)
	last_story_battle_result = await map.start_preset_battle(preset_id, victory_flag)
	for saved in suspended:
		var balloon = saved.node.get_ref()
		if is_instance_valid(balloon):
			balloon.visible = saved.visible
			balloon.set("will_block_other_input", saved.block)
	return last_story_battle_result

## 兼容原有剧情调用；新剧情推荐 start_story_battle + 胜负分支。

## 商店/打造由界面管理；剧情暂时让出输入，关闭窗口后继续同一段对白。
func _suspend_dialogue_for_popup() -> Array:
	var saved := _hide_dialogue_balloons()
	for entry in saved:
		var balloon = entry.node.get_ref()
		if not is_instance_valid(balloon): continue
		entry["block"] = balloon.get("will_block_other_input")
		balloon.set("will_block_other_input", false)
		balloon.remove_from_group("ballon")
	return saved

func _resume_dialogue_after_popup(saved: Array) -> void:
	for entry in saved:
		var balloon = entry.node.get_ref()
		if not is_instance_valid(balloon) or not balloon.is_inside_tree(): continue
		balloon.add_to_group("ballon")
		balloon.set("will_block_other_input", entry.get("block", true))
	_restore_dialogue_balloons(saved)

func open_shop(npc_name: String, teach: bool = false) -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("open_shop"): return
	var saved := _suspend_dialogue_for_popup()
	var shop = scene.open_shop(npc_name)
	if teach: shop.start_material_tutorial()
	await shop.closed
	_resume_dialogue_after_popup(saved)

func has_crafting_materials() -> bool:
	return preload("res://Script/UI/CommerceLesson.gd").has_example_materials()

func open_crafting(teach: bool = false) -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("open_crafting"): return
	var saved := _suspend_dialogue_for_popup()
	var crafting = scene.open_crafting()
	if teach: crafting.start_talisman_tutorial()
	await crafting.closed
	_resume_dialogue_after_popup(saved)

func bossFight(boss: String) -> String:
	return await start_story_battle(boss)
