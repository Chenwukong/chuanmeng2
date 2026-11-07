extends RefCounted
## 战斗功能模块；状态和动画宿主由 BattleManager 显式传入。

static func player_summon(_battle, pet: PetData, prefer_pos: Vector2 = Vector2.INF) -> void:
	if _battle.state != _battle.BattleState.PLAYER_TURN: return
	if pet == null:
		_battle.skill_failed.emit("没有可召唤的宠物！")
		return
	
	# 宠物不能召唤
	if _battle._current_actor.is_summoned_pet:
		_battle.skill_failed.emit(GameData._T("LOG_PET_CANT"))
		_battle._push_log(GameData._T("LOG_PET_CANT"), "system")
		return
	if _battle._count_summoned_pets() >= _battle.get_pet_slot_count():
		_battle.skill_failed.emit("召唤位已满！")
		_battle._push_log("召唤位已满！", "system")
		return
	
	# 只有召系角色能召唤
	if not CharacterStats.has_role(_battle._current_actor.stats.role, CharacterStats.Role.SUMMON):
		_battle.skill_failed.emit(GameData._T("LOG_ONLY_SUMMONER"))
		_battle._push_log(GameData._T("LOG_ONLY_SUMMONER"), "system")
		return
	
	_battle._change_state(_battle.BattleState.PLAYER_ACTION)

	# 施法者播放施法动画
	var caster_node = _battle._current_actor.get_parent()
	if caster_node and caster_node.has_method("play_cast_sequence"):
		caster_node.play_cast_sequence("召唤宠物")

	_battle._push_log(GameData._T("LOG_SUMMON_PET") % [
		_battle._current_actor.stats.get_display_name(), pet.character_name, PetData.apt_name(pet.aptitude)
	], "player_action")

	# 让 BattleScene 创建宠物节点并注册
	var scene = _battle.get_parent()
	var pet_node: Node2D = null
	if scene and scene.has_method("summon_pet"):
		pet_node = await scene.summon_pet(pet, prefer_pos)
	else:
		_battle._push_log(GameData._T("LOG_SUMMON_FAIL"), "system")
		await _battle._finish_player_action()
		return

	# 随机选一个存活敌人攻击
	var target = _battle._pick_random_enemy()
	if target == null:
		await _battle._finish_player_action()
		return

	# 灵兽神通：自动施法
	print("[灵兽神通] talent rank=", GameData.get_talent_rank("summon_auto_cast"), " pet skills=", pet.skill_ids, " summoned=", pet.character_name)
	if _battle._current_actor.talent_rank("summon_auto_cast") > 0:
		# 选第一个非普通攻击的技能
		var skill_id = ""
		for sid in pet.skill_ids:
			print("[灵兽神通] pet skill: ", sid, " in db=", SkillManager.get_skill(sid) != null)
			if sid != "普通攻击" and SkillManager.get_skill(sid) != null:
				skill_id = sid
				break
		if skill_id.is_empty() and not pet.skill_ids.is_empty():
			skill_id = pet.skill_ids[0]
		print("[灵兽神通] selected skill_id=", skill_id)
		if not skill_id.is_empty() and SkillManager.get_skill(skill_id) != null:
			_battle._push_log("[灵兽神通] %s 施展 %s！" % [pet.character_name, skill_id], "player_action")
			var bc = pet_node.get_node("BattleCharacter") as BattleCharacter
			var result = SkillManager.execute(bc, target, skill_id)
			_battle._resolve_skill_effects(result, bc, target)
			if result.success:
				bc = pet_node.get_node("BattleCharacter") as BattleCharacter
				await _battle._apply_skill_result(result, bc, target)
			else:
				await _battle.get_tree().create_timer(0.5).timeout
			await _battle._finish_player_action()
			return

	# 执行攻击动画和伤害
	var target_pos = target.get_parent().global_position
	if pet_node and pet_node.has_method("play_attack_sequence"):
		var enemy_nd = target.get_parent() as EnemyNode
		await pet_node.play_attack_sequence(target_pos, enemy_nd)
	else:
		await _battle.get_tree().create_timer(0.5).timeout

	_battle._do_pet_attack_damage(pet, target)
	await _battle.get_tree().create_timer(_battle.action_delay * 0.5).timeout
	await _battle._finish_player_action()


