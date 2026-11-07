# TeamPopup.gd
# 队伍列表弹窗 — 5个 Player 节点（从左到右），按队伍顺序显示队员
# sprite 用 WAS 播放朝右下角(direction 0)的待机动画；role 显示「定位/五行」；level 显示「LV:xx」
class_name TeamPopup
extends Node2D

signal closed()

@onready var _list_root: Node2D = $队伍列表

## 队员 WAS 待机动画候选文件名
const IDLE_CANDIDATES: Array[String] = ["待机.was", "idle.was", "站立.was"]
## 右下角方向（队员 WAS 只有4个方向，0=右下）
const IDLE_DIRECTION: int = 0


func _ready() -> void:
	_refresh()


## 打开弹窗（刷新并显示，阻止走路/怪物追击）
func open() -> void:
	_refresh()
	show()
	GameData.ui_blocked = true


## 关闭弹窗（恢复走路/怪物追击）
func close() -> void:
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://Audio/SE/003-System03.ogg")
	snd.bus = "SFX"
	get_tree().root.add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)
	GameData.ui_blocked = false
	hide()
	closed.emit()


## 打开时拦截输入：ESC 或鼠标点击 → 关闭
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		close()
		get_viewport().set_input_as_handled()


## 安全网：被外部销毁时也恢复 ui_blocked
func _exit_tree() -> void:
	if visible:
		GameData.ui_blocked = false


## 按队伍顺序填充 5 个 Player 节点
func _refresh() -> void:
	var all: Array = GameData.get_full_party()
	# 过滤掉主角（MAIN role 不显示）
	var members: Array = []
	for s in all:
		if s is CharacterStats and not (CharacterStats.has_role(s.role, CharacterStats.Role.MAIN)):
			members.append(s)
	for i in 5:
		var player := _list_root.get_node_or_null("Player%d" % (i + 1)) as Node2D
		if player == null:
			continue
		player.get_node("Order").text = "伙伴 %02d" % (i + 1)
		if i < members.size():
			player.visible = true
			player.get_node("Empty").hide()
			_setup_player(player, members[i])
		else:
			player.show()
			player.get_node("Empty").show()
			player.get_node("name").text = "等待伙伴加入"
			player.get_node("role").text = "尚未加入队伍"
			player.get_node("level").text = ""
			player.get_node("WASPlayer").stop()
			player.get_node("Visual/sprite").texture = null
	$MemberCount.text = "伙伴 %d / 5" % mini(members.size(), 5)

	# 统计五行人数（只包含伙伴）
	var elem_counts = {}
	for s in members:
		if s is CharacterStats:
			elem_counts[s.element] = elem_counts.get(s.element, 0) + 1
	# 更新五行人数标签
	for elem_str in ["金","木","水","火","土"]:
		var elem_node = get_node_or_null(elem_str) as Label
		if elem_node == null:
			continue
		var count_lbl = elem_node.get_node_or_null("label") as Label
		if count_lbl == null:
			continue
		var elem_val = CharacterStats.element_to_enum(elem_str)
		var count = elem_counts.get(elem_val, 0)
		count_lbl.text = str(count)
		# 颜色：2绿 3蓝 4紫 5红
		match count:
			2:
				count_lbl.modulate = Color.WHITE
				count_lbl.add_theme_color_override("font_color", Color(0.10, 0.43, 0.28))
			3:
				count_lbl.modulate = Color.WHITE
				count_lbl.add_theme_color_override("font_color", Color(0.10, 0.36, 0.65))
			4:
				count_lbl.modulate = Color.WHITE
				count_lbl.add_theme_color_override("font_color", Color(0.47, 0.24, 0.65))
			5:
				count_lbl.modulate = Color.WHITE
				count_lbl.add_theme_color_override("font_color", Color(0.65, 0.25, 0.18))
			_:
				count_lbl.modulate = Color.WHITE
				count_lbl.add_theme_color_override("font_color", Color(0.15, 0.27, 0.46))

	# 统计共鸣增益
	var active_gains = []
	var elem_cfg = {
		CharacterStats.Element.METAL: {2:"物攻:+5%", 3:"物攻:+10%", 4:"物攻:+15%", 5:"物攻:+20%"},
		CharacterStats.Element.WOOD:  {2:"治疗:+5%", 3:"治疗:+10%", 4:"治疗:+15%", 5:"治疗:+20%"},
		CharacterStats.Element.WATER: {2:"速度:+5%", 3:"速度:+10%", 4:"速度:+15%", 5:"速度:+20%"},
		CharacterStats.Element.FIRE:  {2:"法攻:+5%", 3:"法攻:+10%", 4:"法攻:+15%", 5:"法攻:+20%"},
		CharacterStats.Element.EARTH: {2:"防御:+5%", 3:"防御:+10%", 4:"防御:+15%", 5:"防御:+20%"},
	}
	for elem_val in elem_cfg:
		var count = elem_counts.get(elem_val, 0)
		if count >= 5:
			active_gains.append(elem_cfg[elem_val][5])
		elif count >= 4:
			active_gains.append(elem_cfg[elem_val][4])
		elif count >= 3:
			active_gains.append(elem_cfg[elem_val][3])
		elif count >= 2:
			active_gains.append(elem_cfg[elem_val][2])
	# 五行齐全
	var non_zero = 0
	for ev in [CharacterStats.Element.METAL, CharacterStats.Element.WOOD, CharacterStats.Element.WATER, CharacterStats.Element.FIRE, CharacterStats.Element.EARTH]:
		if elem_counts.get(ev, 0) > 0:
			non_zero += 1
	if non_zero >= 5:
		active_gains.append("全属性+10%")

	$ResonanceSummary.text = "  ·  ".join(active_gains) if not active_gains.is_empty() else "暂无共鸣 · 同五行达到2人可激活"


