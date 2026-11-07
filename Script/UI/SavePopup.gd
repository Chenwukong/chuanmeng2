# SavePopup.gd
# 存档弹窗 — 6槽，节点全部在编辑器场景中
extends CanvasLayer
const UIFeedback = preload("res://Script/UI/UISoundFeedback.gd")

signal closed

const AUTO_SLOT := 0
const SLOT_COUNT := 5

const PORTRAIT_SCENE = preload("res://scenes/UI/Save/SavePortrait.tscn")
@export var load_only := false


func _ready() -> void:
	GameData.auto_saved.connect(_on_auto_saved)

	get_node("CloseBtn").pressed.connect(func():
		var snd = AudioStreamPlayer.new()
		snd.stream = load("res://Audio/SE/003-System03.ogg")
		snd.bus = "SFX"
		get_tree().root.add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)
		queue_free(); closed.emit())
	_connect_slot_signals()
	if load_only:
		$PageTitle.text = "加载游戏"
		$Subtitle.text = "选择存档继续游戏"
		$Footer.hide()
		for s in range(SLOT_COUNT):
			var slot := get_node("Slot_%d" % s)
			slot.get_node("SaveBtn").hide()
			slot.get_node("DelBtn").hide()
	_refresh_all()
	if load_only:
		$CloseBtn.grab_focus()


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
func _on_auto_saved() -> void:
	_refresh_slot(AUTO_SLOT)

func _do_save(slot: int) -> void:
	GameData.save_game(slot)


# ═══ 按钮 ═══
func _on_save_clicked(slot: int) -> void:
	_do_save(slot)
	_refresh_slot(slot)

func _on_load_clicked(slot: int) -> void:
	if load_only:
		var path := str(_get_slot_info(slot).get("scene_path", ""))
		if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
			UIFeedback.play_ui(&"error")
			return
	if GameData.load_game(slot) and not GameData.current_scene_path.is_empty():
		GameData.ui_blocked = false
		get_tree().change_scene_to_file.call_deferred(GameData.current_scene_path)
	else:
		UIFeedback.play_ui(&"error")

func _on_delete_clicked(slot: int) -> void:
	if _get_slot_info(slot).is_empty():
		UIFeedback.play_ui(&"error")
		return
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
		portraits.remove_child(child)
		child.queue_free()

	var data := _get_slot_info(slot)
	slot_node.get_node("LoadBtn").disabled = data.is_empty()
	slot_node.get_node("DelBtn").disabled = data.is_empty()
	slot_node.get_node("TimeCaption").visible = not data.is_empty()
	if data.is_empty():
		if time_val: time_val.text = "尚无存档"
		if gold_val: gold_val.text = ""
		if ch_val: ch_val.text = ""
		return

	var secs := int(data.get("play_time_sec", 0))
	time_val.text = "%d:%02d:%02d" % [secs / 3600, (secs % 3600) / 60, secs % 60]
	gold_val.text = "金币  %d" % data.get("player_gold", 0)
	ch_val.text = "第%d章" % data.get("chapter_id", 1)

	var party_data: Dictionary = data.get("characters", {})
	var party_order: Array = data.get("party_order", party_data.keys())
	var shown := 0
	for mid in party_order:
		if not party_data.has(mid): continue
		var member: Dictionary = party_data[mid]
		var was_base: String = member.get("was", "")
		if was_base.is_empty():
			continue
		var tex := _load_portrait(was_base)
		if tex == null:
			continue
		var portrait = PORTRAIT_SCENE.instantiate()
		portrait.get_node("Portrait").texture = tex
		portrait.tooltip_text = str(member.get("name", "队员"))
		portraits.add_child(portrait)
		shown += 1
		if shown >= 6: break



static func _get_slot_info(slot: int) -> Dictionary:
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
	var data = json.get_data()
	if not data is Dictionary or not preload("res://Script/Save/SaveService.gd").is_current_schema(data):
		return {}
	return data


func _load_portrait(was_base: String) -> Texture2D:
	var root_texture = preload("res://Script/Assets/AssetLoader.gd").root_portrait(was_base)
	if root_texture != null: return root_texture
	if was_base.is_empty():
		return null
	var path := was_base + "/头像/头像.was"
	if not FileAccess.file_exists(path):
		path = was_base + "/头像/x44.was"
	if not FileAccess.file_exists(path):
		return null
	var r_frame: Dictionary = preload("res://Script/Assets/AssetLoader.gd").was_frame(path)
	if r_frame.is_empty():
		return null
	var d := r_frame
	if d.is_empty():
		return null
	return d.get("texture", null)
