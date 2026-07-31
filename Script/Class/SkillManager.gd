# SkillManager.gd
# 技能执行器 - 计算并应用技能效果，返回战斗日志文本
class_name SkillManager
extends RefCounted

## 全局技能数据库  { skill_id: SkillData }
static var _skill_db: Dictionary = {}

# ──────────────────────────────────────────────────────
## 注册技能（游戏启动时调用，传入所有 SkillData 资源）
static func register_skill(data: SkillData) -> void:
	_skill_db[data.skill_id] = data

static func get_skill(skill_id: String) -> SkillData:
	return _skill_db.get(skill_id, null)

## 获取所有已注册的技能 ID 列表
static func list_all_skills() -> Array[String]:
	return _skill_db.keys()

# ──────────────────────────────────────────────────────
## 计算技能效果，返回 SkillResult
## 注意：只计算数值，不实际造成伤害/治疗（调用方在动画结束后再 apply）
static func execute(
	caster: BattleCharacter,
	target: BattleCharacter,
	skill_id: String
) -> SkillResult:

	var result = SkillResult.new()
	result.skill_id = skill_id

	var data: SkillData = get_skill(skill_id)
	if data == null:
		result.log_text = GameData._T("LOG_SKILL_NOT_FOUND") % skill_id
		return result

	# ── 检查 MP（已在 player_use_skill / execute_enemy_skill 中扣除，此处只做防止冻结）──

	# ── 检查冰冻状态 ─────────────────────────
	if caster.is_frozen:
		caster.is_frozen = false
		result.success = false
		result.log_text = GameData._T("LOG_FROZEN_CANT_ACT") % caster.stats.get_display_name()
		return result

	result.success = true
	result.skill_type = data.skill_type

	# ── 根据类型处理 ─────────────────────────
	match data.skill_type:
		SkillData.SkillType.PHYSICAL, SkillData.SkillType.MAGIC:
			_calc_damage(caster, target, data, result)
		SkillData.SkillType.MULTI_HIT:
			_calc_multi_hit(caster, target, data, result)
		SkillData.SkillType.HEAL:
			_calc_heal(caster, target, data, result)
		SkillData.SkillType.BUFF:
			_apply_buff(caster, target, data, result, false)
		SkillData.SkillType.DEBUFF:
			_apply_buff(caster, target, data, result, true)

	# ── 附带效果（伤害型/治疗型技能也可携带 Buff）──
	if data.apply_buff_id != "" and result.success and data.skill_type != SkillData.SkillType.BUFF:
		if randf() <= _calc_debuff_chance(caster, target, data.apply_buff_chance):
			target.add_buff(data.apply_buff_id, data.apply_buff_turns, data.apply_buff_value, data.skill_id)
			result.applied_buff = data.apply_buff_id

	return result

## 动画结束后调用：把 result 中的伤害/治疗实际应用到目标身上
static func apply_result(result: SkillResult, target: BattleCharacter) -> void:
	for dmg in result.damage_list:
		target.take_damage(dmg)
	if result.heal_amount > 0:
		target.heal(result.heal_amount)

