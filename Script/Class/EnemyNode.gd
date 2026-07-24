# EnemyNode.gd
# 挂载到每个敌人的根节点 — 只负责表现 + 点击选中
class_name EnemyNode
extends Node2D

@onready var sprite:      Sprite2D           = $Sprite2D
@onready var click_area:  Area2D             = $Area2D
@onready var was_player:  WASAnimationPlayer = $WASAnimationPlayer
@onready var _audio_atk:  AudioStreamPlayer = $Audio_Attack
@onready var _audio_cast: AudioStreamPlayer = $Audio_Cast
@onready var _select_indicator: Sprite2D = $SelectIndicator
@onready var _png: AnimatedSprite2D = $PNG

## 是否可以被点击选中（玩家回合才允许）
var selectable: bool = false
var _current_spell_anim: String = ""
## 对应的战斗数据（供 UI 回调使用）
var battle_character: BattleCharacter = null

signal hovered(char: BattleCharacter)   ## 鼠标悬停（用于 UI 切换选中）
signal mouse_left                        ## 鼠标离开（隐藏 tooltip）

const GENERIC_CAST_SOUND: String = "res://Audio/SE/男-枪.ogg"

const COLOR_NORMAL:   Color = Color.WHITE
const COLOR_HOVER:    Color = Color(1.4, 1.4, 0.6)   # 鼠标悬停：泛黄

signal clicked(char: BattleCharacter)

func _ready() -> void:
	click_area.input_event.connect(_on_area_input_event)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	# 绑定死亡表现
	battle_character = $BattleCharacter
	battle_character.died.connect(_on_died)
	battle_character.revived.connect(_on_revived)

## 传入 WAS 文件路径，由外部在 setup 后调用
func setup_was(was_path: String) -> void:
	was_player.load_file(was_path)

# ─────────────────────────────────────────────
# 点击 / 悬停
# ─────────────────────────────────────────────
func _on_area_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if not selectable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(battle_character)
		_play_select_flash()

func _on_mouse_entered() -> void:
	if battle_character.killed_by_fire:
		return
	if selectable:
		sprite.modulate = COLOR_HOVER
		hovered.emit(battle_character)

func _on_mouse_exited() -> void:
	if battle_character.killed_by_fire:
		return
	sprite.modulate = COLOR_NORMAL
	mouse_left.emit()

## 外部调用：设置"被选中"高亮（显示浮动指示器 + 白色描边）
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

## 短暂闪白表示被击中
func play_hit_flash() -> void:
	if battle_character.killed_by_fire or battle_character.is_dead:
		return
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(3, 3, 3), 0.2)
	tween.tween_property(sprite, "modulate", COLOR_NORMAL,   0.15)
	tween.tween_property(sprite, "modulate", Color(3, 3, 3), 0.05)
	tween.tween_property(sprite, "modulate", COLOR_NORMAL,   0.15)

## 加速抖动效果
## 加速抖动效果 — 覆盖整个施法过程
var _shake_tween: Tween = null

func shake(intensity: float = 3.0, duration: float = 0.0) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	# 清除旧的自动停止计时器
	if has_meta("_shake_timer"):
		var old_timer: SceneTreeTimer = get_meta("_shake_timer")
		if old_timer and old_timer.time_left > 0:
			pass
		remove_meta("_shake_timer")
	var orig := position
	_shake_tween = create_tween()
	_shake_tween.set_loops()
	for _i in range(4):
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		_shake_tween.tween_property(self, "position", orig + offset, 0.04)
	# 自动停止
	if duration > 0:
		var tm := get_tree().create_timer(duration)
		set_meta("_shake_timer", tm)
		tm.timeout.connect(func():
			if is_instance_valid(self):
				stop_shake()
		, CONNECT_ONE_SHOT)

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
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)

## 加物防：金光闪烁
func flash_gold(times: int = 4, interval: float = 0.1) -> void:
	var tween := create_tween()
	for _i in range(times):
		tween.tween_property(sprite, "modulate", Color(1.9, 1.7, 0.2), interval * 0.5)
		tween.tween_property(sprite, "modulate", COLOR_NORMAL, interval * 0.5)

func _play_select_flash() -> void:
	# 点击反馈：短暂闪白
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2, 2, 2), 0.05)
	tween.tween_property(sprite, "modulate", COLOR_NORMAL, 0.15)

# ─────────────────────────────────────────────
# 动画
# ─────────────────────────────────────────────
func play_animation(anim_name: String) -> void:
	if _try_play_any(anim_name):
		return
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

## 回到待机
func play_idle() -> void:
	was_player.play("idle")

