# BattleCharacter.gd
# BattleCharacter.gd
# 战斗中角色的运行时状态（HP/MP 实时值、Buff 列表等）
# 作为 fightScenePlayer 的子节点存在，直接控制头顶血条
class_name BattleCharacter
extends Node

## 基础数据引用
var stats: CharacterStats
var is_player: bool = false
var member_id: String = ""  # 玩家角色 ID（用于永久存档）
var pet_id: String = ""      # 如果是宠物，记录 pet_id
var summoner_member_id: String = ""  # 宠物/召唤物的主人 member_id（用于统计归因）
var trait_data: Dictionary = {}       # 特性运行时状态

## 运行时战斗状态
var current_hp: int = 0
var current_mp: int = 0
var shattered: bool = false  # 被碎冰击杀，不可复活

## Buff / Debuff 列表  { buff_id: { "turns": int, "value": Variant } }
var buffs: Dictionary = {}

## 状态标记
var is_dead: bool = false
var is_frozen: bool = false  # 冰冻：跳过本回合
var is_weakened: bool = false  # 虚弱：跳过本回合（横扫千军后触发）
var is_summoned_pet: bool = false  # 战斗中召唤出的宠物
var consecutive_turns: int = 0  # 连续行动次数（连续衰减用）

## 技能列表（skill_ids 来自 stats）
var book_skills: Array[String] = []  # 被动书技能（战斗中用）

## 运行时 SP（行动条 0~100）
var current_sp: float = 0.0

## 信号（供 UI 中的状态卡监听）
signal hp_changed(old_val: int, new_val: int, max_val: int)
signal mp_changed(old_val: int, new_val: int, max_val: int)
signal sp_changed(old_val: float, new_val: float, max_val: float)
signal buff_added(buff_id: String)
signal buff_removed(buff_id: String)
signal died
signal revived

## 头顶 UI（兄弟节点，setup 后才可用）
var _hp_bar:      TextureProgressBar = null
var _mp_bar:      TextureProgressBar = null
var _sp_bar:      TextureProgressBar = null
var _name_label:  Label       = null
var _hp_tween_node: Node
var _mp_tween_node: Node

# ─────────────────────────────────────────────
func setup(character_stats: CharacterStats, for_player: bool = false) -> void:
	stats = character_stats.duplicate_for_battle()
	is_player = for_player
	book_skills = stats.book_skills.duplicate()
	trait_data = stats.traits.duplicate()
	current_hp = stats.saved_hp if stats.saved_hp > 0 else get_effective_max_hp()
	current_mp = stats.saved_mp if stats.saved_mp > 0 else stats.max_mp

	# 初始化专用 tween 容器（避免 HP/MP 互相覆盖）
	if not _hp_tween_node:
		_hp_tween_node = Node.new(); _hp_tween_node.name = "HPTween"
		add_child(_hp_tween_node)
	if not _mp_tween_node:
		_mp_tween_node = Node.new(); _mp_tween_node.name = "MPTween"
		add_child(_mp_tween_node)

	# 找兄弟节点上的头顶 UI（英雄和敌人结构一致）
	var parent = get_parent()
	if parent == null: return
	_hp_bar     = parent.get_node_or_null("WorldUI/HPBar") as TextureProgressBar
	_mp_bar     = parent.get_node_or_null("WorldUI/MPBar") as TextureProgressBar
	_sp_bar     = parent.get_node_or_null("WorldUI/SPBar") as TextureProgressBar
	_name_label = parent.get_node_or_null("WorldUI/NameLabel")
	if _hp_bar:
		_hp_bar.max_value = get_effective_max_hp()
		_hp_bar.value     = current_hp
	if _mp_bar:
		_mp_bar.max_value = stats.max_mp
		_mp_bar.value     = current_mp
	if _sp_bar:
		_sp_bar.max_value = 100
		_sp_bar.value     = current_sp
	if _name_label:
		_name_label.text = stats.get_display_name()

	# 加载 WAS 动画
	if not stats.was_base_path.is_empty():
		var was = parent.get_node_or_null("WASAnimationPlayer") as WASAnimationPlayer
		if was:
			was.direction = stats.was_direction
			_register_was_anims(was, stats.was_base_path)
		# 检测武器 WAS
		if parent.has_method("setup_weapon"):
			parent.setup_weapon(stats.was_base_path)

	# 加载角色专属攻击音效
	if not stats.attack_sound_path.is_empty():
		var audio = parent.get_node_or_null("Audio_Attack") as AudioStreamPlayer
		if audio and ResourceLoader.exists(stats.attack_sound_path):
			audio.stream = load(stats.attack_sound_path)

	# 加载角色专属施法音效（喊声）
	if not stats.cast_sound_path.is_empty():
		var audio = parent.get_node_or_null("Audio_Cast") as AudioStreamPlayer
		if audio and ResourceLoader.exists(stats.cast_sound_path):
			audio.stream = load(stats.cast_sound_path)

	# 加载 Debuff/Buff 精灵帧
	_load_debuff_frames(parent)
	_load_buff_frames(parent)
	_load_spell_frames(parent)


