extends RefCounted
## 一对佩戴者共享两次保命。群伤整批结算后再确认，避免顺序结算互相救活。
var members: Array[WeakRef] = []
var battle: WeakRef
var remaining: int = 2
var group_depth: int = 0
var pending: Dictionary = {}

static func bind_pairs(manager) -> void:
	var wearers: Array = []
	for actor in manager.party:
		actor.fish_bond = null
		if not actor.is_summoned_pet and actor.equip_special.get("fish_bond", 0) > 0:
			wearers.append(actor)
	# 超过两人时按队伍顺序两两结对，单出的佩戴者不生效。
	for i in range(0, wearers.size() - 1, 2):
		var bond = load("res://Script/Battle/FishBond.gd").new()
		bond.battle = weakref(manager)
		bond.members.assign([weakref(wearers[i]), weakref(wearers[i + 1])])
		wearers[i].fish_bond = bond
		wearers[i + 1].fish_bond = bond

static func begin_group(manager) -> void:
	for bond in _bonds(manager): bond.group_depth += 1

static func end_group(manager) -> void:
	for bond in _bonds(manager):
		bond.group_depth = maxi(0, bond.group_depth - 1)
		if bond.group_depth == 0: bond.resolve_group()

static func _bonds(manager) -> Array:
	var result: Array = []
	for actor in manager.party:
		if actor.fish_bond != null and actor.fish_bond not in result: result.append(actor.fish_bond)
	return result

func prevent_death(actor) -> bool:
	if remaining <= 0: return false
	var manager = battle.get_ref()
	if manager == null or actor not in manager.party: return false
	var partner = _partner(actor)
	if not is_instance_valid(partner) or partner not in manager.party or partner.is_dead or partner.current_hp <= 0: return false
	if group_depth > 0:
		pending[actor.get_instance_id()] = weakref(actor)
	else:
		_trigger(actor)
	return true

func _partner(actor):
	for ref in members:
		var member = ref.get_ref()
		if is_instance_valid(member) and member != actor: return member
	return null

func _trigger(actor) -> void:
	remaining -= 1
	var manager = battle.get_ref()
	preload("res://Script/Battle/AccessoryEffects.gd").notify(actor, "fish_bond", "保留1点气血 · 共享剩余 %d 次" % remaining, manager)

func resolve_group() -> void:
	if pending.is_empty(): return
	var victims: Array = []
	for ref in pending.values():
		var member = ref.get_ref()
		if is_instance_valid(member): victims.append(member)
	pending.clear()
	var together := victims.size() == 2 and victims.all(func(c): return c.current_hp <= 1)
	for victim in victims:
		if victim.is_dead: continue
		var partner = _partner(victim)
		if together or not is_instance_valid(partner) or partner.is_dead or remaining <= 0:
			victim._take_damage_raw(victim.current_hp + victim.get_shield(), true, true)
		else:
			_trigger(victim)
