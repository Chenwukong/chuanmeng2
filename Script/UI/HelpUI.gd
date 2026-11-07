extends CanvasLayer

@onready var overlay: Control = $Overlay
@onready var categories: VBoxContainer = $Overlay/Panel/Layout/Body/Categories
@onready var pages: TabContainer = $Overlay/Panel/Layout/Body/Pages

func _ready() -> void:
	$HelpButton.pressed.connect(toggle)
	$Overlay/Panel/Layout/Header/Close.pressed.connect(close)
	for i in categories.get_child_count():
		categories.get_child(i).pressed.connect(_select.bind(i))
	_select(0)
	_process(0.0)

func _process(_delta: float) -> void:
	$HelpButton.visible = not GameData.in_battle
	if GameData.in_battle and is_open(): close()

func _select(index: int) -> void:
	pages.current_tab = index
	for i in categories.get_child_count():
		categories.get_child(i).set_pressed_no_signal(i == index)

func is_open() -> bool:
	return overlay.visible

func toggle() -> void:
	if GameData.in_battle: return
	if is_open():
		close()
	else:
		overlay.show()
		get_parent()._register_popup(overlay)
		overlay.set_meta("keyboard_cancel", close)
		categories.get_child(pages.current_tab).grab_focus()

func close() -> void:
	if not is_open(): return
	overlay.hide()
	get_parent()._unregister_popup(overlay)
	if $HelpButton.is_visible_in_tree(): $HelpButton.grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			toggle()
			get_viewport().set_input_as_handled()
		elif is_open() and event.is_action_pressed("ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
