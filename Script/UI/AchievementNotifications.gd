extends CanvasLayer
## 独立于地图和菜单的非阻塞提示，连续达成和领取按顺序显示。
@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = %NoticeTitle
@onready var _message: Label = %NoticeMessage
var _busy: bool = false
var _tween: Tween

func _ready() -> void:
	GameData.achievement_notice_requested.connect(_show_next)
	_show_next()

func _show_next() -> void:
	if _busy or GameData.achievement_notice_queue.is_empty(): return
	_busy = true
	var notice: Dictionary = GameData.achievement_notice_queue.pop_front()
	_title.text = String(notice.title)
	_message.text = notice.message
	_panel.modulate.a = 0.0
	_panel.show()
	_panel.reset_size.call_deferred()
	_tween = create_tween()
	var tween := _tween
	tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
	tween.tween_interval(3.2)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func():
		_panel.hide()
		_busy = false
		_show_next()
	)

func dismiss_all() -> void:
	if _tween: _tween.kill()
	_panel.hide()
	_busy = false
