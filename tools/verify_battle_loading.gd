extends SceneTree
## 独立进程检查加载、资源复用和初始化耗时，不运行回合、不写入存档。

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var host := Node2D.new()
	root.add_child(host)
	current_scene = host
	var ui := CanvasLayer.new()
	ui.name = "UI"
	host.add_child(ui)
	var log := RichTextLabel.new()
	log.name = "BattleLog"
	ui.add_child(log)
	var data = root.get_node("GameData")
	data.add_party_by_name("游霄云")
	data.add_party_by_name("叮咚")
	data.set_meta("pending_party", ["youxiaoyun", "dingdong"])
	data.set_meta("pending_enemies", ["超级赤焰兽", "超级赤焰兽", "超级赤焰兽", "超级赤焰兽", "超级赤焰兽", "超级赤焰兽"])
	var assets = load("res://Script/Assets/BattleAssetLoader.gd")
	var reader_script = load("res://Script/Assets/WASReader.gd")
	var path := "res://WAS/超级赤焰兽/待机.was"
	var first = reader_script.shared_from_file(path)
	var second = reader_script.shared_from_file(path)
	check(first != null and first == second, "Identical WAS files share parsed data")
	check(first.decode_frame(0, 0).texture == second.decode_frame(0, 0).texture, "Repeated units share decoded frame textures")
	var weak: WeakRef = weakref(first)
	first = null
	second = null
	check(weak.get_ref() == null, "Unused WAS readers and frame caches are not pinned globally")
	var started := Time.get_ticks_usec()
	assets.request()
	var requested := Time.get_ticks_usec()
	var packed: PackedScene = await assets.scene_ready(self)
	check(packed != null and packed.can_instantiate(), "Threaded battle scene load completes")
	print("BATTLE ASSET REQUEST ms=", (requested - started) / 1000.0, " prepare_ms=", (Time.get_ticks_usec() - started) / 1000.0)
	for effect in ["debuff", "buff", "animation"]:
		var effect_path := "res://scenes/Battle/%s.tscn" % effect
		check(assets.cached_scene(effect_path) == assets.cached_scene(effect_path), "Effect templates are reused: " + effect)
	for pass_id in 2:
		var begin := Time.get_ticks_usec()
		var scene = packed.instantiate()
		var instance_done := Time.get_ticks_usec()
		scene.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(scene)
		print("BATTLE ENTRY ", pass_id, " instantiate_ms=", (instance_done - begin) / 1000.0, " ready_ms=", (Time.get_ticks_usec() - instance_done) / 1000.0)
		check(scene.battle_manager.party.size() == 2, "Party composition is preserved")
		check(scene.battle_manager.enemies.size() == 6, "Enemy composition is preserved")
		for character in scene.battle_manager.party + scene.battle_manager.enemies:
			var actor = character.get_parent()
			check(actor.has_node("Animation") and actor.has_node("BuffSprite") and actor.has_node("DebuffSprite"), "Each unit retains independent effect nodes")
		await process_frame
		for player in scene.find_children("*", "AudioStreamPlayer", true, false): player.stop()
		scene.queue_free()
		await process_frame
		var again: PackedScene = await assets.scene_ready(self)
		check(again == packed, "Following battles reuse the prepared scene")
	check(load("res://Script/World/MapRoot.gd").can_instantiate(), "Map entry integration compiles")
	await create_timer(0.2).timeout
	host.queue_free()
	await process_frame
	print("BATTLE LOADING TESTS: ", "PASS" if failures.is_empty() else "FAIL: %d" % failures.size())
	quit(0 if failures.is_empty() else 1)
