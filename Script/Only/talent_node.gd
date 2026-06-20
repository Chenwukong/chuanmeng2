@tool
class_name TalentNode
extends Button

@export var talent_id: String = ""
@export var talent_name: String = ""
@export_multiline var description: String = ""
@export_range(1, 10, 1) var max_rank: int = 1
@export var requirements: Array[Resource] = []

var rank: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(126, 70)
	size = custom_minimum_size
	_update_text()


func can_upgrade(points: int) -> bool:
	if points <= 0:
		return false
	if rank >= max_rank:
		return false
	return requirements_met()


func requirements_met() -> bool:
	for requirement in requirements:
		if requirement == null:
			continue

		var path := requirement.get("talent_path") as NodePath
		var required_rank := int(requirement.get("rank_required"))
		if path.is_empty():
			continue

		var target := _resolve_requirement_talent(path)
		if target == null or not target.has_method("get_rank"):
			return false
		if target.get_rank() < required_rank:
			return false

	return true


func add_rank() -> void:
	rank = mini(rank + 1, max_rank)
	_update_text()


func refresh_state(points: int) -> void:
	disabled = not can_upgrade(points)
	if rank >= max_rank:
		modulate = Color(1.0, 0.86, 0.38, 1.0)
	elif requirements_met():
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		modulate = Color(0.48, 0.48, 0.48, 1.0)
	_update_text()


func get_rank() -> int:
	return rank


func get_detail_text() -> String:
	var requirement_text := "无"
	if not requirements.is_empty():
		var parts: Array[String] = []
		for requirement in requirements:
			if requirement == null:
				continue
			var path := requirement.get("talent_path") as NodePath
			var required_rank := int(requirement.get("rank_required"))
			var target := _resolve_requirement_talent(path)
			var target_name := str(path)
			if target != null and "talent_name" in target:
				target_name = target.talent_name
			parts.append("%s %d级" % [target_name, required_rank])
		if not parts.is_empty():
			requirement_text = "、".join(parts)

	return "[b]%s[/b]\n\n%s\n\n等级：%d/%d\n前置：%s\n\n点击消耗 1 点天赋点升级。" % [
		talent_name,
		description,
		rank,
		max_rank,
		requirement_text,
	]


func _update_text() -> void:
	text = "%s\n%d/%d" % [talent_name, rank, max_rank]


func _resolve_requirement_talent(path: NodePath) -> Node:
	var from_parent := get_parent().get_node_or_null(path)
	if from_parent != null:
		return from_parent
	return get_node_or_null(path)
