extends Node
const UIFeedback = preload("res://Script/UI/UISoundFeedback.gd")
## 非战斗菜单的统一输入入口。业务动作仍由各界面自己的回调执行。

var host: Node
var panels: Array[Node] = []
var scope: Node
var selected: Control
var items: Array[Control] = []
var memories: Dictionary = {}
var region_memories: Dictionary = {}
var keyboard_mode := true
var menu_open := false
var menu_index := 0
var _menu_entry := ""
var _last_index := 0
var _last_path := NodePath()
@export_multiline var world_hint: String = ""
@export_multiline var popup_hint: String = ""
@export_multiline var menu_hint: String = ""
@onready var _overlay: CanvasLayer = $Overlay
@onready var _frame: ReferenceRect = $Overlay/SelectionFrame
@onready var _hint = $Overlay/Hint
@onready var _actions: PopupMenu = $Actions
var _action_callbacks: Array[Callable] = []
var _action_source: Control
var _action_committed := false

const MENU := ["人物", "道具", "宠物", "天赋", "打造", "队伍", "悬赏", "剧情", "地图", "系统", "存档", "成就"]

func _ready() -> void:
	_actions.id_pressed.connect(_run_action)
	_actions.id_focused.connect(func(_index): UIFeedback.play_ui(&"select"))
	_actions.popup_hide.connect(func():
		if is_instance_valid(_action_source): select(_action_source, false)
		_action_hide_feedback.call_deferred()
	)

func push(panel: Node) -> void:
	if not is_instance_valid(panel): return
	UIFeedback.play_ui(&"confirm")
	panels.erase(panel)
	panels.append(panel)
	# 保证统一入口先于弹窗的 _input 收到事件。
	var branch: Node = self
	while branch != host and branch.get_parent():
		var parent := branch.get_parent()
		parent.move_child(branch, parent.get_child_count() - 1)
		branch = parent

func _live(node: Node) -> bool:
	if not is_instance_valid(node) or node.is_queued_for_deletion(): return false
	if node is CanvasLayer and not node.visible: return false
	if node is CanvasItem and not node.is_visible_in_tree(): return false
	return true

func _modal(node: Node) -> Node:
	var children := node.get_children()
	children.reverse()
	for child in children:
		if not _live(child): continue
		var nested := _modal(child)
		if nested: return nested
		if child.get_meta("keyboard_modal", false): return child
	return null

func _refresh_scope() -> void:
	panels = panels.filter(func(p): return is_instance_valid(p) and not p.is_queued_for_deletion())
	var next: Node = null
	for panel in panels:
		if _live(panel): next = panel
	if next:
		var modal := _modal(next)
		if modal: next = modal
	if next != scope:
		if is_instance_valid(scope): memories[scope.get_instance_id()] = [_last_path, _last_index]
		scope = next
		selected = null
		_last_path = NodePath()
		_last_index = 0
		if scope and memories.has(scope.get_instance_id()):
			var saved: Array = memories[scope.get_instance_id()]
			_last_path = saved[0]
			_last_index = saved[1]
	items.clear()
	if scope: _collect(scope)
	if not items.is_empty() and (not is_instance_valid(selected) or selected not in items):
		var restored := scope.get_node_or_null(_last_path) as Control if not _last_path.is_empty() else null
		if restored not in items:
			restored = items[mini(_last_index, items.size() - 1)]
			if _last_path.is_empty():
				for item in items:
					if item.get_meta("keyboard_default", false):
						restored = item
						break
		select(restored)
	elif items.is_empty():
		selected = null

func _collect(node: Node) -> void:
	if not _live(node) or node.get_meta("keyboard_skip", false): return
	if node is SubViewport: return
	if node is Control:
		var c := node as Control
		var interactive := c is BaseButton or c is Slider or c is SpinBox or c is LineEdit
		interactive = interactive or c.has_meta("keyboard_activate") or c.has_meta("keyboard_detail") or c.has_method("keyboard_move")
		interactive = interactive or not c.gui_input.get_connections().is_empty()
		if c is BaseButton and c.disabled and not c.get_meta("keyboard_inspect_disabled", false): interactive = false
		if c.size.x <= 0 or c.size.y <= 0: interactive = false
		if interactive:
			UIFeedback.bind_control(c)
			c.focus_mode = Control.FOCUS_ALL
			items.append(c)
			if c is SpinBox: return
	for child in node.get_children(): _collect(child)

