# Inventory.gd
# 背包系统 - 管理道具数量，执行使用逻辑
# 挂载在玩家节点或 Autoload 上
class_name Inventory
extends RefCounted

## 背包槽：{ item_id: { "data": ItemData, "count": int } }
var _slots: Dictionary = {}

signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
signal item_used(item_id: String, target: BattleCharacter, result: UseResult)

# ──────────────────────────────────────────
## 添加道具
func add_item(data: ItemData, count: int = 1) -> void:
	if data.item_id in _slots:
		_slots[data.item_id]["count"] = mini(
			data.max_stack,
			_slots[data.item_id]["count"] + count
		)
	else:
		_slots[data.item_id] = { "data": data, "count": mini(data.max_stack, count) }
	item_added.emit(data.item_id, count)

## 移除道具
func remove_item(item_id: String, count: int = 1) -> bool:
	if not has_item(item_id, count):
		return false
	_slots[item_id]["count"] -= count
	if _slots[item_id]["count"] <= 0:
		_slots.erase(item_id)
	item_removed.emit(item_id, count)
	return true

func has_item(item_id: String, count: int = 1) -> bool:
	return item_id in _slots and _slots[item_id]["count"] >= count

func get_count(item_id: String) -> int:
	return _slots[item_id]["count"] if item_id in _slots else 0

func get_all_items() -> Array:
	var result = []
	for id in _slots:
		result.append({ "data": _slots[id]["data"], "count": _slots[id]["count"] })
	return result

## 使用道具（战斗中调用）
func use_item(item_id: String, target: BattleCharacter) -> UseResult:
	var result = UseResult.new()

	if not has_item(item_id):
		result.success = false
		result.log_text = "背包中没有该道具！"
		return result

	var data: ItemData = _slots[item_id]["data"]
	result.item_name = data.item_name

	match data.item_type:
		ItemData.ItemType.HP_POTION:
			var amt = data.hp_restore + int(target.stats.max_hp * data.hp_restore_percent)
			var actual = target.heal(amt)
			result.heal_amount = actual
			result.log_text = "使用【%s】，恢复 %d 点气血" % [data.item_name, actual]

		ItemData.ItemType.MP_POTION:
			var amt = data.mp_restore + int(target.stats.max_mp * data.mp_restore_percent)
			target.restore_mp(amt)
			result.mp_amount = amt
			result.log_text = "使用【%s】，恢复 %d 点灵力" % [data.item_name, amt]

		ItemData.ItemType.BUFF_ITEM:
			target.add_buff(data.buff_id, data.buff_turns)
			result.applied_buff = data.buff_id
			result.log_text = "使用【%s】，获得强力增益！" % data.item_name

		ItemData.ItemType.REVIVE:
			if not target.is_dead:
				result.success = false
				result.log_text = "【%s】只能对阵亡角色使用！" % data.item_name
				return result
			target.is_dead = false
			target.heal(int(target.stats.max_hp * data.revive_hp_percent))
			result.log_text = "使用【%s】，九死一生！" % data.item_name

		_:
			result.success = false
			result.log_text = "【%s】无法在战斗中使用" % data.item_name
			return result

	remove_item(item_id)
	result.success = true
	item_used.emit(item_id, target, result)
	return result

# ─── 序列化（存档）────────────────────────
func serialize() -> Dictionary:
	var data = {}
	for id in _slots:
		data[id] = _slots[id]["count"]
	return data

func deserialize(saved: Dictionary, item_db: Dictionary) -> void:
	_slots.clear()
	for id in saved:
		if id in item_db:
			_slots[id] = { "data": item_db[id], "count": saved[id] }


class UseResult:
	var success: bool = true
	var item_name: String = ""
	var heal_amount: int = 0
	var mp_amount: int = 0
	var applied_buff: String = ""
	var log_text: String = ""
