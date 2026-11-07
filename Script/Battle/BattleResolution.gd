extends RefCounted
## 所有战斗数值变更的入口。动画时机由调用者决定，结算不依赖 UI / 当前行动者。
static func apply(manager, event: Dictionary) -> int:
	var target: BattleCharacter = event.get("target")
	var actor: BattleCharacter = event.get("attacker")
	var amount: int = maxi(0, int(event.get("amount", 0)))
	var kind: String = event.get("kind", "damage")
	var actual := 0
	if not is_instance_valid(target): return 0
	if kind == "heal" or kind == "revive":
		if target.is_dead and kind != "revive": return 0
		if amount <= 0: return 0
		var original_amount := amount
		var heal_bonus := maxf(0.0, float(actor.equip_special.get("outgoing_heal_bonus", 0.0))) if actor else 0.0
		if heal_bonus > 0.0: amount = roundi(amount * (1.0 + heal_bonus))
		actual = target.heal(amount)
		preload("res://Script/Battle/AccessoryEffects.gd").convert_overheal(actor, target, maxi(0, amount - actual), manager, bool(event.get("secondary", false)))
		if heal_bonus > 0.0 and actual > original_amount:
			preload("res://Script/Battle/AccessoryEffects.gd").notify(actor, "healing_amplification", "治疗量+%d%%，额外恢复%d气血" % [roundi(heal_bonus * 100.0), actual - original_amount], manager)
		if actual > 0 and actor and manager._threat_mgr:
			if kind == "revive": manager._threat_mgr.add_revive_threat(actor)
			else: manager._threat_mgr.add_heal_threat(actor, event.get("heal_size", "medium"))
	elif kind == "shield":
		if target.is_dead or amount <= 0: return 0
		target.set_shield(amount)
		actual = amount
		if actor and manager._threat_mgr: manager._threat_mgr.add_shield_threat(actor, false)
	else:
		if target.is_dead: return 0
		var evasion_target := target
		# 最先判定，包含 DOT、反伤、法术、真实伤害及其他 secondary 事件。
		if amount > 0 and preload("res://Script/Battle/AccessoryEffects.gd").try_evade(target):
			event["actual"] = 0
			manager._push_log("【%s】%s 闪避了伤害！" % [event.get("skill_id", "伤害"), target.stats.get_display_name()], "system")
			return 0
		var missed: bool = event.get("missed", false)
		var secondary: bool = event.get("secondary", false)
		if not secondary and actor and actor == manager.current_actor() and manager.state == manager.BattleState.PLAYER_ACTION:
			if actor.dice_has_pending: actor.begin_dice_attack()
			if amount > 0: amount = maxi(1, int(amount * actor.dice_action_multiplier))
		var is_magic: bool = event.get("is_magic", false)
		if not secondary and is_magic and not event.get("is_aoe", false) and amount > 0 and not missed:
			var absorb: float = target.trait_data.get("_magic_absorb", 0)
			if absorb > 0 and randf() * 100.0 < absorb:
				var absorbed := maxi(1, int(amount * 0.3))
				apply(manager, {"target": target, "amount": absorbed, "kind": "heal", "emit_float": false})
				amount -= absorbed
		if missed:
			target.show_trait_float("闪避")
			manager._push_log("【%s】%s 闪避了攻击！" % [event.get("skill_id", "攻击"), target.stats.get_display_name()], "system")
			return 0
		# 命中即消耗骰子：零伤害、护盾或无敌挡住也算一次攻击，落空则保留。
		if not secondary and actor and actor == manager.current_actor() and manager.state == manager.BattleState.PLAYER_ACTION:
			actor.settle_dice_hit()
		if target.has_buff("invincible"):
			target.show_trait_float("无敌")
			return 0
		if amount <= 0:
			if event.get("emit_float", true): manager.damage_floated.emit(target, 0, "normal")
			return 0
		if not secondary and target.has_buff("ghost_shield"):
			var layers: Array = target.buffs.get("ghost_shield", {}).get("layers", [])
			if not layers.is_empty():
				layers[0]["value"] = float(layers[0].get("value", 1.0)) - 1.0
				if layers[0]["value"] <= 0.0: target.remove_buff("ghost_shield")
				manager.damage_floated.emit(target, 0, "dodge")
				return 0
		if amount <= 0: return 0
		# 主动护主仅拦截敌方直接攻击；DOT、反伤和治疗不进入此分支。
		if not secondary and actor and not actor.is_player:
			var armies: Array = []
			if target.has_meta("bean_army"): armies.append(target.get_meta("bean_army"))
			if GameData.get_talent_rank("summon_love_allies") > 0:
				for ally in manager.party:
					if ally != target and ally.has_meta("bean_army"): armies.append(ally.get_meta("bean_army"))
			for army in armies:
				if not is_instance_valid(army): continue
				var defender = army.get_guardian(target)
				if not is_instance_valid(defender): continue
				var protected := target
				defender.protect_hit(protected.get_parent().global_position, actor.get_parent().global_position)
				target = defender.character
				event["target"] = target
				manager._push_log("【豆兵护主】%s 替 %s 挡下攻击！" % [target.stats.get_display_name(), protected.stats.get_display_name()], "system")
				break
		if actor: target.last_attacker = actor
		amount = preload("res://Script/Battle/AccessoryEffects.gd").amplify_active_attack(actor, amount, manager, secondary)
		# Character 负责护盾吸收、分担、死亡及其信号；这里仅调用一次。
		# 护主若更换了承伤者，新目标需要使用自己的闪避率。
		actual = target.take_damage(amount, actor if not secondary else null, target == evasion_target)
		preload("res://Script/Battle/AccessoryEffects.gd").record_damage(actor, actual, manager)
		if actual > 0 and actor and manager._threat_mgr and not target.is_player:
			manager._threat_mgr.add_damage_threat(actor, actual)
		if actual > 0 and not secondary and actor:
			_apply_on_hit(manager, actor, target, actual, is_magic)
	event["actual"] = actual
	if actual > 0:
		manager._record_settlement(actor, target, actual, kind)
	if event.get("emit_float", true):
		manager.damage_floated.emit(target, actual, event.get("type", "heal" if kind in ["heal", "revive"] else kind if kind == "shield" else "normal"))
	target.sync_visual()
	return actual

