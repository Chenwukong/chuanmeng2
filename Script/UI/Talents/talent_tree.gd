extends CanvasLayer

signal closed

@export var starting_points: int = 20

@onready var page_buttons = $PageButtons
@onready var point_label: Label = $PointsBadge/Row/PointLabel
@onready var pages: Control = $Pages
@onready var detailPanel = $DetailPanel
@onready var detail_label = $DetailPanel/DetailLabel
@onready var close_btn: Button = $CloseButton

var talent_points: int
var current_page: Control
var _detail_talent: TalentNode
var _page_tween: Tween


func _ready() -> void:
	if !detailPanel:
		return
	detailPanel.visible = false
	detailPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	talent_points = GameData.talent_points
	GameData.achievements_changed.connect(_refresh_all)
	close_btn.pressed.connect(close)
	for button in page_buttons.get_children():
		button.pressed.connect(func(page_name := button.name): show_page(page_name.replace("Btn_", "Page_")))

	for page in pages.get_children():
		page.talent_hovered.connect(_show_talent_detail)
		page.talent_unhovered.connect(_hide_talent_detail)
		page.talent_pressed.connect(_try_upgrade_talent)
		page.talent_rank_removed.connect(_on_talent_removed)

	# TextureRect sizes the decoded image without the TCP sprite's game-world anchor.
	$PointsBadge/Row/Icon.texture = preload("res://Script/Assets/AssetLoader.gd").tcp_texture("res://TCP/UI/2302.tcp")
	_layout_talent_tree()
	get_viewport().size_changed.connect(_layout_talent_tree)
	_restore_ranks()
	show_page("Page_Main")
	_refresh_all()

func _restore_ranks() -> void:
	for page in pages.get_children():
		for talent in page.get_talents():
			var saved_rank := GameData.get_talent_rank(talent.talent_id)
			for _i in range(saved_rank):
				if talent.rank < talent.max_rank:
					talent.rank += 1
					talent._update_text()

## 收集所有页面的天赋节点
func _get_all_talent_nodes() -> Array[TalentNode]:
	var result: Array[TalentNode] = []
	for page in pages.get_children():
		result.append_array(page.get_talents())
	return result


func _process(_delta: float) -> void:
	if is_instance_valid(_detail_talent) and detailPanel.visible:
		_position_detail()

func _position_detail() -> void:
	var anchor := get_viewport().get_mouse_position()
	if _detail_talent.get_meta("keyboard_selected", false):
		anchor = (_detail_talent.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, _detail_talent.size)).end
	var bounds := get_viewport().get_visible_rect().size
	var at := anchor + Vector2(20, 18)
	if at.x + detailPanel.size.x > bounds.x - 24:
		at.x = anchor.x - detailPanel.size.x - 20
	detailPanel.position = at.clamp(Vector2(24, 56), (bounds - detailPanel.size - Vector2(24, 44)).max(Vector2(24, 56)))