var _debuff_container: Node2D = null  # debuff.tscn 实例
var _debuff_children: Dictionary = {}  # name -> AnimatedSprite2D

func _load_debuff_frames(parent: Node) -> void:
	var scene = load("res://Component/debuff.tscn")
	if scene == null: return
	# 删掉旧的 DebuffSprite
	var old = parent.get_node_or_null("DebuffSprite")
	if old: old.queue_free()
	# 实例化新的
	_debuff_container = scene.instantiate() as Node2D
	_debuff_container.name = "DebuffSprite"
	_debuff_children.clear()
	for child in _debuff_container.get_children():
		if child is AnimatedSprite2D:
			_debuff_children[child.name] = child
			child.visible = false
	parent.add_child(_debuff_container)


func _load_buff_frames(parent: Node) -> void:
	var scene = load("res://Component/buff.tscn")
	if scene == null: return
	var template = scene.instantiate() as AnimatedSprite2D
	var buff_sprite = parent.get_node_or_null("BuffSprite") as AnimatedSprite2D
	if buff_sprite and template and template.sprite_frames:
		buff_sprite.sprite_frames = template.sprite_frames.duplicate()
		buff_sprite.scale = template.scale
		buff_sprite.position = template.position
	template.queue_free()


func _load_spell_frames(parent: Node) -> void:
	var scene = load("res://Component/animation.tscn")
	if scene == null: return
	var template = scene.instantiate() as AnimatedSprite2D
	var spell_sprite = parent.get_node_or_null("Animation") as AnimatedSprite2D
	if spell_sprite and template and template.sprite_frames:
		spell_sprite.sprite_frames = template.sprite_frames.duplicate()
		spell_sprite.scale = template.scale
		spell_sprite.position = template.position
	template.queue_free()


## 显示 Debuff 动画（"冰封"/"虚弱"等）
func show_debuff(anim_name: String, persistent: bool = false) -> void:
	if _debuff_container == null: return
	if not persistent and _debuff_container.get_meta("persistent_debuff", false):
		return
	_debuff_container.set_meta("persistent_debuff", persistent)
	_debuff_container.visible = true
	for c in _debuff_children.values():
		c.visible = false
		c.stop()
	var target = _debuff_children.get(anim_name)
	if target:
		target.visible = true
		target.play()

func hide_debuff() -> void:
	if _debuff_container == null: return
	_debuff_container.set_meta("persistent_debuff", false)
	for c in _debuff_children.values():
		c.visible = false
		c.stop()
	_debuff_container.visible = false

func play_spell_effect(anim_name: String) -> void:
	var parent = get_parent()
	if parent == null: return
	var ss = parent.get_node_or_null("Animation") as AnimatedSprite2D
	if ss == null or not ss.sprite_frames or not ss.sprite_frames.has_animation(anim_name):
		return
	ss.stop()
	ss.sprite_frames.set_animation_loop(anim_name, false)
	ss.visible = true
	ss.play(anim_name)
	await ss.animation_finished
	ss.visible = false

