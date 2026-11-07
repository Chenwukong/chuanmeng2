extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func unit(id: String, player: bool):
	var c = load("res://Script/Battle/BattleCharacter.gd").new()
	c.stats = load("res://Script/Data/Models/CharacterStats.gd").new()
	c.stats.max_hp = 100
	c.stats.character_name = id
	c.current_hp = 100
	c.member_id = id
	c.is_player = player
	root.add_child(c)
	return c
func fixture():
	var m = load("res://Script/Battle/BattleManager.gd").new()
	var ai = load("res://Script/Battle/EnemyAI.gd").new()
	ai.name = "EnemyAI"
	m.add_child(ai)
	root.add_child(m)
	m.set_process(false)
	m._threat_mgr = load("res://Script/Battle/ThreatManager.gd").new()
	m.party.assign([unit("youxiaoyun", true), unit("ally", true)])
	m.enemies.assign([unit("enemy", false)])
	m.state = m.BattleState.ENEMY_TURN
	return m
func verify() -> void:
	var data = root.get_node("GameData")
	data.set_process(false)
	data.talent_ranks = {}
	data.restore_difficulty(1)
	var rules = load("res://Script/Battle/DelayedRevival.gd")
	var equip = load("res://Script/Data/Models/EquipData.gd").get_named("还魂珠")
	assert(not equip.is_empty())
	var effects = load("res://Script/Battle/AccessoryEffects.gd").equipment_stats(equip)
	assert(effects.delayed_revival == 3)
	var m = fixture()
	var actor = m.party[0]
	actor.equip_special = effects
	actor.is_dead = true
	actor.current_hp = 0
	await m._on_character_died(actor)
	assert(m._delayed_revivals.has(actor))
	assert(m._delayed_revivals[actor].turns == 3)
	var duration: float = 100.0 / (5.0 + actor.get_effective_speed() * 0.8) + 0.00001
	for turn in 2:
		rules.tick(m, duration)
		assert(actor.is_dead)
		assert(m._delayed_revivals[actor].turns == 2 - turn)
	rules.tick(m, duration)
	assert(not actor.is_dead and actor.current_hp == 50)
	assert(actor.current_sp == 0)
	assert(not m._delayed_revivals.has(actor))
	# 再次死亡重新计3回合，提前被救起取消，不额外回血。
	actor.is_dead = true
	actor.current_hp = 0
	await m._on_character_died(actor)
	assert(m._delayed_revivals[actor].turns == 3)
	m.apply_heal(null, actor, 20, true)
	rules.tick(m, duration * 3)
	assert(actor.current_hp == 20 and not m._delayed_revivals.has(actor))
	# 全灭不能拖延失败，困难主角死亡不能靠饰品保命。
	actor.is_dead = true
	actor.current_hp = 0
	m.party[1].is_dead = true
	await m._on_character_died(actor)
	assert(m.state == m.BattleState.BATTLE_LOSE)
	assert(m._delayed_revivals.is_empty())
	data.restore_difficulty(2)
	var hard = fixture()
	hard.party[0].equip_special = effects
	hard.party[0].is_dead = true
	hard.party[0].current_hp = 0
	await hard._on_character_died(hard.party[0])
	assert(hard.state == hard.BattleState.BATTLE_LOSE)
	assert(hard._delayed_revivals.is_empty())
	print("DELAYED REVIVAL PASS: equipment effect, three personal SP rounds, 50% HP, reset SP, repeat death, early revive cancels, all-dead loss and hard protagonist loss preserved")
	quit()