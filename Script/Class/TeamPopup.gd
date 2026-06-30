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
	var members: Array = GameData.get_full_party()  # 顺序即队伍顺序
	for i in 5:
		var player := _list_root.get_node_or_null("Player%d" % (i + 1)) as Node2D
		if player == null:
			continue
		if i < members.size():
			player.visible = true
			_setup_player(player, members[i])
		else:
			# 多出来的格子隐藏
			player.visible = false


func _setup_player(player: Node2D, stats: CharacterStats) -> void:
	var name_lbl := player.get_node_or_null("name") as Label
	var role_lbl := player.get_node_or_null("role") as Label
	var level_lbl := player.get_node_or_null("level") as Label
	var sprite := player.get_node_or_null("sprite") as Sprite2D

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


## 在 player 的 sprite 上播放 WAS 待机动画（朝右下角）
func _play_idle(player: Node2D, sprite: Sprite2D, stats: CharacterStats) -> void:
	if sprite == null or stats.was_base_path.is_empty():
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

	# 复用/创建 WASAnimationPlayer（挂在 player 下，target 指向兄弟 sprite）
	var was := player.get_node_or_null("WASPlayer") as WASAnimationPlayer
	if was == null:
		was = WASAnimationPlayer.new()
		was.name = "WASPlayer"
		was.target_sprite = NodePath("../sprite")  # 兄弟节点
		player.add_child(was)

	was.stop()
	was.anim_files.clear()
	was.direction = IDLE_DIRECTION
	was.add_anim("idle", idle_path)
	was.load_all()
	sprite.centered = true
	was.play("idle")


func _on_close_button_pressed() -> void:
	close()