static func player_summon_mech(_battle, mech_name: String, replace_bc: BattleCharacter = null) -> void:
	if _battle.state != _battle.BattleState.PLAYER_TURN: return
	if _battle._current_actor.is_summoned_pet:
		_battle.skill_failed.emit(GameData._T("LOG_PET_CANT"))
		_battle._push_log(GameData._T("LOG_PET_CANT"), "system")
		return
	var mech_data = GameData.mech_db.get(mech_name)
	if mech_data == null:
		_battle.skill_failed.emit(GameData._T("LOG_MEHC_NOT_FOUND") % mech_name)
		_battle._push_log(GameData._T("LOG_MEHC_NOT_FOUND") % mech_name, "system")
		return
	# 消耗 MP 并设置冷却
	var skill_data = SkillManager.get_skill("召唤铁甲兽")
	if _battle.get_skill_cooldown(_battle._current_actor, "召唤铁甲兽") > 0:
		_battle.skill_failed.emit("召唤铁甲兽仍在冷却！")
		return
	if skill_data:
		if not _battle._current_actor.use_mp(skill_data.mp_cost):
			_battle.skill_failed.emit(GameData._T("BATTLE_LOW_MP"))
			_battle._push_log(GameData._T("BATTLE_LOW_MP"), "system")
			return
		var effective_cd := preload("res://Script/Battle/AccessoryEffects.gd").effective_cooldown(_battle._current_actor, skill_data.cooldown_turns)
		if effective_cd > 0:
			_battle.skill_cooldowns[_battle._cd_key(_battle._current_actor, "召唤铁甲兽")] = effective_cd
		if effective_cd < skill_data.cooldown_turns:
			preload("res://Script/Battle/AccessoryEffects.gd").notify(_battle._current_actor, "skill_cooldown_reduction", "召唤铁甲兽：冷却 %d → %d 回合" % [skill_data.cooldown_turns, effective_cd], _battle)
	_battle._change_state(_battle.BattleState.PLAYER_ACTION)
	# 施法者播放施法动画
	var caster_node = _battle._current_actor.get_parent()
	if caster_node and caster_node.has_method("play_cast_sequence"):
		caster_node.play_cast_sequence("召唤铁甲兽")
	_battle._push_log(GameData._T("LOG_SUMMON_MEHC") % [_battle._current_actor.stats.get_display_name(), mech_data.name], "player_action")
	var stats = CharacterStats.new()
	stats.character_name = mech_data.name; stats.character_class = "铁甲"
	stats.max_hp = 80 + mech_data.level * 15; stats.max_mp = 30
	stats.attack = mech_data.atk; stats.magic_attack = 0
	stats.defense = mech_data.def_; stats.magic_defense = mech_data.def_
	stats.speed = mech_data.spd; stats.level = mech_data.level
	stats.was_base_path = mech_data.was_base_path; stats.role = int(mech_data.get("role", CharacterStats.Role.GUARD))
	stats.was_direction = 2
	stats.skill_ids = mech_data.get("skills", []).duplicate()
	var scene = _battle.get_parent()
	var pet_node: Node2D = null
	if scene and scene.has_method("summon_mech_pet"):
		var prefer_pos = Vector2.INF
		if replace_bc and replace_bc.get_parent():
			prefer_pos = replace_bc.get_parent().position
			var old_node = replace_bc.get_parent() as Node2D
			if old_node:
				var t = _battle.create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				t.tween_property(old_node, "position:x", old_node.position.x + 300, 0.4)
				t.parallel().tween_property(old_node, "modulate:a", 0.0, 0.35)
				await t.finished
			_battle.remove_character(replace_bc)
			if is_instance_valid(old_node): old_node.queue_free()
		pet_node = await scene.summon_mech_pet(stats, prefer_pos)
		_battle.summoned_mech_ids.append(mech_name)
		# 在 BattleCharacter 上记录 mech_name，死亡时可回溯清理
		var mech_bc = pet_node.get_node_or_null("BattleCharacter") as BattleCharacter
		if mech_bc:
			mech_bc.pet_id = mech_name
			mech_bc.summoner_member_id = _battle._current_actor.member_id
	else:
		_battle._push_log(GameData._T("LOG_MEHC_FAIL"), "system"); await _battle._finish_player_action(); return
	var target = _battle._pick_random_enemy()
	if target == null: await _battle._finish_player_action(); return
	var target_pos = target.get_parent().global_position
	if pet_node and pet_node.has_method("play_attack_sequence"):
		await pet_node.play_attack_sequence(target_pos, target.get_parent() as EnemyNode)
	var summoned = pet_node.get_node("BattleCharacter") as BattleCharacter
	var dmg = maxi(1, summoned.get_effective_attack() - int(target.get_effective_defense()))
	dmg = maxi(1, int(dmg * randf_range(0.95, 1.05)))
	_battle.apply_damage(summoned, target, dmg); target.sync_visual()
	_battle.damage_floated.emit(target, dmg, "normal")
	_battle._push_log(GameData._T("LOG_PET_ATK") % [stats.character_name, target.stats.get_display_name(), dmg], "player_action")
	await _battle.get_tree().create_timer(_battle.action_delay * 0.5).timeout
	await _battle._finish_player_action()

