# LanternDisplay.gd
# 点天灯显示组件 — 挂在角色节点下，管理灯笼 TCP 显示
class_name LanternDisplay
extends Node2D

const MAX_LANTERNS := 3
const TCP_PATH := "res://TCP/UI/31205.tcp"

var _lantern_count: int = 0
var _lantern_sprites: Array[Sprite2D] = []


func _ready() -> void:
	# 预创建 3 个灯笼 Sprite2D
	var tex = _load_tcp_texture()
	if tex == null:
		push_error("[LanternDisplay] TCP 加载失败: " + TCP_PATH)
		return
	for i in MAX_LANTERNS:
		var spr = Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(0.3, 0.3)
		spr.position = Vector2(-15 + i * 22, -175)
		spr.z_index = 100
		spr.visible = false
		add_child(spr)
		_lantern_sprites.append(spr)


## 添加一个灯笼，满 3 个返回 true 触发回血
func add_lantern() -> bool:
	if _lantern_count >= MAX_LANTERNS:
		return false
	if _lantern_count < _lantern_sprites.size():
		_lantern_sprites[_lantern_count].visible = true
	_lantern_count += 1
	return _lantern_count >= MAX_LANTERNS


## 清除所有灯笼
func clear_lanterns() -> void:
	_lantern_count = 0
	for spr in _lantern_sprites:
		spr.visible = false


func get_lantern_count() -> int:
	return _lantern_count


func _load_tcp_texture() -> Texture2D:
	if not FileAccess.file_exists(TCP_PATH):
		push_error("[LanternDisplay] TCP 文件不存在: " + TCP_PATH)
		return null
	var reader = TcpReader.new()
	if not reader.load_from_file(TCP_PATH):
		push_error("[LanternDisplay] TCP 加载失败")
		return null
	var d = reader.decode_frame(0)
	if d.is_empty() or not d.has("texture"):
		push_error("[LanternDisplay] TCP 解码失败")
		return null
	return d.texture
