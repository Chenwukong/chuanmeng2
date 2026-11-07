extends RefCounted
const TUTORIAL_FLAG := "教学/符咒/已完成"

static func should_teach(manager) -> bool:
	if GameData.story_flag(TUTORIAL_FLAG) or manager.enemies.size() != 1: return false
	if manager.enemies[0].stats.character_name != "机关人": return false
	for actor in manager.party:
		if not actor.is_summoned_pet and CharacterStats.has_role(actor.stats.role, CharacterStats.Role.MAIN): return true
	return false

const ITEM_IDS := ["talisman_fire", "talisman_thunder", "talisman_ice", "talisman_haste", "talisman_ceasefire", "talisman_revive", "talisman_basic"]

static func consume(manager, actor: BattleCharacter) -> bool:
	if actor == null: return false
	var type := int(actor.stats.talisman_type)
	if type == CharacterStats.TalismanType.BASIC: return true
	if manager.free_talismans_left > 0 and actor.talent_rank("jieyuechengben") > 0:
		manager.free_talismans_left -= 1
		return true
	if type < 0 or type >= ITEM_IDS.size() or manager.player_inventory == null: return false
	return manager.player_inventory.remove_item(ITEM_IDS[type], 1)

static func targets(manager, actor: BattleCharacter, target: BattleCharacter) -> Array[BattleCharacter]:
	var result: Array[BattleCharacter] = [target]
	var extra := actor.talent_rank("fenliefu")
	if actor.stats.talisman_type == CharacterStats.TalismanType.FIRE: extra = maxi(extra, 2)
	var candidates: Array[BattleCharacter] = manager.alive_enemies()
	candidates.erase(target)
	candidates.shuffle()
	for i in mini(extra, candidates.size()): result.append(candidates[i])
	return result

static func damage(actor: BattleCharacter, target: BattleCharacter) -> int:
	var multiplier := 1.0
	var type := int(actor.stats.talisman_type)
	if type >= 0 and type < ITEM_IDS.size():
		var item := GameData.item_db.get(ITEM_IDS[type]) as ItemData
		if item: multiplier = item.damage_multiplier
	var base := maxi(1, int(actor.get_effective_magic_attack() * multiplier) - int(target.get_effective_magic_defense()))
	return int(base * actor.metamorphosis_mod * (1.0 + 0.05 * actor.talent_rank("funeng")))

static func support(manager, actor: BattleCharacter, target: BattleCharacter) -> void:
	if actor.stats.talisman_type == CharacterStats.TalismanType.REVIVE:
		if target.is_dead:
			manager.apply_heal(actor, target, int(target.stats.max_hp * 0.3), true, {"emit_float": true})
			manager._push_log("借尸还魂！%s 复活了！" % target.stats.get_display_name(), "player_action")
	elif actor.stats.talisman_type == CharacterStats.TalismanType.HASTE and not target.is_dead:
		manager.apply_buff(actor, target, "haste", 3, 1.3 * (1.0 + 0.05 * actor.talent_rank("fudong")), "talisman_haste")
		target.sync_visual()
		manager._push_log("%s 获得了加速！" % target.stats.get_display_name(), "player_action")

static func support_targets(manager, target: BattleCharacter) -> Array[BattleCharacter]:
	var result: Array[BattleCharacter] = [target]
	var candidates: Array[BattleCharacter] = []
	for ally in manager.party:
		if ally != target and not ally.is_dead and ally.get_buff_layer_count("haste") < 3:
			candidates.append(ally)
	candidates.shuffle()
	var caster: BattleCharacter = manager.current_actor()
	var extra := caster.talent_rank("fenliefu") if caster else 0
	for i in mini(2 + extra, candidates.size()): result.append(candidates[i])
	return result
