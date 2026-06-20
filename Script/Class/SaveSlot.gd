# SaveSlot.gd
# 单个存档槽 — 用于 SavePopup 中复用
tool
extends Control

signal save_pressed
signal load_pressed
signal delete_pressed

var _btn_save: Button
var _btn_load: Button
var _btn_del: Button
var _time_val: Label
var _gold_val: Label
var _ch_val: Label
var _portraits: Control
var _portrait_bg_tex: Texture2D


func _ready() -> void:
	var top = get_node("TopRow")
	var bottom = get_node_or_null("BottomRow")

	_time_val = top.get_node("TimeVal") as Label
	_gold_val = top.get_node("GoldVal") as Label
	_ch_val   = top.get_node("ChVal") as Label
	_portraits = top.get_node("Portraits") as Control

	_btn_save = get_node_or_null("SaveBtn") as Button
	_btn_load = get_node_or_null("LoadBtn") as Button
	_btn_del  = get_node_or_null("DelBtn")  as Button

	if _btn_save: _btn_save.pressed.connect(func(): save_pressed.emit())
	if _btn_load: _btn_load.pressed.connect(func(): load_pressed.emit())
	if _btn_del:  _btn_del.pressed.connect(func(): delete_pressed.emit())

	_portrait_bg_tex = load("res://Graphic/UI/人物头像底图.png")


func update_slot(data: Dictionary) -> void:
	_time_val = get_node("TopRow/TimeVal") as Label
	_gold_val = get_node("TopRow/GoldVal") as Label
	_ch_val   = get_node("TopRow/ChVal") as Label
	_portraits = get_node("TopRow/Portraits") as Control

	for child in _portraits.get_children():
		child.queue_free()

	if data.is_empty():
		_time_val.text = "（空）"
		_gold_val.text = ""
		_ch_val.text = ""
		return

	var secs := int(data.get("play_time_sec", 0))
	_time_val.text = "%d:%02d:%02d" % [secs / 3600, (secs % 3600) / 60, secs % 60]
	_gold_val.text = "%d" % data.get("player_gold", 0)
	_ch_val.text = "第%d章" % data.get("chapter_id", 1)

	var party_data: Dictionary = data.get("party", {})
	var xoff := 0.0
	for mid in party_data:
		var was_base: String = party_data[mid].get("was", "")
		if was_base.is_empty(): continue
		var tex := _load_portrait(was_base)
		if tex == null: continue
		var bg := TextureRect.new()
		bg.texture = _portrait_bg_tex
		bg.custom_minimum_size = Vector2(44, 44)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg.position = Vector2(xoff, 0)
		bg.size = Vector2(44, 44)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portraits.add_child(bg)

		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(44, 44)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.position = Vector2(xoff, 0)
		rect.size = Vector2(44, 44)
		_portraits.add_child(rect)
		xoff += 52


func _load_portrait(was_base: String) -> Texture2D:
	if was_base.is_empty(): return null
	var path := was_base + "/头像/x44.was"
	if not FileAccess.file_exists(path): return null
	var r := WASReader.new()
	if not r.load_from_file(path): return null
	var d := r.decode_frame(0, 0)
	if d.is_empty(): return null
	return d.get("texture", null)
