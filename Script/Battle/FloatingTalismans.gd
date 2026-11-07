extends Node2D

@export_range(0.0, 12.0) var float_height := 5.5
@export_range(0.5, 5.0) var period := 2.4
@export_range(0.1, 0.6) var switch_duration := 0.28
var _actor: Node2D
var _phase := 0.0
var _offsets: Array[Vector2] = []
var _label_rest: Dictionary = {}
var _slide: Tween

func _ready() -> void:
	for slot: Node2D in get_children():
		_offsets.append(slot.position)
		_label_rest[slot] = slot.get_node("Label").position
	set_process(false)

func follow(actor: Node2D) -> void:
	if actor != _actor:
		_stop_slide()
	_actor = actor
	visible = is_instance_valid(_actor)
	set_process(visible)
	if visible:
		global_position = actor.global_position

# 以符种记录此刻画面，连按或反向切换都从纸符当前的位置接续。
func displayed_poses() -> Dictionary:
	var poses := {}
	for slot: Node2D in get_children():
		var paper := slot.get_node("Sprite2D") as Sprite2D
		poses[slot.get_meta("_talisman_type_idx", -1)] = {
			"position": slot.position + paper.position,
			"scale": paper.scale,
			"alpha": paper.self_modulate.a,
		}
	return poses

func _stop_slide() -> void:
	if _slide:
		_slide.kill()
		_slide = null
	for slot: Node2D in get_children():
		var paper := slot.get_node("Sprite2D") as Sprite2D
		paper.position = Vector2.ZERO
		paper.self_modulate.a = 1.0
		var label := slot.get_node("Label") as Label
		label.position = _label_rest[slot]
		label.self_modulate.a = 1.0

func slide_to_selection(previous: Dictionary, direction: int) -> void:
	_stop_slide()
	_slide = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for slot: Node2D in get_children():
		var paper := slot.get_node("Sprite2D") as Sprite2D
		var label := slot.get_node("Label") as Label
		var target_scale := paper.scale
		var pose: Dictionary = previous.get(slot.get_meta("_talisman_type_idx"), {})
		var start: Vector2 = pose.get("position", slot.position + Vector2(24 * direction, 8))
		paper.position = start - slot.position
		paper.scale = pose.get("scale", target_scale * 0.76)
		paper.self_modulate.a = pose.get("alpha", 0.0)
		label.position = _label_rest[slot] + paper.position
		label.self_modulate.a = 0.0
		_slide.tween_property(paper, "position", Vector2.ZERO, switch_duration)
		_slide.tween_property(paper, "scale", target_scale, switch_duration)
		_slide.tween_property(paper, "self_modulate:a", 1.0, switch_duration)
		_slide.tween_property(label, "position", _label_rest[slot], switch_duration)
		_slide.tween_property(label, "self_modulate:a", 1.0, switch_duration * 0.65).set_delay(switch_duration * 0.35)

func _process(delta: float) -> void:
	if not is_instance_valid(_actor):
		follow(null)
		return
	global_position = _actor.global_position
	_phase = fmod(_phase + delta * TAU / period, TAU)
	for i in _offsets.size():
		var slot := get_child(i) as Node2D
		var angle := _phase + i * TAU / _offsets.size()
		slot.position = _offsets[i] + Vector2(1.8 * cos(angle), float_height * sin(angle))
		var paper := slot.get_node("Sprite2D") as Sprite2D
		paper.rotation = 0.075 * cos(angle)
