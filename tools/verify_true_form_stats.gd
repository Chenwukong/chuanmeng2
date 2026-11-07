extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var data = root.get_node("GameData")
	data.set_process(false)
	data.talent_ranks = {}
	var rules = load("res://Script/Battle/TrueFormRules.gd")
	var original = load("res://Script/Data/Models/CharacterStats.gd").new()
	for stat in rules.BASE_STATS: original.set(stat, 100)
	var actor = load("res://Script/Battle/BattleCharacter.gd").new()
	root.add_child(actor)
	actor.stats = original.duplicate_for_battle()
	actor.is_player = true
	actor.current_hp = 40
	actor.current_mp = 70
	rules.apply(actor)
	for stat in rules.BASE_STATS:
		assert(actor.stats.get(stat) == (130 if stat in ["defense", "magic_defense"] else 150))
		assert(original.get(stat) == 100)
	assert(actor.current_hp == 60 and actor.current_mp == 105)
	assert(actor.get_effective_attack() == 150 and actor.get_effective_magic_attack() == 150)
	assert(actor.get_effective_defense() == 130 and actor.get_effective_magic_defense() == 130)
	assert(actor.get_effective_speed() == 150)
	rules.apply(actor)
	assert(actor.stats.max_hp == 150 and actor.current_hp == 60)
	# 新一场战斗从永久数据重新复制，不继承变身增幅。
	var next_battle = original.duplicate_for_battle()
	assert(next_battle.max_hp == 100 and next_battle.luck == 100)
	print("TRUE FORM STATS PASS: dual defenses +30%, other base stats +50%, current HP/MP ratios preserved, effective combat stats updated, no duplicate stacking, persistent stats and next battle unchanged")
	quit()