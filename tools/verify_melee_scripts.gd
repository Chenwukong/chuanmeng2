extends SceneTree
func _initialize():
	for path in ["res://Script/Battle/BattleManager.gd", "res://Script/UI/Battle/battleUI.gd"]:
		var script = load(path)
		assert(script != null and script.can_instantiate(), path)
	print("MELEE SCRIPTS: PASS")
	quit()
