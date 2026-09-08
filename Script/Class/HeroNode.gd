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
@onready var _png: AnimatedSprite2D = $PNG
## 武器层（如果角色有配套武器 WAS 文件夹则自动创建）
var _weapon_sprite: Sprite2D = null
var _weapon_was: WASAnimationPlayer = null

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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit($BattleCharacter)

func _on_mouse_entered() -> void:
	if selectable: sprite.modulate = COLOR_HOVER
	hovered.emit($BattleCharacter)


func _on_mouse_exited() -> void:
	if selectable: sprite.modulate = COLOR_NORMAL
	mouse_left.emit()

## 检测并加载武器 WAS（如 was_base_path = "res://WAS/剑侠客" → 武器 = "res://WAS/剑侠客武器/"）
func setup_weapon(was_base: String) -> void:
	var weapon_dir := was_base.trim_suffix("/") + "武器"
	if not DirAccess.dir_exists_absolute(weapon_dir):
		return
	var idle_path := weapon_dir + "/待机.was"
	if not FileAccess.file_exists(idle_path):
		return
	# 创建武器层
	_weapon_sprite = Sprite2D.new()
	_weapon_sprite.name = "WeaponSprite"
	_weapon_sprite.centered = true
	_weapon_sprite.z_index = sprite.z_index + 1
	add_child(_weapon_sprite)

	_weapon_was = WASAnimationPlayer.new()
	_weapon_was.name = "WeaponWAS"
	_weapon_was.target_sprite = NodePath("../WeaponSprite")
	_weapon_was.direction = was_player.direction
	_weapon_was.frame_time = was_player.frame_time
	add_child(_weapon_was)

	var names := {"idle":"待机","attack":"攻击","hit":"挨打","die":"死亡","cast":"施法","defend":"防御","move":"移动","walk":"行走"}
	for anim in names:
		var p = weapon_dir + "/" + names[anim] + ".was"
		if FileAccess.file_exists(p):
			_weapon_was.add_anim(anim, p)
	_weapon_was.load_all()
	_weapon_was.play("idle")

# ─────────────────────────────────────────────
# 动画
# ─────────────────────────────────────────────
## 攻击命中特效（在敌人身上播放攻击_2.was，如果有武器文件夹）
func _spawn_hit_effect(on_target: Node2D) -> void:
	if _weapon_was == null or _weapon_was.anim_files.is_empty(): return
	# 清除旧特效避免冲突
	var old_sprite := on_target.get_node_or_null("HitEffectSprite")
	if old_sprite: old_sprite.queue_free()
	var old_was := on_target.get_node_or_null("HitEffectWAS")
	if old_was: old_was.queue_free()
	var first_path: String = _weapon_was.anim_files.values()[0]
	var weapon_dir := first_path.get_base_dir()
	var effect_path := weapon_dir.path_join("攻击_2.was")
	if not FileAccess.file_exists(effect_path): return

	var fx_sprite := Sprite2D.new()
	fx_sprite.name = "HitEffectSprite"
	fx_sprite.centered = true
	fx_sprite.z_index = 100
#	fx_sprite.scale = Vector2(0.6, 0.6)
	on_target.add_child(fx_sprite)
	fx_sprite.position.x += 50
	fx_sprite.position.y += 30
	var fx_was := WASAnimationPlayer.new()
	fx_was.name = "HitEffectWAS"
	fx_was.target_sprite = NodePath("../HitEffectSprite")
	fx_was.direction = was_player.direction
	fx_was.add_anim("hit2", effect_path)
	fx_was.load_all()
	on_target.add_child(fx_was)
	fx_was.play("hit2", false)
	fx_was.animation_finished.connect(func(_a): fx_sprite.queue_free(); fx_was.queue_free(), CONNECT_ONE_SHOT)

