extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	root.size = Vector2i(1100, 740)
	var data = root.get_node("GameData")
	data.talent_ranks = {"main_shop_discount": 2, "main_exp_boost": 2, "main_gold_boost": 1, "main_forge": 1, "summon_mech_cost": 2}
	data.talent_points = 20
	var tree = load("res://scenes/UI/TalentTree.tscn").instantiate()
	root.add_child(tree)
	current_scene = tree
	var support = tree.get_node("Pages/Page_Support")
	for name in ["与人为善", "天赋异禀", "财迷心窍", "锻造大师", "机甲精算"]:
		var talent = support.get_node(name)
		assert(talent.rank == data.get_talent_rank(talent.talent_id))
		assert(talent.has_node("Typography"))
		assert(not tree.has_node("Pages/Page_Main/" + name))
		assert(not tree.has_node("Pages/Page_Summon/" + name))
		for req in talent.requirements:
			assert(talent._resolve_requirement_talent(req.talent_path) != null)
	assert(not support.has_node("打造"))
	var shop = support.get_node("与人为善")
	assert(shop.requirements.is_empty())
	var previous: int = data.talent_points
	tree._try_upgrade_talent(shop)
	assert(shop.rank == 3 and data.talent_points == previous - 1)
	tree.show_page("Page_Support")
	await create_timer(0.4).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/support_economy_preview.png")
	print("SUPPORT ECONOMY PASS: five economy talents, saved ranks, removed crafting unlock talent, shop has no deleted prerequisite, scene typography, purchase cost")
	quit()