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
	for difficulty in [0, 1]:
		data.restore_difficulty(difficulty)
		var normal = fixture()
		normal.party[0].is_dead = true
		normal.party[0].current_hp = 0
		await normal._check_battle_end()
		assert(not normal._battle_ended_flag)
		assert(normal.state == normal.BattleState.ENEMY_TURN)
	data.restore_difficulty(2)
	var hard = fixture()
	var result := {"count": 0, "won": true}
	hard.battle_ended.connect(func(won, xp, gold, _levels):
		result.count += 1
		result.won = won
		assert(xp == 0 and gold == 0)
	)
	# 非主角死亡不触发；即使主角有必定复生，死亡也立即失败。
	hard.party[1].is_dead = true
	await hard._check_battle_end()
	assert(not hard._battle_ended_flag)
	hard.party[1].is_dead = false
	hard.party[0].trait_data["复生"] = 100
	hard.party[0].is_dead = true
	hard.party[0].current_hp = 0
	await hard._on_character_died(hard.party[0])
	assert(hard.party[0].is_dead)
	assert(hard.state == hard.BattleState.BATTLE_LOSE)
	assert(result.count == 1 and not result.won)
	await hard._check_battle_end()
	assert(result.count == 1)
	# 同归于尽优先失败；不结算金币与经验。
	var tie = fixture()
	tie.party[0].is_dead = true
	tie.enemies[0].is_dead = true
	var before_gold: int = data.player_gold
	await tie._check_battle_end()
	assert(tie.state == tie.BattleState.BATTLE_LOSE)
	assert(data.player_gold == before_gold)
	assert(data.DifficultyDB.description(2).contains("主角死亡即失败"))
	assert(not data.DifficultyDB.description(1).contains("主角死亡即失败"))
	print("HARD MAIN DEATH PASS: main death loses with living ally, revive bypassed, ally death safe, simultaneous wipe loses without reward, one result only, easy/normal unchanged")
	quit()