## 远程攻击命中特效（在敌人身上播放角色 WAS 目录下的 攻击_2.was）
func play_ranged_hit_effect(on_target: Node2D, was_base_path: String) -> void:
	var effect_path := was_base_path.trim_suffix("/") + "/攻击_2.was"
	if not FileAccess.file_exists(effect_path): return
	var fx_sprite := Sprite2D.new()
	fx_sprite.name = "HitEffectSprite"
	fx_sprite.centered = true
	fx_sprite.z_index = 100
	on_target.add_child(fx_sprite)
	fx_sprite.position.x -= 90
	fx_sprite.position.y += 20
	var fx_was := WASAnimationPlayer.new()
	fx_was.name = "HitEffectWAS"
	fx_was.target_sprite = NodePath("../HitEffectSprite")
	fx_was.add_anim("hit2", effect_path)
	fx_was.load_all()
	on_target.add_child(fx_was)
	fx_was.play("hit2", false)
	fx_was.animation_finished.connect(func(_a): fx_sprite.queue_free(); fx_was.queue_free(), CONNECT_ONE_SHOT)


## 施法特效（在施法者身上播放施法_2.was）
func _spawn_cast_effect() -> void:
	var was := get_node_or_null("WASAnimationPlayerMagicEffect") as WASAnimationPlayer
	if was == null: return
	if _weapon_was == null or _weapon_was.anim_files.is_empty(): return
	var first_path: String = _weapon_was.anim_files.values()[0]
	var eff_path := first_path.get_base_dir().path_join("施法_2.was")
	if not FileAccess.file_exists(eff_path): return

	# 指向场景里的 CastSprite
	var spr := get_node_or_null("CastSprite") as Sprite2D
	if spr == null: return
	was.target_sprite = NodePath("../CastSprite")
	was._sprite = spr
	was.stop()
	was.anim_files.clear()
	was.direction = was_player.direction
	was.frame_time = 0.15
	was.add_anim("cast2", eff_path)
	was.load_all()
	was.play("cast2", false)


func play_animation(anim_name: String) -> void:
	# PNG 优先（walk/move → 走, attack → 攻击, magic → 施法）
	if _try_play_any(anim_name):
		return
	was_player.play(anim_name, anim_name == "idle")
	if _weapon_was and _weapon_was.anim_files.has(anim_name):
		_weapon_was.play(anim_name, anim_name == "idle")

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
## 原地播放施法动画（带施法_2特效）
func play_cast_sequence(spell_name: String = "") -> void:
	_play_cast_voice()
	_current_spell_anim = spell_name
	_spawn_cast_effect()
	if not _try_play_any("cast"):
		was_player.play("cast", false)
		if _weapon_was and _weapon_was.anim_files.has("cast"):
			_weapon_was.play("cast", false)
	if not _try_play_any("cast"):
		await was_player.play_frames_direct("cast")
	else:
		await _png.animation_finished
		_try_play_any("idle")
	_current_spell_anim = ""
	was_player.play("idle")
	if _weapon_was:
		_weapon_was.play("idle")


## 远程攻击 — 原地播放攻击动画，不走动
var _ranged_animating: bool = false

## 远程攻击 — 原地播放攻击动画（不走动），内部 await 完自动切 idle
func play_ranged_attack() -> void:
	_ranged_animating = true
	_audio_atk.play()
	if _weapon_was and _weapon_was.anim_files.has("attack"):
		_weapon_was.play("attack", false)
	if not _try_play_any("attack"):
		await was_player.play_frames_direct("attack")
	else:
		await _png.animation_finished
		_try_play_any("idle")
	was_player.play("idle")
	if _weapon_was:
		_weapon_was.play("idle")
	_ranged_animating = false


