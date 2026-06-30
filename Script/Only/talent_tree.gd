extends CanvasLayer

@export var starting_points: int = 20

@onready var page_buttons = $PageButtons
@onready var point_label: Label = $PointLabel
@onready var pages: Control = $Pages
@onready var detail_label: RichTextLabel = $DetailLabel

var talent_points: int
var current_page: Control


func _ready() -> void:
	talent_points = starting_points
	for button in page_buttons.get_children():
		button.pressed.connect(func(page_name := button.name): show_page(page_name.replace("Btn_", "Page_")))

	for page in pages.get_children():
		page.talent_hovered.connect(_show_talent_detail)
		page.talent_pressed.connect(_try_upgrade_talent)

	show_page("Page_Main")
	_refresh_all()


func show_page(page_name: String) -> void:
	for page in pages.get_children():
		page.visible = page.name == page_name
		if page.visible:
			current_page = page

	for button in page_buttons.get_children():
		button.button_pressed = button.name.replace("Btn_", "Page_") == page_name

	_refresh_all()


func _try_upgrade_talent(talent: TalentNode) -> void:
	if not talent.can_upgrade(talent_points):
		_show_talent_detail(talent)
		return

	talent_points -= 1
	talent.add_rank()
	_show_talent_detail(talent)
	_refresh_all()


func _refresh_all() -> void:
	point_label.text = "天赋点：%d" % talent_points
	for page in pages.get_children():
		page.refresh(talent_points)

	if detail_label.text.is_empty():
		detail_label.text = "[b]选择天赋[/b]\n\n鼠标移到天赋上查看说明，点击可消耗天赋点升级。"


func _show_talent_detail(talent: TalentNode) -> void:
	detail_label.text = talent.get_detail_text()
