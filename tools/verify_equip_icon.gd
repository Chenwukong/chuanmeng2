extends SceneTree


func _init() -> void:
	var page: EquipPage = load("res://scenes/EquipPage.tscn").instantiate()
	root.add_child(page)
	await process_frame

	var first_mid := ""
	for mid in GameData.party_order:
		if GameData.party_db.has(mid):
			first_mid = mid
			break
	if first_mid.is_empty():
		for mid in GameData.party_db:
			first_mid = mid
			break
	page.set_member_id(first_mid)
	page.set_equip_bag(GameData.equip_bag)
	page.set_inventory(GameData.player_inventory._slots)
	page.full_refresh()
	await process_frame

	var icon := page.get_node("RightArea/ItemSlot_00/Icon") as TextureRect
	print("[verify_equip_icon] texture=", icon.texture != null, " size=", icon.texture.get_size() if icon.texture else Vector2.ZERO)
	quit()
