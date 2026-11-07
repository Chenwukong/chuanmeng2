extends Resource
## 只保存测试场布置和播放偏好，不属于正式剧情数据。
@export var preview: String = "金符蓄力"
@export_range(150.0,500.0,10.0) var target_distance: float = 380.0
@export var swap_actors: bool = false
@export var loop_playback: bool = false