## 完整攻击序列：走过去 → 攻击(同时触发目标受击) → 走回来
## on_hit: 攻击命中后、走回前的回调（用于立刻扣血+斩杀）
func play_attack_sequence(target_pos: Vector2, hit_target: Node2D = null, on_hit: Callable = Callable()) -> void:
	_original_pos = position
	_original_z = z_index
	z_index = 999
	var local_target = get_parent().to_local(target_pos)
	var approach = local_target + (position - local_target).normalized() * 30

	# 走过去（隐藏 buff/debuff 装饰）
	$BuffSprite.visible = false
	_play_png_loop("walk")
	if not _try_play_any("move"):
		was_player.play("move", false)
		if _weapon_was and _weapon_was.anim_files.has("move"):
			_weapon_was.play("move", false)
	var tween = create_tween()
	tween.tween_property(self, "position", approach, 0.35)
	tween.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	await get_tree().create_timer(0.05).timeout

	GameData.hit_stop()
	_audio_atk.play()
	if hit_target and hit_target.has_method("play_hit_reaction"):
		hit_target.play_hit_reaction()
	# 攻击命中瞬间播放法术特效（如力劈华山），播后清空避免残留到下次
	if _current_spell_anim != "" and hit_target:
		var bc = hit_target.get_node_or_null("BattleCharacter") as BattleCharacter
		if bc and bc.has_method("play_spell_effect"):
			bc.play_spell_effect(_current_spell_anim)
		_current_spell_anim = ""
	if _weapon_was and _weapon_was.anim_files.has("attack"):
		_weapon_was.play("attack", false)
	if not _try_play_any("attack"):
		await was_player.play_frames_direct("attack")
	else:
		# PNG attack: 播完等待
		await _png.animation_finished
		# attack 播完切回 idle
		_try_play_any("idle")
	if _weapon_was:
		_weapon_was.play("idle")

	# ── 攻击命中后、走回前：执行回调（扣血+斩杀） ──
	if on_hit.is_valid():
		await on_hit.call()

	# 走回来
	_play_png_loop("walk")
	if not _try_play_any("move"):
		was_player.play("move", false)
		if _weapon_was and _weapon_was.anim_files.has("move"):
			_weapon_was.play("move", false)
	tween = create_tween()
	tween.tween_property(self, "position", _original_pos, 0.3)
	tween.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_play_png_loop("idle")
	was_player.play("idle")
	z_index = _original_z
	if _weapon_was:
		_weapon_was.play("idle")
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
	_original_z = z_index
	z_index = 999
	var local_target = get_parent().to_local(target_pos)
	var approach = local_target + (position - local_target).normalized() * 30

	# 走过去（隐藏 buff/debuff 装饰）
	$BuffSprite.visible = false
	was_player.play("move", false)
	if _weapon_was and _weapon_was.anim_files.has("move"):
		_weapon_was.play("move", false)
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
		# 第一段攻击命中时播放法术特效，播后清空避免残留到下次
		if i == 0 and _current_spell_anim != "" and hit_target:
			var bc = hit_target.get_node_or_null("BattleCharacter") as BattleCharacter
			if bc and bc.has_method("play_spell_effect"):
				bc.play_spell_effect(_current_spell_anim)
			_current_spell_anim = ""
		if hit_target and hit_target.has_method("play_hit_flash"):
			hit_target.play_hit_flash()
		if hit_target:
			_spawn_hit_effect(hit_target)
			# 每刀都播 gotHit
			var hit_ani := hit_target.get_node_or_null("gotHit") as AnimatedSprite2D
			if hit_ani:
				hit_ani.visible = true
				hit_ani.play("default")
				hit_ani.animation_finished.connect(func(): hit_ani.visible = false, CONNECT_ONE_SHOT)
		if _weapon_was and _weapon_was.anim_files.has("attack"):
			_weapon_was.play("attack", false)
		await was_player.play_frames_direct("attack")
		if _weapon_was:
			_weapon_was.play("idle")
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
	if _weapon_was and _weapon_was.anim_files.has("move"):
		_weapon_was.play("move", false)
	tween = create_tween()
	tween.tween_property(self, "position", _original_pos, 0.3)
	tween.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	z_index = _original_z
	was_player.play("idle")
	if _weapon_was:
		_weapon_was.play("idle")
	if $BattleCharacter.buffs.size() > 0:
		$BuffSprite.visible = true
	if $BattleCharacter.is_frozen:
		$BattleCharacter.show_debuff("冰封", true)
	elif $BattleCharacter.is_weakened:
		$BattleCharacter.show_debuff("虚弱")

