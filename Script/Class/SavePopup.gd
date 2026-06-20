# SavePopup.gd
# 存档弹窗 — 6槽，节点全部在编辑器场景中
extends CanvasLayer

signal closed

const AUTO_SLOT := 0
const SLOT_COUNT := 5

var _auto_timer: Timer
var _portrait_bg_tex: Texture2D


func _ready() -> void:
	_portrait_bg_tex = load("res://Graphic/UI/人物头像底图.png")
	GameData.battle_ended_for_save.connect(_on_battle_ended_save)
	_auto_timer = Timer.new()
	_auto_timer.one_shot = false
	_auto_timer.wait_time = 60.0
	_auto_timer.timeout.connect(_on_auto_save)
	add_child(_auto_timer)
	_auto_timer.start()

	get_node("CloseBtn").pressed.connect(func(): queue_free(); closed.emit())
	_connect_slot_signals()
	_refresh_all()


func _connect_slot_signals() -> void:
	var slot0 = get_node("Slot_0")
	slot0.get_node("LoadBtn").pressed.connect(_on_load_clicked.bind(0))
	slot0.get_node("SaveBtn").pressed.connect(_on_save_clicked.bind(0))
	slot0.get_node("DelBtn").pressed.connect(_on_delete_clicked.bind(0))

	for s in range(1, SLOT_COUNT):
		var slot = get_node("Slot_%d" % s)
		slot.get_node("SaveBtn").pressed.connect(_on_save_clicked.bind(s))
		slot.get_node("LoadBtn").pressed.connect(_on_load_clicked.bind(s))
		slot.get_node("DelBtn").pressed.connect(_on_delete_clicked.bind(s))


# ═══ 自动保存 ═══
func _on_battle_ended_save() -> void:
	_do_save(AUTO_SLOT)
	_refresh_slot(AUTO_SLOT)

func _on_auto_save() -> void:
	_do_save(AUTO_SLOT)
	_refresh_slot(AUTO_SLOT)

func _do_save(slot: int) -> void:
	GameData.save_game(slot)


# ═══ 按钮 ═══
func _on_save_clicked(slot: int) -> void:
	_do_save(slot)
	_refresh_slot(slot)

func _on_load_clicked(slot: int) -> void:
	if GameData.load_game(slot) and not GameData.current_scene_path.is_empty():
		GameData.ui_blocked = false
		get_tree().change_scene_to_file.call_deferred(GameData.current_scene_path)

func _on_delete_clicked(slot: int) -> void:
	GameData.delete_save(slot)
	_refresh_slot(slot)


# ═══ 刷新 ═══
func _refresh_all() -> void:
	for s in range(SLOT_COUNT):
		_refresh_slot(s)


func _refresh_slot(slot: int) -> void:
	var slot_node = get_node_or_null("Slot_%d" % slot)
	if slot_node == null: return

	var title = slot_node.get_node_or_null("Title") as Label
	var time_val = slot_node.get_node_or_null("TimeVal") as Label
	var gold_val = slot_node.get_node_or_null("GoldVal") as Label
	var ch_val   = slot_node.get_node_or_null("ChVal") as Label
	var portraits = slot_node.get_node_or_null("Portraits") as Control

	if time_val == null or gold_val == null or ch_val == null or portraits == null:
		return

	for child in portraits.get_children():
		child.queue_free()

	var data := _get_slot_info(slot)
	if data.is_empty():
		if time_val: time_val.text = "（空）"
		if gold_val: gold_val.text = ""
		if ch_val: ch_val.text = ""
		return

	var secs := int(data.get("play_time_sec", 0))
	time_val.text = "%d:%02d:%02d" % [secs / 3600, (secs % 3600) / 60, secs % 60]
	gold_val.text = "%d" % data.get("player_gold", 0)
	ch_val.text = "第%d章" % data.get("chapter_id", 1)

	var party_data: Dictionary = data.get("party", {})
	var xoff := 0.0
	for mid in party_data:
		var was_base: String = party_data[mid].get("was", "")
		if was_base.is_empty():
			continue
		var tex := _load_portrait(was_base)
		if tex == null:
			continue
		var bg := TextureRect.new()
		bg.texture = _portrait_bg_tex
		bg.custom_minimum_size = Vector2(60, 60)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg.position = Vector2(xoff -3 , -3)
		bg.size = Vector2(44, 44)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portraits.add_child(bg)

		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(50, 50)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.position = Vector2(xoff, 0)
		rect.size = Vector2(44, 44)
		portraits.add_child(rect)
		xoff += 70


func _get_slot_info(slot: int) -> Dictionary:
	var path := GameData.SAVE_PATH if slot == 0 else "user://save_%d.json" % slot
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.get_data()


func _load_portrait(was_base: String) -> Texture2D:
	if was_base.is_empty():
		return null
	var path := was_base + "/头像/x44.was"
	if not FileAccess.file_exists(path):
		return null
	var r := WASReader.new()
	if not r.load_from_file(path):
		return null
	var d := r.decode_frame(0, 0)
	if d.is_empty():
		return null
	return d.get("texture", null)