func _setup_player(player: Node2D, stats: CharacterStats) -> void:
	var name_lbl := player.get_node_or_null("name") as Label
	var role_lbl := player.get_node_or_null("role") as Label
	var level_lbl := player.get_node_or_null("level") as Label
	var sprite := player.get_node_or_null("Visual/sprite") as Sprite2D

	if name_lbl:
		name_lbl.text = stats.get_display_name()
	if role_lbl:
		# 定位/五行，例如 主/金、护/土
		role_lbl.text = "%s/%s" % [
			CharacterStats.role_name(stats.role),
			CharacterStats.element_name(stats.element),
		]
	if level_lbl:
		level_lbl.text = "LV:%d" % stats.level

	_play_idle(player, sprite, stats)


## 在 player 的 sprite 上播放待机动画（PNG 行走图 或 WAS）
func _play_idle(player: Node2D, sprite: Sprite2D, stats: CharacterStats) -> void:
	if sprite == null:
		return

	var was := player.get_node("WASPlayer") as WASAnimationPlayer
	was.stop()
	sprite.texture = null
	sprite.region_enabled = false
	sprite.offset = Vector2.ZERO
	# 优先 PNG 行走图：右下方向第一帧
	var png_path = "res://Graphic/Character/" + stats.character_name + "/行走.png"
	if FileAccess.file_exists(png_path):
		var tex = load(png_path) as Texture2D
		if tex:
			var frame_w = tex.get_width() / 4
			var frame_h = tex.get_height() / 4
			sprite.texture = tex
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, frame_w, frame_h)
			sprite.centered = true
			player.fit_preview()
			return

	# 回退 WAS 待机
	if stats.was_base_path.is_empty():
		return

	# 查找待机 .was 文件
	var idle_path := ""
	for candidate in IDLE_CANDIDATES:
		var p := stats.was_base_path.path_join(candidate)
		if FileAccess.file_exists(p):
			idle_path = p
			break
	if idle_path.is_empty():
		return

	was.stop()
	was.anim_files.clear()
	was.direction = IDLE_DIRECTION
	was.add_anim("idle", idle_path)
	was.load_all()
	sprite.centered = true
	was.play("idle")
	player.fit_preview()


func _on_close_button_pressed() -> void:
	close()
