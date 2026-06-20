# EquipData.gd — 装备系统（纯字典）
class_name EquipData
extends RefCounted

# ═══ 槽位 ═══
enum SlotType {
	WEAPON,     # 武器
	HEAD,       # 头盔 / 发钗
	NECKLACE,   # 项链
	BODY,       # 铠甲 / 女衣
	BELT,       # 腰带
	SHOES,      # 鞋子
}

static func slot_key(slot: SlotType) -> String:
	match slot:
		SlotType.WEAPON:   return "武器"
		SlotType.HEAD:     return "头盔"
		SlotType.NECKLACE: return "项链"
		SlotType.BODY:     return "铠甲"
		SlotType.BELT:     return "腰带"
		SlotType.SHOES:    return "鞋子"
	return ""

static func slot_label(slot: SlotType) -> String:
	match slot:
		SlotType.WEAPON:   return "武器"
		SlotType.HEAD:     return "头盔／发钗"
		SlotType.NECKLACE: return "项链"
		SlotType.BODY:     return "铠甲／女衣"
		SlotType.BELT:     return "腰带"
		SlotType.SHOES:    return "鞋子"
	return ""

# ═══ 品质 ═══
enum Rarity {
	COMMON,     # 普通
	UNCOMMON,   # 优秀
	RARE,       # 稀有
	EPIC,       # 史诗
	LEGENDARY,  # 传说
}

static func rarity_name(r: Rarity) -> String:
	match r:
		Rarity.COMMON:    return "普通"
		Rarity.UNCOMMON:  return "优秀"
		Rarity.RARE:      return "稀有"
		Rarity.EPIC:      return "史诗"
		Rarity.LEGENDARY: return "传说"
	return ""

static func rarity_color(r: Rarity) -> Color:
	match r:
		Rarity.COMMON:    return Color(0.75, 0.75, 0.75)
		Rarity.UNCOMMON:  return Color(0.3, 1.0, 0.3)
		Rarity.RARE:      return Color(0.3, 0.5, 1.0)
		Rarity.EPIC:      return Color(0.85, 0.3, 1.0)
		Rarity.LEGENDARY: return Color(1.0, 0.55, 0.05)
	return Color.WHITE

# ═══ 词缀类型 ═══
enum AffixType {
	LIFESTEAL,   # 吸血 +N%
	STRENGTH,    # 力量 +N%
	INTELLECT,   # 智力 +N%
	CRIT_RATE,   # 暴击率 +N%
	CRIT_DMG,    # 暴击伤害 +N%
	HASTE,       # 急速 +N%
	PENETRATION, # 穿透 +N%
	MAX_HP,      # 气血 +N%
	MAX_MP,      # 灵力 +N%
}

static func affix_label(a: AffixType) -> String:
	match a:
		AffixType.LIFESTEAL:   return "吸血"
		AffixType.STRENGTH:    return "力量"
		AffixType.INTELLECT:   return "智力"
		AffixType.CRIT_RATE:   return "暴击率"
		AffixType.CRIT_DMG:    return "暴击伤害"
		AffixType.HASTE:       return "急速"
		AffixType.PENETRATION: return "穿透"
		AffixType.MAX_HP:      return "气血"
		AffixType.MAX_MP:      return "灵力"
	return ""

## 完全随机一条词缀（值和类型皆随机）
static func random_affix(rarity: Rarity) -> Dictionary:
	var pool: Array = [
		AffixType.LIFESTEAL, AffixType.STRENGTH, AffixType.INTELLECT,
		AffixType.CRIT_RATE, AffixType.CRIT_DMG, AffixType.HASTE,
		AffixType.PENETRATION, AffixType.MAX_HP, AffixType.MAX_MP,
	]
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var af_type = pool[rng.randi_range(0, pool.size() - 1)]
	var base_val := 5.0
	match rarity:
		Rarity.UNCOMMON:  base_val = rng.randf_range(3.0, 7.0)
		Rarity.RARE:      base_val = rng.randf_range(5.0, 12.0)
		Rarity.EPIC:      base_val = rng.randf_range(8.0, 20.0)
		Rarity.LEGENDARY: base_val = rng.randf_range(15.0, 35.0)
		_:                base_val = rng.randf_range(2.0, 5.0)
	return {"type": af_type, "value": snapped(base_val, 1.0)}


# ═══ 命名装备库（静态字典，键为装备ID） ═══

## 用 create_named() 注册的命名装备
static var named_db: Dictionary = {}

## 注册一件命名装备（TCP 路径可为空）
static func register_named(id: String, slot: SlotType, rarity: Rarity,
		name_str: String, base: Dictionary, tcp_path: String = "",
		level: int = 1, affixes: Array = []) -> void:
	named_db[id] = {
		"id": id,
		"slot": slot,
		"rarity": rarity,
		"level": level,
		"name": name_str,
		"display_name": "%s·%s" % [rarity_name(rarity), name_str] if rarity != Rarity.COMMON else name_str,
		"base": base,
		"affixes": affixes,
		"tcp_path": tcp_path,
	}

