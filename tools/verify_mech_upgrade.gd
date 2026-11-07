extends SceneTree
## 独立进程验证强化扣费，不读写玩家存档。

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	current_scene = host
	var data = root.get_node("GameData")
	data._init_mech_pets()
	data.material_bag.clear()
	data.material_bag.append(data.get_material("black_ore"))
	data.player_gold = 8000
	var popup = load("res://scenes/UI/Mech/MechPopup.tscn").instantiate()
	host.add_child(popup)
	popup.open()
	await process_frame
	check(popup._selected == "机关兽", "Opening selects the first owned mech")
	check(popup.btn_upgrade.disabled, "Missing gears disables upgrading")
	var original: Dictionary = data.mech_db["机关兽"].duplicate(true)
	popup._on_upgrade()
	check(data.mech_db["机关兽"] == original and data.player_gold == 8000, "Missing gears changes neither stats nor gold")
	for i in 5: data.material_bag.append(data.get_material("gear"))
	popup._refresh()
	check(popup._gear_count() == 5 and not popup.btn_upgrade.disabled, "Gear material is recognised")
	var plan: Dictionary = popup._upgrade_plan(original)
	check(plan.gears == 1 and plan.gold == 800, "Initial costs are one gear and 800 gold")
	popup._on_upgrade()
	var upgraded: Dictionary = data.mech_db["机关兽"]
	check(upgraded.level == 2 and upgraded.atk == 34 and upgraded.def_ == 23 and upgraded.spd == 9, "Successful upgrade applies the previewed stat gains")
	check(popup._gear_count() == 4 and data.player_gold == 7200, "Successful upgrade charges each cost exactly once")
	check(data.material_bag[0].name == "黑曜石", "Unrelated materials are preserved")
	data.player_gold = 0
	var before_failure: Dictionary = upgraded.duplicate(true)
	popup._on_upgrade()
	check(upgraded == before_failure and popup._gear_count() == 4, "Missing gold does not consume gears or alter the mech")
	check(not popup._consume_gears(99) and popup._gear_count() == 4, "An impossible material deduction is atomic")
	var high_level := original.duplicate(true)
	high_level.level = 11
	check(popup._upgrade_plan(high_level).gears == 2, "Gear demand increases after ten levels")
	popup._keyboard_detail("机关鸟")
	check(popup._selected == "机关鸟" and popup.detail_name.text == "机关鸟", "Selecting the other mech refreshes its details")
	data.mech_team.erase("机关鸟")
	var locked: Dictionary = data.mech_db["机关鸟"].duplicate(true)
	data.player_gold = 8000
	popup._on_upgrade()
	check(data.mech_db["机关鸟"] == locked and popup._gear_count() == 4, "An unowned mech cannot be upgraded")
	data.mech_team.append("机关鸟")
	popup._keyboard_detail("机关兽")
	if not OS.get_environment("MECH_PREVIEW").is_empty():
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("MECH_PREVIEW"))
	var first_slot = popup.mech_grid.get_child(0)
	for i in 8:
		var pid := "extra_mech_%d" % i
		var extra := original.duplicate(true)
		extra.name = "扩展机关%d" % i
		extra.was_base_path = ""
		extra.erase("description")
		data.mech_db[pid] = extra
		data.mech_team.append(pid)
	popup._refresh()
	check(popup.mech_grid.get_child_count() == 10, "All ten owned mechs appear without fixed slot limits")
	check(popup.mech_grid.get_child(0) == first_slot, "Refreshing retains existing list nodes and their focus")
	var last_slot = popup.mech_grid.get_child(9)
	last_slot.pressed.emit()
	check(popup._selected == "extra_mech_7" and popup.detail_name.text == "扩展机关7", "New mech entries select their own data")
	check(popup.get_node("Panel/Detail/Role").text == "机关伙伴 · 可使用齿轮强化", "New types use a generic description instead of being classified as birds")
	last_slot.grab_focus()
	await process_frame
	await process_frame
	check(popup.get_node("Panel/MechScroll").scroll_vertical > 0, "Keyboard focus scrolls to entries beyond the visible list")
	data.mech_db.erase("extra_mech_7")
	popup._refresh()
	check(popup.mech_grid.get_child_count() == 9 and popup._selected == "机关兽", "Removing the selected mech restores a valid selection")
	data.mech_team.clear()
	popup._refresh()
	check(popup.mech_grid.get_child_count() == 0 and not popup.get_node("Panel/Detail").visible, "Empty ownership clears the list and stale details")
	popup._on_close()
	check(not popup.visible, "Closing returns input to the parent menu")
	await create_timer(0.8).timeout
	host.queue_free()
	await process_frame
	print("MECH TESTS: ", "PASS" if failures.is_empty() else "FAIL: %d" % failures.size())
	quit(0 if failures.is_empty() else 1)
