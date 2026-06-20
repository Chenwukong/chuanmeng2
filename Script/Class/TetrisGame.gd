# TetrisGame.gd
# 俄罗斯方块 — block.png 1行7帧作为颜色基底
extends CanvasLayer

signal closed

const COLS = 10
const ROWS = 20
var cell_size = 32

const SHAPES = [
	[Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,0)],
	[Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)],
	[Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(1,1)],
	[Vector2i(0,0), Vector2i(1,0), Vector2i(1,1), Vector2i(2,1)],
	[Vector2i(1,0), Vector2i(2,0), Vector2i(0,1), Vector2i(1,1)],
	[Vector2i(0,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1)],
	[Vector2i(2,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1)],
]

enum State { IDLE, PLAYING, OVER }
var state = State.IDLE
var score = 0
var lines = 0
var level = 1
var tick_interval = 0.5

var timer: Timer
var block_tex: Texture2D
var board_data = PackedInt32Array()
var static_sprites = []
var active_cells = []
var active_pivot = Vector2i(0, 0)
var shape_idx = 0
var rotations = 0
var next_shape = 0
var next_frames = []
var preview_sprites = []
var ghost_sprites = []
var active_sprites = []
var input_cooldown = 0.0

var board_node: Node2D
var preview_node: Node2D
var score_label: Label
var lines_label: Label
var level_label: Label
var status_label: Label


func _init():
	var tex = load("res://Graphic/UI/block.png") as Texture2D
	if tex:
		block_tex = tex
		cell_size = tex.get_width() / 7


func _ready():
	_build_ui()
	_show_status("按 Enter 开始")
	timer = Timer.new()
	timer.one_shot = false
	timer.wait_time = tick_interval
	timer.timeout.connect(_on_tick)
	add_child(timer)
	timer.start()


func _build_ui():
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var bw = COLS * cell_size
	var bh = ROWS * cell_size
	var lx = 500
	var ty = 30

	var bb = ColorRect.new()
	bb.color = Color(0.05, 0.05, 0.08, 0.85)
	bb.size = Vector2(bw, bh)
	bb.position = Vector2(lx, ty)
	add_child(bb)

	board_node = Node2D.new()
	board_node.position = Vector2(lx, ty)
	add_child(board_node)

	for x in range(COLS + 1):
		var gl = ColorRect.new()
		gl.color = Color(1, 1, 1, 0.04)
		gl.size = Vector2(1, bh)
		gl.position = Vector2(lx + x * cell_size, ty)
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(gl)
	for y in range(ROWS + 1):
		var gl = ColorRect.new()
		gl.color = Color(1, 1, 1, 0.04)
		gl.size = Vector2(bw, 1)
		gl.position = Vector2(lx, ty + y * cell_size)
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(gl)

	var rx = lx + bw + 30
	preview_node = Node2D.new()
	preview_node.position = Vector2(rx, ty + 30)
	add_child(preview_node)
	var nl = Label.new()
	nl.text = "NEXT"
	nl.position = Vector2(rx, ty + 5)
	add_child(nl)

	score_label = Label.new()
	score_label.position = Vector2(rx, ty + 110)
	add_child(score_label)
	lines_label = Label.new()
	lines_label.position = Vector2(rx, ty + 135)
	add_child(lines_label)
	level_label = Label.new()
	level_label.position = Vector2(rx, ty + 160)
	add_child(level_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color.YELLOW)
	status_label.position = Vector2(lx + bw / 2 - 100, ty + bh / 2 - 30)
	add_child(status_label)


func _show_status(t: String):
	status_label.text = t
	status_label.visible = not t.is_empty()


# ════════════════════════════
# 方块逻辑
# ════════════════════════════

func _start_game():
	_clear_board()
	score = 0; lines = 0; level = 1
	tick_interval = 0.5; timer.wait_time = tick_interval
	_update_labels()
	_show_status("")
	next_shape = randi() % 7
	_regenerate_next_frames()
	_draw_preview()
	if _activate_next():
		state = State.PLAYING
	else:
		state = State.OVER
		_show_status("GAME OVER\n按 Enter 重来")


