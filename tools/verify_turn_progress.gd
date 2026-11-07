extends SceneTree

# 用实际战斗场景验证每一帧的可见头像矩形，包括开战、超车、回合开始和退场。
# --fixed-fps 60 --script res://tools/verify_turn_progress.gd [-- --capture=绝对路径]
var ui
var manager
var hero
var companion
var failure := ""
var frame_directory := ""

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="): frame_directory = arg.trim_prefix("--frames=")
	var game = root.get_node("GameData")
	game.add_party_by_name("游霄云")
	game.add_party_by_name("叮咚")
	game.party_order.assign(["youxiaoyun", "dingdong"])
	game.pet_team.clear()
	game.set_meta("pending_party", game.party_order.duplicate())
	var opponents: Array = []
	opponents.resize(8)
	opponents.fill("火沙虫")
	game.set_meta("pending_enemies", opponents)

	# 战斗 UI 会访问地图场景的战斗记录。用最小宿主保留该入口。
	var host := Node.new()
	root.add_child(host)
	current_scene = host
	var world_ui := Node.new()
	world_ui.name = "UI"
	host.add_child(world_ui)
	var world_log := RichTextLabel.new()
	world_log.name = "BattleLog"
	world_ui.add_child(world_log)
	var battle = load("res://scenes/Battle/battleField.tscn").instantiate()
	host.add_child(battle)
	ui = battle.get_node("BattleUI")
	manager = battle.get_node("BattleManager")
	for actor in manager.party:
		if actor.member_id == "youxiaoyun": hero = actor
		if actor.member_id == "dingdong": companion = actor
	if hero == null or companion == null or manager.enemies.size() != 8:
		_fail("测试阵容加载失败")
		return
	# 故意让主角从落后叮咚 8 点起步，随后靠速度反超，直到自然获得首个回合。
	for i in manager.enemies.size():
		var actor = manager.enemies[i]
		actor.stats.speed = 3
		actor.current_sp = [8.0, 8.0, 8.0, 8.0, 16.0, 27.0, 52.0, 63.0][i]
	hero.stats.speed = 55
	hero.current_sp = 30.0
	companion.stats.speed = 10
	companion.current_sp = 38.0
	var started_behind := false
	var moved_in_front := false
	var moving_samples := 0
	var last_hero_x := INF
	var active_frames := 0
	for frame in 420:
		await physics_frame
		if not frame_directory.is_empty() and frame % 5 == 0:
			await RenderingServer.frame_post_draw
			var track := Rect2i(ui._turn_order.get_global_rect().grow(6.0))
			var capture := root.get_texture().get_image().get_region(track)
			if capture.save_png(frame_directory.path_join("%04d.png" % frame)) != OK:
				_fail("行动条帧采集失败")
				return
		if not _check_entries(10):
			_fail("第 %d 帧：%s" % [frame, failure])
			return
		var hero_entry = ui._turn_entries.get(hero, {}).get("entry")
		var other_entry = ui._turn_entries.get(companion, {}).get("entry")
		if hero_entry and other_entry and hero_entry.visible and other_entry.visible:
			var hero_x := _tip_x(hero_entry)
			var other_x := _tip_x(other_entry)
			if hero.current_sp < companion.current_sp and hero_x < other_x: started_behind = true
			if started_behind and hero.current_sp > companion.current_sp and hero_x > other_x: moved_in_front = true
			if last_hero_x < hero_x - 0.02: moving_samples += 1
			last_hero_x = hero_x
		if manager.state == manager.BattleState.PLAYER_TURN and manager.current_actor() == hero:
			active_frames += 1
			if active_frames >= 20: break
	if not (started_behind and moved_in_front and moving_samples >= 3 and active_frames >= 20):
		_fail("未观察到完整超车和主角回合 behind=%s passed=%s moving=%s active=%s" % [started_behind, moved_in_front, moving_samples, active_frames])
		return
	var current: Control = ui._turn_entries[hero].entry
	for actor in ui._turn_entries:
		var entry: Control = ui._turn_entries[actor].entry
		if entry.visible and actor != hero:
			if _tip_x(entry) >= _tip_x(current) or entry.scale.x >= current.scale.x:
				_fail("当前行动者应抵达右端")
				return
	# 主角已自然进入指令回合，令叮咚的进度逐帧逼近 100，重现右端贴脸。
	var companion_entry: Control = ui._turn_entries[companion].entry
	for i in 25:
		var old_sp: float = companion.current_sp
		companion.current_sp = 97.0 + 3.0 * float(i) / 24.0
		companion.sp_changed.emit(old_sp, companion.current_sp, 100.0)
		await process_frame
		await physics_frame
		if not _check_entries(10):
			_fail("右端拥挤时第 %d 帧：%s" % [i, failure])
			return
		var left_x: float = ui._turn_order.global_position.x + 20.0
		var right_x: float = ui._turn_order.global_position.x + ui._turn_order.size.x - 20.0
		var companion_x := lerpf(left_x, right_x, companion.current_sp / 100.0)
		if absf(_tip_x(companion_entry) - companion_x) > 1.0 or absf(_tip_x(current) - right_x) > 1.0:
			_fail("头像避让时指针尖端仍须指向实际 SP")
			return
		if current.get_global_rect().get_center().x <= companion_entry.get_global_rect().get_center().x:
			_fail("放大的行动者应位于右端")
			return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			if image == null or image.save_png(arg.trim_prefix("--capture=")) != OK:
				_fail("实战截图失败")
				return
	var first_enemy = manager.enemies[0]
	var grouped: Label = ui._turn_entries[first_enemy].entry.get_node("Bg/Count")
	if not grouped.is_visible_in_tree() or grouped.text != "×4":
		_fail("同进度同种敌人应合并为一个 ×4 标记")
		return
	var previous_sp: float = first_enemy.current_sp
	first_enemy.current_sp += 3.5
	first_enemy.sp_changed.emit(previous_sp, first_enemy.current_sp, 100.0)
	await process_frame
	await process_frame
	var rest_group: Label = ui._turn_entries[manager.enemies[1]].entry.get_node("Bg/Count")
	if grouped.is_visible_in_tree() or not rest_group.is_visible_in_tree() or rest_group.text != "×3":
		_fail("进度分开后应拆成独立头像与 ×3 标记")
		return
	for i in range(1, manager.enemies.size()):
		var actor = manager.enemies[i]
		actor.is_dead = true
		actor.died.emit()
	for i in 5:
		await physics_frame
	if not _check_entries(3):
		_fail("仅三人存活：" + failure)
		return
	print("TURN_TRACK_INTEGRATION_PASS: 10 actors, tied SP, overtake, hero turn, 3 survivors")
	quit(0)

