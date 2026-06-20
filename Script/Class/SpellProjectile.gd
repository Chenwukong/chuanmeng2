# SpellProjectile.gd — 符咒投射物，飞向目标并触发效果
class_name SpellProjectile
extends Node2D

var speed: float = 1000.0
var target_pos: Vector2
var target_node: Node2D
var on_hit: Callable
var texture: Texture2D
var talisman_type: int = 0
var attacker: BattleCharacter = null

var _finished: bool = false

signal hit


func _ready():
	var spr = Sprite2D.new()
	spr.name = "Sprite"
	spr.scale = Vector2(0.5, 0.5)
	add_child(spr)

	if texture:
		spr.texture = texture
	else:
		var colors = [Color(1.0, 0.3, 0.2), Color(0.7, 0.3, 1.0), Color(0.3, 0.6, 1.0), Color(0.3, 1.0, 0.5)]
		var c = colors[talisman_type] if talisman_type < colors.size() else Color.RED
		var rect = ColorRect.new()
		rect.color = c
		rect.size = Vector2(20, 20)
		rect.position = Vector2(-10, -10)
		add_child(rect)

	z_index = 100


func _process(delta):
	if _finished or not is_inside_tree():
		return
	var dir = target_pos - global_position
	var dist = dir.length()
	if dist < 20:
		_hit()
		return
	global_position += dir.normalized() * min(delta * speed, dist)
	rotation = dir.angle() - deg_to_rad(90)


func _hit():
	if _finished: return
	_finished = true
	if on_hit.is_valid():
		on_hit.call()
	_apply_talisman_effect()
	if target_node and is_instance_valid(target_node):
		var flash = target_node.get_node_or_null("Sprite2D")
		if flash:
			var tw = create_tween()
			tw.tween_property(flash, "modulate", Color(3, 3, 3), 0.08)
			tw.tween_property(flash, "modulate", Color.WHITE, 0.1)
	var tw2 = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw2.tween_property(self, "modulate:a", 0.0, 0.2)
	tw2.tween_callback(func(): hit.emit(); queue_free())


func _apply_talisman_effect():
	if attacker == null: return
	var target_bc = target_node.get_node("BattleCharacter") as BattleCharacter if target_node else null
	if target_bc == null: return

	match talisman_type:
		0:
			if not target_bc.is_dead:
				target_bc.add_buff("burn", 3)
		1:
			if not target_bc.is_dead:
				target_bc.add_buff("freeze", 1)
		2:
			if not target_bc.is_dead:
				target_bc.add_buff("slow", 2)
		3:
			if not target_bc.is_dead:
				target_bc.add_buff("haste", 3)


static func shoot(
	from_pos: Vector2,
	to_pos: Vector2,
	target_node_ref: Node2D,
	hit_callback: Callable,
	parent: Node,
	attacker: BattleCharacter = null,
	talisman: int = 0,
	icon_texture: Texture2D = null
) -> Signal:
	var p = SpellProjectile.new()
	# 挂在目标所在 group 下（敌人/我方都在 BattleScene 的 Node2D 子节点中）
	# 这样投射物和角色在同一世界坐标系
	var group = target_node_ref.get_parent()
	p.global_position = from_pos
	p.target_pos = to_pos
	p.target_node = target_node_ref
	p.on_hit = hit_callback
	p.texture = icon_texture
	p.talisman_type = talisman
	p.attacker = attacker
	group.add_child(p)
	return p.hit
