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
var flythrough_dmg: int = 0

var _finished: bool = false
var _hit_enemies: Array = []

signal hit


func _ready():
	if target_node and flythrough_dmg > 0:
		var bc = target_node.get_node_or_null("BattleCharacter") as BattleCharacter
		if bc:
			_hit_enemies.append(bc)
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
	_apply_flight_damage()


func _apply_flight_damage() -> void:
	if flythrough_dmg <= 0 or GameData.get_talent_rank("main_pierce") <= 0:
		return
	var bm = null
	if target_node and is_instance_valid(target_node):
		var pg = target_node.get_parent()
		if pg:
			var ppg = pg.get_parent()
			if ppg:
				bm = ppg.get_node_or_null("BattleManager")
	if bm == null:
		for c in get_tree().root.get_children():
			bm = c.get_node_or_null("BattleManager")
			if bm: break
	if bm == null:
		return
	for enemy in bm.enemies:
		if enemy in _hit_enemies or enemy.is_dead:
			continue
		var enemy_node = enemy.get_parent()
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if enemy_node.global_position.distance_squared_to(global_position) > 12000:
			continue
		_hit_enemies.append(enemy)
		var dmg = maxi(1, int(flythrough_dmg * 0.1))
		enemy.take_damage(dmg, attacker)
		enemy.sync_visual()
		bm.damage_floated.emit(enemy, dmg, "pass_through")


func _hit():
	if _finished: return
	_finished = true
	GameData.hit_stop()
	# 先应用符咒效果，再扣血（否则敌人直接死了就冻不住了）
	_apply_talisman_effect()
	# 从道具数据读取符咒命中音效
	var talisman_ids := ["talisman_fire", "talisman_thunder", "talisman_ice", "talisman_haste", "talisman_ceasefire", "talisman_revive", "talisman_basic"]
	var hit_sound := "res://Audio/SE/法术5.ogg"
	if talisman_type >= 0 and talisman_type < talisman_ids.size():
		var item_data = GameData.item_db.get(talisman_ids[talisman_type]) as ItemData
		if item_data and not item_data.hit_sound.is_empty():
			hit_sound = item_data.hit_sound
	var snd = AudioStreamPlayer.new()
	snd.stream = load(hit_sound)
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


## 运气判定 + 失败震开
func _try_apply_debuff(target_bc: BattleCharacter, buff_id: String, turns: int, base_chance: float, source: String = "") -> bool:
	var caster_luck = attacker.stats.luck + attacker.equip_special.get("luck", 0)
	var target_luck = target_bc.stats.luck + target_bc.equip_special.get("luck", 0)
	var chance := base_chance + float(caster_luck - target_luck)
	var buff_name := "封印" if buff_id == "freeze" else ("灼烧" if buff_id == "burn" else buff_id)
	
	print("[符咒] %s → %s, base=%.2f, caster_luck=%d, target_luck=%d, chance=%.2f" % [attacker.stats.get_display_name(), target_bc.stats.get_display_name(), base_chance, caster_luck, target_luck, chance])
	
	# 找 battle manager 发 log
	var bm = null
	if target_node and target_node.get_parent() and target_node.get_parent().get_parent():
		bm = target_node.get_parent().get_parent().get_node_or_null("BattleManager")
	
	if chance <= 0.0:
		if bm and bm.has_method("_push_log"):
			bm._push_log("%s 的%s被 %s 抵抗！" % [target_bc.stats.get_display_name(), buff_name, attacker.stats.get_display_name()], "system")
		if target_node and target_node.has_method("shake"):
			target_node.shake(8.0, 0.25)
		return false
	if randf() > chance:
		if bm and bm.has_method("_push_log"):
			bm._push_log("%s 的%s未能命中 %s！" % [attacker.stats.get_display_name(), buff_name, target_bc.stats.get_display_name()], "system")
		if target_node and target_node.has_method("shake"):
			target_node.shake(8.0, 0.25)
		return false
	target_bc.add_buff(buff_id, turns, null, source)
	if bm and bm.has_method("_push_log"):
		bm._push_log("%s 被%s了！" % [target_bc.stats.get_display_name(), buff_name], "debuff")
	return true


func _apply_talisman_effect():
	if attacker == null:
		print("[符咒] attacker null")
		return
	var target_bc = target_node.get_node("BattleCharacter") as BattleCharacter if target_node else null
	if target_bc == null:
		print("[符咒] target_bc null, target_node=", target_node)
		return
	print("[符咒] hit target=", target_bc.stats.get_display_name(), " talisman_type=", talisman_type, " is_dead=", target_bc.is_dead)

	match talisman_type:
		0:  # 星火篆 → 灼烧
			if not target_bc.is_dead:
				print("[符咒] 星火篆 → calling play_spell_effect")
				target_bc.play_spell_effect("星火篆")
			else:
				print("[符咒] 星火篆 skipped: target dead")
		1:  # 雷电 → 概率麻痹
			if not target_bc.is_dead:
				target_bc.play_spell_effect("五雷咒")
		2:  # 冰冻
			if not target_bc.is_dead:
				if _try_apply_debuff(target_bc, "freeze", 1, 0.7, "虚沉冰封"):
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
				# battle log
				var group = target_node.get_parent()
				if group:
					var bm = group.get_parent().get_node_or_null("BattleManager") if group.get_parent() else null
					if bm and bm.has_method("_push_log"):
						bm._push_log("%s 被扣除 %d 点蓝量" % [target_bc.stats.get_display_name(), mp_loss], "debuff")


static func shoot(
	from_pos: Vector2,
	to_pos: Vector2,
	target_node_ref: Node2D,
	hit_callback: Callable,
	parent: Node = null,
	attacker: BattleCharacter = null,
	talisman: int = 0,
	icon_texture: Texture2D = null,
	flythrough_dmg: int = 0
) -> Signal:
	var p = SpellProjectile.new()
	p.target_pos = to_pos
	p.target_node = target_node_ref
	p.on_hit = hit_callback
	p.texture = icon_texture
	p.talisman_type = talisman
	p.attacker = attacker
	p.flythrough_dmg = flythrough_dmg
	from_pos.x -= 240
	from_pos.y -= 400
	p.global_position = from_pos
	# 挂在目标所在 group 下（同一世界坐标）
	var group = target_node_ref.get_parent()
	group.add_child(p)
	return p.hit
