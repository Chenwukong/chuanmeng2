extends Resource
## 可序列化的地图出口配置，供 MapData.exits 在检查器中编辑。
@export_file("*.tscn") var to_scene: String = ""
@export var to_spawn: Vector2 = Vector2.ZERO
@export var trigger_rect: Rect2 = Rect2()
