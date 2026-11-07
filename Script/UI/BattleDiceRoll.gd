extends CanvasLayer

const Rules = preload("res://Script/Battle/OrcDiceRules.gd")
@onready var die: Control = $Root/Center/Die
@onready var shadow: Control = $Root/Center/Shadow
@onready var result_label: Label = $Root/Result
@onready var title: Label = $Root/Title
@export var rolling_title: String = "半兽人 · 扔色子"
@export var rolling_hint: String = "气运流转，静待落定……"
@export var roll_duration: float = 1.9
@export var result_duration: float = 1.0
@export var throw_start: Vector2 = Vector2(230, 60)
@export var throw_height: float = 110.0
@export var bounce_height: float = 38.0
var settled_face: int = 0
var _rolling: bool = false
var _end_angles: Vector3
var _die_origin: Vector2
var _shadow_origin: Vector2
signal roll_settled(face: int)

static func face_basis(face: int) -> Basis:
	var orientation := Basis.IDENTITY
	match face:
		2: orientation = Basis(Vector3.RIGHT, PI / 2.0)
		3: orientation = Basis(Vector3.UP, -PI / 2.0)
		4: orientation = Basis(Vector3.UP, PI / 2.0)
		5: orientation = Basis(Vector3.RIGHT, -PI / 2.0)
		6: orientation = Basis(Vector3.UP, PI)
	# 结束时结果面正对屏幕，翻滚过程仍由三轴旋转表现立体感。
	return orientation

func _set_orientation(angles: Vector3) -> void:
	die.material.set_shader_parameter("cube_basis", Basis.from_euler(angles))

func show_face(face: int) -> void:
	if _rolling: return
	die.material.set_shader_parameter("cube_basis", face_basis(clampi(face, 1, 6)))
	settled_face = clampi(face, 1, 6)

func _ready() -> void:
	_die_origin = die.position
	_shadow_origin = shadow.position
	die.pivot_offset = die.size / 2.0
	shadow.pivot_offset = shadow.size / 2.0
	show_face(1)

func _animate_throw(progress: float) -> void:
	var offset: Vector2
	var altitude: float
	if progress < 0.42:
		var u := progress / 0.42
		offset = throw_start.lerp(Vector2(78, 0), u)
		altitude = sin(u * PI) * throw_height
		offset.y -= altitude
	elif progress < 0.63:
		var u := (progress - 0.42) / 0.21
		altitude = sin(u * PI) * bounce_height
		offset = Vector2(lerpf(78.0, 29.0, u), -altitude)
	elif progress < 0.8:
		var u := (progress - 0.63) / 0.17
		altitude = sin(u * PI) * bounce_height * 0.32
		offset = Vector2(lerpf(29.0, 7.0, u), -altitude)
	else:
		var u := (progress - 0.8) / 0.2
		altitude = sin(u * PI) * 3.0
		offset = Vector2(lerpf(7.0, 0.0, 1.0 - pow(1.0 - u, 2.0)), -altitude)
	die.position = _die_origin + offset
	var size_factor := lerpf(0.72, 1.0, minf(progress / 0.42, 1.0))
	die.scale = Vector2.ONE * size_factor
	var ground_y := throw_start.y * (1.0 - minf(progress / 0.42, 1.0))
	shadow.position = _shadow_origin + Vector2(offset.x, ground_y)
	shadow.scale = Vector2.ONE * size_factor * lerpf(1.0, 0.6, altitude / throw_height)
	shadow.modulate.a = lerpf(1.0, 0.32, altitude / throw_height)
	# 空中翻转、落地后继续滚动；位置和朝向共用一个时间轴，结束时无切面。
	var spin := 1.0 - pow(1.0 - progress, 2.5)
	_set_orientation(Vector3(0.5, 0.3, 0.15).lerp(_end_angles, spin))

func roll(face: int) -> void:
	if _rolling: return
	_rolling = true
	settled_face = 0
	face = clampi(face, 1, 6)
	title.text = rolling_title
	result_label.text = rolling_hint
	# 点数由骰体朝向决定；连续旋转直接减速至结果，不再随机换面。
	_end_angles = face_basis(face).get_euler() + Vector3(TAU * 2.0, -TAU * 3.0, -TAU)
	_animate_throw(0.0)
	var tween := create_tween()
	tween.tween_method(_animate_throw, 0.0, 1.0, roll_duration)
	await tween.finished
	settled_face = face
	_rolling = false
	result_label.text = "%d 点 · %s" % [face, Rules.EFFECTS[face - 1]]
	roll_settled.emit(face)
	await get_tree().create_timer(result_duration).timeout