# ──────────────────────────────────────────────────────
static func _calc_damage(
	caster: BattleCharacter,
	target: BattleCharacter,
	data: SkillData,
	result: SkillResult
) -> void:

	var is_magic = data.is_magic_damage or data.skill_type == SkillData.SkillType.MAGIC
	result.is_magic = is_magic
	var raw_atk = caster.get_effective_magic_attack() if is_magic else caster.get_effective_attack()
	var def     = target.get_effective_magic_defense() if is_magic else target.get_effective_defense()

	# 无视防御 + 一剑破万法天赋：额外无视 25%/级
	var slay_rank = GameData.get_talent_rank("attack_slay")
	var ignore_ratio = data.ignore_defense_ratio + 0.02 * slay_rank
	def = int(def * (1.0 - ignore_ratio))

	# 基础伤害 = 攻击 * 倍率 - 防御 * 0.6
	var base_dmg = int(raw_atk * data.damage_multiplier * caster.get_night_dmg_mul()) - int(def * 0.6) + data.flat_damage
	base_dmg = maxi(1, base_dmg)
	
	# 力劈华山：根据目标攻击追加伤害（目标攻越高追加越低）
	if data.target_atk_dmg_mult > 0:
		var t_atk = maxi(target.stats.attack, 1)
		var bonus_mult = clampf(float(caster.stats.attack) / t_atk, 0.3, 2.0)
		var bonus = int(target.stats.attack * bonus_mult * data.target_atk_dmg_mult)
		base_dmg += bonus

	# 随机浮动 ±5%
	base_dmg = int(base_dmg * randf_range(0.95, 1.05))

	# 法波动：法术伤害在 low%~high% 间浮动
	if is_magic and caster._has_book_type("magic_fluctuate"):
		var low_mul = 0.85; var high_mul = 1.15
		for b in caster.book_skills:
			var bdb = SkillDB.BOOK_SKILL_DB.get(b, {})
			if bdb.get("type", "") == "magic_fluctuate":
				var v = bdb.get("value", {})
				low_mul = min(low_mul, v.get("low", 0.85))
				high_mul = max(high_mul, v.get("high", 1.15))
		base_dmg = int(base_dmg * randf_range(low_mul, high_mul))

	# 暴击（物理用物理暴击率，法术用法术暴击率）
	var crit_chance = caster.get_effective_magic_crit_rate() if is_magic else caster.get_effective_crit_rate()
	var crit_mult = caster.stats.crit_mult
	var is_crit = randf() < crit_chance
	if is_crit:
		base_dmg = int(base_dmg * crit_mult)

	# 鬼煞附体：伤害提升
	if caster.has_buff("ghost_boost"):
		var gb = caster.get_buff_value("ghost_boost")
		if gb != null and gb > 0:
			base_dmg = int(base_dmg * (1.0 + gb))

	# 阎王令：鬼魂增伤
	if data.skill_name == "阎王令":
		var ghost_cfg = caster.trait_data.get("驭鬼术", {})
		var ghost_pct = ghost_cfg.get("dmg_pct", 0.5) if not ghost_cfg.is_empty() else 0.5
		var ghost_count = caster.trait_data.get("_ghost_count", 0)
		if ghost_count > 0:
			base_dmg = int(base_dmg * (1.0 + ghost_pct * ghost_count))
			caster.trait_data["_ghost_count"] = 0

	# 摄魂痛击：杀敌叠伤
	if data.skill_name == "摄魂痛击":
		var kills = caster.trait_data.get("_soul_strike_kills", 0)
		if kills > 0:
			base_dmg = int(base_dmg * (1.0 + 0.2 * kills))

	# 割喉之战：标记目标双倍伤害
	base_dmg = SkillManager.apply_marked_bonus(caster, target, base_dmg)

	result.damage_list.append(base_dmg)
	result.is_crit = is_crit

	var crit_str = " " + GameData._T("LOG_CRIT") if is_crit else ""
	var dmg_type = GameData._T("DMG_TYPE_MAGIC") if is_magic else GameData._T("DMG_TYPE_PHYSICAL")
	result.log_text = GameData._T("LOG_DAMAGE_DEALT") % [caster.stats.get_display_name(), GameData._T(data.skill_name), target.stats.get_display_name(), base_dmg, dmg_type, crit_str]

static func _calc_multi_hit(
	caster: BattleCharacter,
	target: BattleCharacter,
	data: SkillData,
	result: SkillResult
) -> void:

	var total = 0
	for i in data.hit_count:
		var raw_atk = caster.get_effective_attack()
		var def     = target.get_effective_defense()
		var per_hit = int(raw_atk * data.damage_multiplier / data.hit_count)
		var per_def = int(def / data.hit_count)
		var dmg = maxi(1, per_hit - per_def)
		dmg = maxi(1, int(dmg * randf_range(0.95, 1.05)))
		dmg = SkillManager.apply_marked_bonus(caster, target, dmg)
		result.damage_list.append(dmg)
		total += dmg
	
	# 多段攻击暴击（全部命中后整体暴击）
	var crit_chance = caster.get_effective_crit_rate()
	var is_crit = randf() < crit_chance
	result.is_crit = is_crit
	if is_crit:
		for i in range(result.damage_list.size()):
			result.damage_list[i] = int(result.damage_list[i] * caster.stats.crit_mult)
		total = int(total * caster.stats.crit_mult)

	result.log_text = GameData._T("LOG_MULTI_HIT_DMG") % [caster.stats.get_display_name(), GameData._T(data.skill_name), data.hit_count, total]

