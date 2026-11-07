extends RefCounted

## 主页通用增益由全体角色共享，不再要求主定位；召唤物仍走专门的召唤加成。
const PARTY_WIDE_MAIN_TALENTS := ["main_root", "main_focus", "main_recover", "main_channel", "main_spirit", "baochong"]

## 定位天赋的统一资格判断。宠物不继承角色天赋，铁甲按自身定位例外处理。
static func applies_to(stats: CharacterStats, talent_id: String, summoned_pet: bool = false) -> bool:
	if stats == null: return false
	if (summoned_pet or stats.character_class == "宠物") and stats.character_class != "铁甲": return false
	if talent_id in PARTY_WIDE_MAIN_TALENTS: return true
	var role := 0
	if talent_id.begins_with("main_") or talent_id in ["funeng", "fudong", "fenliefu", "jieyuechengben", "qinxiukulian", "wanfuguiyuan", "duoduoyishan", "baochong"]:
		role = CharacterStats.Role.MAIN
	elif talent_id.begins_with("attack_"): role = CharacterStats.Role.ATTACK
	elif talent_id.begins_with("support_"): role = CharacterStats.Role.SUPPORT
	elif talent_id.begins_with("summon_"): role = CharacterStats.Role.SUMMON
	elif talent_id.begins_with("guard_"): role = CharacterStats.Role.GUARD
	return role != 0 and (stats.role & role) != 0

static func rank_for(stats: CharacterStats, talent_id: String, summoned_pet: bool = false) -> int:
	return GameData.get_talent_rank(talent_id) if applies_to(stats, talent_id, summoned_pet) else 0

static func get_support_talent_bonus(talent_id: String, base_val: float, per_rank: float) -> float:
	var rank := GameData.get_talent_rank(talent_id)
	return 1.0 + per_rank * rank

## 召唤属性加成倍率；豆兵使用同一套系数，不继承角色定位天赋。
static func get_pet_stat_mult(stat: String) -> float:
	var mult := 1.0
	var rank := GameData.get_talent_rank("summon_pet_speed")
	if stat == "speed" and rank > 0:
		mult += 0.1 * rank
	rank = GameData.get_talent_rank("summon_pet_hp")
	if stat == "hp" and rank > 0:
		mult += 0.15 * rank
	rank = GameData.get_talent_rank("summon_pet_damage")
	if stat == "damage" and rank > 0:
		mult += 0.15 * rank
	rank = GameData.get_talent_rank("summon_pet_defense")
	if stat == "defense" and rank > 0:
		mult += 0.15 * rank
	return mult

