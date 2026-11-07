extends CanvasLayer
## 首次击败20级守关黑熊后的天赋教学，结束后保留天赋页供玩家加点。

const COMPLETION_FLAG := "tutorial.talent.completed"
signal completed

@export var headings: PackedStringArray = []
@export var explanations: PackedStringArray = []
@export var continue_text := "下一步"
@export var finish_text := "完成教学"
var active := false
var page := 0
var _tree: SceneTree
var _was_paused := false
var _focus_before: WeakRef

func _ready() -> void:
	_tree = get_tree()
	hide()
	$Screen/Window/Body/Buttons/Previous.pressed.connect(_previous)
	$Screen/Window/Body/Buttons/Next.pressed.connect(_next)
	$Screen/Window/Body/Buttons/Skip.pressed.connect(_finish)
	active = true
	page = 0
	_was_paused = _tree.paused
	var focus := get_viewport().gui_get_focus_owner()
	_focus_before = weakref(focus) if focus != null else null
	_tree.paused = true
	show()
	_refresh()

func _refresh() -> void:
	$Screen/Window/Body/Step.text = "%d / %d" % [page + 1, headings.size()]
	$Screen/Window/Body/Heading.text = headings[page]
	$Screen/Window/Body/Explanation.text = explanations[page]
	$Screen/Window/Body/Buttons/Previous.disabled = page == 0
	# Godot 的显式焦点邻居不会越过禁用按钮，第一页直接连接跳过与下一步。
	var previous_path := NodePath("../Skip") if page == 0 else NodePath("../Previous")
	var next_path := NodePath("../Next") if page == 0 else NodePath("../Previous")
	$Screen/Window/Body/Buttons/Next.focus_neighbor_left = previous_path
	$Screen/Window/Body/Buttons/Next.focus_previous = previous_path
	$Screen/Window/Body/Buttons/Skip.focus_neighbor_right = next_path
	$Screen/Window/Body/Buttons/Skip.focus_next = next_path
	$Screen/Window/Body/Buttons/Next.text = finish_text if page == headings.size() - 1 else continue_text
	$Screen/Window/Body/Buttons/Next.grab_focus()

func _next() -> void:
	if not active: return
	if page == headings.size() - 1:
		_finish()
		return
	page += 1
	_refresh()

func _previous() -> void:
	if not active or page == 0: return
	page -= 1
	_refresh()

func _finish() -> void:
	if not active: return
	active = false
	hide()
	GameData.complete_story_event(COMPLETION_FLAG)
	_tree.paused = _was_paused
	var focus = _focus_before.get_ref() if _focus_before != null else null
	if is_instance_valid(focus) and focus.is_inside_tree() and focus.is_visible_in_tree(): focus.grab_focus()
	completed.emit()
	queue_free()

func _exit_tree() -> void:
	# 中途退出不标记学完；只恢复暂停状态，不唤醒已经销毁的教学调用方。
	if active and is_instance_valid(_tree): _tree.paused = _was_paused
	active = false
