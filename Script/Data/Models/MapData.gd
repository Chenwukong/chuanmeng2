# MapData.gd
# 每张地图的配置数据 — 拖拽到场景的 MapRoot 节点上填写即可
extends Resource
class_name MapData
const MapExit = preload("res://Script/Data/Models/MapExit.gd")

@export var map_name: String = "未命名地图"
@export var bg_image: Texture2D           # 背景图
@export var bg_scale: Vector2 = Vector2.ONE

## 入口点（玩家生在这个位置，全局坐标）
@export var spawn_point: Vector2 = Vector2.ZERO

## 连接的地图（入口位置 → 目标场景路径）
@export var exits: Array[MapExit] = []

