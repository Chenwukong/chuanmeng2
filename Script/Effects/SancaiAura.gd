extends Node2D
## 一个共享的阵地，位置在施放时确定，不跟随出击的角色。
@export var ground_ratio: float = 0.58
@export var minimum_radius: float = 220.0
@export var boundary_padding: float = 65.0
var manager: BattleManager
var caster: BattleCharacter
var skill: SkillData
var radius: float = 220.0
var _bloom: Tween
var _inside: Dictionary = {}
var _previous: Dictionary = {}

func configure(battle: BattleManager, source: BattleCharacter, data: SkillData) -> void:
	manager = battle
	caster = source
	skill = data
	manager.set_meta("sancai_domain", self)
	_inside.clear()
	_previous.clear()
	var positions: Array[Vector2] = []
	for ally in manager.party:
		if not ally.is_dead: positions.append(ally.get_parent().global_position)
	var bounds := Rect2(positions[0], Vector2.ZERO)
	for point in positions: bounds = bounds.expand(point)
	global_position = bounds.get_center()
	radius = minimum_radius
	for point in positions:
		var distance := point - global_position
		distance.y /= ground_ratio
		radius = maxf(radius, distance.length() + boundary_padding)
	$Ground.scale = Vector2(radius / 66.4, radius * ground_ratio / 66.4)
	$Ground.material.set_shader_parameter("stroke_scale", clampf(90.0 / radius, 0.3, 1.0))
	$Heaven.position = Vector2(-12, -radius * ground_ratio * 0.61 - 10)
	$Earth.position = Vector2(-radius * 0.53 - 12, radius * ground_ratio * 0.31 - 10)
	$Human.position = Vector2(radius * 0.53 - 12, radius * ground_ratio * 0.31 - 10)
	$Wisps.emission_rect_extents = Vector2(radius * 0.7, radius * ground_ratio * 0.6)

func bloom() -> void:
	$Wisps.restart()
	$Wisps.emitting = true
	if _bloom and _bloom.is_valid(): _bloom.kill()
	scale = Vector2.ONE * 0.45
	modulate.a = 0.0
	_bloom = create_tween().set_parallel(true)
	_bloom.tween_property(self, "scale", Vector2.ONE * 1.05, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bloom.tween_property(self, "modulate:a", 0.85, 0.3)
	_bloom.chain().tween_property(self, "scale", Vector2.ONE, 0.55)
	_bloom.parallel().tween_property(self, "modulate:a", 0.64, 0.55)

func pulse() -> void:
	$Wisps.restart()
	$Wisps.emitting = true
	if _bloom and _bloom.is_valid(): _bloom.kill()
	scale = Vector2.ONE
	modulate.a = 0.75
	_bloom = create_tween()
	_bloom.tween_property(self, "modulate:a", 0.64, 0.65)

func _process(_delta: float) -> void:
	check_contacts()

func check_contacts() -> void:
	if not is_instance_valid(manager) or not is_instance_valid(caster):
		queue_free()
		return
	var active := false
	for ally in manager.party:
		if not ally.is_dead and ally.has_buff("sancai"): active = true
	if not active or manager.state in [manager.BattleState.NONE, manager.BattleState.BATTLE_WIN, manager.BattleState.BATTLE_LOSE]:
		queue_free()
		return
	if GameData.get_talent_rank("main_sancai_damage") <= 0:
		_inside.clear()
		_previous.clear()
		return
	for enemy in manager.enemies:
		if not is_instance_valid(enemy) or enemy.is_dead: continue
		var key := enemy.get_instance_id()
		var offset: Vector2 = enemy.get_parent().global_position - global_position
		offset.y /= ground_ratio
		var previous: Vector2 = _previous.get(key, offset)
		_previous[key] = offset
		if _inside.has(key):
			# 微小容差防止动画抖动在边界上反复刷伤害。
			if offset.length() > radius + 5.0: _inside.erase(key)
			continue
		var nearest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, previous, offset)
		if nearest.length_squared() > radius * radius: continue
		if offset.length_squared() <= radius * radius: _inside[key] = true
		var amount := maxi(1, int(caster.get_effective_magic_attack() * skill.damage_multiplier) - int(enemy.get_effective_magic_defense() * 0.6) + skill.flat_damage)
		var off_turn := caster != manager.current_actor() or manager.state != manager.BattleState.PLAYER_ACTION
		if off_turn and caster.dice_has_pending: amount = maxi(1, int(amount * caster.dice_pending_multiplier))
		var actual := manager.apply_damage(caster, enemy, amount, {"is_magic": true, "emit_float": true, "skill_id": "三才阵"})
		if off_turn: caster.settle_dice_hit()
		if actual > 0:
			pulse()
			manager._push_log("【三才阵】%s 踏入阵地，受到 %d 点法术伤害！" % [enemy.stats.get_display_name(), actual], "player_action")

func _exit_tree() -> void:
	if is_instance_valid(manager) and manager.has_meta("sancai_domain") and manager.get_meta("sancai_domain") == self:
		manager.remove_meta("sancai_domain")
