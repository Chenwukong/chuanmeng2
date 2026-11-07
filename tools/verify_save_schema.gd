extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var data = root.get_node("GameData")
	var saves = load("res://Script/Save/SaveService.gd")
	data.add_party_by_name("游霄云")
	data.add_party_by_name("叮咚")
	data.dialogue_progress["镖头"] = 1
	data.unlock_npc_dialogue("机关人", "通过试炼")
	for bus in ["BGM", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	var snapshot: Dictionary = saves.serialize_state(data)
	assert(snapshot.version == 4 and not snapshot.has("party") and snapshot.dialogue_indexes["镖头"] == 1)
	var saved_json: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	assert(not saves.restore_state(data, {"version": 3, "party": {}}))
	var cash = data.player_gold
	var party_order = data.party_order.duplicate()
	var equipped = data.player_equipment.duplicate(true)
	var bag = data.equip_bag.duplicate(true)
	data.player_gold = 1
	data.lock_npc_dialogue("机关人", "通过试炼")
	data.party_order.clear()
	assert(saves.restore_state(data, saved_json))
	assert(data.player_gold == cash and data.party_order == party_order)
	print("EQUIP EQUAL: ", data.player_equipment == equipped, " BAG SIZES ", data.equip_bag.size(), " / ", bag.size())
	assert(JSON.stringify(data.player_equipment) == JSON.stringify(saved_json.equipment))
	assert(JSON.stringify(data.equip_bag) == JSON.stringify(saved_json.equip_bag))
	assert(data.get_npc_dialogue("biaotou").title == "镖头_日常交谈")
	assert(not data.is_npc_dialogue_locked("机关人", "通过试炼"))
	for id in party_order:
		assert(data.party_db[id] == data.character_roster[id])
	print("SAVE V4 JSON ROUNDTRIP + FACADE: PASS (no disk writes)")
	quit()