## 召唤宠物槽数量（1 + 天赋加成）


static func player_summon_fallback(_battle) -> void:
	if _battle.state != _battle.BattleState.PLAYER_TURN: return
	_battle._change_state(_battle.BattleState.PLAYER_ACTION)
	# 施法者播放施法动画
	var caster_node = _battle._current_actor.get_parent()
	if caster_node and caster_node.has_method("play_cast_sequence"):
		caster_node.play_cast_sequence("")
	_battle._push_log(GameData._T("LOG_FALLBACK") % _battle._current_actor.stats.get_display_name(), "system")
	var target = _battle._pick_random_enemy()
	if target == null:
		await _battle._finish_player_action()
		return
	_battle._push_log(GameData._T("LOG_FALLBACK_DIRECT"), "system")
	_battle.apply_damage(_battle._current_actor, target, 50, {"secondary": true})
	target.sync_visual()
	_battle.damage_floated.emit(target, 50, "normal")
	await _battle._finish_player_action()


static func _do_pet_attack_damage(_battle, pet: PetData, target: BattleCharacter) -> void:
	var skill_id = "普通攻击"
	var sk_data = SkillManager.get_skill(skill_id)
	var dmg = maxi(1, pet.attack - int(target.get_effective_defense()))
	dmg = int(dmg * randf_range(0.95, 1.05))
	_battle.apply_damage(_battle._current_actor, target, dmg, {"secondary": true})
	target.sync_visual()
	_battle.damage_floated.emit(target, dmg, "normal")
	_battle._push_log(GameData._T("LOG_PET_ATK") % [pet.character_name, target.stats.get_display_name(), dmg], "player_action")


## 召唤铁甲兽上场


static func _do_pet_attack(_battle, pet: PetData, target: BattleCharacter) -> void:
	var skill_id = "普通攻击"
	if not pet.skill_ids.is_empty():
		skill_id = pet.skill_ids[randi() % pet.skill_ids.size()]
	var sk_data = SkillManager.get_skill(skill_id)

	if sk_data == null or skill_id == "普通攻击":
		var dmg = maxi(1, pet.attack - int(target.get_effective_defense()))
		dmg = int(dmg * randf_range(0.95, 1.05))
		_battle.apply_damage(_battle._current_actor, target, dmg, {"secondary": true})
		target.sync_visual()
		_battle.damage_floated.emit(target, dmg, "normal")
		_battle._push_log(GameData._T("LOG_PET_ATK") % [pet.character_name, target.stats.get_display_name(), dmg], "player_action")
	else:
		var mul = sk_data.damage_multiplier if sk_data.damage_multiplier > 0 else 1.0
		var dmg = maxi(1, int(pet.attack * mul) - int(target.get_effective_defense()))
		dmg = int(dmg * randf_range(0.95, 1.05))
		_battle.apply_damage(_battle._current_actor, target, dmg, {"secondary": true})
		target.sync_visual()
		_battle.damage_floated.emit(target, dmg, "normal")
		_battle._push_log(GameData._T("LOG_PET_SKILL_ATK") % [pet.character_name, skill_id, target.stats.get_display_name(), dmg], "player_action")
	await _battle.get_tree().create_timer(_battle.action_delay).timeout

## 捕捉


