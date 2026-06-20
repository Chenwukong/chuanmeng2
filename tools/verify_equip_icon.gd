extends SceneTree


func _init() -> void:
	var page: EquipPage = load("res://scenes/EquipPage.tscn").instantiate()
	root.add_child(page)
	await process_frame

	page.set_equipment(GameData.player_equipment)
	page.set_equip_bag(GameData.equip_bag)
	page.set_inventory(GameData.player_inventory._slots)
	page.full_refresh()
	await process_frame

	var icon := page.get_node("RightArea/ItemSlot_00/Icon") as TextureRect
	print("[verify_equip_icon] texture=", icon.texture != null, " size=", icon.texture.get_size() if icon.texture else Vector2.ZERO)
	quit()