## 高速环绕突袭序列：从不同方向快速穿过敌人 N 次
func play_blitz_sequence(target_pos: Vector2, hit_target: Node2D, hit_count: int, on_hit: Callable = Callable(), skill_sound: String = "") -> void:
	_original_pos = position
	_original_z = z_index
	z_index = 999
	var local_target = get_parent().to_local(target_pos)
	var approach = local_target + (position - local_target).normalized() * 40

	# 走过去（隐藏 buff/血条/名字/蓝条/行动条 + 暗影化）
	$BuffSprite.visible = false
	var wui = get_node_or_null("WorldUI")
	if wui:
		for c in wui.get_children():
			c.visible = false
	var _orig_modulate = modulate
	modulate = Color(0.1, 0.1, 0.1, 1)
	was_player.play("move", false)
	if _weapon_was and _weapon_was.anim_files.has("move"):
		_weapon_was.play("move", false)
	var tw = create_tween()
	tw.tween_property(self, "position", approach, 0.3)
	tw.set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await get_tree().create_timer(0.05).timeout

	# 保存受击方原位
	var target_orig_pos := hit_target.position if hit_target else Vector2.ZERO
	if hit_target and hit_target.has_method("play_hit_once"):
		hit_target.play_hit_once()

	# 8 个方向的突袭路径（围绕敌人环绕）
	var dashes := [
		[Vector2(120, 0), Vector2(-120, 0)],      # 右 → 左
		[Vector2(-80, 80), Vector2(80, -80)],      # 左下 → 右上
		[Vector2(0, 100), Vector2(0, -100)],       # 下 → 上
		[Vector2(-80, -80), Vector2(80, 80)],      # 左上 → 右下
		[Vector2(-120, 0), Vector2(120, 0)],       # 左 → 右
		[Vector2(80, 80), Vector2(-80, -80)],      # 右下 → 左上
		[Vector2(0, -100), Vector2(0, 100)],       # 上 → 下
		[Vector2(80, -80), Vector2(-80, 80)],      # 右上 → 左下

	]

	# 角色攻击音效只播一次
	_audio_atk.play()

	# 预载技能音效
	var skill_player: AudioStreamPlayer = null
	if not skill_sound.is_empty() and ResourceLoader.exists(skill_sound):
		skill_player = AudioStreamPlayer.new()
		skill_player.stream = load(skill_sound)
		skill_player.bus = "SFX"
		add_child(skill_player)

	for i in mini(hit_count, dashes.size()):
		var entry = local_target + dashes[i][0]
		var exit  = local_target + dashes[i][1]
		# 每次突袭时屏幕震动
		GameData.hit_stop(0.03, 0.08, 6.0, 0.12)
		# 根据穿越方向旋转角色（突袭结束后恢复）
		var angle = rad_to_deg(atan2(exit.y - entry.y, exit.x - entry.x))
		rotation_degrees = angle
		# 瞬移到入口
		position = entry
		# 每次突袭播技能音效
		if skill_player:
			skill_player.play()
		# 闪白 + 受击
		if hit_target and hit_target.has_method("play_hit_flash"):
			hit_target.play_hit_flash()
		if hit_target:
			var hit_ani := hit_target.get_node_or_null("gotHit") as AnimatedSprite2D
			if hit_ani:
				hit_ani.visible = true
				hit_ani.frame = 0
				hit_ani.play("default")
		# 快速穿过到出口
		var dt = create_tween()
		dt.tween_property(self, "position", exit, 0.09)
		dt.set_ease(Tween.EASE_IN)
		await dt.finished
		await get_tree().create_timer(0.08).timeout

	# 攻击命中后回调（扣血）
	if on_hit.is_valid():
		await on_hit.call()

	# 敌人归位
	if hit_target:
		var rt = create_tween()
		rt.tween_property(hit_target, "position", target_orig_pos, 0.15)
		var bc: BattleCharacter = hit_target.get_node_or_null("BattleCharacter") as BattleCharacter
		if bc and (bc.is_frozen or bc.is_weakened or bc.is_dead):
			pass
		elif hit_target.has_method("play_idle"):
			hit_target.play_idle()

	# 走回来恢复旋转
	rotation_degrees = 0
	was_player.play("move", false)
	if _weapon_was and _weapon_was.anim_files.has("move"):
		_weapon_was.play("move", false)
	tw = create_tween()
	tw.tween_property(self, "position", _original_pos, 0.3)
	tw.set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	z_index = _original_z
	# 先恢复颜色再播 idle，否则看不见
	modulate = _orig_modulate
	sprite.visible = true
	_play_png_loop("idle")
	was_player.play("idle")
	if _weapon_was:
		_weapon_was.play("idle")
	if skill_player:
		skill_player.queue_free()
	if wui:
		for c in wui.get_children():
			c.visible = true
	if $BattleCharacter.buffs.size() > 0:
		$BuffSprite.visible = true
	if $BattleCharacter.is_frozen:
		$BattleCharacter.show_debuff("冰封", true)
	elif $BattleCharacter.is_weakened:
		$BattleCharacter.show_debuff("虚弱")

