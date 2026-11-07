extends "res://addons/dialogue_manager/example_balloon/example_balloon.gd"
## 普通 / 剧情共用交互，布局与样式在各自场景及 ChatTheme 中维护。
const Portraits = preload("res://Script/UI/Dialogue/ChatPortraits.gd")
@export var portrait_overrides: Dictionary[String, Texture2D] = {}
var _introduced := false

func apply_dialogue_line() -> void:
	Portraits.prepare_line(dialogue_line)
	super.apply_dialogue_line()

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(dialogue_line): return
	var choices := responses_menu.visible and not dialogue_line.responses.is_empty()
	%ResponseFrame.visible = choices
	if choices:
		var height := minf(270.0, responses_menu.get_combined_minimum_size().y + 28.0)
		%ResponseFrame.offset_top = -height - 12.0
	%HintLabel.text = "左键 / Enter 显示全文" if dialogue_label.is_typing else "↑ ↓ 选择 · Enter 确认" if choices else "左键 / Enter 继续"
	if not _introduced and balloon.visible:
		_introduced = true
		balloon.modulate.a = 0.0
		create_tween().tween_property(balloon, "modulate:a", 1.0, 0.16)

func _load_portrait(speaker: String) -> void:
	var display_name: String = Portraits.speaker_info(speaker).name
	portrait.texture = portrait_overrides.get(speaker, portrait_overrides.get(display_name))
	if portrait.texture == null:
		portrait.texture = Portraits.texture_for(speaker)
	%PortraitFallback.visible = portrait.texture == null
	%PortraitFallback.text = display_name.left(1) if not display_name.is_empty() else "叙"
	character_label.text = tr(display_name, "dialogue") if not display_name.is_empty() else "旁白"
	character_label.visible = true

func _on_balloon_gui_input(event: InputEvent) -> void:
	if dialogue_label.is_typing and event.is_action_pressed(next_action):
		dialogue_label.skip_typing()
		get_viewport().set_input_as_handled()
		return
	super._on_balloon_gui_input(event)
