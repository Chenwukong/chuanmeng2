extends RefCounted

static func execute(battle, caster: BattleCharacter, data: SkillData) -> void:
	var sound = data.sound_path
	if not sound.is_empty() and ResourceLoader.exists(sound):
		var player := AudioStreamPlayer.new()
		player.stream = load(sound)
		player.bus = "SFX"
		battle.add_child(player)
		player.finished.connect(player.queue_free)
		player.play()
	# 全体覆盖，不使用随机 extra_targets；同源 buff 刷新，不叠加。
	for ally in battle.party:
		if ally.is_dead: continue
		battle.apply_buff(caster, ally, "sancai", data.apply_buff_turns, data.apply_buff_value, "三才阵")
		ally.buffs["sancai"]["mana_regen_pct"] = data.mana_regen_pct
		ally.show_trait_float("三才阵 · 双抗↑")
	var aura = battle.get_meta("sancai_domain") if battle.has_meta("sancai_domain") else null
	if not is_instance_valid(aura):
		aura = preload("res://scenes/Effects/SancaiAura.tscn").instantiate()
		var scene = battle.get_parent()
		scene.add_child(aura)
		var group = scene.get_node_or_null("EnemyGroup")
		if group: scene.move_child(aura, group.get_index())
	aura.configure(battle, caster, data)
	aura.bloom()
	var effects := "全体双抗提高30%"
	if GameData.get_talent_rank("main_sancai_mana") > 0: effects += "，每回合恢复最大法力10%"
	if GameData.get_talent_rank("main_sancai_damage") > 0: effects += "，敌人踏入阵地受到法术伤害"
	battle._push_log("【三才阵】天地人三才相合，%s，持续4回合！" % effects, "player_action")
	var visual = caster.get_parent()
	if visual and visual.has_method("play_cast_sequence"):
		await visual.play_cast_sequence("三才阵")
	await battle.get_tree().create_timer(0.45).timeout

static func recover_mana(battle, target: BattleCharacter) -> void:
	if target.is_dead or not target.has_buff("sancai"): return
	if GameData.get_talent_rank("main_sancai_mana") <= 0: return
	var pct: float = target.buffs["sancai"].get("mana_regen_pct", 0.1)
	var previous := target.current_mp
	var maximum := target.get_effective_max_mp()
	if maximum <= 0 or pct <= 0: return
	target.restore_mp(maxi(1, int(maximum * pct)))
	var actual := target.current_mp - previous
	if actual <= 0: return
	battle.damage_floated.emit(target, actual, "mp")
	battle._push_log("【三才阵】%s 恢复 %d 点法力" % [target.stats.get_display_name(), actual], "heal")
	var aura = battle.get_meta("sancai_domain") if battle.has_meta("sancai_domain") else null
	if is_instance_valid(aura): aura.pulse()
