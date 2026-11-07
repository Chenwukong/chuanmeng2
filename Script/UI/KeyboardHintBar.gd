extends PanelContainer
## 固定提示布局在场景中定义；这里只更新文案与内容宽度。
@export_multiline var text: String = "Tab 菜单 · Esc 存档":
	set(value):
		if text == value: return
		text = value
		if is_node_ready(): _refresh_text()

func _ready() -> void:
	_refresh_text()

func _refresh_text() -> void:
	var content: RichTextLabel = $Row/Content
	var keys := RegEx.new()
	keys.compile("(方向键/WASD|方向键|Enter|Tab|Esc|Q/E)")
	content.text = keys.sub(text, "[color=#ffe5a0]$1[/color]", true)
	var font := content.get_theme_font("normal_font")
	content.custom_minimum_size.x = ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x) + 4