## 同时播放两个法术特效（金刚护法 + 一苇渡江），调用方无需 await
func play_dual_spell_effect() -> void:
	var parent = get_parent()
	if parent == null: return
	var ss1 = parent.get_node_or_null("Animation") as AnimatedSprite2D
	if ss1 == null or not ss1.sprite_frames: return
	# 创建第二个动画精灵同时播放
	var ss2 := AnimatedSprite2D.new()
	ss2.name = "Animation_Dual"
	ss2.sprite_frames = ss1.sprite_frames
	ss2.position = ss1.position
	ss2.offset = ss1.offset
	ss2.scale = ss1.scale
	ss2.centered = ss1.centered
	parent.add_child(ss2)
	# 播放
	var has_jg = ss1.sprite_frames.has_animation("金刚护法")
	var has_yw := ss2.sprite_frames.has_animation("一苇渡江")
	if has_jg:
		ss1.stop()
		ss1.sprite_frames.set_animation_loop("金刚护法", false)
		ss1.visible = true
		ss1.play("金刚护法")
	if has_yw:
		ss2.sprite_frames.set_animation_loop("一苇渡江", false)
		ss2.visible = true
		ss2.play("一苇渡江")
	# 用 Timer 等两个都播完（避免 animation_finished 信号竞态）
	var max_frames := 0
	if has_jg:
		max_frames = maxi(max_frames, ss1.sprite_frames.get_frame_count("金刚护法"))
	if has_yw:
		max_frames = maxi(max_frames, ss2.sprite_frames.get_frame_count("一苇渡江"))
	var duration := maxi(0.5, float(max_frames) / 15.0)
	await get_tree().create_timer(duration).timeout
	ss1.visible = false
	if is_instance_valid(ss2):
		ss2.queue_free()

## 特性触发红字飘字：从角色身上浮起再消失
func show_trait_float(trait_name: String) -> void:
	var parent = get_parent()
	if parent == null: return
	var lbl := Label.new()
	lbl.text = trait_name
	lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-40, -70)
	lbl.size = Vector2(80, 30)
	parent.add_child(lbl)
	var tw := lbl.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(lbl, "position:y", lbl.position.y - 50, 1)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.5)
	tw.tween_callback(lbl.queue_free)

func show_buff(anim_name: String) -> void:
	var parent = get_parent()
	if parent == null: return
	var bs = parent.get_node_or_null("BuffSprite") as AnimatedSprite2D
	if bs == null: return
	bs.visible = true
	if bs.sprite_frames and bs.sprite_frames.has_animation(anim_name):
		bs.play(anim_name)

## 施法完毕后触发 debuff 视觉（动画已完成）
func apply_debuff_visual(buff_id: String) -> void:
	if buff_id in FREEZE_BUFF_IDS:
		sync_freeze_anim()
	elif buff_id == "weakened":
		show_debuff("虚弱")

## 刷新所有 debuff 视觉（动画完成后调用）
func refresh_debuff_visuals() -> void:
	if is_frozen:
		sync_freeze_anim()
	if is_weakened:
		show_debuff("虚弱")


func hide_buff() -> void:
	var parent = get_parent()
	if parent == null: return
	var bs = parent.get_node_or_null("BuffSprite") as AnimatedSprite2D
	if bs: bs.visible = false


## 按约定文件名注册动画
func _register_was_anims(was: WASAnimationPlayer, base_path: String) -> void:
	var dir = DirAccess.open(base_path)
	if dir == null:
		return
	# 尝试中/英文文件名，优先中文
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
			var full = base_path.path_join(candidate + ".was")
			if FileAccess.file_exists(full):
				was.add_anim(anim_name, full)
				break
	was.load_all()
	# 默认播放 idle
	was.play("idle")

# ─── HP / MP ─────────────────────────────────
func take_damage(amount: int) -> int:
	var old = current_hp
	current_hp = maxi(0, current_hp - amount)
	hp_changed.emit(old, current_hp, get_effective_max_hp())
	_tween_hp_bar()
	if current_hp == 0:
		is_dead = true
		died.emit()
	return old - current_hp  # 实际扣血量

