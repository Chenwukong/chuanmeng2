extends RefCounted
## 真身的基础属性增幅，统一在此配置；只修改战斗中独立复制的属性资源。
const BASE_STAT_BONUS := 0.50
const DEFENSE_BONUS := 0.30
const BASE_STATS := ["max_hp", "max_mp", "attack", "magic_attack", "defense", "magic_defense", "speed", "luck"]

static func apply(actor) -> void:
	if actor.trait_data.get("_true_form_stats_applied", false): return
	var old_hp_max: int = actor.get_effective_max_hp()
	var old_mp_max: int = actor.get_effective_max_mp()
	var hp: int = actor.current_hp
	var mp: int = actor.current_mp
	for stat in BASE_STATS:
		var bonus := DEFENSE_BONUS if stat in ["defense", "magic_defense"] else BASE_STAT_BONUS
		actor.stats.set(stat, roundi(float(actor.stats.get(stat)) * (1.0 + bonus)))
	actor.trait_data["_true_form_stats_applied"] = true
	var hp_max: int = actor.get_effective_max_hp()
	var mp_max: int = actor.get_effective_max_mp()
	if old_hp_max > 0: actor.current_hp = mini(hp_max, roundi(float(hp) * hp_max / old_hp_max))
	if old_mp_max > 0: actor.current_mp = mini(mp_max, roundi(float(mp) * mp_max / old_mp_max))
	actor.sync_visual()