func _activate_next() -> bool:
	shape_idx = next_shape
	rotations = 0
	active_cells.clear()

	var frames = next_frames.duplicate()
	if frames.size() != 4:
		frames = [shape_idx, shape_idx, shape_idx, shape_idx]

	var cells = _rotated_cells(shape_idx, 0)
	# 出生位置：顶部居中
	var left = (COLS - _piece_width(shape_idx, 0)) / 2
	active_pivot = Vector2i(left, 0)

	for i in range(4):
		var pos = active_pivot + cells[i]
		active_cells.append({"pos": pos, "frame": frames[i]})

	if _collides():
		return false

	_draw_active()
	_update_ghost()
	next_shape = randi() % 7
	_regenerate_next_frames()
	_draw_preview()
	return true


func _piece_width(shape: int, rot: int) -> int:
	var cells = _rotated_cells(shape, rot)
	var min_x = 9999; var max_x = -9999
	for c in cells:
		if c.x < min_x: min_x = c.x
		if c.x > max_x: max_x = c.x
	return max_x - min_x + 1


func _regenerate_next_frames():
	next_frames.clear()
	if next_shape == 1:
		for _i in range(4):
			next_frames.append(randi() % 7)
	else:
		for _i in range(4):
			next_frames.append(next_shape)


func _rotated_cells(shape: int, rot: int) -> Array:
	var cells = SHAPES[shape].duplicate()
	if shape == 1:  # O 不旋转
		return cells

	for _r in range(rot % 4):
		var nc = []
		for v in cells:
			nc.append(Vector2i(v.y, -v.x))
		# 归一化：移到正坐标
		var min_x = 9999; var min_y = 9999
		for v in nc:
			if v.x < min_x: min_x = v.x
			if v.y < min_y: min_y = v.y
		for i in range(nc.size()):
			nc[i] = Vector2i(nc[i].x - min_x, nc[i].y - min_y)
		cells = nc
	return cells


func _rotate_piece():
	if shape_idx == 1: return
	var new_rot = (rotations + 1) % 4
	var new_cells = _rotated_cells(shape_idx, new_rot)

	for kick in [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(-2,0), Vector2i(2,0)]:
		var ok = true
		var test = []
		for i in range(4):
			var p = active_pivot + new_cells[i] + kick
			if not _free(p):
				ok = false
				break
			test.append(p)
		if ok:
			rotations = new_rot
			for i in range(4):
				active_cells[i]["pos"] = test[i]
			_draw_active()
			_update_ghost()
			return


func _move(dx: int, dy: int) -> bool:
	for cell in active_cells:
		if not _free(cell["pos"] + Vector2i(dx, dy)):
			return false
	for cell in active_cells:
		cell["pos"] = cell["pos"] + Vector2i(dx, dy)
	active_pivot = active_pivot + Vector2i(dx, dy)
	_draw_active()
	_update_ghost()
	return true


func _hard_drop():
	while _move(0, 1):
		score += 2
	_lock()


