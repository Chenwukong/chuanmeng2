extends SceneTree

class TestMap extends Node2D:
	func get_player_node() -> Node2D:
		return $Player

func _initialize() -> void:
	call_deferred("verify")
func reward(kind: int, id: String, count: int):
	var r = load("res://Script/Data/Models/ChestLoot.gd").new()
	r.kind = kind
	r.reward_id = id
	r.amount = count
	return r
func chest(host: Node, id: String):
	var c = load("res://scenes/World/TreasureChest.tscn").instantiate()
	c.chest_id = id
	host.add_child(c)
	return c
func verify() -> void:
	var data = root.get_node("GameData")
	data.set_process(false)
	data.restore_difficulty(1)
	data.game_flags = {}
	data.talent_ranks = {}
	data.player_inventory = load("res://Script/Data/Models/Inventory.gd").new()
	data.add_party_by_name("游霄云")
	var host := TestMap.new()
	root.add_child(host)
	current_scene = host
	var player := Node2D.new()
	player.name = "Player"
	host.add_child(player)
	var c = chest(host, "fixture_1")
	assert(not c.try_pickup(player))
	assert(not c.is_opened())
	var item_id: String = ""
	for id in data.item_db:
		if data.item_db[id].max_stack >= 2:
			item_id = id
			break
	var material_id: String = load("res://Script/Data/MaterialDB.gd").MATERIAL_DB.keys()[0]
	c.loot.assign([reward(0, "", 50), reward(1, item_id, 2), reward(2, "基础符纸", 2), reward(3, material_id, 3), reward(4, "", 10), reward(5, "", 1)])
	var gold: int = data.player_gold
	var equips: int = data.equip_bag.size()
	var materials: int = data.material_bag.size()
	var points: int = data.talent_points
	player.position.x = 200
	c._process(0.0)
	assert(not c.is_opened())
	player.position.x = 0
	data.in_battle = true
	c._process(0.0)
	assert(not c.is_opened())
	data.in_battle = false
	data._npc_dialogue_playing = true
	c._process(0.0)
	assert(not c.is_opened())
	data._npc_dialogue_playing = false
	# 奖励中的道具信号再次请求开启，不能重复领。
	data.player_inventory.item_added.connect(func(_id, _count): assert(not c.try_pickup(player)), CONNECT_ONE_SHOT)
	c._process(0.0)
	assert(c.is_opened())
	assert(not c.visible and c.is_queued_for_deletion())
	assert(data.player_gold == gold + 50)
	assert(data.player_inventory.get_count(item_id) == 2)
	assert(data.equip_bag.size() == equips + 2)
	assert(data.material_bag.size() == materials + 3)
	assert(data.talent_points == points + 1)
	assert(data._auto_save_pending)
	assert(not c.try_pickup(player))
	var same = chest(host, "fixture_1")
	assert(same.is_opened())
	assert(not same.visible and same.is_queued_for_deletion())
	var save = load("res://Script/Save/SaveService.gd").serialize_state(data)
	assert(save.game_flags["chest/fixture_1"])
	save.vol_master = -1
	save.vol_music = -1
	save.vol_sfx = -1
	data.game_flags = {}
	assert(not c.is_opened())
	assert(load("res://Script/Save/SaveService.gd").restore_state(data, save))
	var restored = chest(host, "fixture_1")
	assert(not restored.visible and restored.is_queued_for_deletion())
	# 错误配置或堆叠溢出时整箱不发，保留未开启状态。
	var invalid = chest(host, "fixture_bad")
	invalid.loot.assign([reward(0, "", 500), reward(1, "no_such_item", 1)])
	assert(not invalid.try_pickup(player))
	assert(not invalid.is_opened() and data.player_gold == gold + 50)
	invalid.loot.assign([reward(0, "", 500), reward(1, item_id, data.item_db[item_id].max_stack)])
	assert(not invalid.try_pickup(player))
	assert(not invalid.is_opened() and data.player_gold == gold + 50)
	assert(load("res://Script/World/MapWalker.gd") != null)
	print("CHEST PASS: configurable six reward kinds, empty/invalid/overflow atomic rejection, range and battle/dialogue guards, exact gold, one-time state serialized, re-entry and reentrant duplicate prevention, autosave requested, walker integration compiles")
	quit()
