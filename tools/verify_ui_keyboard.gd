extends SceneTree
## 无存档写入的键盘导航回归检查：godot --headless --path . --script tools/verify_ui_keyboard.gd

class Host extends Node:
	var _keyboard_nav: Node
	var closed := 0
	func _close_top_popup() -> void:
		closed += 1
	func _activate_menu(_name: String) -> void:
		pass

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for path in ["UI/UIKeyboardNavigator", "World/MainScene", "UI/EquipPage", "UI/PetPopup", "UI/MechPopup", "UI/TitleScreen", "UI/ShopPopup", "UI/BuildPopup", "UI/Talents/talent_node", "UI/Talents/talent_tree", "World/map_panel", "World/map_container", "World/minimap_overlay"]:
		var script = load("res://Script/%s.gd" % path)
		check(script != null and script.can_instantiate(), "Script failed: " + path)
	var host := Host.new()
	root.add_child(host)
	current_scene = host
	var scene_fixture = load("res://scenes/MainScene.tscn").instantiate()
	var nav = scene_fixture.get_node("UI/UIKeyboardNavigator")
	nav.get_parent().remove_child(nav)
	scene_fixture.free()
	host._keyboard_nav = nav
	nav.host = host
	host.add_child(nav)
	var panel := Panel.new()
	panel.size = Vector2(600, 500)
	host.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 2
	panel.add_child(grid)
	var counter := [0]
	for i in 4:
		var button := Button.new()
		button.text = str(i)
		button.custom_minimum_size = Vector2(80, 40)
		button.pressed.connect(func(): counter[0] += 1)
		grid.add_child(button)
	var disabled := Button.new()
	disabled.disabled = true
	panel.add_child(disabled)
	var custom := Panel.new()
	custom.position = Vector2(300, 150)
	custom.size = Vector2(80, 40)
	custom.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed: counter[0] += 10
	)
	panel.add_child(custom)
	var toggle := CheckBox.new()
	toggle.position = Vector2(300, 220)
	toggle.size = Vector2(80, 40)
	panel.add_child(toggle)
	nav.push(panel)
	await process_frame
	await process_frame
	nav._refresh_scope()
	check(nav.items.size() == 6, "Candidates must skip disabled controls")
	nav.select(grid.get_child(0))
	nav._move(Vector2.RIGHT)
	check(nav.selected == grid.get_child(1), "Grid right navigation")
	nav._move(Vector2.DOWN)
	check(nav.selected == grid.get_child(3), "Grid down navigation")
	nav._move(Vector2.RIGHT)
	check(nav.selected == grid.get_child(3), "Grid edge stays in its region instead of jumping diagonally")
	nav._activate()
	check(counter[0] == 1, "Button activates exactly once")
	nav.select(custom)
	nav._activate()
	check(counter[0] == 11, "Custom slot activates through existing callback")
	nav.select(grid.get_child(0))
	var accept := InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.pressed = true
	Input.parse_input_event(accept)
	await process_frame
	check(counter[0] == 12, "Dispatched Enter activates once without native focus duplication")
	counter[0] = 11
	# 场景树顺序故意与画面相反，Tab 仍按从上到下、从左到右循环。
	panel.move_child(toggle, 0)
	nav._refresh_scope()
	nav.select(grid.get_child(0))
	nav._tab(false)
	check(nav.selected == custom, "Tab follows visual region order, independent of scene node order")
	nav._tab(false)
	check(nav.selected == toggle, "Tab advances to the next visual region")
	nav._tab(true)
	check(nav.selected == custom, "Shift+Tab reverses the exact Tab order")
	nav.select(toggle)
	nav._activate()
	check(toggle.button_pressed, "Checkbox updates toggle state")
	toggle.disabled = true
	toggle.set_meta("keyboard_activate", func(): counter[0] += 7)
	nav._activate()
	check(counter[0] == 18, "Disabled inspectable controls retain custom actions such as talent refunds")
	counter[0] = 11
	toggle.disabled = false
	toggle.remove_meta("keyboard_activate")
	var modal := Panel.new()
	modal.size = Vector2(200, 100)
	modal.set_meta("keyboard_modal", true)
	panel.add_child(modal)
	var cancel := Button.new()
	cancel.text = "取消"
	modal.add_child(cancel)
	nav._refresh_scope()
	check(nav.scope == modal and nav.items.size() == 1, "Modal traps navigation")
	nav._cancel()
	await process_frame
	nav._refresh_scope()
	check(nav.scope == panel and nav.selected == toggle, "Esc restores previous scope and selection")
	# Rebuilt slots retain their logical position even when the original node is freed.
	nav.select(custom)
	var old_index: int = nav.items.find(custom)
	custom.queue_free()
	await process_frame
	nav._refresh_scope()
	check(is_instance_valid(nav.selected) and nav.items.find(nav.selected) == mini(old_index, nav.items.size() - 1), "Rebuild restores a valid neighbouring selection")
	panel.queue_free()
	await process_frame
	var data = root.get_node("GameData")
	data.add_party_by_name("游霄云")
	for i in 3:
		var pet = load("res://Script/Data/Models/PetData.gd").new()
		pet.pet_id = "keyboard_test_%d" % i
		pet.character_name = "测试宠物%d" % i
		data.pet_db[pet.pet_id] = pet
	data.pet_team.clear()
	for path in ["scenes/EquipPage", "scenes/UI/Pets/PetPopup", "scenes/UI/StatusPopup", "scenes/UI/SettingPopup", "scenes/UI/Save/SavePopup", "scenes/UI/ShopPopup", "scenes/UI/build_popup", "scenes/UI/TalentTree", "scenes/UI/AchievementPopup", "scenes/UI/BountyPopup", "scenes/UI/hintPopup", "scenes/UI/map"]:
		var popup = load("res://%s.tscn" % path).instantiate()
		host.add_child(popup)
		if path == "scenes/EquipPage":
			popup.set_member_id(str(data.party_order[0]))
			popup.set_equip_bag(data.equip_bag)
			popup.set_inventory(data.player_inventory._slots)
			popup.full_refresh()
		if popup.has_method("open") and path != "scenes/UI/Pets/PetPopup": popup.open()
		if path == "scenes/UI/StatusPopup": popup._setup()
		nav.push(popup)
		await process_frame
		await process_frame
		nav._refresh_scope()
		check(not nav.items.is_empty(), "No keyboard controls: " + path)
		var candidates: Array = nav.items.duplicate()
		for item in candidates:
			if is_instance_valid(item): nav.select(item)
		if path == "scenes/EquipPage":
			nav.select(popup._item_slots[0])
			nav._tab(false)
			check(nav._region(nav.selected) == "tabs", "Backpack Tab follows the explicit region sequence")
			nav._tab(true)
			check(nav.selected == popup._item_slots[0], "Backpack reverse Tab restores the selected item")
			nav._activate()
			check(nav._actions.item_count > 1, "Equipment action menu opens")
			var real_index: int = popup._visible_equip_indices()[0]
			var expected: Dictionary = data.equip_bag[real_index]
			var slot_key: String = load("res://Script/Data/Models/EquipData.gd").slot_key(expected.get("slot", -1))
			nav._run_action(0)
			check(popup.equipment.get(slot_key, {}).get("display_name", "") == expected.get("display_name", ""), "Keyboard action equips the selected item")
			nav._actions.hide()
			var button = popup.get_node("LeftArea/" + str(popup.SLOT_NODE_MAP.find_key(slot_key)) + "/ClickBtn")
			nav.select(button)
			nav._activate()
			nav._run_action(0)
			nav._actions.hide()
			check(popup.equipment.get(slot_key, {}).is_empty(), "Keyboard action unequips the selected item")
		if path == "scenes/UI/Pets/PetPopup":
			check(not popup._selected_pid.is_empty(), "Keyboard focus displays pet details")
			var first_slot = popup.pet_grid.get_child(0)
			nav.select(first_slot)
			nav._move(Vector2.RIGHT)
			check(nav.selected == popup.pet_grid.get_child(1), "Pet right navigation supports named regions")
			nav._move(Vector2.LEFT)
			nav._move(Vector2.LEFT)
			check(nav.selected == first_slot, "Pet left edge handles mixed region types without an operator error")
			var pet_id: String = popup._selected_pid
			popup._on_deploy()
			check(pet_id in data.pet_team, "Pet deployment preserves the selected pet")
			nav._click(popup.deploy_grid.get_child(0))
			check(pet_id not in data.pet_team, "Deployed slot recalls the pet")
			check(popup.pet_grid.get_child(0) == first_slot, "Pet refresh preserves scene-defined slots")
			check(popup.deploy_grid.get_child_count() == 6 and popup.pet_grid.get_child_count() == 8, "Fixed pet slot counts remain stable")
			popup._show_book_select_popup([{"name": "测试技能书", "count": 1, "desc": "测试说明", "book_id": "test", "item_id": "test"}], data.pet_db[pet_id])
			nav._refresh_scope()
			check(nav.scope.name == "BookSelectPopup", "Book selection traps focus")
			nav._cancel()
			nav._refresh_scope()
			check(nav.scope == popup, "Book selection returns without consuming an item")
			popup._show_confirm_popup("测试确认", func(): counter[0] += 100)
			nav._refresh_scope()
			check(nav.scope.name == "ConfirmPopup", "Pet confirmation traps focus")
			nav._cancel()
			await process_frame
			nav._refresh_scope()
			check(nav.scope == popup and counter[0] == 11, "Esc cancels pet confirmation without executing it")
			popup._open_mech_upgrade()
			nav._refresh_scope()
			check(nav.scope == popup._mech_popup, "Mech submenu traps focus")
			nav._cancel()
			nav._refresh_scope()
			check(nav.scope == popup, "Mech submenu returns to pet panel")
		if path == "scenes/UI/BountyPopup":
			popup.confirm_dialog.show()
			nav._refresh_scope()
			check(nav.scope == popup.confirm_dialog, "Bounty confirmation traps focus")
			nav._cancel()
			nav._refresh_scope()
			check(nav.scope == popup, "Bounty confirmation returns to bounty list")
		if path == "scenes/UI/ShopPopup":
			popup._on_sell_item(0)
			nav._refresh_scope()
			check(nav.scope == popup._sell_panel, "Sale confirmation traps focus")
			nav._cancel()
			await process_frame
			nav._refresh_scope()
			check(nav.scope == popup and popup._sell_panel == null, "Sale cancellation returns to shop")
		if path == "scenes/UI/build_popup":
			popup.set_materials([
				{"slot": 0, "name": "基础符纸", "display_name": "基础符纸", "base": {"dmg": 10, "luck": 2}, "price": 120},
				{"slot": 0, "name": "第二件装备", "display_name": "第二件装备", "base": {"atk": 20}}
			])
			var source = popup.equip_slots[0]
			var next_source = popup.equip_slots[1]
			nav.select(source)
			check(popup._tooltip_label.text.contains("伤害: +10") and not popup._tooltip_label.text.contains("dmg"), "Crafting translates damage stat keys")
			check(popup._tooltip_label.text.contains("气运: +2"), "Crafting translates luck stat keys")
			next_source.mouse_entered.emit()
			nav.select(next_source, false)
			popup._hide_tooltip(source)
			check(popup._tooltip_label.visible and popup._tooltip_label.text.contains("第二件装备"), "Late exit and pointer focus sync cannot hide the new tooltip")
			for slot in popup.equip_slots + popup.mat_slots + popup.rslots:
				check(slot.get_node("Icon").mouse_filter == Control.MOUSE_FILTER_IGNORE, "Crafting icons do not intercept hover events")
			popup._equip_page = 1
			popup._refresh()
			await process_frame
			check(not popup._tooltip_label.visible, "Changing to an empty page clears stale tooltips")
			popup._show_result_popup({"name": "测试装备", "level": 1})
			nav._refresh_scope()
			check(nav.scope != popup, "Forge result traps focus")
			nav._cancel()
			await process_frame
			nav._refresh_scope()
			check(nav.scope == popup, "Forge result returns to forge panel")
		if path == "scenes/UI/map":
			var container = popup.get_node("MapContainer")
			nav.select(container)
			nav._tab(false)
			check(nav.selected != container, "Tab leaves map panning for map buttons")
		if popup.has_method("keyboard_page"):
			popup.keyboard_page(1)
			popup.keyboard_page(-1)
		print("PANEL OK: ", path, " (", candidates.size(), " controls)")
		popup.queue_free()
		await process_frame
	root.get_node("GameData").in_battle = true
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	nav._input(key)
	check(counter[0] == 11, "Battle input is left untouched")
	root.get_node("GameData").in_battle = false
	host.queue_free()
	await process_frame
	# 使用真实主场景验证注册与关闭；移除地图，只测试 UI，不启动世界事件。
	var main = load("res://scenes/MainScene.tscn").instantiate()
	for child in main.get_children():
		if child.has_method("set_day_tint"):
			child.free()
	root.add_child(main)
	current_scene = main
	await process_frame
	var main_nav = main._keyboard_nav
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await process_frame
	check(main_nav.menu_open, "Tab enters the actual HUD keyboard menu")
	var visual_menu: Array = ["打造", "道具", "宠物", "队伍", "存档", "悬赏", "剧情", "人物", "地图", "天赋", "系统", "成就"]
	check(main_nav._menu_available() == visual_menu, "HUD order matches the buttons from left to right")
	for i in visual_menu.size():
		check(main_nav._menu_available()[main_nav.menu_index] == visual_menu[i], "HUD Tab position %d" % i)
		main_nav._handle_menu(tab)
	check(main_nav.menu_index == 0, "HUD Tab completes one stable cycle")
	var repeat_tab := tab.duplicate() as InputEventKey
	repeat_tab.echo = true
	main_nav._handle_menu(repeat_tab)
	check(main_nav.menu_index == 0, "Holding Tab does not skip menu entries")
	for entry in ["人物", "道具", "宠物", "天赋", "打造", "队伍", "悬赏", "剧情", "地图", "系统", "存档", "成就"]:
		main._activate_menu(entry)
		await process_frame
		await process_frame
		main_nav._refresh_scope()
		check(main_nav.scope != null, "HUD registered panel: " + entry)
		if entry == "道具" and not OS.get_environment("UI_KEYBOARD_PREVIEW").is_empty():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("UI_KEYBOARD_PREVIEW"))
		main_nav._cancel()
		await process_frame
		check(not main._has_any_popup_open(), "HUD released panel: " + entry)
	main.open_shop("", 10)
	await process_frame
	main_nav._refresh_scope()
	check(main_nav.scope == main._shop_popup, "NPC shop is registered")
	main_nav._cancel()
	await process_frame
	check(not main._has_any_popup_open(), "NPC shop releases input blocking")
	print("KEYBOARD TESTS: ", "PASS" if failures.is_empty() else "FAIL: %d" % failures.size())
	main.queue_free()
	await process_frame
	# 让挂在 root 下的关闭音效正常播放完毕并自行释放。
	await create_timer(1.0).timeout
	quit(0 if failures.is_empty() else 1)
