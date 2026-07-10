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
	# 场景已自带 Sprite2D 子节点（position 0, -30），直接复用
	var spr = get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		spr = Sprite2D.new()
		spr.name = "Sprite2D"
		add_child(spr)
	
	if texture:
		spr.texture = texture
		spr.scale = Vector2(0.4, 0.4)
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
	GameData.hit_stop()
	# 先应用符咒效果，再扣血（否则敌人直接死了就冻不住了）
	_apply_talisman_effect()
	# 播放命中音效
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://Audio/SE/法术5.ogg")
	snd.bus = "SFX"
	get_tree().root.add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)
	# 冰符：播放受击动画但不扣血
	if talisman_type == 2:
		var target_bc = target_node.get_node("BattleCharacter") as BattleCharacter if target_node else null
		if target_node and is_instance_valid(target_node):
			if target_node.has_method("play_hit_once"):
				target_node.play_hit_once()
			var flash = target_node.get_node_or_null("Sprite2D")
			if flash:
				var tw = create_tween()
				tw.tween_property(flash, "modulate", Color(3, 3, 3), 0.08)
				tw.tween_property(flash, "modulate", Color.WHITE, 0.1)
		# 短暂等待让受击动画播放
		await get_tree().create_timer(0.15).timeout
		# 受击后检查冰冻状态，不要回 idle
		if target_node and is_instance_valid(target_node) and target_node.has_method("play_idle"):
			if target_bc and target_bc.is_frozen:
				target_bc.sync_freeze_anim()
			elif target_bc and target_bc.is_dead:
				pass
			else:
				target_node.play_idle()
	else:
		if on_hit.is_valid():
			on_hit.call()
	if target_node and is_instance_valid(target_node):
		var tw2 = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw2.tween_property(self, "modulate:a", 0.0, 0.2)
		tw2.tween_callback(func(): hit.emit(); queue_free())


func _apply_talisman_effect():
	if attacker == null: return
	var target_bc = target_node.get_node("BattleCharacter") as BattleCharacter if target_node else null
	if target_bc == null: return

	match talisman_type:
		0:  # 火焰 → 灼烧
			if not target_bc.is_dead:
				target_bc.add_buff("burn", 3)
			# 法术动画
			target_bc.play_spell_effect("fire")
		1:  # 雷电 → 概率麻痹
			if not target_bc.is_dead and randf() < 0.3:
				target_bc.add_buff("freeze", 1)
				target_bc.play_spell_effect("thunder")
		2:  # 冰冻
			if not target_bc.is_dead:
				target_bc.add_buff("freeze", 1, null, "虚沉冰封")
				target_bc.sync_freeze_anim()
				target_bc.show_debuff("冰封")
		3:  # 加速 → 在 battleUI 里已处理为选队友加速
			# 此处投射物已命中，不额外处理
			pass
		4:  # 止战 → 削减敌人 30% MP
			if not target_bc.is_dead:
				var mp_loss = int(target_bc.current_mp * 0.3)
				target_bc.current_mp = maxi(0, target_bc.current_mp - mp_loss)
				target_bc.sync_visual()
				target_bc.play_spell_effect("ceasefire")


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
	# 先设属性再入树，避免 _ready 触发时 texture 尚未赋值
	p.target_pos = to_pos
	p.target_node = target_node_ref
	p.on_hit = hit_callback
	p.texture = icon_texture
	p.talisman_type = talisman
	p.attacker = attacker
	from_pos.x -= 240
	from_pos.y -= 400
	p.global_position = from_pos
	# 挂在目标所在 group 下（同一世界坐标）
	var group = target_node_ref.get_parent()
	group.add_child(p)
	return p.hit
