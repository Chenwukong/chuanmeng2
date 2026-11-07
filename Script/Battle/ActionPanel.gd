# ActionPanel.gd
# 战斗指令面板 — 6颗精灵图按钮，选完后从右边滑出，取消/执行完滑入
class_name ActionPanel
extends Control

@onready var btn_attack:  CmdButton = $BtnAttack
@onready var btn_skill:   CmdButton = $BtnSkill
@onready var btn_item:    CmdButton = $BtnItem
@onready var btn_summon:  CmdButton = $BtnSummon
@onready var btn_guard:   CmdButton = $BtnGuard
@onready var btn_capture: CmdButton = $BtnCapture

var _btns: Array = []

## 外部回调
var _on_attack_pressed:  Callable = Callable()
var _on_skill_pressed:   Callable = Callable()
var _on_item_pressed:    Callable = Callable()
var _on_summon_pressed:  Callable = Callable()
var _on_guard_pressed:   Callable = Callable()
var _on_capture_pressed: Callable = Callable()

## 当前行动角色
var _actor: BattleCharacter = null
var _get_cooldown: Callable = Callable()
var _inventory: Inventory = null

## 弹窗信号
signal open_skill_popup(actor: BattleCharacter, get_cd_func: Callable)
signal open_item_popup(actor: BattleCharacter, inventory: Inventory)

var _click_snd: AudioStream
var _slide_tween: Tween
## 当前滑入目标 x（由 show_near 设置，默认 1000）
var _slide_target_x: float = 1000.0

func _ready() -> void:
	if ResourceLoader.exists("res://Audio/SE/001-System01.ogg"):
		_click_snd = load("res://Audio/SE/001-System01.ogg")
	_btns = [btn_attack, btn_skill, btn_item, btn_summon, btn_guard, btn_capture]
	# 初始藏在屏幕外右侧
	position.x = 3000

func _input(event: InputEvent) -> void:
	if not btn_attack.visible or btn_attack.disabled: return
	if event.is_action_pressed("ui_up"):
		_wrap_focus(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_wrap_focus(1)
		get_viewport().set_input_as_handled()

func _wrap_focus(dir: int) -> void:
	if _btns.is_empty(): return
	var idx := -1
	for i in _btns.size():
		if (_btns[i] as Control).has_focus():
			idx = i
			break
	if idx == -1: return
	var next_idx = posmod(idx + dir, _btns.size())
	(_btns[next_idx] as Control).grab_focus()

func setup(
	on_attack:   Callable, on_skill: Callable, on_item:    Callable,
	on_summon:   Callable, on_guard: Callable, on_capture: Callable,
	get_cd_func: Callable, inventory: Inventory
) -> void:
	_on_attack_pressed  = on_attack
	_on_skill_pressed   = on_skill
	_on_item_pressed    = on_item
	_on_summon_pressed  = on_summon
	_on_guard_pressed   = on_guard
	_on_capture_pressed = on_capture
	_get_cooldown        = get_cd_func
	_inventory           = inventory

	btn_attack.pressed.connect(_cmd_attack)
	btn_skill.pressed.connect(_cmd_skill)
	btn_item.pressed.connect(_cmd_item)
	btn_summon.pressed.connect(_cmd_summon)
	btn_guard.pressed.connect(_cmd_guard)
	btn_capture.pressed.connect(_cmd_capture)

func refresh(actor: BattleCharacter, interactable: bool) -> void:
	_actor = actor
	set_enabled(interactable)
	if interactable:
		slide_in()

func show_near(screen_pos: Vector2) -> void:
	_slide_target_x = screen_pos.x + 20
	var target_y := screen_pos.y - 250
	# 从目标右侧滑入（设好起始位置，slide_in 会 tween 到 _slide_target_x）
	position = Vector2(_slide_target_x + 300, target_y)

func slide_in() -> void:
	if _slide_tween: _slide_tween.kill()
	_slide_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_slide_tween.tween_property(self, "position:x", _slide_target_x, 0.2)

func slide_out() -> void:
	if _slide_tween: _slide_tween.kill()
	_slide_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
	_slide_tween.tween_property(self, "position:x", 2000, 0.12)

func set_enabled(val: bool) -> void:
	btn_attack.disabled  = not val
	btn_skill.disabled   = not val
	btn_item.disabled    = not val
	btn_summon.disabled  = not val
	btn_guard.disabled   = not val
	btn_capture.disabled = not val

# ── 按钮回调 ──

func _cmd_attack() -> void:
	_play_click()
	slide_out()
	_on_attack_pressed.call()

func _cmd_skill() -> void:
	_play_click()
	slide_out()
	open_skill_popup.emit(_actor, _get_cooldown)

func _cmd_item() -> void:
	_play_click()
	slide_out()
	open_item_popup.emit(_actor, _inventory)

func _cmd_summon() -> void:
	_play_click()
	slide_out()
	_on_summon_pressed.call()

func _cmd_guard() -> void:
	_play_click()
	slide_out()
	_on_guard_pressed.call()

func _cmd_capture() -> void:
	_play_click()
	slide_out()
	_on_capture_pressed.call()

func _play_click() -> void:
	if _click_snd:
		var ap = AudioStreamPlayer.new()
		ap.stream = _click_snd
		ap.finished.connect(ap.queue_free)
		add_child(ap)
		ap.play()