func select(control: Control, show_detail: bool = true) -> void:
	if not is_instance_valid(control): return
	if is_instance_valid(selected) and selected != control:
		selected.set_meta("keyboard_selected", false)
		if show_detail: selected.mouse_exited.emit()
	selected = control
	control.set_meta("keyboard_selected", true)
	if scope:
		_last_path = scope.get_path_to(control)
	_last_index = maxi(0, items.find(control))
	if scope: region_memories[str(scope.get_instance_id()) + str(_region(control))] = scope.get_path_to(control)
	control.grab_focus()
	var parent := control.get_parent()
	while parent and parent != scope:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	if show_detail:
		control.mouse_entered.emit()
		if control.has_meta("keyboard_detail"):
			var detail: Callable = control.get_meta("keyboard_detail")
			detail.call()

func _node_region(node: Node) -> String:
	return "node:%d" % node.get_instance_id()

func _region(control: Control) -> String:
	if control.has_meta("keyboard_region"): return str(control.get_meta("keyboard_region"))
	if control.has_method("keyboard_move"): return _node_region(control)
	var parent := control.get_parent()
	var container: Node = null
	while parent and parent != scope:
		if parent.has_meta("keyboard_region"): return str(parent.get_meta("keyboard_region"))
		if parent is GridContainer or parent is BoxContainer: container = parent
		parent = parent.get_parent()
	return _node_region(container if container else control)

func _move(direction: Vector2) -> void:
	if not is_instance_valid(selected): return
	if selected.has_method("keyboard_move"):
		selected.keyboard_move(direction)
		UIFeedback.play_ui(&"adjust")
		return
	if (selected is Slider or selected is SpinBox) and direction.x != 0:
		selected.value += direction.x * selected.step
		return
	var origin := _screen_rect(selected).get_center()
	var best: Control
	var score := INF
	# 格子和列表到边界停住，跨区域使用 Tab；独立按钮按屏幕方向移动。
	for same_region in [true, false]:
		if not same_region and _region(selected) != _node_region(selected): break
		for candidate in items:
			if candidate == selected: continue
			if same_region and _region(candidate) != _region(selected): continue
			var offset := _screen_rect(candidate).get_center() - origin
			var forward := offset.dot(direction)
			if forward <= 2: continue
			var sideways := absf(offset.cross(direction))
			var source_size := _screen_rect(selected).size
			var target_size := _screen_rect(candidate).size
			var overlap := (source_size.y + target_size.y) * 0.5 if direction.x != 0 else (source_size.x + target_size.x) * 0.5
			if sideways > maxf(4.0, overlap - 2.0): continue
			var cost := forward + sideways * 3.0
			if cost < score:
				score = cost
				best = candidate
		if best: break
	if best: select(best)

func _tab(backward: bool) -> void:
	var groups: Array = []
	var ordered := _reading_order(items)
	for item in ordered:
		var group = _region(item)
		if group not in groups: groups.append(group)
	var explicit: Array = scope.get_meta("keyboard_region_order", []) if scope else []
	if not explicit.is_empty():
		var fixed: Array = []
		for group in explicit:
			if group in groups: fixed.append(group)
		for group in groups:
			if group not in fixed: fixed.append(group)
		groups = fixed
	if groups.is_empty(): return
	var index := groups.find(_region(selected)) if is_instance_valid(selected) else -1
	var next = groups[posmod(index + (-1 if backward else 1), groups.size())]
	var memory_key := str(scope.get_instance_id()) + str(next)
	if region_memories.has(memory_key):
		var previous := scope.get_node_or_null(region_memories[memory_key]) as Control
		if previous in items and _region(previous) == next:
			select(previous)
			return
	for item in ordered:
		if _region(item) == next:
			select(item)
			return

func _reading_order(controls: Array[Control]) -> Array[Control]:
	# 先按纵向排序，再把同一视觉行内的控件按从左到右排列。
	# 不使用带容差的 sort 比较器，避免比较关系不传递而打乱顺序。
	var remaining: Array[Control] = controls.duplicate()
	remaining.sort_custom(func(a: Control, b: Control):
		var pa := _screen_rect(a).position
		var pb := _screen_rect(b).position
		return pa.y < pb.y if not is_equal_approx(pa.y, pb.y) else pa.x < pb.x
	)
	var result: Array[Control] = []
	while not remaining.is_empty():
		var row_y := remaining[0].get_global_rect().position.y
		var row: Array[Control] = []
		while not remaining.is_empty() and remaining[0].get_global_rect().position.y <= row_y + 12.0:
			row.append(remaining.pop_front())
		row.sort_custom(func(a: Control, b: Control): return _screen_rect(a).position.x < _screen_rect(b).position.x)
		result.append_array(row)
	return result

