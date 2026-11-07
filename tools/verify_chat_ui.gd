extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("verify")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func verify() -> void:
	root.size = Vector2i(1280, 800)
	var host := Node2D.new()
	root.add_child(host)
	current_scene = host
	var manager = Engine.get_singleton("DialogueManager")
	var compiled = manager.create_resource_from_text("~ start\n游霄云: 山门已近，云海深处便是方寸山。\n- 询问试炼\n\t叮咚: 先去问问机关人吧。\n- 暂时离开\n\t游霄云: 稍后再来。\n=> END")
	for name in ["normalChat", "storyChat", "example_balloon", "small_example_balloon"]:
		var balloon = load("res://addons/dialogue_manager/example_balloon/" + name + ".tscn").instantiate()
		host.add_child(balloon)
		balloon.start(compiled, "start")
		await create_timer(0.08).timeout
		var accept := InputEventAction.new()
		accept.action = "ui_accept"
		accept.pressed = true
		balloon._on_balloon_gui_input(accept)
		await create_timer(0.08).timeout
		check(not balloon.dialogue_label.is_typing, name + ": Enter reveals text")
		check(balloon.responses_menu.visible, name + ": choices shown")
		check(balloon.responses_menu.get_menu_items().size() == 2, name + ": response count")
		check(balloon.portrait.texture != null, name + ": shared portrait")
		check(balloon.balloon.get_global_rect().end.y <= 800, name + ": inside viewport")
		var response = balloon.dialogue_line.responses[0]
		balloon._on_responses_menu_response_selected(response)
		await create_timer(0.05).timeout
		balloon.dialogue_label.skip_typing()
		await create_timer(0.05).timeout
		check(balloon.character_label.text == "叮咚", name + ": choice advances speaker")
		balloon._load_portrait("未命名的路人")
		check(balloon.get_node("%PortraitFallback").visible, name + ": missing portrait fallback")
		balloon.next(balloon.dialogue_line.next_id)
		await process_frame
		check(not is_instance_valid(balloon), name + ": clean end")
	root.size = Vector2i(960, 640)
	root.content_scale_size = Vector2i(960, 640)
	var many_text := "~ start\n游霄云: " + "山间云雾缭绕，沿着石阶继续前行。".repeat(16) + "\n"
	for i in 8: many_text += "- 第%d个选项，这是一条较长的询问内容\n\t叮咚: 已选择。\n" % (i + 1)
	many_text += "=> END"
	var many_resource = manager.create_resource_from_text(many_text)
	var compact = load("res://addons/dialogue_manager/example_balloon/normalChat.tscn").instantiate()
	host.add_child(compact)
	compact.start(many_resource, "start")
	await create_timer(0.05).timeout
	compact.dialogue_label.skip_typing()
	await create_timer(0.1).timeout
	check(compact.responses_menu.get_menu_items().size() == 8, "many responses retained")
	check(compact.get_node("%ResponseFrame").size.y <= 271, "response list height capped")
	check(compact.dialogue_label.scroll_active, "long dialogue can scroll")
	check(compact.balloon.get_global_rect().end.x <= 960, "compact viewport width")
	check(compact.balloon.get_global_rect().end.y <= 640, "compact viewport height")
	compact.queue_free()
	await process_frame
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	var feed = load("res://addons/dialogue_manager/example_balloon/teamChat.tscn").instantiate()
	host.add_child(feed)
	for i in 7:
		feed.add_message("游霄云" if i % 2 == 0 else "叮咚", "山间云雾缭绕。".repeat(4))
	await process_frame
	check(feed.get_node("%Messages").get_child_count() == 3, "team: capped message count")
	check(not feed.is_in_group("ballon"), "team: does not block world input")
	var latest = feed.get_node("%Messages").get_child(2)
	check(latest.get_node("Card/Row/Text/Message").text.length() > 0, "team: long text visible")
	feed.queue_free()
	await process_frame
	var playback = load("res://addons/dialogue_manager/example_balloon/teamChat.tscn").instantiate()
	host.add_child(playback)
	playback.minimum_line_duration = 0.01
	playback.seconds_per_character = 0.0
	var spoken: Array[String] = []
	playback.line_shown.connect(func(_speaker, message): spoken.append(message))
	var team_resource = manager.create_resource_from_text("~ start\n游霄云: 第一句\n叮咚: 最后一句\n=> END")
	check(await playback.play(team_resource, "start"), "team: completes")
	check(spoken == ["第一句", "最后一句"], "team: final line is not skipped")
	playback.queue_free()
	await process_frame
	check(get_nodes_in_group("ballon").is_empty(), "no dialogue input lock remains")
	print("CHAT UI TESTS: ", "PASS" if failures.is_empty() else str(failures))
	host.queue_free()
	quit(0 if failures.is_empty() else 1)