func _layout_talent_tree() -> void:
	# CanvasLayer 与所有交互元素使用同一套视口坐标。
	transform = Transform2D.IDENTITY
	var view := get_viewport().get_visible_rect().size
	var frame := Rect2(Vector2(24, 16), view - Vector2(48, 58))
	$Background.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	$Background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	$Background.position = frame.position
	$Background.size = frame.size
	$Background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Label.position = Vector2(view.x * 0.5 - 210, 11)
	$Label.size = Vector2(420, frame.size.y * 54.0 / 992.0)
	$Label.add_theme_font_size_override("font_size", mini(26, int(frame.size.y * 54.0 / 992.0 * 0.72)))
	close_btn.scale = Vector2.ONE
	close_btn.position = Vector2(view.x - 88, 26)
	close_btn.size = Vector2(48, 28)
	page_buttons.position = Vector2.ZERO
	var order := ["Main", "Summon", "Support", "Guard", "Attack"]
	for i in order.size():
		var button: TextureButton = page_buttons.get_node("Btn_" + order[i])
		button.scale = Vector2.ONE
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.position = Vector2(view.x * 0.5 - 220 + i * 90, 86)
		button.size = Vector2(80, 40)
		for child in button.get_children():
			if child is CanvasItem: child.hide()
		var caption: Label = button.get_node("Caption")
		caption.show()
	# One parent owns placement; the HBox owns icon/text alignment at every size.
	$PointsBadge.position = Vector2(view.x - 246, 84)
	$PointsBadge.size = Vector2(196, 44)
	pages.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	pages.position = Vector2.ZERO
	pages.size = view
	var content := Rect2(Vector2(78, 164), view - Vector2(156, 250))
	for page in pages.get_children():
		page.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		var talents: Array = page.get_talents()
		if talents.is_empty(): continue
		var bounds: Rect2 = talents[0].get_rect()
		for talent in talents: bounds = bounds.merge(talent.get_rect())
		var fit := minf(1.0, minf(content.size.x / bounds.size.x, content.size.y / bounds.size.y))
		page.scale = Vector2.ONE * fit
		page.position = content.get_center() - bounds.get_center() * fit
		page.size = bounds.end.max(Vector2.ONE)
		page.queue_redraw()
	detailPanel.size = Vector2(292, 240)
	detailPanel.self_modulate = Color.WHITE
	detailPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$DetailPanel/ColorRect.hide()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.23, 0.39, 0.97)
	style.border_color = Color(0.65, 0.78, 0.96)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	detailPanel.add_theme_stylebox_override("panel", style)
	detail_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_label.offset_left = 14
	detail_label.offset_top = 12
	detail_label.offset_right = -14
	detail_label.offset_bottom = -12
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_page(page_name: String) -> void:
	var new_page: Control = null
	var old_page := current_page
	for page in pages.get_children(): page.set_meta("keyboard_skip", str(page.name) != page_name)

	for page in pages.get_children():
		if page.name == page_name:
			new_page = page

	for button in page_buttons.get_children():
		var is_active := button.name.replace("Btn_", "Page_") == page_name
		button.button_pressed = is_active
		button.get_node("Caption").add_theme_color_override("font_color", Color(1.0, 0.91, 0.64) if is_active else Color(0.9, 0.94, 1.0))
		button.self_modulate = Color(0.87, 0.93, 1.0, 1) if is_active else Color(0.58, 0.68, 0.84, 1)

	if _page_tween: _page_tween.kill()
	_hide_talent_detail()
	for page in pages.get_children():
		page.visible = page == new_page
		page.modulate.a = 1.0
	current_page = new_page
	if new_page and old_page != new_page:
		new_page.modulate.a = 0.0
		_page_tween = create_tween()
		_page_tween.tween_property(new_page, "modulate:a", 1.0, 0.2)

	_refresh_all()


func _try_upgrade_talent(talent: TalentNode) -> void:
	if not talent.can_upgrade(talent_points):
		_show_talent_detail(talent)
		return

	GameData.talent_points -= 1
	talent_points = GameData.talent_points
	talent.add_rank()
	_show_talent_detail(talent)
	_refresh_all()

func _on_talent_removed(talent: TalentNode) -> void:
	GameData.talent_points += 1
	talent_points = GameData.talent_points
	_refresh_all()


func _refresh_all() -> void:
	talent_points = GameData.talent_points
	point_label.text = "天赋点：%d" % talent_points
	for page in pages.get_children():
		page.refresh(talent_points)

	if detail_label.text.is_empty():
		detail_label.text = "选择天赋\n\n鼠标移到天赋上查看说明，点击可消耗天赋点升级。"


func _show_talent_detail(talent: TalentNode) -> void:
	if not visible: return
	detail_label.text = talent.get_detail_text()
	_detail_talent = talent
	detailPanel.visible = true
	detailPanel.size.y = maxf(180.0, detail_label.get_minimum_size().y + 24.0)
	_position_detail()


func _hide_talent_detail() -> void:
	_detail_talent = null
	if is_instance_valid(detailPanel):
		detailPanel.visible = false

func close() -> void:
	# 断开页面信号，防止 queue_free 过程中触发回调
	for page in pages.get_children():
		if page.talent_hovered.is_connected(_show_talent_detail):
			page.talent_hovered.disconnect(_show_talent_detail)
		if page.talent_unhovered.is_connected(_hide_talent_detail):
			page.talent_unhovered.disconnect(_hide_talent_detail)
		if page.talent_pressed.is_connected(_try_upgrade_talent):
			page.talent_pressed.disconnect(_try_upgrade_talent)
		if page.talent_rank_removed.is_connected(_on_talent_removed):
			page.talent_rank_removed.disconnect(_on_talent_removed)
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://Audio/SE/003-System03.ogg")
	snd.bus = "SFX"
	get_tree().root.add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)
	closed.emit()
	queue_free()


func keyboard_page(direction: int) -> void:
	var index := pages.get_children().find(current_page)
	var target := pages.get_child(posmod(index + direction, pages.get_child_count()))
	show_page(str(target.name))