static func _calc_heal(
	caster: BattleCharacter,
	target: BattleCharacter,
	data: SkillData,
	result: SkillResult
) -> void:

	var amount = int(target.stats.max_hp * data.heal_multiplier * caster.get_effective_heal_rate()) + data.flat_heal
	amount = maxi(1, amount)

	# 护盾：基于目标最大 HP 的百分比
	if data.shield_pct > 0.0:
		result.shield_amount = int(target.stats.max_hp * data.shield_pct)

	# 治疗暴击：概率 = 天运 × 3%，暴击倍率 = 1.5
	var heal_crit_chance = caster.stats.luck * 0.03
	var is_crit = randf() < heal_crit_chance
	if is_crit:
		amount = int(amount * 1.5)
		result.is_crit = true

	result.heal_amount = amount
	var crit_str = " " + GameData._T("LOG_CRIT") if is_crit else ""
	result.log_text = GameData._T("LOG_HEAL_CAST") % [caster.stats.get_display_name(), GameData._T(data.skill_name), target.stats.get_display_name(), amount, crit_str]

static func _apply_buff(
	caster: BattleCharacter,
	target: BattleCharacter,
	data: SkillData,
	result: SkillResult,
	is_debuff: bool
) -> void:

	if data.apply_buff_id != "":
		var success = true
		if is_debuff:
			success = randf() <= _calc_debuff_chance(caster, target, data.apply_buff_chance)
		if success:
			target.add_buff(data.apply_buff_id, data.apply_buff_turns, data.apply_buff_value, data.skill_id)
			result.applied_buff = data.apply_buff_id
			var buf_label = GameData._T("LOG_BUFF_GAIN") if not is_debuff else GameData._T("LOG_BUFF_CURSED")
			result.log_text = GameData._T("LOG_BUFF_CAST") % [caster.stats.get_display_name(), GameData._T(data.skill_name), target.stats.get_display_name(), buf_label]
		elif is_debuff:
			result.log_text = GameData._T("LOG_BUFF_FAIL") % [GameData._T(data.skill_name), target.stats.get_display_name()]
		else:
			result.log_text = GameData._T("LOG_SKILL_CAST") % [caster.stats.get_display_name(), GameData._T(data.skill_name)]


## 死亡宣告：标记目标后下次攻击双倍伤害
static func apply_marked_bonus(attacker: BattleCharacter, target: BattleCharacter, dmg: int) -> int:
	if target.has_buff("marked"):
		target.remove_buff("marked")
		return dmg * 2
	return dmg
# ──────────────────────────────────────────────────────
## 运气修正封印/异常成功率：base + (caster_luck - target_luck) / 100.0
static func _calc_debuff_chance(caster: BattleCharacter, target: BattleCharacter, base_chance: float) -> float:
	var caster_luck = caster.stats.luck + caster.equip_special.get("luck", 0)
	var target_luck = target.stats.luck + target.equip_special.get("luck", 0)
	var chance = base_chance + float(caster_luck - target_luck)
	# 封印精通天赋
	chance += 0.03 * GameData.get_talent_rank("support_seal_chance")
	if chance <= 0.0: return 0.0
	return clampf(chance, 0.0, 1.0)

## 返回值结构
class SkillResult:
	var skill_id: String = ""
	var success: bool = true
	var damage_list: Array[int] = []  # 每段伤害
	var heal_amount: int = 0
	var shield_amount: int = 0
	var is_crit: bool = false
	var applied_buff: String = ""
	var log_text: String = ""
	var skill_type: int = 0        # SkillData.SkillType, 用于决定动画 (attack vs cast)
	var is_magic: bool = false

	func total_damage() -> int:
		var t = 0
		for d in damage_list: t += d
		return t
