extends Control
signal crafted(output_id: String)
const Catalog = preload("res://Script/Data/CraftingCatalog.gd")
var recipes: Array[Dictionary] = []

func _ready() -> void:
	set_meta("keyboard_modal", true)
	set_meta("keyboard_cancel", queue_free)
	recipes = Catalog.unlocked_recipes()
	for recipe in recipes:
		$Panel/Recipe.add_item(recipe.output_name)
	$Panel/Recipe.item_selected.connect(func(_i): refresh())
	$Panel/Quantity.value_changed.connect(func(_n): refresh())
	$Panel/Maximum.pressed.connect(func(): $Panel/Quantity.value = maxi(1, max_batches(selected_recipe())))
	$Panel/Make.pressed.connect(make_selected)
	$Panel/Close.pressed.connect(queue_free)
	refresh()

func selected_recipe() -> Dictionary:
	return recipes[$Panel/Recipe.selected] if $Panel/Recipe.selected >= 0 and $Panel/Recipe.selected < recipes.size() else {}

func select_output(output_id: String) -> void:
	for index in recipes.size():
		if recipes[index].output == output_id:
			$Panel/Recipe.select(index)
			refresh()
			return

static func owned(id: String) -> int:
	if GameData.debug_cheats_enabled: return GameData.DEBUG_GOLD
	var count := 0
	for material in GameData.material_bag:
		if material.get("name", "") == MaterialDB.MATERIAL_DB[id].name: count += 1
	return count

static func fee(recipe: Dictionary) -> int:
	var total := 0
	for id in recipe.materials:
		total += int(MaterialDB.MATERIAL_DB[id].get("price", 100)) * int(recipe.materials[id])
	return maxi(1, total / 4)

static func max_batches(recipe: Dictionary) -> int:
	if recipe.is_empty() or not Catalog.is_unlocked(recipe): return 0
	var data = GameData.item_db.get(recipe.output) as ItemData
	if data == null: return 0
	var maximum := maxi(0, (data.max_stack - GameData.player_inventory.get_count(recipe.output)) / 3)
	maximum = mini(maximum, GameData.player_gold / fee(recipe))
	for id in recipe.materials: maximum = mini(maximum, owned(id) / int(recipe.materials[id]))
	return maximum

func refresh() -> void:
	var recipe := selected_recipe()
	if recipe.is_empty():
		$Panel/Description.text = "暂无已解锁配方"
		$Panel/Materials.text = ""
		$Panel/Summary.text = ""
		$Panel/Make.disabled = true
		$Panel/Maximum.disabled = true
		return
	var batches := int($Panel/Quantity.value)
	var lines: Array[String] = []
	for id in recipe.materials:
		var need := int(recipe.materials[id]) * batches
		var have := owned(id)
		lines.append("%s：需要 %d　持有 %d　缺少 %d" % [MaterialDB.MATERIAL_DB[id].name, need, have, maxi(0, need - have)])
	$Panel/Materials.text = "\n".join(lines)
	var data = GameData.item_db.get(recipe.output) as ItemData
	$Panel/Description.text = data.description if data else ""
	$Panel/Summary.text = "每份产出3张，本次产出 %d 张\n费用 %d 金币　持有 %d 金币\n成品持有 %d / %d　当前最多制作 %d 份" % [batches * 3, fee(recipe) * batches, GameData.player_gold, GameData.player_inventory.get_count(recipe.output), data.max_stack if data else 0, max_batches(recipe)]
	$Panel/Make.disabled = batches > max_batches(recipe)
	$Panel/Maximum.disabled = max_batches(recipe) == 0

func make_selected() -> void:
	var recipe := selected_recipe()
	var batches := int($Panel/Quantity.value)
	# 提交前重新核对，数量、材料、金币和成品空间一起结算。
	if batches < 1 or batches > max_batches(recipe):
		refresh()
		return
	for id in recipe.materials:
		for _i in int(recipe.materials[id]) * batches:
			if GameData.debug_cheats_enabled: break
			var index := GameData.material_bag.find_custom(func(mat): return mat.get("name", "") == MaterialDB.MATERIAL_DB[id].name)
			GameData.material_bag.remove_at(index)
	GameData.player_gold -= fee(recipe) * batches
	GameData.player_inventory.add_item(GameData.item_db[recipe.output], batches * 3)
	$Panel/Result.text = "已制作 %s ×%d，已放入行囊" % [recipe.output_name, batches * 3]
	crafted.emit(recipe.output)
	refresh()
