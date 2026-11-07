extends RefCounted
const DB = preload("res://Script/Data/AccessoryEffectDB.gd")
const CONTROL_IDS: Array[String] = ["freeze", "失魂", "silence", "sleep", "confuse", "slow", "weakened"]

static func begin_turn(actor: BattleCharacter) -> void:
	actor.hidden_blade_turn_open = true
	actor.hidden_blade_dealt_damage = false
	actor.hidden_blade_action_multiplier = 1.0

static func begin_action(actor: BattleCharacter) -> void:
	if actor: actor.hidden_blade_action_multiplier = 1.0

static func finish_turn(actor: BattleCharacter, manager) -> void:
	if actor == null or not actor.hidden_blade_turn_open: return
	actor.hidden_blade_turn_open = false
	actor.hidden_blade_action_multiplier = 1.0
	if actor.is_dead or float(actor.equip_special.get("hidden_blade_bonus", 0.0)) <= 0.0:
		actor.hidden_blade_ready = false
		return
	var was_ready := actor.hidden_blade_ready
	actor.hidden_blade_ready = not actor.hidden_blade_dealt_damage
	if actor.hidden_blade_ready and not was_ready:
		notify(actor, "hidden_blade", "蓄势：下回合首次主动攻击伤害+25%", manager)

static func amplify_active_attack(actor: BattleCharacter, amount: int, manager, secondary: bool) -> int:
	if actor == null or secondary or actor != manager.current_actor() or manager.state != manager.BattleState.PLAYER_ACTION: return amount
	var bonus := maxf(0.0, float(actor.equip_special.get("hidden_blade_bonus", 0.0)))
	if bonus <= 0.0: return amount
	if actor.hidden_blade_ready:
		actor.hidden_blade_ready = false
		actor.hidden_blade_action_multiplier = 1.0 + bonus
		notify(actor, "hidden_blade", "蓄势释放：本次主动攻击伤害+%d%%" % roundi(bonus * 100.0), manager)
	return maxi(1, roundi(amount * actor.hidden_blade_action_multiplier))

static func record_damage(actor: BattleCharacter, actual: int, manager) -> void:
	if actor and actual > 0 and actor.hidden_blade_turn_open and actor == manager.current_actor():
		actor.hidden_blade_dealt_damage = true

static func convert_overheal(actor: BattleCharacter, target: BattleCharacter, overflow: int, manager, secondary: bool = false) -> int:
	if actor == null or target == null or target.is_dead or overflow <= 0 or secondary: return 0
	if actor != manager.current_actor() or manager.state != manager.BattleState.PLAYER_ACTION: return 0
	var ratio := maxf(0.0, float(actor.equip_special.get("overheal_shield_ratio", 0.0)))
	if ratio <= 0.0: return 0
	var cap := int(target.get_effective_max_hp() * 0.20)
	# 机甲耐久不是普通护盾，不能被 set_shield 重复计入。
	var current_shield := maxi(0, target.get_shield() - target.mech_durability)
	var gained := mini(int(overflow * ratio), maxi(0, cap - current_shield))
	if gained <= 0: return 0
	target.set_shield(current_shield + gained)
	if manager._threat_mgr: manager._threat_mgr.add_shield_threat(actor, false)
	manager._record_settlement(actor, target, gained, "shield")
	manager.damage_floated.emit(target, gained, "shield")
	notify(actor, "overheal_shield", "为%s转化%d点护盾（%d/%d）" % [target.stats.get_display_name(), gained, current_shield + gained, cap], manager)
	return gained