func heal(amount: int) -> int:
	var old = current_hp
	var eff_max = get_effective_max_hp()
	current_hp = mini(eff_max, current_hp + amount)
	hp_changed.emit(old, current_hp, eff_max)
	_tween_hp_bar()
	if old == 0 and current_hp > 0:
		if shattered:
			# 碎冰击杀不可复活，强制保持死亡
			is_dead = true
			current_hp = 0
			return 0
		is_dead = false
		revived.emit()
	return current_hp - old  # 实际回复量

func use_mp(amount: int) -> bool:
	if current_mp < amount:
		return false
	current_mp -= amount
	_tween_mp_bar()
	return true

func restore_mp(amount: int) -> void:
	current_mp = mini(stats.max_mp, current_mp + amount)
	_tween_mp_bar()

## 动画结束后统一同步视觉（头顶条 + 面板信号）
func sync_visual() -> void:
	var eff_max_hp = get_effective_max_hp()
	_update_hp_bar()
	_update_mp_bar()
	# 面板通过信号同步，但不要覆盖头顶正在跑的 tween
	hp_changed.emit(current_hp, current_hp, eff_max_hp)
	mp_changed.emit(current_mp, current_mp, stats.max_mp)

func _update_hp_bar() -> void:
	if _hp_bar:
		_hp_bar.max_value = get_effective_max_hp()

## 平滑 tween 血条数值变化（加血/扣血/扣蓝/回蓝）
func _tween_hp_bar() -> void:
	if not _hp_bar: return
	var tw = _hp_tween_node.create_tween().set_ease(Tween.EASE_OUT)
	tw.tween_property(_hp_bar, "value", float(current_hp), 0.25)

func _tween_mp_bar() -> void:
	if not _mp_bar: return
	var tw = _mp_tween_node.create_tween().set_ease(Tween.EASE_OUT)
	tw.tween_property(_mp_bar, "value", float(current_mp), 0.25)


## 播放加血上限的胀缩动画（变大 → 暂停 → 更新上限 → 缩小）
func play_hp_up_effect() -> void:
	if not _hp_bar: return
	var orig_scale = _hp_bar.scale
	var tw = create_tween().set_ease(Tween.EASE_OUT)
	tw.tween_property(_hp_bar, "scale", Vector2(1.8, 1.5), 0.2)
	await tw.finished
	await get_tree().create_timer(0.1).timeout
	# 此时更新血条上限（视觉上在极限大小处生效）
	sync_visual()
	tw = create_tween().set_ease(Tween.EASE_IN)
	tw.tween_property(_hp_bar, "scale", orig_scale, 0.3)

func _update_mp_bar() -> void:
	if _mp_bar:
		_mp_bar.max_value = stats.max_mp

func _update_sp_bar() -> void:
	if _sp_bar:
		_sp_bar.value = current_sp

## SP 行动条积累，返回是否已满（>=100）
func accumulate_sp(delta: float) -> bool:
	if is_dead:
		return false
	# 已满 = 等待行动，不再积累但仍报告 ready
	if current_sp >= 100.0:
		return true
	var old = current_sp
	var rate = 5.0 + get_effective_speed() * 0.8  # 速度越快积累越快
	# 连续行动衰减：第二回合 -20%，第三回合 -40%，以此类推
	if consecutive_turns > 1:
		rate *= maxf(0.2, 1.0 - 0.2 * (consecutive_turns - 1))
	current_sp += rate * delta
	if current_sp > 100.0:
		current_sp = 100.0
	sp_changed.emit(old, current_sp, 100.0)
	_update_sp_bar()
	return current_sp >= 100.0

## 回合开始时清零 SP
func reset_sp() -> void:
	current_sp = 0.0
	_update_sp_bar()
	sp_changed.emit(100.0, 0.0, 100.0)

## 冻结类 buff ID 列表
const FREEZE_BUFF_IDS: Array[String] = ["frozen", "freeze", "冰封", "失魂"]
const DEBUFF_IDS: Array[String] = ["poison", "burn", "slow", "def_broken", "atk_down", "frozen", "freeze", "冰封", "失魂", "weakened"]

