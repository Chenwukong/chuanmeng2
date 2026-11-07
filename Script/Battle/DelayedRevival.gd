extends RefCounted
## 死亡角色不参与行动队列，用独立行动条累计其本人的死亡回合。
static func schedule(battle, target: BattleCharacter) -> void:
	if battle._battle_ended_flag: return
	var turns := int(target.equip_special.get("delayed_revival", 0))
	if turns <= 0 or not target.is_player or not target.is_dead: return
	battle._delayed_revivals[target] = {"turns": turns, "sp": 0.0}
	preload("res://Script/Battle/AccessoryEffects.gd").notify(target, "delayed_revival", "%d回合后还魂" % turns, battle)

static func tick(battle, delta: float) -> void:
	if battle._battle_ended_flag: return
	for target in battle._delayed_revivals.keys():
		if not is_instance_valid(target) or target not in battle.party or not target.is_dead:
			battle._delayed_revivals.erase(target)
			continue
		var pending: Dictionary = battle._delayed_revivals[target]
		pending.sp += (5.0 + target.get_effective_speed() * 0.8) * delta
		while pending.sp >= 100.0 and pending.turns > 0:
			pending.sp -= 100.0
			pending.turns -= 1
			if pending.turns > 0:
				target.show_trait_float("还魂 · 剩%d回合" % pending.turns)
		if pending.turns > 0: continue
		battle._delayed_revivals.erase(target)
		var amount := maxi(1, int(target.get_effective_max_hp() * 0.5))
		battle.apply_heal(null, target, amount, true)
		target.reset_sp()
		target.consecutive_turns = 0
		target.sync_visual()
		preload("res://Script/Battle/AccessoryEffects.gd").notify(target, "delayed_revival", "还魂复活 · 恢复50%气血", battle)