## 播放一次挨打动画，停住不循环
func play_hit_once() -> void:
	# 优先播 PNG 受击动画
	if _try_play_png("hurt"):
		return
	sprite.visible = true
	was_player.play("hit", false)
	if _weapon_was and _weapon_was.anim_files.has("hit"):
		_weapon_was.play("hit", false)
	# 播放 gothit 动画精灵（如果存在）
	var hit_ani := get_node_or_null("gotHit") as AnimatedSprite2D
	if hit_ani:
		hit_ani.visible = true
		hit_ani.play("default")
		hit_ani.animation_finished.connect(func():
			hit_ani.visible = false
		, CONNECT_ONE_SHOT)

## 受击反应：闪白 + 后退一步 + 短暂停顿 + 归位 + 恢复待机
func play_hit_reaction() -> void:
	if $BattleCharacter.is_dead:
		return
	# 播放 gotHit 动画
	var hit_ani := get_node_or_null("gotHit") as AnimatedSprite2D
	if hit_ani:
		hit_ani.visible = true
		hit_ani.play("default")
		hit_ani.animation_finished.connect(func(): hit_ani.visible = false, CONNECT_ONE_SHOT)
	# 被控制时（冰冻/虚弱）只播挨打动画，不后退不归位，不回 idle
	if $BattleCharacter.is_frozen:
		$BattleCharacter.sync_freeze_anim()
		if _weapon_was and _weapon_was.anim_files.has("hit"):
			_weapon_was.play("hit", false)
		return
	if $BattleCharacter.is_weakened:
		was_player.play("hit", false)
		if _weapon_was and _weapon_was.anim_files.has("hit"):
			_weapon_was.play("hit", false)
		return
	var orig_pos = position
	was_player.play("hit", false)
	if _weapon_was and _weapon_was.anim_files.has("hit"):
		_weapon_was.play("hit", false)
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
	if _weapon_was:
		_weapon_was.play("idle")

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
	if not was_player.is_playing():
		var tw := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tw.tween_callback(func(): visible = false)
	if _weapon_was and _weapon_was.anim_files.has("die"):
		_weapon_was.play("die", false)

func _on_revived() -> void:
	# 显示头顶UI
	var wui = get_node_or_null("WorldUI")
	if wui: wui.visible = true
	sprite.modulate = COLOR_NORMAL
	was_player.play("idle")

## 当前回合高亮（已禁用青色发光）
func set_active_turn(_is_active: bool) -> void:
	pass

## 重新加载 WAS 动画（变身用）
func reload_was(was_base_path: String) -> void:
	was_player.anim_files.clear()
	was_player._readers.clear()
	was_player.stop()
	var anim_names = {
		"idle":   ["待机", "idle"],
		"attack": ["攻击", "attack"],
		"hit":    ["挨打", "hit"],
		"die":    ["死亡", "die"],
		"cast":   ["施法", "cast"],
		"move":   ["移动", "move", "行走", "walk"],
	}
	for anim_name in anim_names:
		for candidate in anim_names[anim_name]:
			var full = was_base_path.path_join(candidate + ".was")
			if FileAccess.file_exists(full):
				was_player.add_anim(anim_name, full)
				break
	was_player.load_all()
	was_player.play("idle")
	setup_weapon(was_base_path)
	# 烟雾特效：用多个半透明 Sprite 扩散
	var smoke_tex := load("res://Graphic/RANDOM/shadow (2).png")
	for i in 6:
		var smoke := Sprite2D.new()
		smoke.texture = smoke_tex
		smoke.centered = true
		smoke.z_index = 150
		smoke.modulate = Color(0.5, 0.55, 0.6, 0.3)
		var dur := randf_range(0.5, 0.8)
		var start_scale := randf_range(0.2, 0.4)
		smoke.scale = Vector2(start_scale, start_scale)
		var angle := randf_range(0, TAU)
		var dist := randf_range(15, 50)
		smoke.position = Vector2(cos(angle) * dist, sin(angle) * dist - 10)
		add_child(smoke)
		var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(smoke, "scale", Vector2(2.0, 2.0) * start_scale, dur)
		tween.parallel().tween_property(smoke, "modulate:a", 0.0, dur)
		tween.tween_callback(smoke.queue_free)
	# 变身特效：放大 → 闪烁 → 缩小
	scale = Vector2(1.4, 1.4)
	play_hit_flash()
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.6)

