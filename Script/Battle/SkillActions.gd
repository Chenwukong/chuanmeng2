extends RefCounted
## 战斗功能模块；状态和动画宿主由 BattleManager 显式传入。

static func player_use_skill(_battle, skill_id: String, target: BattleCharacter) -> void:
	if _battle.state != _battle.BattleState.PLAYER_TURN:
		return
	var is_mimic := skill_id == "千机变"
	if not _battle._current_actor.mech_fusion.is_empty() and skill_id not in preload("res://Script/Battle/MechFusion.gd").SKILLS:
		_battle.skill_failed.emit("合体期间只能使用机甲技能，请先解除合体。")
		return
	var mimic_source: String = ""
	if skill_id == "千机变":
		var copied := preload("res://Script/Battle/MimicRules.gd").resolve(_battle, _battle._current_actor, target)
		if copied.has("error"):
			_battle.skill_failed.emit(copied.error)
			_battle._push_log(copied.error, "system")
			_battle._play_error_sound()
			return
		mimic_source = target.stats.get_display_name()
		skill_id = copied.skill
		target = copied.target
	var data = SkillManager.get_skill(skill_id)
	if data == null:
		_battle.skill_failed.emit(GameData._T("BATTLE_SKILL_NOT_FOUND"))
		_battle._push_log(GameData._T("BATTLE_SKILL_NOT_FOUND"), "system")
		return
	if data.target_type == SkillData.TargetType.SELF:
		target = _battle._current_actor
	elif data.target_type == SkillData.TargetType.SINGLE_ENEMY and (not is_instance_valid(target) or target not in _battle.enemies or target.is_dead):
		_battle.skill_failed.emit("技能目标已失效，请重新选择。")
		return
	elif data.target_type == SkillData.TargetType.SINGLE_ALLY and (not is_instance_valid(target) or target not in _battle.party or target.is_dead != (data.heal_size == "revive")):
		_battle.skill_failed.emit("技能目标已失效，请重新选择。")
		return
	# 封技能：被封印时不能使用技能（仍可普通攻击）
	if _battle._current_actor.has_buff("silence"):
		_battle.skill_failed.emit("被封技能，无法使用技能！")
		_battle._push_log("【封印】%s 被封技能，无法使用技能！" % _battle._current_actor.stats.get_display_name(), "system")
		_battle._play_error_sound()
		return
	if is_mimic:
		var copied_data: SkillData = SkillManager.get_skill(skill_id)
		var cost: int = _battle._current_actor.get_skill_mp_cost(copied_data.mp_cost)
		if _battle._current_actor.current_mp < cost:
			_battle.skill_failed.emit("法力不足，无法模仿【%s】。" % skill_id)
			_battle._push_log("法力不足，无法模仿【%s】。" % skill_id, "system")
			return
	var cd_key = _battle._cd_key(_battle._current_actor, skill_id)
	if skill_id in ["机甲合体", "解除合体", "机甲重击", "机甲炮击"]:
		var reason := preload("res://Script/Battle/MechFusion.gd").validate(_battle, _battle._current_actor, skill_id)
		if not reason.is_empty():
			_battle.skill_failed.emit(reason)
			_battle._push_log(reason, "system")
			return
	# 横扫不休：跳过冷却
	var no_cd = _battle._current_actor.check_no_cooldown_after_skill(skill_id)
	if no_cd:
		_battle._push_log(GameData._T("LOG_NO_CD") % [_battle._current_actor.stats.get_display_name(), "横扫不休"], "player_action")
		_battle._current_actor.show_trait_float("横扫不休")
	print("横扫不休 check: ", no_cd)
	if not no_cd and _battle.skill_cooldowns.get(cd_key, 0) > 0:
		_battle.skill_failed.emit("【%s】仍在冷却。" % skill_id)
		_battle._push_log(GameData._T("LOG_SKILL_CD") % [skill_id, _battle.skill_cooldowns[cd_key]], "system")
		return
	var actual_mp_cost: int = _battle._current_actor.get_skill_mp_cost(data.mp_cost)
	if _battle._current_actor.current_mp < actual_mp_cost:
		_battle.skill_failed.emit(GameData._T("BATTLE_LOW_MP"))
		_battle._push_log(GameData._T("BATTLE_LOW_MP"), "system")
		return
	if skill_id == "舍生取义" and _battle._current_actor.current_hp <= _battle._current_actor.get_effective_max_hp() * data.sacrifice_hp_pct:
		_battle.skill_failed.emit("【舍生取义】气血不足，无法施放！")
		return
	_battle._last_skill_id = skill_id
	_battle._last_target = target
	_battle._combo_triggered = false
	_battle._change_state(_battle.BattleState.PLAYER_ACTION)

	var waiting: int = _battle._current_actor.skill_wait_remaining(data)
	if waiting > 0:
		var reason := "【%s】还需完成自身行动 %d 次" % [skill_id, waiting]
		_battle.skill_failed.emit(reason)
		_battle._push_log(reason, "system")
		_battle._play_error_sound()
		_battle._change_state(_battle.BattleState.PLAYER_TURN)
		return

	# 预检查：铁甲出击无铁甲时直接失败，不消耗资源
	if skill_id == "铁甲出击":
		var has_mech = false
		for c in _battle.party:
			if not c.is_dead and c.stats.character_class == "铁甲":
				has_mech = true
				break
		if not has_mech:
			_battle.skill_failed.emit(GameData._T("LOG_MECH_NO_LAUNCH"))
			_battle._push_log(GameData._T("LOG_MECH_NO_LAUNCH"), "system")
			_battle._play_error_sound()
			_battle._change_state(_battle.BattleState.PLAYER_TURN)
			return
	
	# 预检查：千变万化不能变成主角
	if skill_id == "千变万化" and target and (target == _battle._current_actor or target.is_dead or CharacterStats.has_role(target.stats.role, CharacterStats.Role.MAIN)):
		_battle.skill_failed.emit(GameData._T("BATTLE_CANT_TRANSFORM"))
		_battle._push_log(GameData._T("BATTLE_CANT_TRANSFORM"), "system")
		_battle._play_error_sound()
		_battle._change_state(_battle.BattleState.PLAYER_TURN)
		return
	
	# 真身只影响当前战斗的外观；重复施放不消耗法力或行动。
	if skill_id == "火域" and preload("res://Script/Battle/FireDomain.gd").active_for(_battle._current_actor):
		var reason := "火域已展开，不能重复施放！"
		_battle.skill_failed.emit(reason)
		_battle._push_log(reason, "system")
		_battle._change_state(_battle.BattleState.PLAYER_TURN)
		return
	if skill_id == "扔色子" and _battle._current_actor.member_id != "banshouren":
		_battle._push_log("只有半兽人可以使用扔色子！", "system")
		_battle._change_state(_battle.BattleState.PLAYER_TURN)
		return
	if skill_id == "扔色子" and _battle._current_actor.dice_has_pending:
		var reason := "必须先命中一次攻击，才能再次扔色子（0伤害也算）！"
		_battle.skill_failed.emit(reason)
		_battle._push_log(reason, "system")
		_battle._play_error_sound()
		_battle._change_state(_battle.BattleState.PLAYER_TURN)
		return
	if skill_id == "真身显现" and (_battle._current_actor.member_id not in ["xiaoer", "banshouren"] or _battle._current_actor.trait_data.get("_xiaoer_true_form", false)):
		var reason: String = "%s已经显露真身！" % _battle._current_actor.stats.get_display_name() if _battle._current_actor.member_id in ["xiaoer", "banshouren"] else "只有小二或半兽人可以显露此真身！"
		_battle.skill_failed.emit(reason)
		_battle._push_log(reason, "system")
		_battle._play_error_sound()
		_battle._change_state(_battle.BattleState.PLAYER_TURN)
		return

	# 所有特殊条件先检查，失败时不提交双动类型、MP或冷却。
	if skill_id == "鬼影护体" and int(_battle._current_actor.trait_data.get("_ghost_count", 0) / maxi(data.ghosts_per_charge, 1)) <= 0:
		_battle.skill_failed.emit("【鬼影护体】鬼魂不足，施放失败！")
		_battle._change_state(_battle.BattleState.PLAYER_TURN)
		return

	# 双动：记录首次行动类型，第二次限制不同类（在所有分支之前检查）
	if _battle._current_actor and _battle._current_actor.trait_data.has("双动"):
		var sk_type = _battle.DoubleActionType.NONE
		match data.skill_type:
			SkillData.SkillType.PHYSICAL, SkillData.SkillType.MAGIC, SkillData.SkillType.MULTI_HIT:
				sk_type = _battle.DoubleActionType.DAMAGE
			SkillData.SkillType.HEAL, SkillData.SkillType.BUFF, SkillData.SkillType.DEBUFF:
				sk_type = _battle.DoubleActionType.SUPPORT
		if sk_type == _battle.DoubleActionType.NONE:
			pass  # 未分类技能（如召唤）不限制
		elif _battle._双动_first_type == _battle.DoubleActionType.NONE:
			_battle._双动_first_type = sk_type
		elif _battle._双动_second_phase and sk_type == _battle._双动_first_type:
			_battle._push_log(GameData._T("LOG_DOUBLE_BLOCKED") % _battle._current_actor.stats.get_display_name(), "system")
			_battle._play_error_sound()
			_battle._change_state(_battle.BattleState.PLAYER_TURN)
			# 触发新回合的 UI 刷新和聚焦
			_battle.actor_turn_started.emit(_battle._current_actor, true)
			return

	var effective_cd := preload("res://Script/Battle/AccessoryEffects.gd").effective_cooldown(_battle._current_actor, data.cooldown_turns)
	if effective_cd > 0 and not no_cd:
		_battle.skill_cooldowns[cd_key] = effective_cd
	if actual_mp_cost > 0: _battle._current_actor.use_mp(actual_mp_cost)
	if not no_cd and effective_cd < data.cooldown_turns:
		preload("res://Script/Battle/AccessoryEffects.gd").notify(_battle._current_actor, "skill_cooldown_reduction", "%s：冷却 %d → %d 回合" % [skill_id, data.cooldown_turns, effective_cd], _battle)

	# 资源和前置条件通过后记录；失败选择、封印、冷却和法力不足不覆盖旧记录。
	preload("res://Script/Battle/MimicRules.gd").record(_battle, _battle._current_actor, skill_id, target)
	if is_mimic:
		_battle._push_log("【千机变】%s 模仿 %s 的【%s】！" % [_battle._current_actor.stats.get_display_name(), mimic_source, skill_id], "player_action")

	if skill_id == "机甲合体":
		preload("res://Script/Battle/MechFusion.gd").enter(_battle, _battle._current_actor)
		await _battle._finish_player_action()
		return
	if skill_id == "解除合体":
		preload("res://Script/Battle/MechFusion.gd").leave(_battle._current_actor)
		_battle._push_log("【解除合体】叮咚离开机甲，恢复原形。", "player_action")
		_battle.party_changed.emit()
		await _battle._finish_player_action()
		return
	if skill_id == "机甲炮击":
		var gunner: BattleCharacter = _battle._current_actor
		gunner.begin_dice_attack()
		preload("res://Script/Battle/FishBond.gd").begin_group(_battle)
		for enemy in _battle.alive_enemies():
			if gunner.is_dead or gunner.mech_fusion.is_empty(): break
			var shot := SkillManager.execute(gunner, enemy, skill_id)
			# 炮击原地施法；伤害已按物理计算，is_magic 仍为 false。
			shot.skill_type = SkillData.SkillType.MAGIC
			_battle._resolve_skill_effects(shot, gunner, enemy)
			await _battle._apply_skill_result(shot, gunner, enemy)
		preload("res://Script/Battle/FishBond.gd").end_group(_battle)
		await _battle._finish_player_action()
		return

	# 摄魂痛击：绑定死亡计数
	if skill_id == "摄魂痛击" and target and not target.is_dead:
		target.died.connect(func():
			_battle._current_actor.trait_data["_soul_strike_kills"] = _battle._current_actor.trait_data.get("_soul_strike_kills", 0) + 1
			_battle._push_log("【摄魂痛击】威力提升！当前 %d 层" % _battle._current_actor.trait_data["_soul_strike_kills"], "system")
		, CONNECT_ONE_SHOT)

	# 愈战愈勇：伤害类技能才叠层（BUFF/HEAL 不算）
	if data.skill_type != SkillData.SkillType.BUFF and data.skill_type != SkillData.SkillType.HEAL:
		_battle._current_actor.apply_stacking_buff()

	# 驭鬼术特性：使用技能时鬼魂 +1（阎王令除外消耗鬼魂，普攻不加）
	if _battle._current_actor.trait_data.has("驭鬼术") and skill_id != "阎王令" and skill_id != "普通攻击":
		# 鬼门大开：技能鬼魂获得 +1（基础 1 层 + 额外 1 层）
		var add = 2 if _battle._current_actor.has_buff("ghost_gate") else 1
		var count = _battle._current_actor.trait_data.get("_ghost_count", 0) + add
		_battle._current_actor.trait_data["_ghost_count"] = count
		# 移动类技能先隐藏鬼魂（回到原点再显示）
		if not _battle._is_movement_skill(skill_id):
			_battle._update_ghost_label()
		else:
			_battle._set_ghost_visible(false)

	# 播放技能音效
	if skill_id == "撒豆成兵":
		var owner: BattleCharacter = _battle._current_actor
		var army = owner.get_meta("bean_army") if owner.has_meta("bean_army") else null
		if not is_instance_valid(army):
			army = preload("res://scenes/Effects/BeanArmy.tscn").instantiate()
			_battle.get_parent().add_child(army)
			army.configure(_battle, owner)
		await army.summon(data)
		await _battle._finish_player_action()
		return
	if skill_id == "三才阵":
		await preload("res://Script/Battle/SancaiFormation.gd").execute(_battle, _battle._current_actor, data)
		await _battle._finish_player_action()
		return
	if skill_id == "火域":
		var actor: BattleCharacter = _battle._current_actor
		var domain = preload("res://scenes/Effects/FireDomain.tscn").instantiate()
		var scene = _battle.get_parent()
		scene.add_child(domain)
		# 与背景同层、排在角色组之前；移动置顶时也不会遮挡角色。
		var enemy_group = scene.get_node_or_null("EnemyGroup")
		if enemy_group: scene.move_child(domain, enemy_group.get_index())
		domain.configure(_battle, actor, data)
		domain.check_contacts()
		_battle._push_log("【火域】%s 展开随身火圈！" % actor.stats.get_display_name(), "player_action")
		actor.show_trait_float("火域")
		await _battle._finish_player_action()
		return

	if data.skill_type in [SkillData.SkillType.PHYSICAL, SkillData.SkillType.MAGIC, SkillData.SkillType.MULTI_HIT, SkillData.SkillType.AOE]:
		_battle._current_actor.begin_dice_attack()

	if skill_id == "扔色子":
		var actor: BattleCharacter = _battle._current_actor
		var rules = preload("res://Script/Battle/OrcDiceRules.gd")
		var face: int = rules.roll(actor.stats.luck + float(actor.equip_special.get("luck", 0)))
		var overlay = preload("res://scenes/UI/BattleDiceRoll.tscn").instantiate()
		_battle.add_child(overlay)
		await overlay.roll(face)
		actor.dice_pending_multiplier = rules.MULTIPLIERS[face - 1]
		actor.dice_has_pending = true
		actor.show_trait_float("骰子 %d 点" % face)
		_battle._push_log("【扔色子】%s 投出 %d 点，%s" % [actor.stats.get_display_name(), face, rules.EFFECTS[face - 1]], "player_action")
		overlay.queue_free()
		await _battle._finish_player_action()
		return

	if not data.sound_path.is_empty() and ResourceLoader.exists(data.sound_path):
		var snd = AudioStreamPlayer.new()
		snd.stream = load(data.sound_path)
		snd.bus = "SFX"
		_battle.add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)

	if skill_id == "金符齐射":
		await preload("res://Script/Battle/GoldenTalismanSkill.gd").execute(_battle, _battle._current_actor, target)
		if is_instance_valid(_battle) and _battle.is_inside_tree(): await _battle._finish_player_action()
		return

	if skill_id == "真身显现":
		var actor: BattleCharacter = _battle._current_actor
		var nd = actor.get_parent()
		var reveal := func():
			actor.stats.was_base_path = "res://WAS/小二真身"
			actor.trait_data["_xiaoer_true_form"] = true
			preload("res://Script/Battle/TrueFormRules.gd").apply(actor)
			if is_instance_valid(nd) and nd.has_method("reload_was"):
				nd.reload_was(actor.stats.was_base_path, false)
		if is_instance_valid(nd):
			var effect = preload("res://scenes/Effects/TrueFormBurst.tscn").instantiate()
			nd.add_child(effect)
			await effect.play(reveal)
		else:
			reveal.call()
		var bonus_pct := int(preload("res://Script/Battle/TrueFormRules.gd").BASE_STAT_BONUS * 100.0)
		var defense_pct := int(preload("res://Script/Battle/TrueFormRules.gd").DEFENSE_BONUS * 100.0)
		actor.show_trait_float("真身显现 · 双防+%d%% · 其余基础属性+%d%%" % [defense_pct, bonus_pct])
		_battle._push_log("【真身显现】%s显露真身，双防提高%d%%，其余基础属性提高%d%%，持续至本场结束！" % [actor.stats.get_display_name(), defense_pct, bonus_pct], "player_action")
		await _battle._finish_player_action()
		return

	# 千变万化：变身成一名队友（外观+技能，保留属性）
	if skill_id == "千变万化":
		# 变外观
		var nd = _battle._current_actor.get_parent()
		if nd and nd.has_method("reload_was"):
			nd.reload_was(target.stats.was_base_path)
		# 变技能（保留千变万化）
		var new_skills = target.stats.skill_ids.duplicate()
		if "千变万化" not in new_skills:
			new_skills.append("千变万化")
		_battle._current_actor.stats.skill_ids = new_skills
		# 变远程/近战属性
		_battle._current_actor.stats.is_ranged = target.stats.is_ranged
		_battle._current_actor.stats.role = target.stats.role
		_battle._current_actor.stats.element = target.stats.element
		_battle._current_actor.trait_data = target.trait_data.duplicate()
		_battle._current_actor._apply_talent_boosts()
		_battle._current_actor.stats.traits = target.stats.traits.duplicate()
		_battle._current_actor.stats.was_base_path = target.stats.was_base_path
		_battle._current_actor.trait_data["_metamorphosis"] = true
		_battle._current_actor.metamorphosis_mod = 0.7
		_battle._update_element_resonance()
		_battle._push_log(GameData._T("LOG_TRANSFORM") % [_battle._current_actor.stats.get_display_name(), target.stats.get_display_name()], "player_action")
		_battle._current_actor.show_trait_float("千变万化")
		await _battle._finish_player_action()
		return

	# 寂静剑法：全屏序列帧动画 + 对所有敌人造成物理伤害
	# 全屏法术：对所有存活敌人生效（寂静剑法等）
	if data and data.fullscreen_anim != "":
		var fs_targets: Array[BattleCharacter] = []
		for e in _battle.enemies:
			if not e.is_dead:
				fs_targets.append(e)
		await FullscreenAnimation.prepare(data.fullscreen_anim)
		var fs_caster = _battle._current_actor.get_parent()
		if fs_caster and fs_caster.has_method("play_cast_sequence"):
			await fs_caster.play_cast_sequence(skill_id)
		# 先让所有目标播放受击动画（法术动画期间保持受击姿态），伤害延后结算
		var pending_fs_dmg: Array = []
		for t in fs_targets:
			var tn = t.get_parent() as Node2D
			# 落空判定（龙卷雨击等，受运气影响）：落空则跳过受击动画，只飘"闪避"字
			var miss_rate = _battle._calc_miss_chance(_battle._current_actor, t, data.miss_chance)
			if miss_rate > 0.0 and randf() < miss_rate:
				if t.has_method("show_trait_float"):
					t.show_trait_float("闪避")
				_battle._push_log("【%s】%s 闪避了攻击！" % [skill_id, t.stats.get_display_name()], "system")
				continue
			if tn:
				if tn.has_method("play_hit_reaction"):
					tn.play_hit_reaction(true)
					if not _battle._hit_stay_nodes.has(tn):
						_battle._hit_stay_nodes.append(tn)
				if tn.has_method("play_hit_flash"): tn.play_hit_flash()
			var dmg = maxi(1, int((_battle._current_actor.get_effective_magic_attack() if data.is_magic_damage else _battle._current_actor.get_effective_attack()) * data.damage_multiplier) - int(t.get_effective_defense()))
			dmg = int(dmg * randf_range(0.95, 1.05) * _battle._current_actor.metamorphosis_mod)
			pending_fs_dmg.append({"target": t, "dmg": dmg})
		# 播放全屏法术动画（怪物保持受击姿态）；动画开始 3 秒后屏幕抖动
		if FullscreenAnimation.has_animation(data.fullscreen_anim):
			var fs_anim = FullscreenAnimation.play(data.fullscreen_anim)
			# 寂静剑法动画较长：3.5 秒后抖；其他全屏技能 0.5 秒后抖
			var shake_delay = 4 if skill_id == "寂静剑法" else 0.5
			await _battle.get_tree().create_timer(shake_delay).timeout
			GameData.hit_stop(0.55, 0.06, 15.0, 0.5)
			# 动画若还在播放则等它播完；若已在延迟期间播完（finished 已发出）直接继续，
			# 避免 await 已发出的信号导致战斗卡死
			if is_instance_valid(fs_anim) and fs_anim.is_playing():
				await fs_anim.finished
		# 法术播放完后：统一结算伤害（死亡 + 屏幕震动发生在这里）
		preload("res://Script/Battle/FishBond.gd").begin_group(_battle)
		for entry in pending_fs_dmg:
			var t: BattleCharacter = entry["target"]
			var dmg: int = entry["dmg"]
			dmg = SkillManager.apply_marked_bonus(_battle._current_actor, t, dmg)
			var actual = _battle.apply_damage(_battle._current_actor, t, dmg, {"is_magic": data.is_magic_damage, "is_aoe": true})
			t.sync_visual()
			_battle.damage_floated.emit(t, actual, "magic" if data.is_magic_damage else "normal")
		preload("res://Script/Battle/FishBond.gd").end_group(_battle)
		# 法术播完：没死的怪物恢复待机（受击姿态结束）
		for t in fs_targets:
			if not t.is_dead:
				var tn2 = t.get_parent()
				if tn2 and tn2.has_method("play_idle"):
					tn2.play_idle()
		# 仅寂静剑法：把死亡的怪物吹走
		if skill_id == "寂静剑法":
			for e in _battle.enemies:
				if e.is_dead and e.stats.rank != "boss":
					var nd = e.get_parent()
					if nd and is_instance_valid(nd):
						var tw = nd.create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
						tw.tween_property(nd, "position", nd.position + Vector2(-600, -400), 0.8)
						tw.parallel().tween_property(nd, "modulate:a", 0.0, 0.8)
						tw.tween_callback(func(): nd.visible = false)
		# 全屏法术附带 debuff（灼烧等，只对未死且非 boss 的目标）
		if data.apply_buff_id != "":
			for t in fs_targets:
				if not t.is_dead and t.stats.rank != "boss":
					_battle.apply_buff(_battle._current_actor, t, data.apply_buff_id, data.apply_buff_turns, data.apply_buff_value, data.skill_id)
		_battle._push_log("%s 施展【%s】，全场震撼！" % [_battle._current_actor.stats.get_display_name(), data.skill_name], "player_action")
		await _battle._finish_player_action()
		return

	# 铁甲出击：所有存活的铁甲兽依次攻击目标
	if skill_id == "铁甲出击":
		var mechs: Array[BattleCharacter] = []
		for c in _battle.party:
			if not c.is_dead and c.stats.character_class == "铁甲":
				mechs.append(c)
		# 施法者播放施法动画
		var caster_node = _battle._current_actor.get_parent()
		if caster_node and caster_node.has_method("play_cast_sequence"):
			caster_node.play_cast_sequence(skill_id)
		_battle._push_log(GameData._T("LOG_MECH_LAUNCH") % _battle._current_actor.stats.get_display_name(), "player_action")
		for mech in mechs:
			var target_pos = target.get_parent().global_position
			var nd = mech.get_parent() as Node2D
			var on_hit = func():
				var dmg = maxi(1, mech.stats.attack - int(target.get_effective_defense()))
				dmg = int(dmg * randf_range(0.95, 1.05) * _battle._current_actor.metamorphosis_mod)
				var actual = _battle.apply_damage(mech, target, dmg)
				target.sync_visual()
				_battle.damage_floated.emit(target, actual, "normal")
				_battle._push_log(GameData._T("LOG_MECH_ATK") % [mech.stats.get_display_name(), target.stats.get_display_name(), dmg], "player_action")
			if nd and nd.has_method("play_attack_sequence"):
				await nd.play_attack_sequence(target_pos, target.get_parent() as EnemyNode, on_hit)
			else:
				on_hit.call()
			await _battle.get_tree().create_timer(0.5).timeout
		await _battle._finish_player_action()
		return

	# 横扫千军：多段攻击动画（走到→连续3刀→回来），每刀结算一次伤害
	# 多段攻击：连续攻击多次（横扫千军、破釜沉舟等）
	if data and data.skill_type == SkillData.SkillType.MULTI_HIT:
		_battle._set_ghost_visible(false)
		# 横扫千军：检查血量条件（HP > 50% 才可用）
		if skill_id == "横扫千军" and _battle._current_actor.current_hp <= _battle._current_actor.get_effective_max_hp() * 0.5:
			_battle._push_log("【横扫千军】气血不足 50%，无法使用！", "system")
			_battle._play_error_sound()
			await _battle._finish_player_action()
			return
		var result = SkillManager.execute(_battle._current_actor, target, skill_id)
		_battle._resolve_skill_effects(result, _battle._current_actor, target)
		if not result.success:
			_battle._push_log(result.log_text, "system")
			await _battle._finish_player_action()
			return
		# 保护拦截
		var actual_target = target
		if not _battle._current_actor.is_player:
			var g = _battle.guard_relations.get(target)
			if g and not g.is_dead:
				actual_target = g
		# 播放多段攻击动画
		var nd = _battle._current_actor.get_parent() as Node2D
		var hits = result.damage_list.size()
		var meta_mul = _battle._current_actor.metamorphosis_mod
		var blitz_total_dmg = 0
		
		# on_hit：命中后立刻结算伤害
		var on_hit = func():
			blitz_total_dmg = 0
			var dmg_list = result.damage_list.duplicate()
			for i in range(dmg_list.size()):
				dmg_list[i] = int(dmg_list[i] * meta_mul)
				blitz_total_dmg += dmg_list[i]
			var actual_total = 0
			for dmg in dmg_list:
				var actual = _battle.apply_damage(_battle._current_actor, actual_target, dmg)
				actual_total += actual
				if actual_target.is_dead:
					break
			actual_target.sync_visual()
			_battle.damage_floated.emit(actual_target, actual_total, "crit" if result.is_crit else "normal")
			_battle._push_log(result.log_text, "player_action")
		
		if nd and nd.has_method("play_blitz_sequence") and skill_id == "暗影突袭":
			var sk_sound = data.sound_path if data else ""
			await nd.play_blitz_sequence(target.get_parent().global_position, actual_target.get_parent() as Node2D, hits, on_hit, sk_sound)
		elif nd and nd.has_method("play_multihit_sequence"):
			await nd.play_multihit_sequence(target.get_parent().global_position, actual_target.get_parent() as Node2D, hits, on_hit)
		else:
			await on_hit.call()
			await _battle.get_tree().create_timer(0.3).timeout
		# 回原位后回血

		_battle._set_ghost_visible(true)
		# 横扫千军专属：降低双抗 30% 持续 3 回合
		if skill_id == "横扫千军":
			_battle.apply_buff(_battle._current_actor, _battle._current_actor, "def_broken", 3, 0.3, skill_id)
			_battle.apply_buff(_battle._current_actor, _battle._current_actor, "mdef_broken", 3, 0.3, skill_id)
			_battle._push_log("【横扫千军】%s 双抗降低 30%" % _battle._current_actor.stats.get_display_name(), "system")
		await _battle._finish_player_action()
		return

	# 一苇渡江：目标必加速 + 随机3个未加速队友加速
	# 群体治疗（如沐春风等）：extra>0 的 HEAL 技能
	if data and data.skill_type == SkillData.SkillType.HEAL and data.extra_targets > 0:
		var heal_targets: Array[BattleCharacter] = [target]
		var base_extra = data.extra_targets
		var max_targets = base_extra + _battle._get_extra_heal_target_count(_battle._current_actor)
		var candidates: Array[BattleCharacter] = []
		for c in _battle.party:
			if c != target and not c.is_dead:
				candidates.append(c)
		candidates.shuffle()
		for j in mini(max_targets - 1, candidates.size()):
			heal_targets.append(candidates[j])

		for h in heal_targets:
			h.play_spell_effect(skill_id)

		var caster_node2 = _battle._current_actor.get_parent()
		if caster_node2 and caster_node2.has_method("play_cast_sequence"):
			await caster_node2.play_cast_sequence(skill_id)

		for h in heal_targets:
			var amt = int(h.stats.max_hp * data.heal_multiplier) + data.flat_heal
			amt = int(amt * _battle._current_actor.metamorphosis_mod)
			# 点天灯：灯累计3个时触发回血，加到本次治疗量里
			if _battle._current_actor and _battle._current_actor.trait_data.has("点天灯"):
				var lantern_heal = _battle._try_add_lantern_to(h)
				if lantern_heal > 0:
					amt += lantern_heal
			var actual = _battle.apply_heal(_battle._current_actor, h, amt, h.is_dead)
			h.sync_visual()
			_battle.damage_floated.emit(h, amt, "heal")
			_battle._push_log(GameData._T("LOG_ITEM_HEAL") % [h.stats.get_display_name(), amt], "system")
			# 群体治疗附带 buff（五气朝元的持续回血等）
			if data.apply_buff_id != "":
				_battle.apply_buff(_battle._current_actor, h, data.apply_buff_id, data.apply_buff_turns, data.apply_buff_value, data.skill_id)
		await _battle.get_tree().create_timer(_battle.action_delay).timeout
		await _battle._finish_player_action()
		return

	# 群体增益：选中目标 + 随机 extra 个队友
	if data and data.skill_type == SkillData.SkillType.BUFF and data.extra_targets > 0:
		var buff_targets: Array[BattleCharacter] = [target]
		var other_allies: Array[BattleCharacter] = []
		for c in _battle.party:
			if c != target and not c.is_dead:
				other_allies.append(c)
		other_allies.shuffle()
		for j in mini(data.extra_targets, other_allies.size()):
			buff_targets.append(other_allies[j])

		for bt in buff_targets:
			bt.play_spell_effect(skill_id)
			# 按 buff 类型播放特效（同原 _apply_aoe_buff）
			var bv = bt.get_parent()
			if data.apply_buff_id == "haste" and bv and bv.has_method("shake"):
				bv.shake()
			elif data.apply_buff_id == "atk_up" and bv and bv.has_method("play_power_up_scale"):
				bv.play_power_up_scale()
			elif (data.apply_buff_id == "def_up" or data.apply_buff_id == "mdef_up") and bv and bv.has_method("flash_gold"):
				bv.flash_gold()

		var caster_node2 = _battle._current_actor.get_parent()
		if caster_node2 and caster_node2.has_method("play_cast_sequence"):
			await caster_node2.play_cast_sequence(skill_id)

		for bt in buff_targets:
			_battle.apply_buff(_battle._current_actor, bt, data.apply_buff_id, data.apply_buff_turns, data.apply_buff_value, data.skill_id)
			# 第二个 buff（双抗/双攻：金刚护体 mdef_up、金刚护法 matk_up 等）
			if data.apply_buff2_id != "":
				_battle.apply_buff(_battle._current_actor, bt, data.apply_buff2_id, data.apply_buff_turns, data.apply_buff_value, data.skill_id)
			# 加气血上限：血条 tween 效果（同达摩护体）
			var bv2 = bt.get_parent()
			if bv2 and bv2.has_method("stop_shake"):
				bv2.stop_shake()
			if data.apply_buff_id == "hp_up":
				await bt.play_hp_up_effect()
			else:
				bt.sync_visual()
		# 点天灯特性联动
		_battle._try_add_lantern_to_targets(target)
		# 自身附加 buff（不灭金身的无敌等）
		if data.self_buff_id != "":
			_battle.apply_buff(_battle._current_actor, _battle._current_actor, data.self_buff_id, data.self_buff_turns, null, data.skill_id)
		await _battle._finish_player_action()
		return

	# 群体减益（刀解其足等）：选中目标 + 随机 extra 个其他敌人，施加 debuff
	if data and data.extra_targets > 0 and data.skill_type == SkillData.SkillType.DEBUFF:
		var debuff_targets: Array[BattleCharacter] = [target]
		var other_enemies2: Array[BattleCharacter] = []
		for e in _battle.enemies:
			if e != target and not e.is_dead:
				other_enemies2.append(e)
		other_enemies2.shuffle()
		for j in mini(data.extra_targets, other_enemies2.size()):
			debuff_targets.append(other_enemies2[j])

		for t in debuff_targets:
			t.play_spell_effect(skill_id)

		var caster_node3 = _battle._current_actor.get_parent()
		if caster_node3 and caster_node3.has_method("play_cast_sequence"):
			await caster_node3.play_cast_sequence(skill_id)

		for t in debuff_targets:
			var chance = SkillManager.calc_debuff_chance(_battle._current_actor, t, data.apply_buff_chance)
			if randf() <= chance:
				_battle.apply_buff(_battle._current_actor, t, data.apply_buff_id, data.apply_buff_turns, data.apply_buff_value, data.skill_id)
				_battle._push_log("【%s】%s 被刀气缠足，速度降低！" % [skill_id, t.stats.get_display_name()], "player_action")
			else:
				_battle._push_log("【%s】%s 抵抗了减速效果！" % [skill_id, t.stats.get_display_name()], "system")
		await _battle._finish_player_action()
		return

	# 群体物理/法术：选中目标 + 随机 extra 个其他敌人
	if data and data.extra_targets > 0 and (data.skill_type == SkillData.SkillType.MAGIC or data.skill_type == SkillData.SkillType.PHYSICAL):
		var targets: Array[BattleCharacter] = [target]
		var other_enemies: Array[BattleCharacter] = []
		for e in _battle.enemies:
			if e != target and not e.is_dead:
				other_enemies.append(e)
		other_enemies.shuffle()
		for j in mini(data.extra_targets, other_enemies.size()):
			targets.append(other_enemies[j])

		for t in targets:
			var tn = t.get_parent() as Node2D
			if tn:
				if tn.has_method("play_hit_once"):
					tn.play_hit_once()
				if tn.has_method("play_hit_flash"):
					tn.play_hit_flash()
			t.play_spell_effect(skill_id)

		var caster_node = _battle._current_actor.get_parent()
		if caster_node and caster_node.has_method("play_cast_sequence"):
			await caster_node.play_cast_sequence(skill_id)

		var is_magic = data.is_magic_damage
		var eff_atk = _battle._current_actor.get_effective_magic_attack() if is_magic else _battle._current_actor.get_effective_attack()
		var night_mul = _battle._current_actor.get_night_dmg_mul()
		for t in targets:
			# 技能落空（如龙卷雨击，受运气影响）：只飘"闪避"字
			var miss_rate = _battle._calc_miss_chance(_battle._current_actor, t, data.miss_chance)
			if miss_rate > 0.0 and randf() < miss_rate:
				if t.has_method("show_trait_float"):
					t.show_trait_float("闪避")
				_battle._push_log("【%s】%s 闪避了攻击！" % [skill_id, t.stats.get_display_name()], "system")
				continue
			var def_val = t.get_effective_magic_defense() if is_magic else t.get_effective_defense()
			var dmg = maxi(1, int(eff_atk * data.damage_multiplier * night_mul) - int(def_val * 0.6) + data.flat_damage)
			dmg = int(dmg * randf_range(0.95, 1.05))
			dmg = SkillManager.apply_marked_bonus(_battle._current_actor, t, dmg)
			var actual = _battle.apply_damage(_battle._current_actor, t, dmg)
			t.sync_visual()
			_battle.damage_floated.emit(t, actual, "magic" if is_magic else "normal")
			_battle._push_log("[群体] %s 受到 %d 点伤害" % [t.stats.get_display_name(), actual], "enemy_action")
			var tn = t.get_parent() as Node2D
			if tn and tn.has_method("play_idle") and not t.is_dead:
				tn.play_idle()
			await _battle.get_tree().create_timer(0.3).timeout

		await _battle._finish_player_action()
		return

	# 割喉之战：瞬移到敌人背后背刺
	if skill_id == "割喉之战":
		var nd = _battle._current_actor.get_parent() as Node2D
		if nd:
			var orig_pos = nd.position
			var orig_z = nd.z_index
			var orig_dir = nd.get_node("WASAnimationPlayer").direction if nd.has_node("WASAnimationPlayer") else 0
			_battle._set_ghost_visible(false)
			nd.z_index = 1
			var enemy_nd = target.get_parent() as Node2D
			var local_target = nd.get_parent().to_local(enemy_nd.global_position) if enemy_nd else target.get_parent().position
			# 瞬移到敌人背后（左边）
			nd.position = local_target + Vector2(-60, -30)
			# 朝左（方向1）
			if nd.has_node("WASAnimationPlayer"):
				var was = nd.get_node("WASAnimationPlayer")
				was.direction = 0
				was.play("attack", false)
			elif nd.has_method("play"):
				nd.play("attack", false)
			# 武器方向同步
			var weapon_was = nd.get_node_or_null("WeaponWAS")
			if weapon_was:
				weapon_was.direction = 2
			# 目标受击 + 武器特效
			if enemy_nd and enemy_nd.has_method("play_hit_reaction"):
				enemy_nd.play_hit_reaction(true)
				if not _battle._hit_stay_nodes.has(enemy_nd):
					_battle._hit_stay_nodes.append(enemy_nd)
			if nd.has_method("_spawn_hit_effect"):
				nd._spawn_hit_effect(enemy_nd)
			# 执行技能（伤害计算）
			var result = SkillManager.execute(_battle._current_actor, target, skill_id)
			_battle._resolve_skill_effects(result, _battle._current_actor, target)
			if result.success:
				var sum_actual = 0
				for dmg in result.damage_list:
					sum_actual += _battle.apply_damage(_battle._current_actor, target, dmg)
				target.sync_visual()
				_battle.damage_floated.emit(target, sum_actual, "crit" if result.is_crit else "normal")
				_battle._push_log(result.log_text, "player_action")
			# 走回来
			await _battle.get_tree().create_timer(1).timeout
			nd.position = orig_pos
			nd.z_index = orig_z
			_battle._set_ghost_visible(true)
			if nd.has_node("WASAnimationPlayer"):
				var was = nd.get_node("WASAnimationPlayer")
				was.direction = orig_dir
				was.play("idle", false)

		await _battle._finish_player_action()
		return

	# 双生：姐妹协同攻击
	if skill_id == "双生":
		# 骨精灵离开原点时隐藏鬼魂
		_battle._set_ghost_visible(false)
		var partner_id = "yingjingling" if _battle._current_actor.member_id == "gujingling" else "gujingling"
		var partner: BattleCharacter = null
		for c in _battle.party:
			if c.member_id == partner_id and not c.is_dead:
				partner = c
				break
		if partner == null:
			_battle._push_log("【双生】姐妹不在场，无法使用！", "system")
			_battle._play_error_sound()
			await _battle._finish_player_action()
			return
		# 执行技能计算伤害
		var result = SkillManager.execute(_battle._current_actor, target, skill_id)
		_battle._resolve_skill_effects(result, _battle._current_actor, target)
		if not result.success:
			_battle._push_log(result.log_text, "system")
			await _battle._finish_player_action()
			return
		# 获取两姐妹的视觉节点
		var nd1 = _battle._current_actor.get_parent() as Node2D
		var nd2 = partner.get_parent() as Node2D
		var enemy_nd = target.get_parent() as Node2D
		if nd1 and nd2 and enemy_nd:
			# 双生冲刺期间隐藏骨精灵鬼魂，回到原点后再显示
			_battle._set_ghost_visible(false)
			var orig1 = nd1.position; var z1 = nd1.z_index
			var orig2 = nd2.position; var z2 = nd2.z_index
			# 保存原始朝向
			var dir1 = nd1.get_node("WASAnimationPlayer").direction if nd1.has_node("WASAnimationPlayer") else 0
			var dir2 = nd2.get_node("WASAnimationPlayer").direction if nd2.has_node("WASAnimationPlayer") else 0
			nd1.z_index = 999; nd2.z_index = 998
			var local_target = nd1.get_parent().to_local(enemy_nd.global_position)
			# 两姐妹瞬移到敌人面前
			nd1.position = local_target + Vector2(-40, -20)
			nd2.position = local_target + Vector2(-40, 20)
			# 设置方向朝右（攻击方向）
			for nd_obj in [nd1, nd2]:
				if nd_obj.has_node("WASAnimationPlayer"):
					var w = nd_obj.get_node("WASAnimationPlayer")
					w.direction = 3
					w.play("attack", false)
			# 先后播放音效（间隔0.1s听出两个人）
			for nd_obj in [nd1, nd2]:
				var atk_snd = nd_obj.get_node_or_null("Audio_Attack") as AudioStreamPlayer
				if atk_snd:
					atk_snd.play()
					await _battle.get_tree().create_timer(0.1).timeout
			await _battle.get_tree().create_timer(0.15).timeout
			# 交叉飞过敌人：一个左上，一个右上 + 画面一闪 + 关灯
			var dlights = []
			if _battle.get_tree():
				dlights = _battle.get_tree().root.find_children("", "PointLight2D", true, false)
				dlights += _battle.get_tree().root.find_children("", "DirectionalLight2D", true, false)
				dlights += _battle.get_tree().root.find_children("", "CanvasModulate", true, false)
			for l in dlights: l.visible = false
			# 全屏闪黑（CanvasLayer 确保盖在灯光之上）
			var flash_cl = CanvasLayer.new()
			flash_cl.layer = 9999
			_battle.get_tree().root.add_child(flash_cl)
			var flash = ColorRect.new()
			flash.color = Color(0, 0, 0, 0)
			flash.set_anchors_preset(Control.PRESET_FULL_RECT)
			flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
			flash_cl.add_child(flash)
			var ft = _battle.create_tween()
			ft.tween_property(flash, "color:a", 0.8, 0.05)
			ft.tween_property(flash, "color:a", 0.0, 0.15).set_delay(0.1)
			ft.finished.connect(func(): flash.queue_free(); flash_cl.queue_free(); for l in dlights: l.visible = true)
			var tw1 = _battle.create_tween()
			tw1.tween_property(nd1, "position", local_target + Vector2(-80, -100), 0.2)
			var tw2 = _battle.create_tween()
			tw2.tween_property(nd2, "position", local_target + Vector2(-80, 100), 0.2)
			if enemy_nd and enemy_nd.has_method("play_hit_reaction"):
				enemy_nd.play_hit_reaction(true)
				if not _battle._hit_stay_nodes.has(enemy_nd):
					_battle._hit_stay_nodes.append(enemy_nd)
			# 扣血
			var sum_actual = 0
			for dmg in result.damage_list:
				sum_actual += _battle.apply_damage(_battle._current_actor, target, dmg)
			target.sync_visual()
			_battle.damage_floated.emit(target, sum_actual, "crit" if result.is_crit else "normal")
			_battle._push_log(result.log_text, "player_action")
			await _battle.get_tree().create_timer(1).timeout
			# 归位（恢复位置/朝向/z）
			nd1.position = orig1; nd1.z_index = z1
			nd2.position = orig2; nd2.z_index = z2
			_battle._set_ghost_visible(true)
			for i in range(2):
				var nd_obj = nd1 if i == 0 else nd2
				var orig_dir = dir1 if i == 0 else dir2
				if nd_obj.has_node("WASAnimationPlayer"):
					var w = nd_obj.get_node("WASAnimationPlayer")
					w.direction = orig_dir
					w.play("idle")
				# 武器恢复 idle
				var weapon_was = nd_obj.get_node_or_null("WeaponWAS")
				if weapon_was:
					weapon_was.direction = orig_dir
					weapon_was.play("idle")
			# 归位后才回血
			var total_d = result.damage_list[0] if result.damage_list.size() > 0 else 0

		await _battle._finish_player_action()
		return

	# 瞬狱影杀阵：全屏黑暗+隐匿+处决
	if skill_id == "瞬狱影杀阵":
		var nd = _battle._current_actor.get_parent()
		if nd:
			var orig_pos = nd.position; var orig_z = nd.z_index
			var orig_dir = nd.get_node("WASAnimationPlayer").direction if nd.has_node("WASAnimationPlayer") else 0
			nd.z_index = 9999
			# 隐藏鬼魂
			_battle._set_ghost_visible(false)
			# 关闭灯光
			var lights = []
			if _battle.get_tree():
				lights = _battle.get_tree().root.find_children("", "PointLight2D", true, false)
				lights += _battle.get_tree().root.find_children("", "DirectionalLight2D", true, false)
				lights += _battle.get_tree().root.find_children("", "CanvasModulate", true, false)
			for l in lights:
				l.visible = false
			# 隐藏队友和其他敌人
			var hidden = []
			for c in _battle.party + _battle.enemies:
				if c == _battle._current_actor or c == target: continue
				var vn = c.get_parent()
				if vn: vn.visible = false; hidden.append(vn)
			# 施法者防御 + 影分身袭击
			var enemy_nd = target.get_parent()
			if nd.has_method("play_guard_cast"):
				nd.play_guard_cast()
			var clone_dirs = [Vector2(100,0), Vector2(-70,70), Vector2(0,100), Vector2(-70,-70), Vector2(70,-70)]
			var clone_exits = [Vector2(-100,0), Vector2(70,-70), Vector2(0,-100), Vector2(70,70), Vector2(-70,70)]
			if enemy_nd:
				# 预载音效
				var se_stream = load("res://Audio/SE/兵器-入肉.ogg")
				# 复制角色精灵用于影分身
				var char_sprite = nd.get_node_or_null("Sprite2D") as Sprite2D
				for ci in range(clone_dirs.size()):
					var clone_spr: Sprite2D
					if char_sprite:
						clone_spr = char_sprite.duplicate() as Sprite2D
						clone_spr.modulate = Color.BLACK
					else:
						clone_spr = Sprite2D.new()
						var img = Image.create(24, 32, false, Image.FORMAT_RGBA8)
						img.fill(Color(0.2, 0.2, 0.2, 0.8))
						clone_spr.texture = ImageTexture.create_from_image(img)
					clone_spr.centered = true
					clone_spr.z_index = 9999
					clone_spr.position = clone_dirs[ci]
					var dv = clone_exits[ci] - clone_dirs[ci]
					clone_spr.rotation = atan2(dv.y, dv.x)
					enemy_nd.add_child(clone_spr)
					if enemy_nd.has_method("play_hit_flash"):
						enemy_nd.play_hit_flash()
					# 兵器音效
					var se = AudioStreamPlayer.new()
					se.stream = se_stream
					se.bus = "SFX"
					_battle.get_parent().add_child(se)
					se.play()
					se.finished.connect(se.queue_free)
					# 飞出淡出
					var ct = _battle.create_tween().set_parallel()
					ct.tween_property(clone_spr, "position", clone_exits[ci], 0.15)
					ct.tween_property(clone_spr, "modulate:a", 0.0, 0.15)
					ct.finished.connect(clone_spr.queue_free)
					await _battle.get_tree().create_timer(0.18).timeout
			# 全屏黑（CanvasLayer 确保全覆盖）
			var flash_cl = CanvasLayer.new()
			flash_cl.layer = 9999
			_battle.get_tree().root.add_child(flash_cl)
			var flash = ColorRect.new()
			flash.color = Color(0, 0, 0, 0)
			flash.set_anchors_preset(Control.PRESET_FULL_RECT)
			flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
			flash_cl.add_child(flash)
			var ft = _battle.create_tween()
			ft.tween_property(flash, "color:a", 1.0, 0.2)
			await ft.finished
			# 瞬移到敌人面前穿刺 + 屏幕剧烈震动
			var local_t = nd.get_parent().to_local(enemy_nd.global_position) if enemy_nd else Vector2.ZERO
			nd.position = local_t + Vector2(40, 0)
			GameData.hit_stop(0.05, 0.05, 20.0, 0.5)
			if nd.has_node("WASAnimationPlayer"):
				var w = nd.get_node("WASAnimationPlayer")
				w.direction = 1
				w.play("attack", false)
			# 兵器音效
			var se = AudioStreamPlayer.new()
			se.stream = load("res://Audio/SE/兵器-入肉.ogg")
			se.bus = "SFX"
			_battle.get_parent().add_child(se)
			se.play()
			se.finished.connect(se.queue_free)
			if enemy_nd and enemy_nd.has_method("play_hit_reaction"):
				enemy_nd.play_hit_reaction(true)
				if not _battle._hit_stay_nodes.has(enemy_nd):
					_battle._hit_stay_nodes.append(enemy_nd)
			if nd.has_method("_spawn_hit_effect"):
				nd._spawn_hit_effect(enemy_nd)
			# 扣血
			var result = SkillManager.execute(_battle._current_actor, target, skill_id)
			_battle._resolve_skill_effects(result, _battle._current_actor, target)
			if result.success:
				var sum_actual = 0
				for dmg in result.damage_list:
					sum_actual += _battle.apply_damage(_battle._current_actor, target, dmg)
				target.sync_visual()
				_battle.damage_floated.emit(target, sum_actual, "crit" if result.is_crit else "normal")
				_battle._push_log(result.log_text, "player_action")
			# 处决：低于5%血量的敌人直接死亡
			for e in _battle.enemies:
				if not e.is_dead and e.hp_percent() < 0.05:
					_battle.Resolution.retire(_battle, _battle._current_actor, e)
					_battle._push_log("【瞬狱影杀阵】%s 被处决！" % e.stats.get_display_name(), "system")
			# 恢复
			await _battle.get_tree().create_timer(0.5).timeout
			# 恢复可视
			ft = _battle.create_tween()
			ft.tween_property(flash, "color:a", 0.0, 0.3)
			await ft.finished
			flash.queue_free()
			flash_cl.queue_free()
			for l in lights:
				l.visible = true
			for vn in hidden:
				vn.visible = true
			nd.position = orig_pos; nd.z_index = orig_z
			_battle._set_ghost_visible(true)
			if nd.has_method("play_idle"):
				nd.play_idle()
			else:
				if nd.has_node("WASAnimationPlayer"):
					var w = nd.get_node("WASAnimationPlayer")
					w.direction = orig_dir
					w.play("idle")
				var weapon_was = nd.get_node_or_null("WeaponWAS")
				if weapon_was:
					weapon_was.direction = orig_dir
					weapon_was.play("idle")
		await _battle._finish_player_action()
		return

	# 阎王令：鬼魂飞击 + 本体攻击
	if skill_id == "阎王令":
		var nd = _battle._current_actor.get_parent()
		var enemy_nd = target.get_parent() as Node2D
		var ghost_count = _battle._current_actor.trait_data.get("_ghost_count", 0)
		# 隐藏鬼魂
		var ghost_node = nd.get_node_or_null("Ghost") if nd else null
		var ghost_tex = null
		if ghost_node:
			var anim_name = ghost_node.animation if ghost_node.animation != "" else "default"
			ghost_tex = ghost_node.sprite_frames.get_frame_texture(anim_name, 0) if ghost_node.sprite_frames and ghost_node.sprite_frames.has_animation(anim_name) else null
			ghost_node.visible = false
		if nd and enemy_nd:
			var orig_pos = nd.position; var orig_z = nd.z_index
			var orig_dir = nd.get_node("WASAnimationPlayer").direction if nd.has_node("WASAnimationPlayer") else 0
			nd.z_index = 9999
			# 远程施法：完整施法动作（配音+特效+动画）
			if nd.has_method("play_cast_sequence"):
				await nd.play_cast_sequence(skill_id)
			elif nd.has_node("WASAnimationPlayer"):
				var w = nd.get_node("WASAnimationPlayer")
				w.direction = 3
				w.play("cast", false)
			# 鬼魂飞向敌人（CanvasLayer 可靠方案）
			var gcl = CanvasLayer.new()
			gcl.layer = 100
			_battle.get_tree().root.add_child(gcl)
			var start_g = nd.global_position
			var end_g = enemy_nd.global_position
			for i in range(ghost_count):
				var g = Sprite2D.new()
				if ghost_tex:
					g.texture = ghost_tex
					g.modulate = Color(1, 1, 1, 0.7)
				else:
					var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
					img.fill(Color(0.7, 0.8, 1.0, 0.7))
					g.texture = ImageTexture.create_from_image(img)
				g.centered = true
				gcl.add_child(g)
				g.position = start_g + Vector2(randf_range(-30, 30), randf_range(-10, 40))
				var gt = _battle.create_tween().set_parallel()
				gt.tween_property(g, "position", end_g + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.4)
				gt.tween_property(g, "modulate:a", 0.0, 0.4)
				gt.finished.connect(g.queue_free)
			# 鬼魂命中
			await _battle.get_tree().create_timer(0.4).timeout
			gcl.queue_free()
			GameData.hit_stop(0.05, 0.05, 15.0, 0.3)
			# 播放阎王令技能特效
			if target and target.has_method("play_spell_effect"):
				target.play_spell_effect(skill_id)
			if enemy_nd and enemy_nd.has_method("play_hit_reaction"):
				enemy_nd.play_hit_reaction(true)
				if not _battle._hit_stay_nodes.has(enemy_nd):
					_battle._hit_stay_nodes.append(enemy_nd)
			var se = AudioStreamPlayer.new()
			se.stream = load("res://Audio/SE/兵器-入肉.ogg")
			se.bus = "SFX"
			_battle.get_parent().add_child(se)
			se.play()
			se.finished.connect(se.queue_free)
			# 扣血
			var result = SkillManager.execute(_battle._current_actor, target, skill_id)
			_battle._resolve_skill_effects(result, _battle._current_actor, target)
			if result.success:
				var sum_actual = 0
				for dmg in result.damage_list:
					sum_actual += _battle.apply_damage(_battle._current_actor, target, dmg)
				target.sync_visual()
				_battle.damage_floated.emit(target, sum_actual, "crit" if result.is_crit else "normal")
				_battle._push_log(result.log_text, "player_action")
			# 收招
			await _battle.get_tree().create_timer(0.3).timeout
			nd.position = orig_pos; nd.z_index = orig_z
			if nd.has_node("WASAnimationPlayer"):
				var w = nd.get_node("WASAnimationPlayer")
				w.direction = orig_dir
				w.play("idle")
			# 恢复鬼魂显示（归零后保持隐藏）
			if ghost_node:
				ghost_node.visible = _battle._current_actor.trait_data.get("_ghost_count", 0) > 0
		await _battle._finish_player_action()
		return

	var result = SkillManager.execute(_battle._current_actor, target, skill_id)
	_battle._resolve_skill_effects(result, _battle._current_actor, target)
	await _battle._apply_skill_result(result, _battle._current_actor, target)
	# 中毒视觉：等攻击/施法动画播完后显示（毒刺、蛊毒咒等）
	if result and result.applied_buff == "poison" and target and not target.is_dead and target.has_buff("poison") and target.has_method("show_debuff"):
		target.show_debuff("中毒", true)
	# 其他 debuff（刀解其足/识破弱点等）：动画播完后统一显示同名持续动画
	if result and result.applied_buff != "" and target and target.has_method("_refresh_buff_icon"):
		target._refresh_buff_icon()
	# 自身附加 buff（不灭金身的无敌等，通用路径）
	if data and data.self_buff_id != "":
		_battle.apply_buff(_battle._current_actor, _battle._current_actor, data.self_buff_id, data.self_buff_turns, null, data.skill_id)
	# 鬼门大开：一大群鬼魂飞向敌人后消失
	if skill_id == "鬼门大开" and target:
		var gnd = _battle._current_actor.get_parent()
		var genemy = target.get_parent() as Node2D
		if gnd and genemy:
			# 取鬼魂精灵纹理
			var ghost_node = gnd.get_node_or_null("Ghost")
			var gtex = null
			if ghost_node and ghost_node is AnimatedSprite2D and ghost_node.sprite_frames:
				var anim = ghost_node.animation if ghost_node.animation != "" else "default"
				if ghost_node.sprite_frames.has_animation(anim):
					gtex = ghost_node.sprite_frames.get_frame_texture(anim, 0)
			if gtex == null:
				var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
				img.fill(Color(0.7, 0.8, 1.0, 0.6))
				gtex = ImageTexture.create_from_image(img)
			# CanvasLayer 保证显示在最上层
			var gcl = CanvasLayer.new()
			gcl.layer = 100
			_battle.get_tree().root.add_child(gcl)
			var start_g = gnd.global_position
			var dir_to_enemy = (genemy.global_position - start_g).normalized()
			var dist_to_enemy = start_g.distance_to(genemy.global_position)
			print("[鬼门大开] gtex=%s start=%s dir=%s dist=%d" % [gtex != null, start_g, dir_to_enemy, dist_to_enemy])
			for i in range(20):
				var g = Sprite2D.new()
				g.texture = gtex
				g.centered = true
				g.scale = Vector2(randf_range(0.5, 1.2), randf_range(0.5, 1.2))
				g.modulate = Color(1, 1, 1, randf_range(0.4, 0.8))
				gcl.add_child(g)
				# 先加入后再设置画布坐标（CanvasLayer 无变换，position=画布坐标）
				g.position = start_g + Vector2(randf_range(-40, 40), randf_range(-30, 50))
				# 朝敌人方向飞散（扇形偏移）
				var spread = Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)).normalized() * randf_range(0, 120)
				var fly_dir = (dir_to_enemy + spread).normalized()
				var fly_dist = dist_to_enemy + randf_range(80, 200)
				var dur = randf_range(0.6, 1.0)
				var gt = _battle.create_tween().set_parallel()
				gt.tween_property(g, "position", g.position + fly_dir * fly_dist, dur)
				gt.tween_property(g, "modulate:a", 0.0, dur)
				gt.tween_property(g, "scale", g.scale * 0.2, dur)
				gt.finished.connect(g.queue_free)
			# 定时清理 CanvasLayer
			var clear_cl = func(): gcl.queue_free()
			await _battle.get_tree().create_timer(1.5).timeout
			clear_cl.call()
	# 阎王令：更新鬼魂标签（计数器已在 _calc_damage 清零）
	if skill_id == "阎王令":
		_battle._update_ghost_label()
	# 鬼影护体 / 鬼煞附体：消耗鬼魂，按层数缩放效果
	if skill_id == "鬼影护体" or skill_id == "鬼煞附体":
		if data and _battle._current_actor.trait_data.has("驭鬼术"):
			var count = _battle._current_actor.trait_data.get("_ghost_count", 0)
			if count <= 0:
				_battle._push_log("【%s】没有鬼魂！" % skill_id, "system")
			else:
				var buff_id = data.apply_buff_id
				if buff_id == "":
					buff_id = "ghost_shield" if skill_id == "鬼影护体" else "ghost_boost"
				if skill_id == "鬼影护体":
					# 每 ghosts_per_charge 层 = 1 次抵挡，余数保留
					var per_charge = maxi(data.ghosts_per_charge, 1)
					var charges = int(count / per_charge)
					if charges <= 0:
						_battle._push_log("【鬼影护体】鬼魂不足（需 %d 层/次）！" % per_charge, "system")
					else:
						var leftover = count % per_charge
						_battle._current_actor.trait_data["_ghost_count"] = leftover
						_battle.apply_buff(_battle._current_actor, _battle._current_actor, buff_id, 999, float(charges), skill_id)
						# 修正值：SkillManager 预加的 buff value=0，这里覆盖为真实次数
						var glayers: Array = _battle._current_actor.buffs.get(buff_id, {}).get("layers", [])
						if not glayers.is_empty():
							glayers[0]["value"] = float(charges)
						_battle._push_log("【鬼影护体】消耗 %d 层鬼魂，抵挡 %d 次攻击，剩余 %d 层！" % [count - leftover, charges, leftover], "system")
				elif skill_id == "鬼煞附体":
					var boost = data.boost_pct * count
					_battle._current_actor.trait_data["_ghost_count"] = 0
					_battle.apply_buff(_battle._current_actor, _battle._current_actor, buff_id, data.apply_buff_turns, boost, skill_id)
					# 修正值：SkillManager 预加的 buff value=0，覆盖为真实 boost
					var blayers: Array = _battle._current_actor.buffs.get(buff_id, {}).get("layers", [])
					if not blayers.is_empty():
						blayers[0]["value"] = boost
					_battle._push_log("【鬼煞附体】消耗 %d 层鬼魂，伤害提升 %d%%！" % [count, int(boost * 100)], "system")
				_battle._update_ghost_label()
	# 割喉之战：黑雾缠身
	if skill_id == "死亡宣告" and target and not target.is_dead:
		if target.has_method("_show_marked_effect"):
			target._show_marked_effect()
	# 舍生取义：扣除 50% 最大气血 + 降低双抗
	if skill_id == "舍生取义":
	
		if data:
			var hp_cost = int(_battle._current_actor.get_effective_max_hp() * data.sacrifice_hp_pct)
			_battle.apply_damage(null, _battle._current_actor, hp_cost, {"secondary": true})
			_battle._current_actor.sync_visual()
			_battle._push_log("[舍生取义] %s 牺牲 %d 点气血，双抗降低" % [_battle._current_actor.stats.get_display_name(), hp_cost], "player_action")
			_battle.apply_buff(_battle._current_actor, _battle._current_actor, "def_broken", 3, data.sacrifice_def_pct, skill_id)
			_battle.apply_buff(_battle._current_actor, _battle._current_actor, "mdef_broken", 3, data.sacrifice_def_pct, skill_id)
	# 影化：同时加速 + 半透明特效
	if skill_id == "影化":
		_battle.apply_buff(_battle._current_actor, _battle._current_actor, "haste", 3, 1.3, skill_id)
		var nd = _battle._current_actor.get_parent()
		if nd:
			# 渐变为半透明
			var tw = _battle.create_tween()
			tw.tween_property(nd, "modulate", Color(1, 1, 1, 0.5), 0.3)
			# buff 结束时恢复（任一 buff 消失即恢复）
			_battle._current_actor.buff_removed.connect(func(_buff_id):
				if is_instance_valid(nd):
					var tw2 = _battle.create_tween()
					tw2.tween_property(nd, "modulate", Color(1, 1, 1, 1), 0.3)
			, CONNECT_ONE_SHOT)
	# 点天灯：对队友施法后挂灯笼
	if _battle._current_actor and _battle._current_actor.trait_data.has("点天灯") and target and target.is_player:
		var lh = _battle._try_add_lantern_to(target)
		if lh > 0:
			_battle.apply_heal(_battle._current_actor, target, lh, target.is_dead, {"secondary": true})
			target.sync_visual()
	# 嘲讽
	if skill_id == "嘲讽":
		_battle._threat_mgr.taunt(_battle._current_actor)
		_battle._push_log(GameData._T("LOG_TAUNT") % _battle._current_actor.stats.get_display_name(), "player_action")
	# 高级魔法连击：35% 概率再施放一次法术
	if not target.is_dead and _battle._current_actor.has_book_skill("高级魔法连击"):
		if data and (data.is_magic_damage or data.skill_type == SkillData.SkillType.MAGIC):
			if randf() < 0.35:
				_battle._push_log(GameData._T("LOG_MAGIC_COMBO") % _battle._current_actor.stats.get_display_name(), "player_action")
				var result2 = SkillManager.execute(_battle._current_actor, target, skill_id)
				_battle._resolve_skill_effects(result2, _battle._current_actor, target)
				await _battle._apply_skill_result(result2, _battle._current_actor, target)
	await _battle._finish_player_action()

## 使用道具
