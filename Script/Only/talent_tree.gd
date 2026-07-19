extends CanvasLayer

signal closed

@export var starting_points: int = 20

@onready var page_buttons = $PageButtons
@onready var point_label: Label = $PointLabel
@onready var pages: Control = $Pages
@onready var detailPanel = $DetailPanel
@onready var detail_label = $DetailPanel/DetailLabel
@onready var close_btn: TextureButton = $CloseButton

var talent_points: int
var current_page: Control


func _ready() -> void:
	if !detailPanel:
		return
	detailPanel.visible = false
	detailPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	talent_points = starting_points
	close_btn.pressed.connect(close)
	for button in page_buttons.get_children():
		button.pressed.connect(func(page_name := button.name): show_page(page_name.replace("Btn_", "Page_")))

	for page in pages.get_children():
		page.talent_hovered.connect(_show_talent_detail)
		page.talent_unhovered.connect(_hide_talent_detail)
		page.talent_pressed.connect(_try_upgrade_talent)
		page.talent_rank_removed.connect(_on_talent_removed)

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

	if not is_instance_valid(detailPanel) or not detailPanel.visible:
		return
		var mouse_pos := get_viewport().get_mouse_position()
		var view_w := get_viewport().get_visible_rect().size.x
		if mouse_pos.x < view_w * 0.5:
			detailPanel.global_position = mouse_pos + Vector2(detailPanel.size.x + 30, -120)
		else:
			detailPanel.global_position = mouse_pos + Vector2(200 - detailPanel.size.x , -120)


func show_page(page_name: String) -> void:
	var new_page: Control = null
	var old_page := current_page

	for page in pages.get_children():
		if page.name == page_name:
			new_page = page

	for button in page_buttons.get_children():
		var is_active := button.name.replace("Btn_", "Page_") == page_name
		button.button_pressed = is_active
		button.self_modulate = Color(1, 0.8, 0.1, 1) if is_active else Color(0.5, 0.5, 0.5, 1)

	if old_page and new_page and old_page != new_page:
		# 淡出旧页，淡入新页
		new_page.visible = true
		new_page.modulate.a = 0
		current_page = new_page
		var tw := create_tween().set_parallel(true)
		tw.tween_property(old_page, "modulate:a", 0.0, 0.35)
		tw.tween_property(new_page, "modulate:a", 1.0, 0.35)
		tw.chain().tween_callback(func():
			old_page.visible = false
			old_page.modulate.a = 1
		)
	else:
		for page in pages.get_children():
			page.visible = page.name == page_name
		current_page = new_page

	_refresh_all()


func _try_upgrade_talent(talent: TalentNode) -> void:
	if not talent.can_upgrade(talent_points):
		_show_talent_detail(talent)
		return

	talent_points -= 1
	talent.add_rank()
	_show_talent_detail(talent)
	_refresh_all()

func _on_talent_removed(talent: TalentNode) -> void:
	talent_points += 1
	_refresh_all()


func _refresh_all() -> void:
	point_label.text = "天赋点：%d" % talent_points
	for page in pages.get_children():
		page.refresh(talent_points)

	if detail_label.text.is_empty():
		detail_label.text = "选择天赋\n\n鼠标移到天赋上查看说明，点击可消耗天赋点升级。"


func _show_talent_detail(talent: TalentNode) -> void:
	if not visible: return
	detail_label.text = talent.get_detail_text()
	var mouse_pos := get_viewport().get_mouse_position()
	var view_w := get_viewport().get_visible_rect().size.x
	if mouse_pos.x < view_w * 0.5:
		detailPanel.global_position = mouse_pos + Vector2(330, -120)
	else:
		detailPanel.global_position = mouse_pos + Vector2(200 - detailPanel.size.x, -120)
	detailPanel.visible = true


func _hide_talent_detail() -> void:
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