## 受击闪白
func play_hit_flash() -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(3, 3, 3), 0.05)
	tween.tween_property(sprite, "modulate", COLOR_NORMAL,   0.15)

## 保护动画：瞬移到被保护者身前，播放挨打动画
func guard_warp(ally_global_pos: Vector2, ally_z: int) -> void:
	print("[guard_warp] called for ", name)
	_original_pos = position
	_original_z = z_index
	var local_target = get_parent().to_local(ally_global_pos)
	var front_pos = local_target + Vector2(-12, -12)
	position = front_pos
	z_index = ally_z - 1
	var played := _try_play_png("defend")
	if not played:
		sprite.visible = true
		if _weapon_was and _weapon_was.anim_files.has("defend"):
			_weapon_was.play("defend", false)
		was_player.play("defend", false)
		if not was_player.is_playing():
			was_player.play("hit", false)
	play_hit_flash()

## 保护动画：回到原位（瞬移）
func guard_return() -> void:
	position = _original_pos
	z_index = _original_z
	play_idle()


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


## 循环播放 PNG 动画（walk/idle 等需要持续的动画）
func _play_png_loop(suffix: String) -> void:
	if _png == null or not _png.sprite_frames:
		return
	var char_name = $BattleCharacter.stats.character_name
	var anim_name = char_name + suffix
	if not _png.sprite_frames.has_animation(anim_name):
		return
	_png.visible = true
	_png.animation = anim_name
	_png.frame = 0
	_png.play()
	sprite.visible = false


## 尝试播放 PNG 动画（如果有 PNG 节点且有所需动画）
## anim_suffix: "hurt" / "defend" / "idle" / "dead"
## 返回 true 表示已播放，false 表示没有 PNG 节点或动画不存在
func _try_play_png(anim_suffix: String) -> bool:
	if _png == null or not _png.sprite_frames:
		return false
	var char_name = $BattleCharacter.stats.character_name
	var anim_name = char_name + anim_suffix
	if not _png.sprite_frames.has_animation(anim_name):
		return false
	_png.visible = true
	_png.animation = anim_name
	_png.frame = 0
	_png.play()
	# 非循环动画（hurt/dead）结束时自动隐藏
	if not _png.sprite_frames.get_animation_loop(anim_name):
		# 非循环动画播完后回到 idle
		_png.animation_finished.connect(func():
			if not is_instance_valid(_png):
				return
			var idle_anim = $BattleCharacter.stats.character_name + "idle"
			if _png.sprite_frames and _png.sprite_frames.has_animation(idle_anim):
				_png.animation = idle_anim
				_png.play()
			else:
				_png.visible = false
		, CONNECT_ONE_SHOT)
	# 隐藏 WAS
	sprite.visible = false
	return true


## 回到待机动画（PNG 优先，WAS 兜底）
func play_idle() -> void:
	if _try_play_png("idle"):
		return
	sprite.visible = true
	was_player.play("idle")
	if _weapon_was:
		_weapon_was.play("idle")


## 守护动作：选择保护时播放一次防御动画
func play_guard_cast() -> void:
	if _try_play_png("defend"):
		return
	sprite.visible = true
	if _weapon_was and _weapon_was.anim_files.has("defend"):
		_weapon_was.play("defend", false)
	was_player.play("defend", false)
	if not was_player.is_playing():
		was_player.play("cast", false)


## 设置 PNG / WAS 模式
func set_png_mode(use_png: bool) -> void:
	if _png == null:
		return
	var bc = $BattleCharacter as BattleCharacter
	if bc == null or bc.stats == null:
		return
	var char_name = bc.stats.character_name
	var idle_anim = char_name + "idle"
	# 自动检测：如果 PNG 节点有匹配的 {角色名}idle 动画就启用 PNG
	var has_png := _png.sprite_frames != null and _png.sprite_frames.has_animation(idle_anim)
	if has_png:
		sprite.visible = false
		_png.visible = true
		_png.animation = idle_anim
		_png.play()
	else:
		_png.visible = false
		sprite.visible = true
