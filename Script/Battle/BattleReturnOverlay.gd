extends CanvasLayer
## 黑幕独立于战斗场景，覆盖战斗退出和地图恢复，避免黑幕随战斗销毁后露底。
@export_range(0.0, 2.0, 0.05) var cover_duration: float = 0.4
@export_range(0.0, 2.0, 0.05) var reveal_duration: float = 0.35
var _tween: Tween

func cover() -> void:
	if is_instance_valid(_tween): _tween.kill()
	_tween = create_tween()
	_tween.tween_property($Shade, "color:a", 1.0, cover_duration)
	await _tween.finished

func hold_black() -> void:
	if is_instance_valid(_tween): _tween.kill()
	$Shade.color = Color.BLACK

func reveal() -> void:
	if is_instance_valid(_tween): _tween.kill()
	_tween = create_tween()
	_tween.tween_property($Shade, "color:a", 0.0, reveal_duration)
	await _tween.finished
	queue_free()