func _free(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= COLS: return false
	if pos.y >= ROWS: return false
	if pos.y < 0: return true
	return board_data[pos.y * COLS + pos.x] == -1


func _collides() -> bool:
	for cell in active_cells:
		if not _free(cell["pos"]):
			return true
	return false


func _lock():
	# 清除活跃 sprite，马上要锁定了
	for s in active_sprites:
		if is_instance_valid(s): s.queue_free()
	active_sprites.clear()
	for cell in active_cells:
		var p = cell["pos"]
		if p.y < 0:
			_game_over()
			return
		board_data[p.y * COLS + p.x] = cell["frame"]
	_sync_board_sprites()
	score += 10
	_check_lines()

	if not _activate_next():
		_game_over()


func _game_over():
	state = State.OVER
	_show_status("GAME OVER\n按 Enter 重来")


func _clear_board():
	board_data.resize(COLS * ROWS)
	board_data.fill(-1)
	for s in static_sprites:
		if is_instance_valid(s): s.queue_free()
	static_sprites.clear()
	for s in ghost_sprites:
		if is_instance_valid(s): s.queue_free()
	ghost_sprites.clear()
	for s in active_sprites:
		if is_instance_valid(s): s.queue_free()
	active_sprites.clear()
	for s in preview_sprites:
		if is_instance_valid(s): s.queue_free()
	preview_sprites.clear()


func _sync_board_sprites():
	# 全量重建静态精灵（和 board_data 保持一致）
	for s in static_sprites:
		if is_instance_valid(s): s.queue_free()
	static_sprites.clear()

	for y in range(ROWS):
		for x in range(COLS):
			var f = board_data[y * COLS + x]
			if f >= 0:
				var spr = Sprite2D.new()
				spr.texture = block_tex
				spr.hframes = 7
				spr.frame = f
				spr.centered = false
				spr.position = Vector2(x * cell_size, y * cell_size)
				board_node.add_child(spr)
				static_sprites.append(spr)


## 绘制当前下坠中的方块
func _draw_active():
	for s in active_sprites:
		if is_instance_valid(s): s.queue_free()
	active_sprites.clear()

	for cell in active_cells:
		var spr = Sprite2D.new()
		spr.texture = block_tex
		spr.hframes = 7
		spr.frame = cell["frame"]
		spr.centered = false
		spr.position = Vector2(cell["pos"].x * cell_size, cell["pos"].y * cell_size)
		board_node.add_child(spr)
		active_sprites.append(spr)


func _update_ghost():
	for s in ghost_sprites:
		if is_instance_valid(s): s.queue_free()
	ghost_sprites.clear()

	# 复制当前方块到底部
	var gp = []
	for c in active_cells:
		gp.append(c["pos"])

	while true:
		var ok = true
		for p in gp:
			if not _free(p + Vector2i(0, 1)):
				ok = false
				break
		if not ok: break
		for i in range(gp.size()):
			gp[i] = gp[i] + Vector2i(0, 1)

	for i in range(gp.size()):
		var spr = Sprite2D.new()
		spr.texture = block_tex
		spr.hframes = 7
		spr.frame = active_cells[i]["frame"]
		spr.modulate = Color(1, 1, 1, 0.2)
		spr.centered = false
		spr.position = Vector2(gp[i].x * cell_size, gp[i].y * cell_size)
		board_node.add_child(spr)
		ghost_sprites.append(spr)


func _draw_preview():
	for s in preview_sprites:
		if is_instance_valid(s): s.queue_free()
	preview_sprites.clear()

	var cells = SHAPES[next_shape]
	for i in range(4):
		var spr = Sprite2D.new()
		spr.texture = block_tex
		spr.hframes = 7
		spr.frame = next_frames[i] if i < next_frames.size() else 0
		spr.centered = false
		spr.position = Vector2(cells[i].x * cell_size, cells[i].y * cell_size)
		preview_node.add_child(spr)
		preview_sprites.append(spr)


# ════════════════════════════
# 消行
# ════════════════════════════

func _check_lines():
	var cleared = 0
	var y = ROWS - 1
	while y >= 0:
		var full = true
		for x in range(COLS):
			if board_data[y * COLS + x] == -1:
				full = false
				break
		if full:
			cleared += 1
			for yy in range(y, 0, -1):
				for x in range(COLS):
					board_data[yy * COLS + x] = board_data[(yy - 1) * COLS + x]
			for x in range(COLS):
				board_data[x] = -1
		else:
			y -= 1

	if cleared > 0:
		match cleared:
			1: score += 100
			2: score += 300
			3: score += 500
			4: score += 800
		lines += cleared
		level = lines / 10 + 1
		tick_interval = max(0.05, 0.5 - (level - 1) * 0.04)
		timer.wait_time = tick_interval
		_sync_board_sprites()
		_update_labels()


func _update_labels():
	score_label.text = "分数: %d" % score
	lines_label.text = "行数: %d" % lines
	level_label.text = "等级: %d" % level


# ════════════════════════════
# 输入 & Tick
# ════════════════════════════

func _on_tick():
	if state != State.PLAYING: return
	if not _move(0, 1):
		_lock()


func _input(event: InputEvent):
	if state == State.IDLE or state == State.OVER:
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER):
			_start_game()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return

	if state != State.PLAYING: return

	if event.is_action_pressed("ui_up"):
		_rotate_piece()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_hard_drop()
		get_viewport().set_input_as_handled()


func _process(delta: float):
	if state != State.PLAYING: return

	if input_cooldown > 0:
		input_cooldown -= delta
		return

	var dx = 0; var dy = 0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A): dx = -1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): dx = 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S): dy = 1

	if dx != 0 or dy != 0:
		if _move(dx, dy):
			if dy > 0: score += 1
			input_cooldown = 0.06
			_update_labels()


func close():
	queue_free()
	closed.emit()
