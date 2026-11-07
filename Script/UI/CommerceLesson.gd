extends PanelContainer
const SHOP_FLAG := "教学/商店/已完成"
const CRAFT_FLAG := "教学/制符/已完成"
@export var shop_heading := ""
@export_multiline var shop_explanation := ""
@export var craft_heading := ""
@export_multiline var craft_explanation := ""
@export var progress_template := "%s"
@export var success_text := ""
var lesson_mode := ""

static func example_requirements() -> Dictionary:
	for recipe in MaterialDB.TALISMAN_RECIPES:
		if recipe.output == "talisman_fire": return recipe.materials
	return {}

static func has_example_materials() -> bool:
	var counts := count_materials(GameData.material_bag)
	for id in example_requirements():
		if counts.get(id, 0) < example_requirements()[id]: return false
	return true

static func count_materials(materials: Array) -> Dictionary:
	var counts := {}
	for material in materials:
		for id in example_requirements():
			if material.get("name", "") == MaterialDB.MATERIAL_DB[id].name:
				counts[id] = counts.get(id, 0) + 1
	return counts

func start_lesson(mode: String) -> void:
	lesson_mode = mode
	show()
	$Body/Heading.text = shop_heading if mode == "shop" else craft_heading
	$Body/Explanation.text = shop_explanation if mode == "shop" else craft_explanation

func update_materials(materials: Array) -> void:
	if not visible: return
	var counts := count_materials(materials)
	var parts: Array[String] = []
	for id in example_requirements():
		parts.append("%s %d/%d" % [MaterialDB.MATERIAL_DB[id].name, counts.get(id, 0), example_requirements()[id]])
	$Body/Progress.text = progress_template % "　".join(parts)

func show_success() -> void:
	$Body/Progress.text = success_text
