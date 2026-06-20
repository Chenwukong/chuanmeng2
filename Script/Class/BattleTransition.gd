# BattleTransition.gd
# 全屏战斗转场特效 — 同一实例正向→反向循环，无缝
class_name BattleTransition
extends ColorRect

signal finished

const MODE_COUNT := 20

const MODE_NAMES: Array[String] = [
	"CRT故障", "水波扭曲", "碎片炸裂", "暗角吞噬",
	"像素溶解", "菱形收缩", "螺旋扭曲", "百叶窗",
	"波浪冲刷", "万花筒",   "墨滴晕染",
	"马赛克崩塌", "多边形炸裂", "时钟扫灭", "帷幕闭合",
	"圆环扩散", "雪花噪点", "网格透底", "光柱扫过",
	"方片飘落",
]

var _tween: Tween = null
var _layer: CanvasLayer = null
var _mode: int = 0
var _center: Vector2 = Vector2(0.5, 0.5)
var _intensity: float = 1.0
var _material: ShaderMaterial = null


static func play(parent: Node, callback: Callable = Callable()) -> BattleTransition:
	var layer := CanvasLayer.new()
	layer.layer = 100
	parent.add_child(layer)

	var bt := BattleTransition.new()
	bt.color = Color(0, 0, 0, 0)  # 透明底色，不闪光
	bt.set_anchors_preset(PRESET_FULL_RECT)
	bt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bt._layer = layer
	layer.add_child(bt)

	if callback.is_valid():
		bt.finished.connect(callback, CONNECT_ONE_SHOT)

	# 随机参数并记下来
	bt._mode = randi() % MODE_COUNT
	print("[转场特效] %s (mode=%d)" % [MODE_NAMES[bt._mode] if bt._mode < MODE_NAMES.size() else "?", bt._mode])
	bt._center = Vector2(randf_range(0.3, 0.7), randf_range(0.3, 0.7))
	bt._intensity = randf_range(0.7, 1.5)

	# 建立唯一一个 ShaderMaterial，全程复用
	bt._material = BattleTransition._make_material(bt._mode, bt._center, bt._intensity)
	bt.material = bt._material
	bt._material.set_shader_parameter("progress", 0.0)

	bt._start_tween(0.0, 1.0, false)
	return bt


## 在同一实例上反向播放 1→0，复用同一个 material，播完自动 free
## 返回 Signal 可用 await 等待
func reverse(callback: Callable = Callable()) -> Signal:
	if callback.is_valid():
		finished.connect(callback, CONNECT_ONE_SHOT)
	var sig := finished
	_start_tween(1.0, 0.0, true)
	return sig


func _start_tween(from: float, to: float, free_after: bool) -> void:
	# 杀掉旧 tween 避免冲突
	if _tween and _tween.is_valid():
		_tween.kill()

	# material 此时 progress == from，直接在当前值基础上 tween
	_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_set_progress, from, to, randf_range(0.35, 0.6))
	if free_after:
		_tween.tween_callback(_free_self)
	else:
		_tween.tween_callback(func(): finished.emit())


func _set_progress(v: float) -> void:
	if _material:
		_material.set_shader_parameter("progress", v)


func _free_self() -> void:
	finished.emit()
	if _layer:
		_layer.queue_free()


## ═══ 震屏 ═══

static func shake_canvas(parent: Node, intensity: float = 14.0, duration: float = 0.35) -> void:
	var layers: Array[CanvasLayer] = []
	if parent is CanvasLayer:
		layers.append(parent as CanvasLayer)
	for c in parent.get_children():
		if c is CanvasLayer:
			layers.append(c as CanvasLayer)
		for gc in c.find_children("*", "CanvasLayer", true, false):
			layers.append(gc as CanvasLayer)

	var originals: Dictionary = {}
	for l in layers:
		originals[l] = l.offset

	var steps := int(duration / 0.02)
	var offsets: Array[Vector2] = []
	for i in range(steps):
		var decay := 1.0 - float(i) / steps
		offsets.append(Vector2(
			randf_range(-intensity, intensity) * decay,
			randf_range(-intensity, intensity) * decay
		))

	var tw := (layers[0] if layers.size() > 0 else parent).create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	for i in range(steps):
		tw.tween_callback(_shake_once.bind(layers, originals, offsets[i])).set_delay(0.02)
	tw.tween_callback(_shake_reset.bind(layers, originals))


static func _shake_once(layers: Array, originals: Dictionary, off: Vector2) -> void:
	for l in layers:
		if l and is_instance_valid(l):
			l.offset = originals[l] + off


static func _shake_reset(layers: Array, originals: Dictionary) -> void:
	for l in layers:
		if l and is_instance_valid(l):
			l.offset = originals[l]


## ═══ material 工厂 ═══

static func _make_material(mode: int, center: Vector2, intensity: float) -> ShaderMaterial:
	var shader := load("res://Shader/battle_transition.gdshader")
	if shader == null:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("center", center)
	mat.set_shader_parameter("intensity", intensity)
	return mat