# ─── BUFF 系统（分层叠加，max 3 层，同源不重复） ───
const MAX_BUFF_LAYERS := 3
## 添加 Buff，turns=-1 表示永久，source 为技能名（空=不追踪来源）
func add_buff(buff_id: String, turns: int, value: Variant = null, source: String = "") -> void:
	# 神迹：免疫/抵抗异常状态
	if buff_id in DEBUFF_IDS:
		if is_immune_to_debuffs():
			return
		var resist = get_debuff_resist_chance()
		if resist > 0 and randf() < resist:
			return
	if not buffs.has(buff_id):
		buffs[buff_id] = { "layers": [] }
	var layers: Array = buffs[buff_id]["layers"]
	# 同源刷新回合，不新增
	if not source.is_empty():
		for l in layers:
			if l.get("source", "") == source:
				l["turns"] = maxi(l["turns"], turns)
				return
	# 已达最大层数
	if layers.size() >= MAX_BUFF_LAYERS:
		return
	layers.append({ "source": source, "turns": turns, "value": value })
	buff_added.emit(buff_id)

	if buff_id in FREEZE_BUFF_IDS:
		is_frozen = true
	if buff_id == "poison":
		show_debuff("中毒", true)

func remove_buff(buff_id: String) -> void:
	if buff_id in buffs:
		buffs.erase(buff_id)
		buff_removed.emit(buff_id)

		if buff_id in FREEZE_BUFF_IDS:
			var still_frozen := false
			for bid in buffs:
				if bid in FREEZE_BUFF_IDS:
					still_frozen = true
					break
			if not still_frozen:
				is_frozen = false
				sync_freeze_anim()
		if buff_id == "poison":
			if not has_buff("poison"):
				hide_debuff()

func has_buff(buff_id: String) -> bool:
	return buff_id in buffs

## 检查是否有来自某技能的 buff 层
func has_buff_source(buff_id: String, source: String) -> bool:
	if not buffs.has(buff_id): return false
	for l in buffs[buff_id]["layers"]:
		if l.get("source", "") == source:
			return true
	return false

## 返回 buff 总层数
func get_buff_layer_count(buff_id: String) -> int:
	if not buffs.has(buff_id): return 0
	return buffs[buff_id]["layers"].size()

## 返回 buff 叠加后的综合值（各层乘积）
func get_buff_value(buff_id: String) -> Variant:
	if not buffs.has(buff_id): return null
	var layers: Array = buffs[buff_id]["layers"]
	if layers.is_empty(): return null
	var prod: float = 1.0
	for l in layers:
		var v = l.get("value")
		if v is float or v is int:
			prod *= float(v)
	return prod

## 设置头顶名字颜色（用于标识当前行动者）
func set_name_label_color(color: Color) -> void:
	if _name_label:
		_name_label.add_theme_color_override("font_color", color)

## 同步冻结状态：冰封 debuff + WAS 循环挨打，解冻清除
func sync_freeze_anim() -> void:
	if is_dead or shattered:
		return
	var parent = get_parent()
	if parent == null: return
	var was = parent.get_node_or_null("WASAnimationPlayer")
	if was == null: return

	if is_frozen:
		# 确定是哪种封印，显示对应 debuff
		var debuff_name := "冰封"
		var body_color := Color(0.5, 0.6, 1.0)
		for bid in ["失魂", "冰封", "freeze", "frozen"]:
			if has_buff(bid):
				debuff_name = "失魂" if bid == "失魂" else "冰封"
				body_color = Color(0.6, 0.5, 0.9) if bid == "失魂" else Color(0.5, 0.6, 1.0)
				break
		show_debuff(debuff_name, true)
		if parent.has_node("Sprite2D"):
			parent.get_node("Sprite2D").modulate = body_color
		if was._current_anim != "hit":
			was.play("hit", true)
	else:
		hide_debuff()
		# 恢复本色
		if parent.has_node("Sprite2D"):
			parent.get_node("Sprite2D").modulate = Color.WHITE
		was.play("idle")

