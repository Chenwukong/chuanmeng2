extends Node2D

var manager: BattleManager
var summoner: BattleCharacter
var units: Array[Node2D] = [null, null, null]
var rounds_left: int = 0
var skill: SkillData
var _dismissing := false

static func capacity() -> int:
	return 3 + clampi(GameData.get_talent_rank("main_bean_legion"), 0, 3)

func configure(battle: BattleManager, source: BattleCharacter) -> void:
	manager = battle
	summoner = source
	summoner.set_meta("bean_army", self)

func summon(data: SkillData) -> void:
	skill = data
	rounds_left = data.apply_buff_turns
	_dismissing = false
	var caster_position: Vector2 = summoner.get_parent().global_position
	var desired := capacity()
	for slot in range(desired, units.size()):
		if is_instance_valid(units[slot]):
			manager.bean_soldiers.erase(units[slot].character)
			units[slot].disperse()
			units[slot].queue_free()
	units.resize(desired)
	var occupied: Array[Vector2] = []
	for ally in manager.party:
		if not ally.is_dead: occupied.append(ally.get_parent().global_position)
	for slot in desired:
		var home := _find_home(caster_position, occupied, slot)
		occupied.append(home)
		if is_instance_valid(units[slot]) and not units[slot].character.is_dead:
			units[slot].reposition(home)
			continue
		if is_instance_valid(units[slot]):
			manager.bean_soldiers.erase(units[slot].character)
			units[slot].queue_free()
		var unit = preload("res://scenes/Effects/BeanSoldier.tscn").instantiate()
		add_child(unit)
		units[slot] = unit
		unit.configure(manager, summoner, home, slot)
		manager.bean_soldiers.append(unit.character)
		unit.materialize(caster_position, slot * 0.10)
	manager.refresh_summon_synergies()
	manager._push_log("【撒豆成兵】金豆落地，%d 名草甲豆兵听令！" % desired, "player_action")
	var visual = summoner.get_parent()
	if visual and visual.has_method("play_cast_sequence"): await visual.play_cast_sequence("撒豆成兵")
	# 扩容后等待最后一粒豆子化形，避免齐攻和化形 Tween 互相覆盖。
	while units.any(func(unit): return is_instance_valid(unit) and unit.materializing):
		await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout

func _find_home(origin: Vector2, occupied: Array[Vector2], slot: int) -> Vector2:
	var screen := get_viewport_rect().size
	for marker in $Homes.get_children():
		var point: Vector2 = origin + marker.position
		point.x = clampf(point.x, 360.0, maxf(400.0, screen.x - 55.0))
		point.y = clampf(point.y, 190.0, maxf(240.0, screen.y - 55.0))
		var clear := true
		for taken in occupied:
			if taken.distance_squared_to(point) < 56.0 * 56.0: clear = false
		if clear: return point
	return Vector2(minf(origin.x + 80.0 + slot * 25.0, screen.x - 35.0), clampf(origin.y + (slot - 1) * 65.0, 190.0, screen.y - 45.0))

func get_guardian(protected: BattleCharacter = null) -> Node2D:
	if _dismissing or rounds_left <= 0 or summoner.is_dead: return null
	if protected != null and protected != summoner:
		if GameData.get_talent_rank("summon_love_allies") <= 0 or protected not in manager.party or protected.is_dead: return null
	for unit in units:
		if is_instance_valid(unit) and unit.can_guard(): return unit
	return null

func choose_target() -> BattleCharacter:
	var enemies := manager.alive_enemies()
	if enemies.is_empty(): return null
	var field = manager.get_meta("sancai_domain") if manager.has_meta("sancai_domain") else null
	if GameData.get_talent_rank("main_bean_formation") > 0 and is_instance_valid(field):
		for enemy in enemies:
			var offset: Vector2 = enemy.get_parent().global_position - field.global_position
			offset.y /= field.ground_ratio
			if offset.length_squared() <= field.radius * field.radius: return enemy
	if is_instance_valid(manager._last_target) and manager._last_target in enemies: return manager._last_target
	return enemies[0]

func after_owner_action() -> void:
	if _dismissing or rounds_left <= 0 or summoner.is_dead: return
	for unit in units:
		if not is_instance_valid(unit) or unit.character.is_dead: continue
		var target := choose_target()
		if target == null: break
		var damage_bonus: float = preload("res://Script/Battle/TalentRules.gd").get_pet_stat_mult("damage") * (1.0 + 0.20 * clampi(GameData.get_talent_rank("main_bean_damage"), 0, 3))
		await unit.strike(target, maxi(1, int(summoner.get_effective_magic_attack() * skill.damage_multiplier * damage_bonus)))
	rounds_left -= 1
	if rounds_left <= 0: await dismiss()

func _process(_delta: float) -> void:
	if not is_instance_valid(summoner) or not is_instance_valid(manager):
		queue_free()
		return
	if not _dismissing and (summoner.is_dead or manager.state in [manager.BattleState.NONE, manager.BattleState.BATTLE_WIN, manager.BattleState.BATTLE_LOSE]):
		dismiss()

func dismiss() -> void:
	if _dismissing: return
	_dismissing = true
	for unit in units:
		if is_instance_valid(unit): unit.disperse()
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(manager):
		for unit in units:
			if is_instance_valid(unit): manager.bean_soldiers.erase(unit.character)
	if is_instance_valid(summoner) and summoner.has_meta("bean_army") and summoner.get_meta("bean_army") == self:
		summoner.remove_meta("bean_army")