func _check_entries(expected: int) -> bool:
	var viewport: Rect2 = ui.get_viewport().get_visible_rect()
	var visible_actors := 0
	var allies: Array[Rect2] = []
	var lowest_enemy := -INF
	var highest_ally := INF
	for actor in ui._turn_entries:
		var data: Dictionary = ui._turn_entries[actor]
		var entry: Control = data.entry
		if not entry.is_visible_in_tree(): continue
		var count: Label = entry.get_node("Bg/Count")
		visible_actors += count.text.trim_prefix("×").to_int() if count.visible else 1
		if data.avatar.texture == null:
			failure = "时间轴头像贴图为空"
			return false
		var bounds := entry.get_global_rect()
		if not viewport.encloses(bounds):
			failure = "%s 在屏幕外 %s" % [actor.stats.character_name, bounds]
			return false
		if actor.is_dead:
			failure = "阵亡角色仍在行动条中"
			return false
		if actor in manager.party:
			for previous in allies:
				if bounds.intersects(previous):
					failure = "我方头像重叠 %s / %s" % [bounds, previous]
					return false
			allies.append(bounds)
			highest_ally = minf(highest_ally, bounds.get_center().y)
		else:
			lowest_enemy = maxf(lowest_enemy, bounds.get_center().y)
	if lowest_enemy >= highest_ally:
		failure = "敌我头像应分别位于时间轴上下方"
		return false
	if visible_actors != expected:
		failure = "标记表示 %d 个角色，期望 %d" % [visible_actors, expected]
		return false
	return true

func _tip_x(entry: Control) -> float:
	var pin := entry.get_node("AxisPin") as Polygon2D
	return pin.to_global(pin.polygon[2]).x

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)

