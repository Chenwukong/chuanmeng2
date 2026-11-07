extends RefCounted
## 配方解锁复用已有进度存档；旧版可用的基础配方保持可用。
static func unlock_flag(output_id: String) -> String:
	return "打造/配方/%s/已解锁" % output_id

static func is_unlocked(recipe: Dictionary) -> bool:
	return bool(GameData.game_flags.get(unlock_flag(recipe.output), recipe.get("unlocked_by_default", false)))

static func unlocked_recipes(category: String = "全部") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe in MaterialDB.TALISMAN_RECIPES:
		if is_unlocked(recipe) and (category == "全部" or recipe.get("category", "其他") == category): result.append(recipe)
	return result

static func unlock_recipe(output_id: String) -> bool:
	for recipe in MaterialDB.TALISMAN_RECIPES:
		if recipe.output == output_id:
			GameData.complete_story_event(unlock_flag(output_id))
			return true
	return false
