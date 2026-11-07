extends CanvasLayer

const TEXT_COLOR := Color("203958")
@onready var _location: Label = $Location
@onready var _status: Label = $Status

func _process(_delta: float) -> void:
	var container = $MapContainer
	var mode: int = 1 if container._current_map_mode else 0
	# 界面布局由场景保存；点击层只跟随编辑器设置的地图区域。
	$MinimapOverlay.position = container.position
	$MinimapOverlay.size = container.size
	$"当前地图".set_pressed_no_signal(mode == 1)
	$"世界地图".set_pressed_no_signal(mode == 0)
	var map_root = container._current_map_root
	if is_instance_valid(map_root):
		var map_name: String = map_root.map_id if not map_root.map_id.is_empty() else str(map_root.name)
		var player = map_root.get_player_node()
		if is_instance_valid(player):
			var local_pos: Vector2 = map_root.to_local(player.global_position) / 10.0
			_location.text = "%s (%d, %d)" % [map_name, int(local_pos.x), int(local_pos.y)]
	var failed: bool = mode == 1 and is_instance_valid(container._minimap_overlay) and container._minimap_overlay._navigation_error
	_status.text = "无法到达此处，请选择其他位置" if failed else ("方向键选点 · Shift+方向键平移 · Enter 寻路 · Q/E 地标 · +/- 缩放" if mode == 1 else "方向键平移 · +/- 缩放 · Tab 切换区域")
	_status.add_theme_color_override("font_color", Color("a12c34") if failed else TEXT_COLOR)