## 每回合结束时调用，递减 Buff 持续时间
func tick_buffs() -> Array[String]:
	var expired: Array[String] = []
	for buff_id in buffs.keys():
		var layers: Array = buffs[buff_id]["layers"]
		for i in range(layers.size() - 1, -1, -1):
			var l: Dictionary = layers[i]
			if l["turns"] > 0:
				l["turns"] -= 1
				if l["turns"] == 0:
					layers.remove_at(i)
		if layers.is_empty():
			expired.append(buff_id)
	for buff_id in expired:
		remove_buff(buff_id)
	# buff 过期后刷新视觉（血条上限 tween 归位）
	sync_visual()
	# 所有 buff 过期后隐藏精灵
	if buffs.is_empty():
		hide_buff()
	return expired

# ─── 属性计算（含 Buff + 被动书加成）─────────
## 累加同类书技能（高级和普通叠加）
## 检查某本书技能的纯数字 value
func _book_num(type: String, fallback: float = 0.0) -> float:
	var result = fallback
	for b in book_skills:
		var db = GameData.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == type:
			var v = db.get("value", 1.0)
			if v is float or v is int:
				result += v
	return result

func _book_mul(type: String, fallback: float = 1.0) -> float:
	var mul = 1.0
	for b in book_skills:
		var db = GameData.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == type:
			var v = db.get("value", 1.0)
			if v is float or v is int:
				mul *= v
	return mul if mul != 1.0 else fallback

func _has_book_type(type: String) -> bool:
	for b in book_skills:
		var db = GameData.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == type:
			return true
	return false

func get_effective_attack() -> int:
	var base = stats.attack
	base = int(base * _book_mul("atk_up"))
	if has_buff("atk_up"):   base = int(base * clamp(get_buff_value("atk_up") if get_buff_value("atk_up") != null else 1.5, 1.0, 3.0))
	if has_buff("atk_down"): base = int(base * clamp(get_buff_value("atk_down") if get_buff_value("atk_down") != null else 0.7, 0.1, 1.0))
	# 愈战愈勇：永久叠伤
	var yzyy_cfg = trait_data.get("愈战愈勇", {})
	if not yzyy_cfg.is_empty():
		var yzyy_stacks: int = trait_data.get("_yzyy_stacks", 0)
		if yzyy_stacks > 0:
			base = int(base * (1.0 + yzyy_stacks * yzyy_cfg.get("dmg_pct", 0.0)))
	# 兽王血脉：每只宠物加攻击%
	var sw_cfg = trait_data.get("兽王血脉", {})
	if not sw_cfg.is_empty():
		var pet_count: int = trait_data.get("_summon_pet_count", 0)
		if pet_count > 0:
			base = int(base * (1.0 + pet_count * sw_cfg.get("atk_pct", 0.0)))
	return base

func get_effective_magic_attack() -> int:
	var base = stats.magic_attack
	base = int(base * _book_mul("matk_up"))
	if has_buff("matk_up"):  base = int(base * clamp(get_buff_value("matk_up") if get_buff_value("matk_up") != null else 1.5, 1.0, 3.0))
	return base

func get_effective_defense() -> int:
	var base = stats.defense
	base = int(base * _book_mul("def_up"))
	if has_buff("shield"):     base = int(base * clamp(get_buff_value("shield") if get_buff_value("shield") != null else 2.0, 1.0, 5.0))
	if has_buff("def_up"):     base = int(base * clamp(get_buff_value("def_up") if get_buff_value("def_up") != null else 1.5, 1.0, 5.0))
	if has_buff("def_broken"): base = int(base * clamp(get_buff_value("def_broken") if get_buff_value("def_broken") != null else 0.5, 0.1, 1.0))
	# 兽王血脉：每只宠物加防御%
	var sw_cfg2 = trait_data.get("兽王血脉", {})
	if not sw_cfg2.is_empty():
		var pet_count: int = trait_data.get("_summon_pet_count", 0)
		if pet_count > 0:
			base = int(base * (1.0 + pet_count * sw_cfg2.get("def_pct", 0.0)))
	return base

func get_effective_magic_defense() -> int:
	var base = stats.magic_defense
	base = int(base * _book_mul("mdef_up"))
	if has_buff("mdef_up"): base = int(base * clamp(get_buff_value("mdef_up") if get_buff_value("mdef_up") != null else 1.5, 1.0, 5.0))
	return base