## 按 ID 取一件命名装备的副本（不影响原模板）
static func get_named(id: String) -> Dictionary:
	return named_db.get(id, {}).duplicate(true)


# ═══ 工厂：创建一件装备（返回纯 Dictionary） ═══

static func create_equip(slot: SlotType, rarity: Rarity, level: int = 1) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var eq: Dictionary = {
		"slot": slot,
		"rarity": rarity,
		"level": level,
		"name": "",
		"affixes": [],
		"base": {},
	}

	# ── 基础属性（随等级成长） ──
	var lv := float(maxi(1, level))
	match slot:
		SlotType.WEAPON:
			eq.name = "武器"
			eq.base = {
				"atk": int(rng.randf_range(8, 14) * lv),
			}
		SlotType.HEAD:
			var is_hairpin := rng.randi() % 2 == 0
			eq.name = "发钗" if is_hairpin else "头盔"
			eq.base = {
				"def":  int(rng.randf_range(3, 7) * lv),
				"mdef": int(rng.randf_range(5, 10) * lv),
			}
		SlotType.NECKLACE:
			eq.name = "项链"
			eq.base = {
				"mp": int(rng.randf_range(8, 16) * lv),
			}
		SlotType.BODY:
			var is_female := rng.randi() % 2 == 0
			eq.name = "女衣" if is_female else "铠甲"
			eq.base = {
				"def": int(rng.randf_range(6, 12) * lv),
			}
		SlotType.BELT:
			eq.name = "腰带"
			eq.base = {
				"hp": int(rng.randf_range(10, 22) * lv),
			}
		SlotType.SHOES:
			eq.name = "鞋子"
			eq.base = {
				"spd": int(rng.randf_range(4, 10) * lv),
			}

	# ── 根据品质补派生属性 ──
	var mul := 1.0 + float(rarity) * 0.25
	for k in eq.base:
		eq.base[k] = maxi(1, int(eq.base[k] * mul))

	# ── 词缀（只有武器有，品质越高越多） ──
	if slot == SlotType.WEAPON:
		var affix_count := 0
		match rarity:
			Rarity.COMMON:    affix_count = 0
			Rarity.UNCOMMON:  affix_count = 1
			Rarity.RARE:      affix_count = rng.randi_range(1, 2)
			Rarity.EPIC:      affix_count = rng.randi_range(2, 3)
			Rarity.LEGENDARY: affix_count = rng.randi_range(3, 4)
		for _i in affix_count:
			eq.affixes.append(random_affix(rarity))

	# 品质前缀
	var prefix := ""
	match rarity:
		Rarity.UNCOMMON:  prefix = "优秀·"
		Rarity.RARE:      prefix = "稀有·"
		Rarity.EPIC:      prefix = "史诗·"
		Rarity.LEGENDARY: prefix = "传说·"
	eq.display_name = "%s%s" % [prefix, eq.name]

	return eq


# ═══ 计算装备总属性加成 ═══

static func calc_stats(equipment: Dictionary) -> Dictionary:
	var s := {"atk": 0, "def": 0, "mdef": 0, "hp": 0, "mp": 0, "spd": 0}
	if equipment.is_empty():
		return s
	var base: Dictionary = equipment.get("base", {})
	for k in s:
		s[k] = base.get(k, 0)
	for af in equipment.get("affixes", []):
		match af.get("type", -1):
			AffixType.LIFESTEAL:   s["lifesteal"] = s.get("lifesteal", 0.0) + af.value * 0.01
			AffixType.STRENGTH:    s["atk"] = int(s.atk * (1.0 + af.value * 0.01))
			AffixType.INTELLECT:   s["mdef"] = int(s.mdef * (1.0 + af.value * 0.01))
			AffixType.CRIT_RATE:   s["crit_rate"] = s.get("crit_rate", 0.0) + af.value * 0.01
			AffixType.CRIT_DMG:    s["crit_dmg"] = s.get("crit_dmg", 0.0) + af.value * 0.01
			AffixType.HASTE:       s["spd"] = int(s.spd * (1.0 + af.value * 0.01))
			AffixType.PENETRATION: s["penetration"] = s.get("penetration", 0.0) + af.value * 0.01
			AffixType.MAX_HP:      s["hp"] = int(s.hp * (1.0 + af.value * 0.01))
			AffixType.MAX_MP:      s["mp"] = int(s.mp * (1.0 + af.value * 0.01))
	return s


# ═══ 全套装备总属性 ═══

static func calc_full_stats(all_equips: Dictionary) -> Dictionary:
	var total := {"atk": 0, "def": 0, "mdef": 0, "hp": 0, "mp": 0, "spd": 0,
				  "lifesteal": 0.0, "crit_rate": 0.0, "crit_dmg": 0.0, "penetration": 0.0}
	for slot_key in all_equips:
		var slot_stats := calc_stats(all_equips[slot_key])
		for k in slot_stats:
			if total.has(k):
				if typeof(total[k]) == TYPE_FLOAT:
					total[k] = total[k] + slot_stats[k]
				else:
					total[k] = total[k] + slot_stats[k]
	return total
