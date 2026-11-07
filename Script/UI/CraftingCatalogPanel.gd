extends Panel
signal recipe_selected(output_id: String)
const Catalog = preload("res://Script/Data/CraftingCatalog.gd")
const Recipes = preload("res://Script/UI/TalismanRecipes.gd")
var entries: Array[Dictionary] = []
var selected_id := ""

func _ready() -> void:
	$Category.item_selected.connect(func(_index): refresh())
	$List.item_selected.connect(_select)
	$Details.pressed.connect(func():
		if not selected_id.is_empty(): recipe_selected.emit(selected_id)
	)
	$List.item_activated.connect(func(index):
		_select(index)
		recipe_selected.emit(selected_id)
	)
	refresh()

func refresh() -> void:
	var category: String = $Category.get_item_text($Category.selected)
	entries = Catalog.unlocked_recipes(category)
	$List.clear()
	var selected := -1
	for recipe in entries:
		var data = GameData.item_db.get(recipe.output) as ItemData
		var icon: Texture2D = preload("res://Script/Assets/AssetLoader.gd").tcp_texture(data.icon_path) if data and data.icon_path.ends_with(".tcp") else null
		$List.add_item("%s　可做%d份" % [recipe.output_name, Recipes.max_batches(recipe)], icon)
		if recipe.output == selected_id: selected = entries.find(recipe)
	$Count.text = "已解锁 %d 项" % entries.size()
	$Empty.visible = entries.is_empty()
	$Details.disabled = entries.is_empty()
	if entries.is_empty():
		selected_id = ""
		$Info.text = ""
	else:
		selected = maxi(0, selected)
		$List.select(selected)
		_select(selected)

func _select(index: int) -> void:
	if index < 0 or index >= entries.size(): return
	var recipe := entries[index]
	selected_id = recipe.output
	var lines: Array[String] = ["%s · %s" % [recipe.output_name, recipe.category]]
	for id in recipe.materials:
		var need := int(recipe.materials[id])
		var have := Recipes.owned(id)
		lines.append("%s %d/%d%s" % [MaterialDB.MATERIAL_DB[id].name, have, need, "（不足）" if have < need else ""])
	lines.append("每份3张 · %d金币" % Recipes.fee(recipe))
	$Info.text = "\n".join(lines)