static func _apply_on_hit(manager, actor: BattleCharacter, target: BattleCharacter, amount: int, is_magic: bool) -> void:
	if not is_magic:
		var reflect: float = target.equip_special.get("reflect", 0)
		reflect += target.get_reflect_ratio() * 100.0
		if reflect > 0 and not actor.is_dead:
			apply(manager, {"attacker": target, "target": actor, "amount": maxi(1, int(amount * reflect / 100.0)), "secondary": true})
	if not actor.is_dead:
		var ratio := actor.get_lifesteal_ratio() + float(actor.equip_special.get("lifesteal", 0)) / 100.0
		ratio += float(actor.trait_data.get("暗影汲取", {}).get("drain_pct", 0.0))
		if actor.has_buff("lifesteal_up"):
			var bonus = actor.get_buff_value("lifesteal_up")
			if bonus != null: ratio += float(bonus)
		if ratio > 0:
			var healed := apply(manager, {"attacker": actor, "target": actor, "kind": "heal", "amount": maxi(1, int(amount * ratio)), "heal_size": "small", "secondary": true})
			if healed > 0: manager._push_log(GameData._T("LOG_LIFESTEAL") % [actor.stats.get_display_name(), healed], "heal")
	if target.is_dead or target.is_immune_to_debuffs(): return
	var venom := actor.get_venom_chance()
	if venom > 0 and randf() < venom:
		target.add_buff("poison", 3, null, "攻击附毒", actor)
		manager._push_log(GameData._T("LOG_POISON") % target.stats.get_display_name(), "debuff")
	var bleed := actor.talent_rank("attack_bleed")
	if bleed > 0 and randf() < 0.3 * bleed:
		target.add_buff("bleed", 3, int(target.stats.max_hp * 0.05 * bleed), "裂伤", actor)
		manager._push_log("%s 裂伤流血！" % target.stats.get_display_name(), "debuff")

static func apply_buff(manager, actor: BattleCharacter, target: BattleCharacter, id: String, turns: int, value = null, source: String = "", record_threat: bool = true) -> void:
	if target == null or target.is_dead: return
	if preload("res://Script/Battle/AccessoryEffects.gd").blocks_debuff(target, id, actor):
		preload("res://Script/Battle/AccessoryEffects.gd").notify_immunity(target, id, manager)
		return
	# 增幅术属于施术者；不能因为受术者有辅助定位就放大敌人或宠物施放的增益。
	if actor and value is float and id not in BattleCharacter.DEBUFF_IDS:
		value *= 1.0 + 0.1 * actor.talent_rank("support_buff_up")
	target.add_buff(id, turns, value, source, actor)
	if record_threat and target.has_buff(id) and actor and manager._threat_mgr:
		manager._threat_mgr.add_buff_threat(actor, false)
	manager.effect_settled.emit(actor, target, 0, "buff")
	target.sync_visual()

## 处决与捕捉不走普通伤害公式，但统一处理退出战斗和死亡信号。
static func retire(manager, actor: BattleCharacter, target: BattleCharacter, captured: bool = false) -> void:
	if target == null or target.is_dead: return
	var previous := target.current_hp
	if not captured and target.fish_bond != null and target.fish_bond.prevent_death(target):
		target.current_hp = 1
		target.hp_changed.emit(previous, 1, target.get_effective_max_hp())
		manager._record_settlement(actor, target, maxi(0, previous - 1), "damage")
		target.sync_visual()
		return
	target.current_hp = 0
	target.is_dead = true
	if not captured: target.last_attacker = actor
	target.hp_changed.emit(previous, 0, target.get_effective_max_hp())
	if captured:
		if manager._threat_mgr: manager._threat_mgr.clear_threat(target)
	else:
		target.died.emit()
		if actor and manager._threat_mgr and not target.is_player: manager._threat_mgr.add_damage_threat(actor, previous)
		manager._record_settlement(actor, target, previous, "damage")
	target.sync_visual()
