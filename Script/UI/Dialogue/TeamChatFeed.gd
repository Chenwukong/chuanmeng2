extends CanvasLayer
signal line_shown(speaker: String, message: String)
const Entry = preload("res://scenes/UI/Dialogue/TeamChatEntry.tscn")
const Portraits = preload("res://Script/UI/Dialogue/ChatPortraits.gd")
@export_range(1, 6) var max_messages: int = 3
@export var minimum_line_duration: float = 1.8
@export var seconds_per_character: float = 0.055
var _running := true
var _last_speaker := ""
var _on_right := true

func cancel() -> void:
	_running = false
	hide()

func add_message(speaker: String, message: String) -> Control:
	var display_name: String = Portraits.speaker_info(speaker).name
	if display_name != _last_speaker:
		_on_right = not _on_right
		_last_speaker = display_name
	var entry := Entry.instantiate() as Control
	entry.get_node("LeftSpace").visible = _on_right
	entry.get_node("RightSpace").visible = not _on_right
	entry.get_node("Card/Row/Text/Name").text = display_name if not display_name.is_empty() else "旁白"
	entry.get_node("Card/Row/Text/Message").text = message
	var texture := Portraits.texture_for(speaker)
	entry.get_node("Card/Row/PortraitWell/Portrait").texture = texture
	entry.get_node("Card/Row/PortraitWell/Fallback").visible = texture == null
	entry.get_node("Card/Row/PortraitWell/Fallback").text = display_name.left(1) if not display_name.is_empty() else "叙"
	%Messages.add_child(entry)
	while %Messages.get_child_count() > max_messages:
		var old := %Messages.get_child(0)
		%Messages.remove_child(old)
		old.queue_free()
	entry.modulate.a = 0.0
	create_tween().tween_property(entry, "modulate:a", 1.0, 0.18)
	_scroll_to_latest.call_deferred()
	line_shown.emit(display_name, message)
	return entry

func _scroll_to_latest() -> void:
	await get_tree().process_frame
	if is_inside_tree(): %Scroll.scroll_vertical = int(%Scroll.get_v_scroll_bar().max_value)

func play(resource: DialogueResource, title: String) -> bool:
	var next_id := title
	while _running and not next_id.is_empty():
		var line := await resource.get_next_dialogue_line(next_id, [])
		if not _running: return false
		if line == null: break
		Portraits.prepare_line(line)
		next_id = line.next_id
		if line.character.is_empty() and line.text.is_empty(): continue
		add_message(line.character, line.text)
		await get_tree().create_timer(maxf(minimum_line_duration, line.text.length() * seconds_per_character)).timeout
	var completed := _running
	if completed:
		await get_tree().create_timer(2.0).timeout
		await create_tween().tween_property(%Feed, "modulate:a", 0.0, 0.35).finished
	return completed