func _click(control: Control, button: MouseButton = MOUSE_BUTTON_LEFT, double_click: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.double_click = double_click
	event.position = control.size * 0.5
	control.gui_input.emit(event)

func _activate() -> void:
	if not is_instance_valid(selected): return
	if selected is BaseButton and selected.disabled and not selected.has_meta("keyboard_activate"):
		UIFeedback.play_ui(&"error")
		return
	UIFeedback.play_ui(&"confirm")
	if selected.has_meta("keyboard_activate"):
		var action: Callable = selected.get_meta("keyboard_activate")
		action.call()
	elif selected.has_method("keyboard_activate"):
		selected.keyboard_activate()
	elif selected is BaseButton:
		if selected.disabled: return
		if selected.toggle_mode: selected.button_pressed = not selected.button_pressed
		selected.pressed.emit()
	else:
		_click(selected)

func show_actions(control: Control, entries: Array) -> void:
	_action_committed = false
	_actions.clear()
	_action_callbacks.clear()
	_action_source = control
	for entry in entries:
		_actions.add_item(entry[0], _action_callbacks.size())
		_action_callbacks.append(entry[1])
	_actions.add_item("取消", _action_callbacks.size())
	_actions.reset_size()
	var slot := _screen_rect(control)
	var bounds := Rect2i(get_viewport().get_visible_rect())
	if not _actions.is_embedded():
		slot = get_viewport().get_screen_transform() * slot
		bounds = DisplayServer.screen_get_usable_rect(get_window().current_screen)
	var pos := Vector2i(slot.end.x + 4, slot.position.y)
	if pos.x + _actions.size.x > bounds.end.x:
		pos.x = int(slot.position.x) - _actions.size.x - 4
	pos = pos.clamp(bounds.position, (bounds.end - _actions.size).max(bounds.position))
	_actions.popup(Rect2i(pos, _actions.size))
	_actions.set_focused_item(0)

func _action_hide_feedback() -> void:
	if not _action_committed: UIFeedback.play_ui(&"cancel")

func _run_action(id: int) -> void:
	_action_committed = true
	UIFeedback.play_ui(&"confirm" if id < _action_callbacks.size() else &"cancel")
	if id < _action_callbacks.size(): _action_callbacks[id].call()
	_refresh_detail.call_deferred()

func _refresh_detail() -> void:
	_refresh_scope()
	if is_instance_valid(selected): select(selected)

func _cancel() -> void:
	UIFeedback.play_ui(&"cancel")
	if scope and scope.has_meta("keyboard_cancel"):
		var cancel: Callable = scope.get_meta("keyboard_cancel")
		cancel.call()
	elif scope and scope.get_meta("keyboard_modal", false):
		scope.queue_free()
	else:
		host._close_top_popup()

func _input(event: InputEvent) -> void:
	if GameData.in_battle or GameData.is_dialogue_active(): return
	if _actions.visible: return
	_refresh_scope()
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		if event is InputEventMouseMotion and event.relative.is_zero_approx(): return
		keyboard_mode = false
		menu_open = false
		host.set_meta("keyboard_menu_open", false)
		if event is InputEventMouseMotion and event.relative.length_squared() > 0:
			for item in items:
				if _screen_rect(item).has_point(item.get_global_mouse_position()):
					select(item, false)
					break
		return
	if not event is InputEventKey or not event.pressed: return
	if event.alt_pressed or event.ctrl_pressed or event.meta_pressed: return
	if not scope:
		_handle_menu(event)
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit and event.keycode not in [KEY_TAB, KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]: return
	var handled := true
	keyboard_mode = true
	if event.is_action_pressed("ui_cancel"):
		if not event.echo: _cancel()
	elif event.keycode == KEY_TAB:
		if not event.echo: _tab(event.shift_pressed)
	elif event.is_action_pressed("ui_up"): _move(Vector2.UP)
	elif event.is_action_pressed("ui_down"): _move(Vector2.DOWN)
	elif event.is_action_pressed("ui_left"): _move(Vector2.LEFT)
	elif event.is_action_pressed("ui_right"): _move(Vector2.RIGHT)
	elif event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		_scroll_page(-1 if event.keycode == KEY_PAGEUP else 1)
	elif event.keycode in [KEY_Q, KEY_E]:
		var page_host: Node = selected
		while is_instance_valid(page_host) and not page_host.has_method("keyboard_page") and page_host != scope:
			page_host = page_host.get_parent()
		if is_instance_valid(page_host) and page_host.has_method("keyboard_page"):
			page_host.keyboard_page(-1 if event.keycode == KEY_Q else 1)
	elif event.keycode in [KEY_MINUS, KEY_EQUAL, KEY_KP_ADD, KEY_KP_SUBTRACT] and is_instance_valid(selected) and selected.has_method("keyboard_zoom"):
		selected.keyboard_zoom(1.2 if event.keycode in [KEY_EQUAL, KEY_KP_ADD] else 1.0 / 1.2)
		UIFeedback.play_ui(&"adjust")
	elif event.is_action_pressed("ui_accept"):
		if not event.echo: _activate()
	else: handled = false
	if handled: get_viewport().set_input_as_handled()

func _menu_available() -> Array[String]:
	var result: Array[String] = []
	for entry in MENU:
		if entry == "成就":
			continue
		var sprite := host.get_node_or_null("UI/按钮底图/" + entry) as AnimatedSprite2D
		if sprite and sprite.visible and sprite.modulate.a > 0.5: result.append(entry)
	result.sort_custom(func(a: String, b: String):
		var left := host.get_node("UI/按钮底图/" + a) as AnimatedSprite2D
		var right := host.get_node("UI/按钮底图/" + b) as AnimatedSprite2D
		return left.get_global_transform_with_canvas().origin.x < right.get_global_transform_with_canvas().origin.x
	)
	if is_instance_valid(host.get("_achievement_btn")) and host._achievement_btn.visible: result.append("成就")
	return result

func _handle_menu(event: InputEventKey) -> void:
	if GameData.ui_blocked: return
	var available := _menu_available()
	if available.is_empty(): return
	if _menu_entry in available: menu_index = available.find(_menu_entry)
	menu_index = mini(menu_index, available.size() - 1)
	if event.keycode == KEY_TAB:
		if event.echo:
			get_viewport().set_input_as_handled()
			return
		if menu_open: menu_index = posmod(menu_index + (-1 if event.shift_pressed else 1), available.size())
		menu_open = true
	elif menu_open and event.is_action_pressed("ui_cancel"):
		menu_open = false
	elif menu_open and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up")):
		menu_index = posmod(menu_index - 1, available.size())
	elif menu_open and (event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down")):
		menu_index = posmod(menu_index + 1, available.size())
	elif menu_open and event.is_action_pressed("ui_accept"):
		if not event.echo: host._activate_menu(available[mini(menu_index, available.size() - 1)])
	else: return
	UIFeedback.play_ui(&"cancel" if not menu_open else &"select")
	_menu_entry = available[menu_index]
	keyboard_mode = true
	host.set_meta("keyboard_menu_open", menu_open)
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if PlatformControls.android_mode and not GamepadInput.active:
		menu_open = false
		if is_instance_valid(host): host.set_meta("keyboard_menu_open", false)
		_overlay.hide()
		return
	var active := not GameData.in_battle and not GameData.is_dialogue_active()
	_overlay.visible = active
	if not active:
		if _actions.visible: _actions.hide()
		return
	_refresh_scope()
	host.set_meta("keyboard_menu_open", menu_open and scope == null)
	_hint.text = popup_hint if scope else world_hint
	if GamepadInput.active:
		_hint.text = "方向选择 · A 确认 · B 返回 · X 切换区域 · LB/RB 翻页" if scope else "左摇杆/十字键移动 · A 交互 · Start 菜单 · B 返回 · Y 骑乘"
	_frame.visible = keyboard_mode and is_instance_valid(selected) and scope != null
	if _frame.visible:
		var rect := _screen_rect(selected)
		_frame.position = rect.position - Vector2(3, 3)
		_frame.size = rect.size + Vector2(6, 6)
	if not scope and menu_open:
		var available := _menu_available()
		if not available.is_empty():
			menu_index = mini(menu_index, available.size() - 1)
			var entry := available[menu_index]
			_hint.text = menu_hint % entry
			if GamepadInput.active: _hint.text = "菜单：%s · 方向选择 · A 打开 · B 返回" % entry
			var sprite := host.get_node_or_null("UI/按钮底图/" + entry) as AnimatedSprite2D
			if sprite:
				_frame.visible = true
				_frame.position = sprite.get_global_transform_with_canvas().origin - Vector2(22, 25)
				_frame.size = Vector2(44, 50)
			elif entry == "成就" and is_instance_valid(host._achievement_btn):
				_frame.visible = true
				var rect: Rect2 = _screen_rect(host._achievement_btn)
				_frame.position = rect.position - Vector2(3, 3)
				_frame.size = rect.size + Vector2(6, 6)

	_hint.size = _hint.get_minimum_size()
	_hint.position = Vector2(12, get_viewport().get_visible_rect().size.y - _hint.size.y - 12)

func _exit_tree() -> void:
	if is_instance_valid(host): host.set_meta("keyboard_menu_open", false)


func _scroll_page(direction: int) -> void:
	var parent: Node = selected
	while is_instance_valid(parent) and parent != scope:
		if parent is ScrollContainer:
			parent.scroll_vertical += int(parent.size.y * 0.8) * direction
			return
		parent = parent.get_parent()
	if scope:
		for child in scope.find_children("*", "ScrollContainer", true, false):
			if child.is_visible_in_tree():
				child.scroll_vertical += int(child.size.y * 0.8) * direction
				return


func _screen_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
