# CmdButton.gd
# 战斗指令按钮 — 4帧水平精灵图，帧序：按(0) 悬(1) 常(2) _
class_name CmdButton
extends TextureButton

@export var spritesheet: Texture2D

func _ready() -> void:
	_setup_frames()
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(grab_focus)

func _setup_frames() -> void:
	if spritesheet == null: return
	var fw = spritesheet.get_width() / 4.0
	var fh = spritesheet.get_height()

	texture_normal    = _make_atlas(2, fw, fh)
	texture_pressed   = _make_atlas(0, fw, fh)
	texture_hover     = _make_atlas(1, fw, fh)
	texture_focused   = _make_atlas(1, fw, fh)
	texture_disabled  = _make_atlas(3, fw, fh)

	stretch_mode = TextureButton.STRETCH_KEEP_CENTERED

func _make_atlas(frame: int, fw: float, fh: float) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = spritesheet
	at.region = Rect2(frame * fw, 0, fw, fh)
	return at