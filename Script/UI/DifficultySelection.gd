extends CanvasLayer
## 本周目开始时选择一次；没有取消或系统设置入口。
signal confirmed
var selected := 1
var _previous_pause := false
var _previous_block := false
var _active := false
var _tree: SceneTree
@export var normal_card_style: StyleBox
@export var selected_card_style: StyleBox
@onready var cards := $Screen/Window/Body/Cards
func _ready() -> void:
	_tree = get_tree()
	if GameData.difficulty_locked:
		queue_free()
		return
	_active = true
	_previous_pause = _tree.paused
	_previous_block = GameData.ui_blocked
	GameData.ui_blocked = true
	_tree.paused = true
	for i in 3:
		cards.get_child(i).get_node("Body/Name").text = GameData.DifficultyDB.PROFILES[i].name
		cards.get_child(i).get_node("Body/Details").text = GameData.DifficultyDB.description(i)
		cards.get_child(i).get_node("Select").pressed.connect(_select.bind(i))
	$Screen/Window/Body/Confirm.pressed.connect(_confirm)
	_select(1)
func _select(value: int) -> void:
	selected = value
	for i in 3:
		cards.get_child(i).get_node("Body/Name").text = GameData.DifficultyDB.PROFILES[i].name
		cards.get_child(i).get_node("Body/Details").text = GameData.DifficultyDB.description(i)
		var card := cards.get_child(i)
		card.get_node("Select").set_pressed_no_signal(i == value)
		card.add_theme_stylebox_override("panel", selected_card_style if i == value else normal_card_style)
	$Screen/Window/Body/Confirm.grab_focus()
func _confirm() -> void:
	if not _active or not GameData.select_difficulty(selected): return
	_active = false
	GameData.ui_blocked = _previous_block
	_tree.paused = _previous_pause
	confirmed.emit()
	queue_free()
func _exit_tree() -> void:
	if _active and is_instance_valid(_tree):
		_tree.paused = _previous_pause
		GameData.ui_blocked = _previous_block
