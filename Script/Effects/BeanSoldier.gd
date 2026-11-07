extends Node2D

@onready var character: BattleCharacter = $BattleCharacter
var manager: BattleManager
var home: Vector2
var _clock := 0.0
var _moving := false
var _gone := false
var _guarding := false
var _rest_flip_h := false
var _motion: Tween
var materializing := false

func _ready() -> void:
	character.died.connect(disperse)
	character.hp_changed.connect(_on_hp_changed)

func configure(battle: BattleManager, summoner: BattleCharacter, home_position: Vector2, slot: int) -> void:
	manager = battle
	home = home_position
	global_position = home
	_refresh_facing()
	# 辅助单位只接入生命/伤害结算，不执行常规队友 setup，不创建行动条或宠物 UI。
	character.stats = CharacterStats.new()
	character.stats.character_name = "豆兵%d" % (slot + 1)
	character.stats.character_class = "豆兵"
	character.stats.role = CharacterStats.Role.SUMMON
	var summon_rules = preload("res://Script/Battle/TalentRules.gd")
	character.stats.max_hp = int(maxi(12, int(summoner.get_effective_max_hp() * 0.18)) * summon_rules.get_pet_stat_mult("hp") * (1.0 + 0.30 * clampi(GameData.get_talent_rank("main_bean_hp"), 0, 3)))
	character.stats.max_mp = 0
	character.stats.defense = int(summoner.stats.defense * 0.25 * summon_rules.get_pet_stat_mult("defense"))
	character.stats.magic_defense = int(summoner.stats.magic_defense * 0.25 * summon_rules.get_pet_stat_mult("defense"))
	character.stats.speed = int(summoner.get_effective_speed() * summon_rules.get_pet_stat_mult("speed"))
	character.current_hp = character.stats.max_hp
	character.current_mp = 0
	character.is_player = true
	character.is_summoned_pet = true
	character.member_id = "bean_%s_%d" % [summoner.member_id, slot]
	character.summoner_member_id = summoner.member_id
	preload("res://Script/Battle/AccessoryEffects.gd").empower_summon(summoner, character, manager)
	$Health.max_value = character.stats.max_hp
	$Health.value = character.current_hp
	$Health.hide()
	_clock = slot * 1.9

func materialize(origin: Vector2, delay: float) -> void:
	materializing = true
	_moving = true
	$Body.hide()
	$Bean.show()
	$Bean.position = origin - home + Vector2(0, -40)
	await get_tree().create_timer(delay).timeout
	var start: Vector2 = $Bean.position
	_motion = create_tween()
	_motion.tween_method(func(t: float):
		$Bean.position = start.lerp(Vector2(0, -6), t) - Vector2(0, sin(t * PI) * 70.0)
		$Bean.rotation = t * TAU * 2.0
	, 0.0, 1.0, 0.48)
	await _wait_motion()
	if _gone: return
	$Bean.hide()
	$Smoke.restart()
	$Smoke.emitting = true
	$Body.show()
	$Health.show()
	$Body.scale = Vector2(0.15, 0.15)
	_motion = create_tween()
	_motion.tween_property($Body, "scale", Vector2.ONE * 0.58, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait_motion()
	if _gone: return
	_moving = false
	materializing = false

func strike(target: BattleCharacter, amount: int) -> void:
	if _gone or character.is_dead: return
	_moving = true
	$Body.flip_h = target.get_parent().global_position.x > global_position.x
	var destination: Vector2 = target.get_parent().global_position + Vector2(28, 8)
	var speed_bonus: float = preload("res://Script/Battle/TalentRules.gd").get_pet_stat_mult("speed")
	_motion = create_tween()
	_motion.tween_property(self, "global_position", destination, 0.21 / speed_bonus).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _wait_motion()
	if _gone: return
	if not character.is_dead and is_instance_valid(target) and not target.is_dead:
		var actual := manager.apply_damage(character, target, amount, {"is_magic": true, "secondary": true, "emit_float": true, "skill_id": "撒豆成兵"})
		if actual > 0:
			var visual = target.get_parent()
			if visual.has_method("play_hit_flash"): visual.play_hit_flash()
	await get_tree().create_timer(0.06).timeout
	if _gone: return
	_motion = create_tween()
	_motion.tween_property(self, "global_position", home, 0.2 / speed_bonus).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait_motion()
	if _gone: return
	_moving = false
	_refresh_facing()
	$Body.flip_h = _rest_flip_h

func _process(delta: float) -> void:
	_clock += delta
	if not _moving and not _gone:
		$Body.position.y = -27.0 + sin(_clock * 3.6) * 1.1
		$Body.rotation = sin(_clock * 2.3) * 0.025

func _on_hp_changed(_old: int, value: int, _maximum: int) -> void:
	$Health.value = value
	$Health.visible = value > 0

func can_guard() -> bool:
	return not _gone and not character.is_dead and not character.cannot_act() and (not _moving or _guarding)

func reposition(destination: Vector2) -> void:
	home = destination
	global_position = home
	_refresh_facing()

func _refresh_facing() -> void:
	# 原画是朝左上敌阵的侧背面；敌阵换到右侧时才水平翻转。
	var enemies := manager.alive_enemies()
	var enemy_x := 0.0
	for enemy in enemies: enemy_x += enemy.get_parent().global_position.x
	_rest_flip_h = not enemies.is_empty() and enemy_x / maxf(1.0, float(enemies.size())) > home.x
	$Body.flip_h = _rest_flip_h

func protect_hit(protected_position: Vector2, attacker_position: Vector2) -> void:
	if not can_guard(): return
	_guarding = true
	_moving = true
	if _motion and _motion.is_valid(): _motion.kill()
	z_index = 100
	global_position = protected_position + (attacker_position - protected_position).normalized() * 26.0
	$Body.flip_h = attacker_position.x > protected_position.x
	$GuardText.show()
	$GuardText.modulate.a = 1.0
	$GuardShield.show()
	$GuardShield.modulate.a = 0.85
	play_hit_flash()
	_motion = create_tween()
	_motion.tween_interval(0.16)
	_motion.tween_property(self, "global_position", home, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion.parallel().tween_property($GuardShield, "modulate:a", 0.0, 0.18)
	_motion.parallel().tween_property($GuardText, "modulate:a", 0.0, 0.18)
	_motion.tween_callback(func():
		_guarding = false
		_moving = false
		z_index = 0
		$Body.flip_h = _rest_flip_h
		$GuardShield.hide()
		$GuardText.hide()
	)

func play_hit_flash() -> void:
	if _gone: return
	$Body.modulate = Color(1.8, 1.6, 0.9)
	var flash := create_tween()
	flash.tween_property($Body, "modulate", Color.WHITE, 0.16)

func play_hit_reaction(_stay: bool = false) -> void:
	play_hit_flash()

func play_hit_once() -> void:
	play_hit_flash()

func play_idle() -> void:
	pass

func disperse() -> void:
	if _gone: return
	_gone = true
	materializing = false
	$GuardShield.hide()
	$GuardText.hide()
	character.is_dead = true
	if is_instance_valid(manager): manager.refresh_summon_synergies()
	if _motion and _motion.is_valid(): _motion.kill()
	$Body.hide()
	$Health.hide()
	$Bean.hide()
	$GuardShield.hide()
	$GuardText.hide()
	$Fragments.restart()
	$Fragments.emitting = true
	$Smoke.restart()
	$Smoke.emitting = true

func _wait_motion() -> void:
	while not _gone and _motion and _motion.is_valid() and _motion.is_running():
		await get_tree().process_frame
