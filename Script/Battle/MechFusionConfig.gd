extends Resource
## 数值与未来机器人素材入口。
@export_dir var robot_path: String = "res://WAS/叮咚机甲"
@export_dir var fallback_path: String = "res://WAS/机关人"
@export_range(0.0, 3.0) var beast_hp_bonus: float = 0.5
@export_range(0.0, 3.0) var bird_speed_bonus: float = 0.7
@export_range(0.1, 3.0) var base_speed_multiplier: float = 0.8
@export_range(0.1, 3.0) var attack_multiplier: float = 1.3
@export_range(0.1, 3.0) var durability_hp_ratio: float = 0.8
## 在原有合体倍率上，额外继承被消耗机甲的实时属性。
@export_range(0.0, 2.0) var mech_attack_transfer: float = 0.5
@export_range(0.0, 2.0) var mech_defense_transfer: float = 0.5
@export_range(0.0, 2.0) var beast_hp_transfer: float = 1.0
@export_range(0.0, 2.0) var bird_speed_transfer: float = 1.0
