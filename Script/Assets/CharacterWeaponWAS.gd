extends RefCounted
## 小二真身的“饰品”实际是带原始锚点的手持武器动作层。
static func directory(was_base: String) -> String:
	var base := was_base.trim_suffix("/")
	if base == "res://WAS/小二真身":
		return base.path_join("饰品")
	return base + "武器"

static func animation_path(weapon_dir: String, action: String) -> String:
	var suffix := "_2" if weapon_dir == "res://WAS/小二真身/饰品" else ""
	return weapon_dir.path_join(action + suffix + ".was")
