# HeroNode.gd
# 挂载到每个我方角色的根节点 — 只负责表现
class_name HeroNode
extends Node2D

@onready var sprite:      Sprite2D           = $Sprite2D
@onready var was_player:  WASAnimationPlayer = $WASAnimationPlayer
@onready var click_area:  Area2D             = $Area2D
@onready var _audio_atk:  AudioStreamPlayer = $Audio_Attack
@onready var _audio_cast: AudioStreamPlayer = $Audio_Cast
@onready var _select_indicator: Sprite2D = $SelectIndicator

## 是否可被点击（选保护目标时）
var selectable: bool = false
var _current_spell_anim: String = ""

signal clicked(char: BattleCharacter)
signal hovered(char: BattleCharacter)
signal mouse_left

const GENERIC_CAST_SOUND: String = "res://Audio/SE/男-枪.ogg"

const COLOR_NORMAL: Color = Color.WHITE
const COLOR_ACTIVE: Color = Color(0.6, 1.4, 1.4)
const COLOR_HOVER:  Color = Color(1.4, 1.4, 0.6)

var _original_pos: Vector2 = Vector2.ZERO
var _original_z: int = 0

func _ready() -> void:
	click_area.input_event.connect(_on_area_input_event)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	$BattleCharacter.died.connect(_on_died)
	$BattleCharacter.revived.connect(_on_revived)
	_original_pos = position

func _on_area_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if not selectable: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit($BattleCharacter)

func _on_mouse_entered() -> void:
	if selectable: sprite.modulate = COLOR_HOVER
	hovered.emit($BattleCharacter)


func _on_mouse_exited() -> void:
	if selectable: sprite.modulate = COLOR_NORMAL
	mouse_left.emit()

## 传入 WAS 文件路径，由外部在 setup 后调用
func setup_was(was_path: String) -> void:
	was_player.load_file(was_path)

# ─────────────────────────────────────────────
# 动画
# ─────────────────────────────────────────────
func play_animation(anim_name: String) -> void:
	was_player.play(anim_name, anim_name == "idle")

## 播放施法音效（降级：施法音效→攻击音效→通用音效）
func _play_cast_voice() -> void:
	var cast = _audio_cast.stream
	if cast != null:
		_audio_cast.play()
		return
	# 降级到攻击音效
	var atk = _audio_atk.stream
	if atk != null:
		_audio_atk.play()
		return
	# 都没有就播通用
	if ResourceLoader.exists(GENERIC_CAST_SOUND):
		_audio_cast.stream = load(GENERIC_CAST_SOUND)
		_audio_cast.play()

## 原地播放 WAS 施法动作（不放法术特效）
## spell_name 仅用于记录，不在此方法显示 Animation sprite
func play_cast_sequence(spell_name: String = "") -> void:
	_play_cast_voice()
	_current_spell_anim = spell_name
	was_player.play("cast", false)
	await was_player.play_frames_direct("cast")
	_current_spell_anim = ""
	was_player.play("idle")


## 远程攻击 — 原地播放攻击动画，不走动
func play_ranged_attack() -> void:
	_audio_atk.play()
	was_player.play("attack", false)
	await was_player.play_frames_direct("attack")
	was_player.play("idle")


## 完整攻击序列：走过去 → 攻击(同时触发目标受击) → 走回来
## on_hit: 攻击命中后、走回前的回调（用于立刻扣血+斩杀）
func play_attack_sequence(target_pos: Vector2, hit_target: Node2D = null, on_hit: Callable = Callable()) -> void:
	_original_pos = position
	var local_target = get_parent().to_local(target_pos)
	var approach = local_target + (position - local_target).normalized() * 30

	# 走过去（隐藏 buff/debuff 装饰）
	$BuffSprite.visible = false
	was_player.play("move", false)
	var tween = create_tween()
	tween.tween_property(self, "position", approach, 0.35)
	tween.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	await get_tree().create_timer(0.05).timeout

	_audio_atk.play()
	if hit_target and hit_target.has_method("play_hit_reaction"):
		hit_target.play_hit_reaction()
	await was_player.play_frames_direct("attack")

	# ── 攻击命中后、走回前：执行回调（扣血+斩杀） ──
	if on_hit.is_valid():
		await on_hit.call()

	# 走回来
	was_player.play("move", false)
	tween = create_tween()
	tween.tween_property(self, "position", _original_pos, 0.3)
	tween.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	was_player.play("idle")
	# 恢复 buff/debuff 显示
	if $BattleCharacter.buffs.size() > 0:
		$BuffSprite.visible = true
	if $BattleCharacter.is_frozen:
		$BattleCharacter.show_debuff("冰封", true)
	elif $BattleCharacter.is_weakened:
		$BattleCharacter.show_debuff("虚弱")


