extends Node2D

var _mount_wasp = null
var _hero_wasp = null
var _dir_idx = 0
var _speed = 200.0
var _moving = false
var _bob_t = 0.0

# 坐骑与人物基准位置
var _mount_base_y = 0.0
var _hero_base_x = 0.0
var _hero_base_y = 0.0

# ===== 调这里 =====
const HERO_RIDE_OFFSET_X = 0.0
const HERO_RIDE_OFFSET_Y = 0.0
# ==================


func _ready():
	_mount_wasp = $Mount/WASAnimationPlayer
	_hero_wasp = $二郎神/WASAnimationPlayer

	_mount_wasp.add_anim("move", "res://WAS/坐骑/坐骑-宝贝葫芦/行走.was")
	_mount_wasp.add_anim("idle", "res://WAS/坐骑/坐骑-宝贝葫芦/站立.was")
	_mount_wasp.load_all()
	_mount_wasp.play("idle")

	_hero_wasp.add_anim("idle", "res://WAS/坐骑/羽灵神-坐骑-宝贝葫芦/站立.was")
	_hero_wasp.add_anim("move", "res://WAS/坐骑/羽灵神-坐骑-宝贝葫芦/行走.was")
	_hero_wasp.load_all()
	_hero_wasp.play("idle")

	# 坐骑基准位置
	_mount_base_y = $Mount.position.y 

	# 人物相对坐骑位置
	_hero_base_x = HERO_RIDE_OFFSET_X - 10
	_hero_base_y = $Mount.position.y + HERO_RIDE_OFFSET_Y


func _process(delta):
	var dx = 0.0
	var dy = 0.0

	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dx -= 1
		dy -= 1

	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dx += 1
		dy += 1

	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		dx += 1
		dy -= 1

	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dx -= 1
		dy += 1

	if dx != 0 or dy != 0:
		var dir = Vector2(dx, dy).normalized()

		_set_dir(dir)

		global_position += dir * _speed * delta

		_bob_t += delta * 8.0

		if not _moving:
			_moving = true
			_mount_wasp.play("move", true)
			_hero_wasp.play("idle", true)
	else:
		_bob_t = 0.0

		if _moving:
			_moving = false
			_mount_wasp.play("idle")
			_hero_wasp.play("idle")

	# 浮动
	var bob = sin(_bob_t) * 4.0

	# 坐骑
	$Mount.position.y = _mount_base_y + bob

	# 人物
	$二郎神.position.x = _hero_base_x
	$二郎神.position.y = _hero_base_y + bob

	# 坐骑在后
	$Mount.z_index = -1
	$二郎神.z_index = 0


func _set_dir(dir):
	if dir.length() < 0.01:
		return

	var a = rad_to_deg(atan2(dir.y, dir.x))
	var n = 0

	if a > 0 and a <= 90:
		n = 0
	elif a > 90:
		n = 1
	elif a <= -90:
		n = 2
	else:
		n = 3

	if n != _dir_idx:
		_dir_idx = n
		_mount_wasp.direction = _dir_idx
		_hero_wasp.direction = _dir_idx
