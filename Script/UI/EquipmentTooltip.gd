extends RichTextLabel

# 与宠物资质保持相同顺序和配色：丁灰、丙绿、乙蓝、甲红、特金。
@export var quality_colors: Array[Color] = [
	Color(0.6, 0.6, 0.6), Color(0.3, 0.8, 0.3), Color(0.3, 0.5, 1.0),
	Color(1.0, 0.3, 0.3), Color(1.0, 0.85, 0.2),
]

func display_icon(equipment: Dictionary, texture: Texture2D) -> void:
	# 图标占独立顶部区域，正文通过内边距避让，不再靠空行占位。
	remove_theme_stylebox_override("normal")
	var body_style := get_theme_stylebox("normal").duplicate() as StyleBox
	body_style.content_margin_top = 88.0 if not equipment.is_empty() else 12.0
	add_theme_stylebox_override("normal", body_style)
	$IconFrame.visible = not equipment.is_empty()
	$QualityLabel.visible = not equipment.is_empty()
	if equipment.is_empty():
		return
	$IconFrame/Icon.texture = texture
	$IconFrame/Fallback.visible = texture == null
	var quality := clampi(int(equipment.get("quality", 0)), 0, quality_colors.size() - 1)
	var frame := $IconFrame.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	frame.border_color = quality_colors[quality]
	$QualityLabel.text = ["丁", "丙", "乙", "甲", "特"][quality]
	$QualityLabel.add_theme_color_override("font_color", quality_colors[quality])
	$IconFrame.add_theme_stylebox_override("panel", frame)