func get_effective_speed() -> int:
	var base = stats.speed
	base = int(base * _book_mul("haste"))
	base = int(base * get_night_spd_mul())
	# 迟钝降速
	for b in book_skills:
		var db = GameData.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == "slow_tank":
			base = int(base * db.value.speed)
	if has_buff("haste"): base = int(base * clamp(get_buff_value("haste") if get_buff_value("haste") != null else 1.3, 1.0, 3.0))
	if has_buff("slow"):  base = int(base * clamp(get_buff_value("slow") if get_buff_value("slow") != null else 0.7, 0.1, 1.0))
	# 愈战愈勇：永久叠速
	var yzyy_cfg2 = trait_data.get("愈战愈勇", {})
	if not yzyy_cfg2.is_empty():
		var yzyy_stacks: int = trait_data.get("_yzyy_stacks", 0)
		if yzyy_stacks > 0:
			base = int(base * (1.0 + yzyy_stacks * yzyy_cfg2.get("spd_pct", 0.0)))
	# 兽王血脉：每只宠物加速度%
	var sw_cfg3 = trait_data.get("兽王血脉", {})
	if not sw_cfg3.is_empty():
		var pet_count: int = trait_data.get("_summon_pet_count", 0)
		if pet_count > 0:
			base = int(base * (1.0 + pet_count * sw_cfg3.get("spd_pct", 0.0)))
	return base

func get_effective_max_hp() -> int:
	var base = stats.max_hp
	base = int(base * _book_mul("hp_up"))
	# 迟钝加血
	for b in book_skills:
		var db = GameData.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == "slow_tank":
			base = int(base * db.value.hp)
	if has_buff("hp_up"): base = int(base * clamp(get_buff_value("hp_up") if get_buff_value("hp_up") != null else 1.3, 1.0, 3.0))
	# 兽王血脉：每只宠物加气血%
	var sw_cfg4 = trait_data.get("兽王血脉", {})
	if not sw_cfg4.is_empty():
		var pet_count: int = trait_data.get("_summon_pet_count", 0)
		if pet_count > 0:
			base = int(base * (1.0 + pet_count * sw_cfg4.get("hp_pct", 0.0)))
	return base

func get_effective_crit_rate() -> float:
	var rate = stats.crit_rate
	for b in book_skills:
		var db = GameData.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == "crit_up":
			rate += db.get("value", 0.0)
	return clampf(rate, 0.0, 1.0)

func get_effective_magic_crit_rate() -> float:
	var rate = 0.05  # 基础法术暴击率 5%
	for b in book_skills:
		var db = GameData.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == "mcrit_up":
			rate += db.get("value", 0.0)
	return clampf(rate, 0.0, 1.0)

## 慧根：MP 消耗减免比例
func get_mp_cost_reduction() -> float:
	return minf(_book_num("mp_save"), 0.8)  # 最多减免80%

## 吸血比例
func get_lifesteal_ratio() -> float:
	var v = 0.0
	for b in book_skills:
		var db = GameData.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == "lifesteal":
			v += db.get("value", 0.0)
	return minf(v, 0.5)

## 反震比例
func get_reflect_ratio() -> float:
	var v = 0.0
	for b in book_skills:
		var db = GameData.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == "reflect":
			v += db.get("value", 0.0)
	return minf(v, 0.6)

## 毒概率
func get_venom_chance() -> float:
	var v = 0.0
	for b in book_skills:
		var db = GameData.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == "venom":
			v += db.get("value", 0.0)
	return minf(v, 0.5)

## 来财金币倍率
func get_gold_boost() -> float:
	var v = 1.0
	for b in book_skills:
		var db = GameData.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == "gold_boost":
			v *= db.get("value", 1.0)
	return v

## 神迹免疫异常？
func is_immune_to_debuffs() -> bool:
	for b in book_skills:
		var db = GameData.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == "immune" and db.get("value", 1.0) >= 1.0:
			return true
	return false

