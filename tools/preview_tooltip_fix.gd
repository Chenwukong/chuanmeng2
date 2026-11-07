extends SceneTree
func _initialize():
	_run.call_deferred()
func _run():
	root.size = Vector2i(1100, 800)
	var page = load("res://scenes/EquipPage.tscn").instantiate()
	root.add_child(page)
	await process_frame
	var eq = {"display_name":"铁齿剑", "desc":"铁制的短剑，边缘带齿", "quality":0, "base":{"atk":20}}
	var text = "[color=#a53242]不可穿戴：游霄云 只能装备符咒武器，无法使用「剑」[/color]\n" + page._equipment_tooltip(eq, {}, false) + "\n\n[color=#526985]左键选中  双击装备[/color]"
	page._show_tooltip(text, Vector2(500,200), "", false, eq)
	for i in 6: await process_frame
	var tip = page.get_node("TooltipPopup")
	assert(tip.get_theme_stylebox("normal").content_margin_top >= tip.get_node("IconFrame").get_rect().end.y)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Godot/传梦之路2/artifacts/equipment-layout-fixed.png")
	print("TOOLTIP LAYOUT PASS ", tip.size)
	quit()
