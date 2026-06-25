# ThreatManager.gd
# 回合制 RPG 仇恨系统 — 怪物共用一个仇恨表，数值可随伤害膨胀自动成长
class_name ThreatManager
extends RefCounted

# ── 职业倍率 ──
const PROFESSION_RATES := {
	"主": 1.0,
	"攻": 1.2,
	"召": 0.8,
	"辅": 0.6,
	"护": 1.8,
}

# ── 治疗仇恨（固定值，不随治疗量变化）──
const HEAL_THREAT := {
	"small": 300,
	"medium": 600,
	"large": 1000,
	"group": 1500,
	"hot": 600,
	"revive": 3000,
}

# ── 护盾仇恨 ──
const SHIELD_SINGLE: int = 300
const SHIELD_GROUP:  int = 800

# ── Buff 仇恨 ──
const BUFF_SINGLE: int = 100
const BUFF_GROUP:  int = 250

# ── 衰减 ──
const DECAY_RATE: float = 0.85

# ── 目标选择权重 ──
const WEIGHT_TOP:    float = 0.70
const WEIGHT_SECOND: float = 0.20
const WEIGHT_THIRD:  float = 0.10

var _threat_table: Dictionary = {}  # { "yuling": 5000, "erlang": 3200 }
var _taunt_map: Dictionary = {}     # { "yuling": 2 }  追敌 → 剩余回合


## 获取 actor 的职业倍率
func _rate(actor: BattleCharacter) -> float:
	return PROFESSION_RATES.get(CharacterStats.role_name(actor.stats.role), 1.0)


## 获取 actor 的仇恨键（优先 member_id，否则 character_name）
func _key(actor: BattleCharacter) -> String:
	if not actor.member_id.is_empty():
		return actor.member_id
	return actor.stats.character_name


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 仇恨增加
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func add_damage_threat(actor: BattleCharacter, actual_damage: int) -> void:
	if actor == null or not actor.is_player:
		return
	var k := _key(actor)
	_threat_table[k] = _threat_table.get(k, 0) + int(actual_damage * _rate(actor))


func add_heal_threat(actor: BattleCharacter, heal_size: String) -> void:
	if actor == null or not actor.is_player:
		return
	var base = HEAL_THREAT.get(heal_size, 0)
	if base == 0:
		return
	var k := _key(actor)
	_threat_table[k] = _threat_table.get(k, 0) + int(base * _rate(actor))


func add_shield_threat(actor: BattleCharacter, is_group: bool) -> void:
	if actor == null or not actor.is_player:
		return
	var base := SHIELD_GROUP if is_group else SHIELD_SINGLE
	var k := _key(actor)
	_threat_table[k] = _threat_table.get(k, 0) + int(base * _rate(actor))


func add_buff_threat(actor: BattleCharacter, is_group: bool) -> void:
	if actor == null or not actor.is_player:
		return
	var base := BUFF_GROUP if is_group else BUFF_SINGLE
	var k := _key(actor)
	_threat_table[k] = _threat_table.get(k, 0) + int(base * _rate(actor))


func add_revive_threat(actor: BattleCharacter) -> void:
	if actor == null or not actor.is_player:
		return
	var base := HEAL_THREAT["revive"]
	var k := _key(actor)
	_threat_table[k] = _threat_table.get(k, 0) + int(base * _rate(actor))


func add_guard_threat(actor: BattleCharacter, damage_taken: int) -> void:
	if actor == null or not actor.is_player:
		return
	var k := _key(actor)
	_threat_table[k] = _threat_table.get(k, 0) + int(damage_taken * 0.5)


## 嘲讽：threat = highest_hate × 1.5，并标记追敌 2 回合
func taunt(actor: BattleCharacter) -> void:
	if actor == null or not actor.is_player:
		return
	var top_val := 0
	for v in _threat_table.values():
		if v > top_val:
			top_val = v
	var k := _key(actor)
	_threat_table[k] = maxi(_threat_table.get(k, 0), int(top_val * 1.5))
	_taunt_map[k] = 2


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 衰减 / 清除
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func decay_all() -> void:
	for k in _threat_table.keys():
		_threat_table[k] = int(_threat_table[k] * DECAY_RATE)
	# 同步衰减 taunt 回合
	var expired: Array = []
	for k in _taunt_map.keys():
		_taunt_map[k] -= 1
		if _taunt_map[k] <= 0:
			expired.append(k)
	for k in expired:
		_taunt_map.erase(k)


func clear_threat(actor: BattleCharacter) -> void:
	if actor == null:
		return
	var k := _key(actor)
	_threat_table.erase(k)
	_taunt_map.erase(k)


## 完全清空（战斗重置）
func reset() -> void:
	_threat_table.clear()
	_taunt_map.clear()


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 目标选择
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 最高仇恨目标
func get_top_target(alive_party: Array[BattleCharacter]) -> BattleCharacter:
	var best: BattleCharacter = null
	var best_val := -1
	for c in alive_party:
		var v = _threat_table.get(_key(c), 0)
		if v > best_val:
			best_val = v
			best = c
	return best if best else (alive_party[0] if alive_party.size() > 0 else null)


## 权重随机选择（70% / 20% / 10%）
func get_weighted_target(alive_party: Array[BattleCharacter]) -> BattleCharacter:
	if alive_party.is_empty():
		return null

	# 如果有追敌，无视仇恨，直接打追敌
	for c in alive_party:
		var k := _key(c)
		if _taunt_map.get(k, 0) > 0:
			return c

	# 按仇恨排序（降序）
	var sorted := alive_party.duplicate()
	sorted.sort_custom(func(a, b):
		return _threat_table.get(_key(a), 0) > _threat_table.get(_key(b), 0)
	)

	match sorted.size():
		0:
			return null
		1:
			return sorted[0]
		2:
			var r := randf()
			if r < WEIGHT_TOP / (WEIGHT_TOP + WEIGHT_SECOND):
				return sorted[0]
			return sorted[1]
		_:
			# 归一化权重
			var total := WEIGHT_TOP + WEIGHT_SECOND + WEIGHT_THIRD
			var r := randf()
			if r < WEIGHT_TOP / total:
				return sorted[0]
			if r < (WEIGHT_TOP + WEIGHT_SECOND) / total:
				return sorted[1]
			return sorted[2]


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UI 状态（不显示数字）
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 返回 "red" / "yellow" / "green"
func get_threat_state(actor: BattleCharacter, alive_party: Array[BattleCharacter]) -> String:
	if actor == null:
		return "green"
	var k := _key(actor)
	var my_val = _threat_table.get(k, 0)
	var top_val := 0
	for c in alive_party:
		var v = _threat_table.get(_key(c), 0)
		if v > top_val:
			top_val = v
	if top_val == 0:
		return "green"
	if my_val >= top_val:
		return "red"
	if my_val >= top_val * 0.8:
		return "yellow"
	return "green"


## 获取原始仇恨值（用于战后面板按数值排序，但不显示给玩家）
func get_threat_value(actor: BattleCharacter) -> int:
	if actor == null:
		return 0
	return _threat_table.get(_key(actor), 0)
