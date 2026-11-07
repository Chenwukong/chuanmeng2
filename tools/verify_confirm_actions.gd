extends SceneTree
func _initialize() -> void:
	call_deferred("_verify")
func _verify() -> void:
	var data = root.get_node("GameData")
	data.add_party_by_name("游霄云")
	var mid = data.party_db.keys()[0]
	var hero = data.party_db[mid]
	hero.alloc_atk = 5
	hero.attack += 5
	data.player_inventory.add_item(data.item_db["item_xisuidan"], 2)
	var count = data.player_inventory.get_count("item_xisuidan")
	var popup = load("res://scenes/UI/StatusPopup.tscn").instantiate()
	root.add_child(popup)
	popup._setup()
	popup._use_xisuidan()
	assert(popup.get_node("ConfirmPopup").visible)
	assert(hero.alloc_atk == 5)
	assert(data.player_inventory.get_count("item_xisuidan") == count)
	popup._cancel_xisuidan()
	assert(hero.alloc_atk == 5)
	popup._use_xisuidan()
	popup._confirm_xisuidan()
	assert(hero.alloc_atk == 0)
	assert(data.player_inventory.get_count("item_xisuidan") == count - 1)
	popup._confirm_xisuidan()
	assert(data.player_inventory.get_count("item_xisuidan") == count - 1)
	var pets = load("res://scenes/UI/Pets/PetPopup.tscn").instantiate()
	root.add_child(pets)
	var pet = load("res://Script/Data/Models/PetData.gd").new()
	pet.pet_id = "confirm_test"
	pet.character_name = "确认测试"
	data.pet_db[pet.pet_id] = pet
	pets._selected_pid = pet.pet_id
	pets._on_release()
	assert(data.pet_db.has(pet.pet_id))
	pets._cancel_confirm()
	assert(data.pet_db.has(pet.pet_id))
	pets._on_release()
	pets._accept_confirm()
	assert(not data.pet_db.has(pet.pet_id))
	print("CONFIRM_ACTIONS_PASS")
	quit()