var _ranged_animating: bool = false

## 远程攻击 — 原地播放攻击动画（不走动），内部 await 完自动切 idle
func play_ranged_attack() -> void:
	_ranged_animating = true
	_audio_atk.play()
	await was_player.play_frames_direct("attack")
	was_player.play("idle")
	_ranged_animating = false

## 播放一次挨打动画，停住不循环
func play_hit_once() -> void:
	if battle_character.is_dead:
		return
	# 优先播 PNG 受击动画
	if _try_play_png("hurt"):
		return
	sprite.visible = true
	was_player.play("hit", false)
	# 播放 gotHit 动画精灵（如果存在）
	var hit_ani := get_node_or_null("gotHit") as AnimatedSprite2D
	if hit_ani:
		hit_ani.visible = true
		hit_ani.play("default")
		hit_ani.animation_finished.connect(func():
			hit_ani.visible = false
		, CONNECT_ONE_SHOT)

## 受击反应：闪白 + 后退一步 + 短暂停顿 + 归位 + 恢复待机
func play_hit_reaction() -> void:
	if battle_character.is_dead:
		return
	# 播放 gotHit 动画
	var hit_ani := get_node_or_null("gotHit") as AnimatedSprite2D
	if hit_ani:
		hit_ani.visible = true
		hit_ani.play("default")
		hit_ani.animation_finished.connect(func(): hit_ani.visible = false, CONNECT_ONE_SHOT)
	# 被控制时（冰冻/虚弱）只播挨打动画，不后退不归位，不回 idle
	if battle_character.is_frozen:
		battle_character.sync_freeze_anim()
		return
	if battle_character.is_weakened:
		was_player.play("hit", false)
		return
	var orig_pos = position
	was_player.play("hit", false)
	play_hit_flash()
	# 后退（敌人朝左退）
	var tween = create_tween()
	tween.tween_property(self, "position", orig_pos + Vector2(-30, -10), 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(self, "position", orig_pos, 0.001)
	await tween.finished
	# 如果在这期间已经死亡，不覆盖死亡动画
	if battle_character.is_dead:
		return
	was_player.play("idle")

## 完整攻击序列：走过去 → 攻击(同时触发目标受击) → 走回来
func play_attack_sequence(target_pos: Vector2, hit_target: Node2D = null, on_hit: Callable = Callable()) -> void:
	var _original_pos = position
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

	GameData.hit_stop()
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
	if battle_character.buffs.size() > 0:
		$BuffSprite.visible = true
	if battle_character.is_frozen:
		battle_character.show_debuff("冰封", true)
	elif battle_character.is_weakened:
		battle_character.show_debuff("虚弱")

# ─────────────────────────────────────────────
# 死亡表现
# ─────────────────────────────────────────────
func _on_died() -> void:
	selectable = false
	set_selected(false)
	var wui = get_node_or_null("WorldUI")
	if wui: wui.visible = false

	if battle_character.is_frozen:
		if battle_character.has_buff("失魂"):
			_soul_leave()
			return
		_freeze_shatter()
		return

	if battle_character.killed_by_fire:
		_charred_death()
		return

	battle_character.sync_visual()
	was_player.play("die", false)
	# 如果没有 WAS 死亡动画（大多数敌人没有），用渐隐替代
	if not was_player.is_playing():
		if battle_character.killed_by_fire:
			pass  # 已焦黑，不渐隐
		else:
			var tw := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
			tw.tween_callback(func(): visible = false)

var _shattered: bool = false

func is_shattered() -> bool:
	return _shattered

func _freeze_shatter() -> void:
	_shattered = true
	battle_character.shattered = true
	set_selected(false)

	# 隐藏所有视觉层（在碎片出现之前）
	battle_character.hide_debuff()
	$BuffSprite.visible = false
	$BuffSprite.stop()
	var wui = get_node_or_null("WorldUI")
	if wui: wui.visible = false

	sprite.visible = false
	was_player.stop()

	# 再创建碎冰粒子
	var pieces: Array = []
	for i in 12:
		var rect := ColorRect.new()
		rect.size = Vector2(randf_range(6, 18), randf_range(6, 18))
		rect.color = Color(0.7, 0.85, 1.0, 0.85)
		rect.position = Vector2(randf_range(-20, 20), randf_range(-30, 10))
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		pieces.append(rect)

	for rect in pieces:
		var tw := create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(rect, "position", rect.position + Vector2(randf_range(-100, 100), randf_range(-100, 100)), 0.6)
		tw.parallel().tween_property(rect, "rotation", randf_range(-4, 4), 0.6)
		tw.parallel().tween_property(rect, "modulate:a", 0.0, 0.6)

	await get_tree().create_timer(0.8).timeout
	visible = false

## 失魂斩杀：灵魂从身体飘出消失
func _soul_leave() -> void:
	_shattered = true
	battle_character.shattered = true
	set_selected(false)
	battle_character.hide_debuff()
	$BuffSprite.visible = false
	$BuffSprite.stop()
	var wui = get_node_or_null("WorldUI")
	if wui: wui.visible = false

	# 本体变暗停住
	sprite.modulate = Color(0.4, 0.4, 0.5, 0.7)
	was_player.stop()

	# 复制一个灵魂 Sprite 飘出
	var soul_sprite := Sprite2D.new()
	soul_sprite.texture = sprite.texture
	soul_sprite.offset = sprite.offset
	soul_sprite.modulate = Color(1, 1, 1, 0.5)
	var soul_pos := sprite.position
	soul_sprite.position = soul_pos
	sprite.position = sprite.position  # 本体留原地
	add_child(soul_sprite)

	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(soul_sprite, "position", soul_sprite.position + Vector2(-80, -100), 1.0)
	t.parallel().tween_property(soul_sprite, "modulate:a", 0.0, 1.0)
	await t.finished
	soul_sprite.queue_free()

	# 本体消散
	var fade := create_tween()
	fade.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fade.tween_property(sprite, "modulate:a", 0.0, 0.6)
	await fade.finished
	visible = false

func _on_revived() -> void:
	if _shattered:
		return
	var wui = get_node_or_null("WorldUI")
	if wui: wui.visible = true
	sprite.modulate = COLOR_NORMAL
	was_player.play("idle")


func _charred_death() -> void:
	# 关闭头顶 UI
	var wui = get_node_or_null("WorldUI")
	if wui: wui.visible = false
	if has_node("BuffSprite"):
		$BuffSprite.visible = false

	# 先播死亡动画，播完变焦黑
	battle_character.sync_visual()
	was_player.play("die", false)
	if was_player.is_playing():
		await was_player.animation_finished
		was_player.stop()
	sprite.modulate = Color(0.12, 0.06, 0.02)


## 尝试播放 PNG 动画（支持别名：WAS 名 → PNG 后缀）
func _try_play_any(was_anim: String) -> bool:
	var suffix_map := {
		"move": "walk",
		"cast": "magic",
	}
	var suffix = suffix_map.get(was_anim, was_anim)
	if _try_play_png(suffix):
		return true
	if suffix != was_anim and _try_play_png(was_anim):
		return true
	return false


## 循环播放 PNG 动画（用于 walk/idle 等需要持续的动画）
func _play_png_loop(suffix: String) -> void:
	if _png == null or not _png.sprite_frames:
		return
	if battle_character == null or battle_character.stats == null:
		return
	var char_name := battle_character.stats.character_name
	var anim_name := char_name + suffix
	if not _png.sprite_frames.has_animation(anim_name):
		return
	_png.visible = true
	_png.animation = anim_name
	_png.frame = 0
	_png.play()
	sprite.visible = false


## 尝试播放 PNG 动画（如果有 PNG 节点且有所需动画）
func _try_play_png(anim_suffix: String) -> bool:
	if _png == null or not _png.sprite_frames:
		return false
	if battle_character == null:
		return false
	var char_name := battle_character.stats.character_name
	var anim_name := char_name + anim_suffix
	if not _png.sprite_frames.has_animation(anim_name):
		return false
	_png.visible = true
	_png.animation = anim_name
	_png.frame = 0
	_png.play()
	if not _png.sprite_frames.get_animation_loop(anim_name):
		_png.animation_finished.connect(func():
			if not is_instance_valid(_png):
				return
			var idle_anim := battle_character.stats.character_name + "idle"
			if _png.sprite_frames and _png.sprite_frames.has_animation(idle_anim):
				_png.animation = idle_anim
				_png.play()
			else:
				_png.visible = false
		, CONNECT_ONE_SHOT)
	sprite.visible = false
	return true


## 设置 PNG / WAS 模式
func set_png_mode(use_png: bool) -> void:
	if _png == null:
		return
	if battle_character == null or battle_character.stats == null:
		return
	var char_name := battle_character.stats.character_name
	var idle_anim := char_name + "idle"
	var has_png := _png.sprite_frames != null and _png.sprite_frames.has_animation(idle_anim)
	if has_png:
		sprite.visible = false
		_png.visible = true
		_png.animation = idle_anim
		_png.play()
	else:
		_png.visible = false
		sprite.visible = true
