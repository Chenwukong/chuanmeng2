extends Node2D
## 独立地面场景，跟随角色但不继承攻击时的置顶层级或变身缩放。
@export var radius: float = 90.0
@export var ground_ratio: float = 0.55
var caster: BattleCharacter
var manager: BattleManager
var contact_enemies: Dictionary = {} # 当前接触中；离开后即可再次灼烧。
var previous_offsets: Dictionary = {}
var skill: SkillData

static func active_for(actor: BattleCharacter) -> bool:
	return actor.has_meta("fire_domain") and is_instance_valid(actor.get_meta("fire_domain"))

func configure(battle: BattleManager, actor: BattleCharacter, data: SkillData) -> void:
	manager = battle
	caster = actor
	skill = data
	radius = data.contact_radius
	caster.set_meta("fire_domain", self)
	$Ring.scale = Vector2(radius / 90.0, 1.0)
	$Embers.emission_rect_extents = Vector2(radius * 0.71, radius * ground_ratio * 0.3)
	global_position = caster.get_parent().global_position

func _process(_delta: float) -> void:
	check_contacts()

func check_contacts() -> void:
	if not is_instance_valid(caster) or not is_instance_valid(manager):
		queue_free()
		return
	if caster.is_dead or manager.state in [manager.BattleState.BATTLE_WIN, manager.BattleState.BATTLE_LOSE]:
		queue_free()
		return
	global_position = caster.get_parent().global_position
	for enemy in manager.enemies:
		if not is_instance_valid(enemy) or enemy.is_dead: continue
		var key := enemy.get_instance_id()
		var offset: Vector2 = enemy.get_parent().global_position - global_position
		offset.y /= ground_ratio
		var previous: Vector2 = previous_offsets.get(key, offset)
		previous_offsets[key] = offset
		var was_contacting := contact_enemies.has(key)
		var inside := offset.length_squared() <= radius * radius
		if not inside: contact_enemies.erase(key)
		# 停留和离开不重复触发；必须离开后重新进入。
		if was_contacting: continue
		# 相对运动的线段检测：自己移动和敌人移动都能触发，低帧率下也不漏掉穿越。
		var nearest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, previous, offset)
		if nearest.length_squared() > radius * radius: continue
		# 无敌期间不消耗本次接触，解除无敌后仍可灼烧。
		if enemy.has_buff("invincible"): continue
		# 单帧穿越后已在圈外，下一段运动按新的接触检测。
		if inside: contact_enemies[key] = true
		var amount := maxi(1, int(caster.get_effective_magic_attack() * skill.damage_multiplier) - int(enemy.get_effective_magic_defense() * 0.6) + skill.flat_damage)
		var options := {"is_magic": true, "emit_float": true, "skill_id": "火域"}
		# 接触可能发生在敌人行动期间，也沿用骰子的待用倍率并解锁重掷。
		var off_turn := caster != manager.current_actor() or manager.state != manager.BattleState.PLAYER_ACTION
		if off_turn and caster.dice_has_pending: amount = maxi(1, int(amount * caster.dice_pending_multiplier))
		var actual := manager.apply_damage(caster, enemy, amount, options)
		if off_turn: caster.settle_dice_hit()
		if actual > 0:
			# 复用持续灼烧结算的序列帧动画，直接播放在受击敌人身上。
			enemy.play_spell_effect("烧伤")
			var contact = preload("res://scenes/Effects/FireDomainContact.tscn").instantiate()
			enemy.get_parent().add_child(contact)
			manager._push_log("【火域】%s 被火圈灼烧，受到 %d 点伤害！" % [enemy.stats.get_display_name(), actual], "player_action")

func _exit_tree() -> void:
	if is_instance_valid(caster) and caster.has_meta("fire_domain") and caster.get_meta("fire_domain") == self:
		caster.remove_meta("fire_domain")