## 多段攻击序列：走过去 → 连续攻击 N 次 → 走回来
## on_hit: 最后一段攻击命中后、走回前的回调（用于立刻扣血+斩杀）
func play_multihit_sequence(target_pos: Vector2, hit_target: Node2D, hit_count: int, on_hit: Callable = Callable()) -> void:
	_original_pos = position
	var local_target = get_parent().to_local(target_pos)
	var approach = local_target + (position - local_target).normalized() * 30

	# 走过去（隐藏 buff/debuff 装饰）
	$BuffSprite.visible = false
	was_player.play("move", false)
	var tween = create_tween()
	tween.tween_property(self, "position", approach, 0.35)
	tween.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	await get_tree().create_timer(0.05).timeout

	# 保存受击方原位
	var target_orig_pos := hit_target.position if hit_target else Vector2.ZERO
	# 第一次挨打：启动挨打动画，之后不重调
	if hit_target and hit_target.has_method("play_hit_once"):
		hit_target.play_hit_once()

	# 连续攻击 N 次 — 每段推远一步后等待
	var push_dir := Vector2(-12, -12)
	for i in hit_count:
		_audio_atk.play()
		if hit_target and hit_target.has_method("play_hit_flash"):
			hit_target.play_hit_flash()
		await was_player.play_frames_direct("attack")
		# 攻击动画播完后才推退
		var step_target = target_orig_pos + push_dir * (i + 1)
		var pt = create_tween()
		pt.tween_property(hit_target, "position", step_target, 0.05)
		await get_tree().create_timer(0.08).timeout

	# ── 攻击命中后、走回前：执行回调（扣血+斩杀） ──
	if on_hit.is_valid():
		await on_hit.call()

	# 受击方归位 + 回到待机（已死则不覆盖死亡动画）
	if hit_target:
		var rt = create_tween()
		rt.tween_property(hit_target, "position", target_orig_pos, 0.15)
		# 冰冻/虚弱/死亡 不回 idle
		var bc: BattleCharacter = hit_target.get_node_or_null("BattleCharacter") as BattleCharacter
		if bc and (bc.is_frozen or bc.is_weakened or bc.is_dead):
			pass
		elif hit_target.has_method("play_idle"):
			hit_target.play_idle()

	# 走回来
	was_player.play("move", false)
	tween = create_tween()
	tween.tween_property(self, "position", _original_pos, 0.3)
	tween.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	was_player.play("idle")
	if $BattleCharacter.buffs.size() > 0:
		$BuffSprite.visible = true
	if $BattleCharacter.is_frozen:
		$BattleCharacter.show_debuff("冰封", true)
	elif $BattleCharacter.is_weakened:
		$BattleCharacter.show_debuff("虚弱")

## 播放一次挨打动画，停住不循环
func play_hit_once() -> void:
	was_player.play("hit", false)

## 受击反应：闪白 + 后退一步 + 短暂停顿 + 归位 + 恢复待机
func play_hit_reaction() -> void:
	if $BattleCharacter.is_dead:
		return
	# 被控制时（冰冻/虚弱）只播挨打动画，不后退不归位，不回 idle
	if $BattleCharacter.is_frozen or $BattleCharacter.is_weakened:
		was_player.play("hit", false)
		return
	var orig_pos = position
	was_player.play("hit", false)
	play_hit_flash()
	# 后退（我方朝右退）
	var tween = create_tween()
	tween.tween_property(self, "position", orig_pos + Vector2(15, 0), 0.1)
	tween.tween_interval(1.5)
	tween.tween_property(self, "position", orig_pos, 0.001)
	await tween.finished
	# 如果在这期间已经死亡，不覆盖死亡动画
	if $BattleCharacter.is_dead:
		return
	was_player.play("idle")

## 加速抖动效果 — 覆盖整个施法过程
var _shake_tween: Tween = null

func shake(intensity: float = 3.0) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	var orig := position
	_shake_tween = create_tween()
	_shake_tween.set_loops()
	for _i in range(4):
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		_shake_tween.tween_property(self, "position", orig + offset, 0.04)

## 停止抖动并归位
func stop_shake() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		_shake_tween = null
	var t := create_tween()
	t.tween_property(self, "position", position, 0.01)

## 加力量：放大 1.5 倍再缩回
func play_power_up_scale() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.4)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)

## 加物防：金光闪烁
func flash_gold(times: int = 15, interval: float = 0.1) -> void:
	var tween := create_tween()
	for _i in range(times):
		tween.tween_property(sprite, "modulate", Color(1.9, 1.7, 0.2), interval * 0.5)
		tween.tween_property(sprite, "modulate", COLOR_NORMAL, interval * 0.5)

## 选中指示器（同敌人）
func set_selected(is_selected: bool) -> void:
	if is_selected:
		_select_indicator.visible = true
		_start_indicator_float()
	else:
		_select_indicator.visible = false
		_stop_indicator_float()

var _indicator_tween: Tween = null

func _start_indicator_float() -> void:
	_stop_indicator_float()
	_indicator_tween = create_tween().set_loops()
	_indicator_tween.tween_property(_select_indicator, "position:y", -105, 0.6)
	_indicator_tween.tween_property(_select_indicator, "position:y", -95, 0.6)

func _stop_indicator_float() -> void:
	if _indicator_tween:
		_indicator_tween.kill()
		_indicator_tween = null

## 死亡表现（由 BattleCharacter.died 信号触发）
func _on_died() -> void:
	set_selected(false)
	$BattleCharacter.sync_visual()
	# 隐藏头顶血蓝条和行动条
	var wui = get_node_or_null("WorldUI")
	if wui: wui.visible = false
	was_player.play("die", false)

func _on_revived() -> void:
	# 显示头顶UI
	var wui = get_node_or_null("WorldUI")
	if wui: wui.visible = true
	sprite.modulate = COLOR_NORMAL
	was_player.play("idle")

## 当前回合高亮（已禁用青色发光）
func set_active_turn(_is_active: bool) -> void:
	pass

## 受击闪白
func play_hit_flash() -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(3, 3, 3), 0.05)
	tween.tween_property(sprite, "modulate", COLOR_NORMAL,   0.15)

## 保护动画：瞬移到被保护者身前，播放挨打动画
func guard_warp(ally_global_pos: Vector2, ally_z: int) -> void:
	_original_pos = position
	_original_z = z_index
	var local_target = get_parent().to_local(ally_global_pos)
	var front_pos = local_target + Vector2(-12, -12)
	position = front_pos
	z_index = ally_z - 1
	was_player.play("hit", false)
	play_hit_flash()

## 保护动画：回到原位（瞬移）
func guard_return() -> void:
	position = _original_pos
	z_index = _original_z
	was_player.play("idle")