## 神迹抵抗异常概率
func get_debuff_resist_chance() -> float:
	for b in book_skills:
		var db = GameData.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == "immune":
			return db.get("value", 0.0)
	return 0.0

## 夜战：是否在夜间（暂时总返回 true，后续可接入系统时间或游戏昼夜系统）
func is_night_time() -> bool:
	return true

## 夜战伤害倍率
func get_night_dmg_mul() -> float:
	if not is_night_time():
		return 1.0
	return _book_mul("night")

## 夜战速度倍率
func get_night_spd_mul() -> float:
	if not is_night_time():
		return 1.0
	var mul = 1.0
	for b in book_skills:
		var db = GameData.BOOK_SKILL_DB.get(b, {})
		if db.get("type", "") == "night":
			var v = db.get("value", {})
			mul *= v.get("spd", 1.0)
	return mul

# ─── 升级（玩家专用）────────────────────────
func gain_exp(amount: int) -> bool:
	if not is_player:
		return false
	stats.exp += amount
	if stats.exp >= stats.exp_to_next:
		_level_up()
		return true
	return false

## 战斗中升级：恢复部分 HP/MP，更新头顶显示
## 注：永久属性提升在 GameData._level_up 中处理
func _level_up() -> void:
	stats.exp -= stats.exp_to_next
	stats.level += 1
	stats.exp_to_next = CharacterStats.calc_exp_to_next(stats.level)
	# 升级时恢复部分 HP / MP
	current_hp = mini(stats.max_hp, current_hp + stats.hp_growth)
	current_mp = mini(stats.max_mp, current_mp + stats.mp_growth)
	_update_hp_bar()
	_update_mp_bar()
	if _name_label:
		_name_label.text = stats.get_display_name()

# ─── 工具 ────────────────────────────────────
func hp_percent() -> float:
	return float(current_hp) / float(stats.max_hp)

func mp_percent() -> float:
	return float(current_mp) / float(stats.max_mp)

## 检查是否有某本书技能
func has_book_skill(skill_name: String) -> bool:
	return skill_name in book_skills

## 获取书技能参数值
func get_book_value(skill_name: String, fallback: float = 1.0) -> float:
	if not has_book_skill(skill_name):
		return fallback
	var db = GameData.BOOK_SKILL_DB.get(skill_name, {})
	return db.get("value", fallback)


# ══ 特性系统 ══

## 横扫不休：横扫千军有概率不冷却
func check_no_cooldown_after_skill(skill_id: String) -> bool:
	if skill_id != "横扫千军": return false
	var cfg = trait_data.get("横扫不休", {})
	if cfg.is_empty(): return false
	return randf() < cfg.get("chance", 0.0)


## 愈战愈勇：普攻永久叠伤+速，返回当前层数（0=无此特性）
func apply_stacking_buff() -> int:
	var cfg = trait_data.get("愈战愈勇", {})
	if cfg.is_empty(): return 0
	var stacks: int = trait_data.get("_yzyy_stacks", 0) + 1
	trait_data["_yzyy_stacks"] = stacks
	trait_data["_yzyy_pending"] = stacks  # 等攻击走回原地后播特效
	return stacks


## 兽王血脉：场上每只宠物加属性百分比
func recalc_summon_buffs(pet_count: int) -> void:
	var cfg = trait_data.get("兽王血脉", {})
	if cfg.is_empty(): return
	var old_count: int = trait_data.get("_summon_pet_count", 0)
	trait_data["_summon_pet_count"] = pet_count
	# 刷新 HP（等比缩放）
	if pet_count != old_count:
		var old_effective := get_effective_max_hp()
		# 临时回退旧计数来算旧有效值
		trait_data["_summon_pet_count"] = old_count
		var old_max := get_effective_max_hp()
		trait_data["_summon_pet_count"] = pet_count
		var new_max := get_effective_max_hp()
		if old_max > 0 and new_max != old_max:
			current_hp = maxi(1, int(float(current_hp) * float(new_max) / float(old_max)))
		if _hp_bar:
			_hp_bar.max_value = new_max
			_hp_bar.value = current_hp
		show_trait_float("兽王血脉")
