extends RefCounted
## 饰品专属效果集中配置；用装备 ID 关联，旧存档的同名装备也生效。
const EFFECTS := {
	"overheal_shield": {
		"name": "余春化盾", "stat": "overheal_shield_ratio", "value": 0.50,
		"desc": "自身行动中主动治疗的溢出量有50%转为受治疗者护盾，可累积至目标最大气血的20%；不覆盖已有更高护盾。满血目标也能生效；吸血、自动回血及其他被动治疗不触发。",
	},
	"hidden_blade": {
		"name": "藏锋蓄势", "stat": "hidden_blade_bonus", "value": 0.25,
		"desc": "自身回合结束时未造成伤害，则蓄势：下回合首次主动攻击的整次伤害提高25%（含群体、多段），触发后消耗。连续蓄势不叠加；反伤、持续伤害及召唤物攻击不会消耗或获得该增伤。",
	},
	"summon_vitality": {
		"name": "御灵固本", "stat": "summon_hp_bonus", "value": 0.20,
		"desc": "佩戴者召唤出的宠物、铁甲和豆兵气血上限提高20%，当前气血按比例同步增加；可与召唤天赋加成叠加，不改变召唤物的永久属性。",
	},
	"healing_amplification": {
		"name": "回春", "stat": "outgoing_heal_bonus", "value": 0.30,
		"desc": "佩戴者造成的治疗量提高30%，包含单体、群体、道具和复活治疗。实际恢复仍受目标最大气血限制；不增加受到的治疗量。",
	},
	"mana_saving": {
		"name": "节灵", "stat": "mp_cost_reduction", "value": 0.30,
		"desc": "技能耗蓝减少30%，适用于全部技能。与技能书及天赋节蓝相加，总减免上限80%；原本耗蓝的技能最低消耗1点，零耗蓝技能不变。",
	},
	"delayed_revival": {
		"name": "三转还魂", "stat": "delayed_revival", "value": 3.0,
		"desc": "死亡后按自身速度累计3个行动回合，以50%最大气血自动复活，行动条从0开始。可再次触发；提前被救活则取消倒计时。全队阵亡仍判负，不能阻止困难模式主角死亡失败。",
	},
	"fish_bond": {
		"name": "双鱼同心", "stat": "fish_bond", "value": 1.0,
		"desc": "两名角色同时佩戴结对生效，每对每场共享2次保命：另一人存活时，受到致命伤害保留1点气血；同一次群伤将双方一起击杀时不生效。多人佩戴按队伍顺序两两结对。",
	},
	"universal_dodge": {
		"name": "疾风护佑", "stat": "all_source_dodge", "value": 10.0,
		"desc": "闪避 +10%，可躲避任何来源的伤害，包括法术、持续伤害、反伤和分担伤害。",
	},
	"control_immunity": {
		"name": "定心", "stat": "control_immunity", "value": 1.0,
		"desc": "完全免疫控制效果，包括冰封、失魂、封印、催眠、混乱、减速和虚弱。",
	},
	"skill_cooldown_reduction": {
		"name": "九宫运转", "stat": "skill_cd_reduction", "value": 1.0,
		"desc": "全部技能的冷却时间减少1回合，最低为0，包含召唤技能；不缩短入场等待。",
	},
	"external_debuff_immunity": {
		"name": "玲珑净心", "stat": "external_debuff_immunity", "value": 1.0,
		"desc": "完全免疫来自他人的所有负面效果；自身施加的负面效果仍然生效。",
	},
}
const EQUIPMENT_EFFECTS := {
	"余春瓶": ["overheal_shield"],
	"藏锋坠": ["hidden_blade"],
	"御灵佩": ["summon_vitality"],
	"回春玉佩": ["healing_amplification"],
	"节灵佩": ["mana_saving"],
	"还魂珠": ["delayed_revival"],
	"双鱼百年结": ["fish_bond"],
	"疾风之铃": ["universal_dodge"],
	"八卦坠": ["control_immunity"],
	"九宫坠": ["skill_cooldown_reduction"],
	"七彩玲珑": ["external_debuff_immunity"],
}

static func effects_for(equipment: Dictionary) -> Array:
	if int(equipment.get("slot", -1)) != EquipData.SlotType.NECKLACE: return []
	return EQUIPMENT_EFFECTS.get(str(equipment.get("id", "")), [])

static func description(equipment: Dictionary) -> String:
	var lines: PackedStringArray = []
	for id in effects_for(equipment):
		var effect: Dictionary = EFFECTS.get(id, {})
		if not effect.is_empty(): lines.append("%s：%s" % [effect.name, effect.desc])
	return "\n".join(lines)