## 统一触发提示入口；效果判定/预览不提示，仅真正生效后调用。
static func notify(target, effect_id: String, detail: String, manager = null) -> void:
	var accessory := "饰品"
	for id in DB.EQUIPMENT_EFFECTS:
		if effect_id in DB.EQUIPMENT_EFFECTS[id]:
			accessory = id
			break
	var now := Time.get_ticks_msec()
	var key := effect_id + ":" + detail
	if target.get_meta("accessory_notice_key", "") == key and now - int(target.get_meta("accessory_notice_time", -1000)) < 400: return
	target.set_meta("accessory_notice_key", key)
	target.set_meta("accessory_notice_time", now)
	var parent = target.get_parent()
	if parent and parent.is_inside_tree():
		var notice = preload("res://scenes/Effects/AccessoryTriggerNotice.tscn").instantiate()
		notice.accessory_name = accessory
		notice.effect_text = detail
		notice.set_meta("accessory_trigger_notice", true)
		var count := 0
		for child in parent.get_children():
			if child.has_meta("accessory_trigger_notice"): count += 1
		notice.position.y = -76.0 * mini(count, 2)
		parent.add_child(notice)
	if manager == null:
		var node = parent
		while node:
			if node.has_node("BattleManager"):
				manager = node.get_node("BattleManager")
				break
			node = node.get_parent()
	if manager: manager._push_log("【%s】%s：%s" % [accessory, target.stats.get_display_name(), detail], "system")

static func notify_immunity(target, buff_id: String, manager = null) -> void:
	var control: bool = buff_id in CONTROL_IDS and target.equip_special.get("control_immunity", 0) > 0
	notify(target, "control_immunity" if control else "external_debuff_immunity", "免疫控制效果" if control else "免疫外来负面效果", manager)

static func effective_cooldown(actor, base_turns: int) -> int:
	return maxi(0, base_turns - maxi(0, int(actor.equip_special.get("skill_cd_reduction", 0))))

static func blocks_debuff(target, buff_id: String, instigator = null) -> bool:
	if buff_id in CONTROL_IDS and float(target.equip_special.get("control_immunity", 0)) > 0: return true
	# 来源未知时不认作自身，不能凭技能名称推断施加者。
	return buff_id in target.DEBUFF_IDS and instigator != target and float(target.equip_special.get("external_debuff_immunity", 0)) > 0

static func equipment_stats(equipment: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id in DB.effects_for(equipment):
		var effect: Dictionary = DB.EFFECTS.get(id, {})
		if effect.is_empty(): continue
		result[effect.stat] = float(result.get(effect.stat, 0.0)) + float(effect.value)
	return result

## 在召唤物完成初始化后统一应用；复制战斗属性，避免修改宠物或铁甲的原始数据。
static func empower_summon(owner: BattleCharacter, summoned: BattleCharacter, manager = null) -> void:
	if owner == null or summoned == null or owner == summoned or not summoned.is_summoned_pet: return
	if summoned.has_meta("summon_vitality_applied"): return
	var bonus := maxf(0.0, float(owner.equip_special.get("summon_hp_bonus", 0.0)))
	if bonus <= 0.0: return
	var previous_max := summoned.get_effective_max_hp()
	var previous_hp := summoned.current_hp
	summoned.stats = summoned.stats.duplicate_for_battle()
	summoned.stats.max_hp = maxi(1, roundi(summoned.stats.max_hp * (1.0 + bonus)))
	var new_max := summoned.get_effective_max_hp()
	summoned.current_hp = mini(new_max, roundi(float(previous_hp) * new_max / maxi(1, previous_max)))
	summoned.set_meta("summon_vitality_applied", true)
	summoned.sync_visual()
	notify(owner, "summon_vitality", "召唤物气血+%d%%，上限增加%d" % [roundi(bonus * 100.0), new_max - previous_max], manager)

## 原有闪避取较高值，饰品额外增加百分点；所有来源统一判定一次。
static func dodge_chance(target) -> float:
	return clampf(maxf(float(target.trait_data.get("_dodge", 0)), float(target.equip_special.get("dodge", 0))) + float(target.equip_special.get("all_source_dodge", 0)), 0.0, 100.0)

static func try_evade(target) -> bool:
	var chance := dodge_chance(target)
	if chance <= 0.0 or randf() * 100.0 >= chance: return false
	target.show_trait_float("闪避")
	if target.equip_special.get("all_source_dodge", 0) > 0:
		notify(target, "universal_dodge", "闪避伤害")
	return true
