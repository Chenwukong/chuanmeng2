extends Resource
## 剧情金符演出参数，不绑定任何角色或剧情。
@export var count: int = 48
@export var charge_duration: float = 2.8
@export var radius: float = 115.0
## 纵向符阵高度、缓慢上升速度及单个符文的长宽比例。
@export var column_height: float = 300.0
@export var rise_speed: float = 0.10
@export var rune_stretch := Vector2(0.9, 1.35)
## 分层轨道各有快慢，同层等距，避免不同速度在同一高度追尾扎堆。
@export var orbit_lanes: int = 6
@export var orbit_speed: float = 2.4
@export var slow_speed_multiplier: float = 0.45
@export var fast_speed_multiplier: float = 1.65
@export var orbit_depth: float = 0.42
@export var perspective: float = 0.22
@export var batch_count: int = 4
@export var batch_interval: float = 0.24
@export var launch_interval: float = 0.0
@export var flight_duration: float = 0.16
@export var paper_height: float = 56.0
## 每张符文的固定长短差异，以及保持数量感的侧面宽度和远处亮度。
@export var min_rune_length: float = 0.55
@export var max_rune_length: float = 1.55
@export var min_side_width: float = 0.35
@export var far_opacity: float = 0.44
@export var actor_offset := Vector2(0, -48)
@export var target_offset := Vector2(0, -40)
@export var gold := Color(1.0, 0.78, 0.22, 1.0)
@export var charge_animation: String = "attack"
@export var release_animation: String = "attack"

@export_group("地面震动")
@export var shake_enabled: bool = true
@export var charge_shake: float = 3.0
@export var release_shake: float = 14.0
@export var shake_frequency: float = 22.0
@export var burst_shake_duration: float = 0.18
