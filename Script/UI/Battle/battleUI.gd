class_name BattleUI
extends CanvasLayer
# BattleUI.gd

@onready var battle_manager:  BattleManager = $"../BattleManager"

@onready var battle_log:      RichTextLabel  = $BattleLog
@onready var actor_indicator: Label          = $ActorIndicator
@onready var action_panel:    ActionPanel    = $ActionPanel
@onready var _turn_order:     Control        = $TurnOrderPanel
@onready var _enemy_total_hp_bar: TextureProgressBar = $"总血条progressbar"
@onready var _enemy_total_hp_bg: Sprite2D = $"总血条"

const SKILL_POPUP = preload("res://scenes/UI/SkillPopup.tscn")
const SUMMON_POPUP = preload("res://scenes/UI/SummonPopup.tscn")
const MECH_SUMMON_POPUP = preload("res://scenes/UI/Mech/MechSummonPopup.tscn")
var _skill_popup: SkillPopup = null
var _summon_popup: SummonPopup = null
var _mech_summon_popup: MechSummonPopup = null

const LOG_COLORS = {
	"player_action":"#d2edff", "enemy_action":"#ffc1b4",
	"heal":"#c8edc0",    "system":"#f0e1b9",
	"turn":"#e8d5a7",         "debuff":"#dfc1f3",
}
const BUFF_ICONS = {
	"shield": "🛡️",
	"atk_up": "⬆️",
	"atk_down": "⬇️",
	"poison": "☠️",
	"freeze": "❄️",
	"失魂": "👻",
	"def_broken": "💢",
	"haste": "⚡",
	"slow": "🐢",
	"burn": "🔥",
	"sleep": "💤",
	"confuse": "🌀",
	"dmg_down": "🔻",
	"silence": "🔒",
}

var _pending_action: Callable  = Callable()
var _quick_cast_held: bool = false
var _quick_skill_per_char: Dictionary = {}  # character_name/member_id -> skill_id

# 🎨 头像变体缓存 🎨
var _portrait_cache: Dictionary = {}

func _load_png_portrait(base_path: String, variant: String) -> Texture2D:
	if base_path.is_empty():
		return null
	var png_path := base_path.trim_suffix("/") + "/" + variant + ".png"
	if not FileAccess.file_exists(png_path):
		return null
	var img := Image.load_from_file(png_path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)


func _portrait_texture(was_base: String, variant: String, png_base: String = "", char_name: String = "") -> Texture2D:
	var icon_texture = preload("res://Script/Assets/AssetLoader.gd").portrait_icon(was_base, png_base, char_name)
	if icon_texture != null: return icon_texture
	var root_texture = preload("res://Script/Assets/AssetLoader.gd").root_portrait(was_base, png_base, char_name)
	if root_texture != null: return root_texture
	var key := "%s|%s|%s|%s" % [was_base, png_base, char_name, variant]
	if _portrait_cache.has(key):
		return _portrait_cache[key]
	# 尝试 PNG：{portrait_path}/{角色名}.png
	if not png_base.is_empty() and not char_name.is_empty():
		var png_path = png_base.trim_suffix("/") + "/" + char_name + ".png"
		if FileAccess.file_exists(png_path):
			var img := Image.load_from_file(png_path)
			if img != null:
				_portrait_cache[key] = ImageTexture.create_from_image(img)
				return _portrait_cache[key]
	# 自动检测：Graphic/Character/{角色名}/{角色名}.png
	if not char_name.is_empty():
		var auto_path = "res://Graphic/Character/" + char_name + "/" + char_name + ".png"
		if FileAccess.file_exists(auto_path):
			var img := Image.load_from_file(auto_path)
			if img != null:
				_portrait_cache[key] = ImageTexture.create_from_image(img)
				return _portrait_cache[key]
	# 尝试 PNG（变体名：x44.png / 头像.png）
	if not png_base.is_empty():
		var png_path2 = png_base.trim_suffix("/") + "/" + variant + ".png"
		if FileAccess.file_exists(png_path2):
			var img := Image.load_from_file(png_path2)
			if img != null:
				_portrait_cache[key] = ImageTexture.create_from_image(img)
				return _portrait_cache[key]
	# 尝试 WAS 头像（变体）
	var path := was_base.trim_suffix("/") + "/头像/" + variant + ".was"
	if FileAccess.file_exists(path):
		var r_frame: Dictionary = preload("res://Script/Assets/AssetLoader.gd").was_frame(path)
		if not r_frame.is_empty():
			var d := r_frame
			if not d.is_empty() and d.has("texture"):
				_portrait_cache[key] = d.texture
				return d.texture
	# 找不到则回退到头像.was
	var fallback_key := was_base + "/头像"
	if _portrait_cache.has(fallback_key):
		return _portrait_cache[fallback_key]
	var fallback_path := was_base.trim_suffix("/") + "/头像/头像.was"
	if not FileAccess.file_exists(fallback_path):
		_portrait_cache[fallback_key] = null
		return null
	var r_frame: Dictionary = preload("res://Script/Assets/AssetLoader.gd").was_frame(fallback_path)
	if r_frame.is_empty():
		_portrait_cache[fallback_key] = null
		return null
	var d := r_frame
	if d.is_empty() or not d.has("texture"):
		_portrait_cache[fallback_key] = null
		return null
	_portrait_cache[fallback_key] = d.texture
	return d.texture

func _update_avatar_for(c: BattleCharacter) -> void:
	var e = _turn_entries.get(c)
	if e == null:
		return
	var tex = _portrait_texture(c.stats.was_base_path, "x44", c.stats.portrait_path, c.stats.character_name)
	if tex:
		e["avatar"].texture = tex
		# 只有 PNG 头像放大 4 倍加偏移
		var png_path = "res://Graphic/Character/" + c.stats.character_name + "/" + c.stats.character_name + ".png"
		if FileAccess.file_exists(png_path):
			e["avatar"].scale = Vector2(4, 4)
			var off = c.stats.portrait_offset
			# 记录原始位置（只记一次）
			if not e["avatar"].has_meta("_orig_pos"):
				e["avatar"].set_meta("_orig_pos", (e["avatar"] as Control).position)
			e["avatar"].layout_mode = 0
			e["avatar"].position = (e["avatar"].get_meta("_orig_pos") as Vector2) + off
		else:
			e["avatar"].scale = Vector2(1, 1)


# 📊 敌人总血量条 📊
var _enemy_total_hp_tween: Tween = null
var _enemy_total_hp_initialized := false
var _enemy_total_hp_prev: float = 0.0  # 上一次血量，检测大额伤害
var _bar_shaking := false

func _refresh_enemy_total_hp() -> void:
	if is_instance_valid(_enemy_total_hp_bg):
		_enemy_total_hp_bg.position.y = get_viewport().get_visible_rect().size.y - 211.7
	var total_max := 0
	var total_cur := 0
	for ch in battle_manager.enemies:
		if ch == null or not is_instance_valid(ch):
			continue
		total_max += ch.stats.max_hp
		total_cur += ch.current_hp
	if _enemy_total_hp_bar == null or not is_instance_valid(_enemy_total_hp_bar):
		return
	_enemy_total_hp_bar.max_value = maxi(1, total_max)
	var target_val := maxi(0, total_cur)
	# 平滑 tween 到新值
	if _enemy_total_hp_tween and _enemy_total_hp_tween.is_valid():
		_enemy_total_hp_tween.kill()
	if not _enemy_total_hp_initialized:
		_enemy_total_hp_bar.value = target_val
		_enemy_total_hp_initialized = true
	else:
		_enemy_total_hp_tween = create_tween().set_ease(Tween.EASE_OUT)
		_enemy_total_hp_tween.tween_property(_enemy_total_hp_bar, "value", target_val, 0.3)
	# 大额伤害震动
	var damage := _enemy_total_hp_prev - float(total_cur)
	if damage > 0 and total_max > 0 and damage / float(total_max) > 0.1:
		_shake_bar(_enemy_total_hp_bar)
		if _enemy_total_hp_bg and is_instance_valid(_enemy_total_hp_bg):
			_shake_bar(_enemy_total_hp_bg)
	_enemy_total_hp_prev = float(total_cur)


func _shake_bar(bar: Node) -> void:
	if _bar_shaking:
		return
	_bar_shaking = true
	var origin = bar.position
	for i in 6:
		var offset_x := lerpf(6.0, 1.0, float(i) / 5.0)
		if i % 2 == 0:
			offset_x = -offset_x
		var t := create_tween().set_ease(Tween.EASE_OUT)
		t.tween_property(bar, "position:x", origin.x + offset_x, 0.03)
		t.tween_property(bar, "position:x", origin.x, 0.03)
		await t.finished
	_bar_shaking = false


# 📋 行动顺序条 📋
var _turn_entries: Dictionary = {}

var _turn_signal_connected: Array = []
var _turn_progress_pending := false

# 📊 战斗统计
var _damage_stats: Dictionary = {}   # { member_id: int }
var _healing_stats: Dictionary = {}  # { member_id: int }
const STATS_ROW := preload("res://scenes/UI/BattleStatsRow.tscn")
const STATS_TABS := {"threat": "%ThreatTab", "damage": "%DamageTab", "heal": "%HealTab"}
@onready var _stats_panel: Control = $StatsPanel
var _stats_mode := "threat"
var _threat_eye: Sprite2D = null            # 仇恨目标变化指示器
var _last_top_threat_key: String = ""       # 上次最高仇恨者
var _threat_eye_first: bool = true           # 开局必须出一次

## 上次攻击目标（Alt+A 快速攻击用）
var _last_attack_target: BattleCharacter = null

## 上次使用道具（Alt+R 快速道具用）
var _last_item_id: String = ""

## 悬浮提示 tooltip
var _tooltip: Panel = null
var _tooltip_labels: Dictionary = {}
var _tooltip_hover_count: int = 0     # 当前悬停的角色数（进入+1，离开-1）

# ══════════════════════════════════════════════
func _ready() -> void:
	# 连接 BattleManager 信号
	# 进入战斗立即隐藏探索层的日志和提示，不等待下一帧，避免叠在战斗日志上。
	for path in ["UI/BattleLog", "UI/信息框", "UI/UIKeyboardNavigator/Overlay"]:
		var world_ui = get_tree().current_scene.get_node_or_null(path)
		if world_ui: world_ui.hide()
	battle_manager.log_pushed.connect(_on_log_pushed)
	battle_manager.skill_failed.connect(_on_skill_failed)
	battle_manager.damage_floated.connect(_on_damage_floated)
	battle_manager.state_changed.connect(_on_state_changed)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.actor_turn_started.connect(_on_actor_turn_started)
	battle_manager.character_animated.connect(_on_character_animated)
	battle_manager.bonus_attack_started.connect(_on_bonus_attack_started)
	battle_manager.party_changed.connect(_connect_party_signals)
	_init_log()
	actor_indicator.text = ""
	action_panel.set_enabled(false)
	# 延迟到下一帧连接战斗信号（确保 battle_manager.setup() 已执行）
	call_deferred("_connect_battle_signals")

# ══════════════════════════════════════════════
# BattleScene 调用的初始化入口
# ══════════════════════════════════════════════

func _init_log() -> void:
	# 重置仇恨 eye
	_threat_eye_first = true
	_last_top_threat_key = ""
	# 把外部 log 历史复制进战场 log
	battle_log.bbcode_enabled = true
	if not GameData.world_log_text.is_empty():
		battle_log.text = GameData.world_log_text
		battle_log.scroll_to_line(battle_log.get_line_count())


func _connect_battle_signals() -> void:
	# 连接敌人点击信号
	for ch in battle_manager.enemies:
		_make_turn_entry(ch)
		var nd = ch.get_parent()
		if nd:
			nd.clicked.connect(_on_enemy_sprite_clicked)
			nd.hovered.connect(_on_enemy_hovered)
			nd.mouse_left.connect(_hide_tooltip)
	# 连接队友点击信号（保护时选目标用）	
	_connect_party_signals()
	action_panel.setup(
		_action_attack,
		_action_skill,
		_action_item,
		_action_summon,
		_action_guard,
		_action_capture,
		func(actor, sid): return battle_manager.get_skill_cooldown(actor, sid),
		battle_manager.player_inventory
	)
	# 连接技能弹窗
	if _skill_popup == null:
		_skill_popup = SKILL_POPUP.instantiate()
		add_child(_skill_popup)
		_skill_popup.hide()
		_skill_popup.skill_selected.connect(_on_popup_skill_selected)
		_skill_popup.item_selected.connect(_on_popup_item_selected)
		_skill_popup.cancelled.connect(_on_popup_cancelled)
		action_panel.open_skill_popup.connect(_on_open_skill_popup)
		action_panel.open_item_popup.connect(_on_open_item_popup)
	# 连接召唤弹窗

	_refresh_enemy_total_hp()
	for ch in battle_manager.enemies:
		ch.hp_changed.connect(_on_enemy_hp_changed)
		ch.died.connect(_on_enemy_died_for_bar)
	battle_manager.damage_floated.connect(_on_damage_floated_for_bar)
	battle_manager.effect_settled.connect(_on_damage_stats)
	_damage_stats = battle_manager.damage_stats
	_healing_stats = battle_manager.healing_stats
	if _summon_popup == null:
		_summon_popup = SUMMON_POPUP.instantiate()
		add_child(_summon_popup)
	_summon_popup.hide()
	_summon_popup.pet_selected.connect(_on_summon_pet_selected)
	_summon_popup.cancelled.connect(_on_summon_cancelled)
	# 连接铁甲召唤弹窗
	if _mech_summon_popup == null:
		_mech_summon_popup = MECH_SUMMON_POPUP.instantiate()
		add_child(_mech_summon_popup)
	_mech_summon_popup.hide()
	_mech_summon_popup.mech_selected.connect(_on_mech_selected)
	_mech_summon_popup.cancelled.connect(_on_mech_summon_cancelled)

	# 📋 行动顺序条 📋
	_turn_order.visible = true
	_build_tooltip()
	# 探危天赋：显示仇恨统计面板
	if GameData.has_talent("main_detect_danger"):
		_build_stats_panel()
	# 延迟一帧确保 _threat_mgr 已创建，开局随机出 eye
	call_deferred("_check_threat_eye")
	_setup_talisman_display()
	# 节约成本：初始化免费符咒次数



# ══════════════════════════════════════════════
# ActionPanel 回调
# ══════════════════════════════════════════════

## 连接或重连 party 成员的 clicked/hovered/mouse_left 信号
func _connect_party_signals() -> void:
	for ch in battle_manager.party:
		_make_turn_entry(ch)
		var nd = ch.get_parent()
		if nd == null: continue
		# 只连接未连接的节点
		if nd.has_meta("_party_signals_connected"):
			continue
		nd.clicked.connect(_on_ally_sprite_clicked.bind(ch))
		nd.hovered.connect(_on_ally_hovered)
		nd.mouse_left.connect(_hide_tooltip)
		nd.set_meta("_party_signals_connected", true)
	_update_turn_order()

func _action_attack() -> void:
	var actor := battle_manager.current_actor()
	# 加速符 → 选队友
	if actor and actor.stats.talisman_type == CharacterStats.TalismanType.HASTE:
		_set_pending_talisman(func(ally: BattleCharacter):
			if ally and not ally.is_dead and actor:
				if not _consume_talisman():
					return
				_set_talisman_visible(false)
				var caster_nd = actor.get_parent()
				if caster_nd and caster_nd.has_method("play_ranged_attack"):
					caster_nd.play_ranged_attack()
				var targets := battle_manager.talisman_support_targets(ally)
				for t in targets:
					var caster_pos = actor.get_parent().global_position if actor.get_parent() else Vector2.ZERO
					caster_pos.x -= 500
					var target_pos = t.get_parent().global_position
					SpellProjectile.shoot(caster_pos, target_pos, t.get_parent(), func():
						t.show_buff("加速")
						battle_manager.apply_talisman_support(actor, t)
						t.sync_visual()
						var av = t.get_parent()
						if av and av.has_method("shake"):
							av.shake()
							get_tree().create_timer(0.5).timeout.connect(func():
								if is_instance_valid(av) and av.has_method("stop_shake"):
									av.stop_shake()
							, CONNECT_ONE_SHOT)
					, self, actor, actor.stats.talisman_type, _get_talisman_texture(actor))
				battle_manager._push_log("符咒加速 %d 人！" % targets.size(), "player_action")
				battle_manager._finish_player_action()
			, true)
		return
	# 借尸符 → 选阵亡队友
	if actor and actor.stats.talisman_type == CharacterStats.TalismanType.REVIVE:
		_set_pending_talisman(func(ally: BattleCharacter):
			if ally and ally.is_dead and actor:
				if not _consume_talisman():
					return
				_set_talisman_visible(false)
				var caster_nd = actor.get_parent()
				if caster_nd and caster_nd.has_method("play_ranged_attack"):
					caster_nd.play_ranged_attack()
				var caster_pos = actor.get_parent().global_position if actor.get_parent() else Vector2.ZERO
				var target_pos = ally.get_parent().global_position
				SpellProjectile.shoot(caster_pos, target_pos, ally.get_parent(), func():
					battle_manager.apply_talisman_support(actor, ally)
				, self, actor, actor.stats.talisman_type, _get_talisman_texture(actor))
				battle_manager._finish_player_action()
			, true, true)
		return
	# 普通攻击（星火篆/雷电/冰冻/止战）+ 分裂符
	var is_main_ranged := actor and CharacterStats.has_role(actor.stats.role, CharacterStats.Role.MAIN) and actor.stats.is_ranged
	if is_main_ranged:
		_set_pending_talisman(func(target: BattleCharacter):
			_execute_talisman_attack(actor, target)
		)
	else:
		_set_pending(func(target: BattleCharacter):
			_last_attack_target = target
			if actor:
				actor.apply_stacking_buff()
			battle_manager.player_use_normal_attack(target)
		)

func _action_skill(skill_id: String) -> void:
	# 记录快速施法（按角色分开）
	var actor := battle_manager.current_actor()
	if actor != null:
		var key := actor.member_id if not actor.member_id.is_empty() else actor.stats.character_name
		_quick_skill_per_char[key] = skill_id
	var data: SkillData = SkillManager.get_skill(skill_id)

	
	if skill_id == "召唤铁甲兽":
		var cd = battle_manager.get_skill_cooldown(battle_manager.current_actor(), skill_id)
		if cd > 0:
			battle_manager._push_log(GameData._T("BATTLE_ON_COOLDOWN") % ["召唤铁甲兽", cd], "system")
			_finish_action()
			return
	
		_show_mech_summon_popup()
		return
	if data == null:
		_restore_failed_skill_selection.call_deferred(battle_manager.current_actor())
		return
	# 全屏技能（龙卷雨击/水漫金山等）：不需要点选敌人，直接施放
	if data.fullscreen_anim != "":
		var fs_targets = battle_manager.alive_enemies()
		if not fs_targets.is_empty():
			battle_manager.player_use_skill(skill_id, fs_targets[0])
		_finish_action()
		return
	match data.target_type:
		SkillData.TargetType.SINGLE_ENEMY:
			_set_pending(func(target: BattleCharacter):
				battle_manager.player_use_skill(skill_id, target)
			)
		SkillData.TargetType.SINGLE_ALLY:
			if data.heal_size == "revive":
				# 复活技能：只选阵亡队友
				_set_pending_dead_ally(func(ally: BattleCharacter):
					battle_manager.player_use_skill(skill_id, ally)
				)
			else:
				_set_pending_ally(func(ally: BattleCharacter):
					battle_manager.player_use_skill(skill_id, ally)
				)
		SkillData.TargetType.SELF:
			battle_manager.player_use_skill(skill_id, battle_manager.current_actor())
			_finish_action()
		_:
			var targets = battle_manager.alive_enemies()
			if not targets.is_empty():
				battle_manager.player_use_skill(skill_id, targets[0])
			_finish_action()

func _action_item(item_id: String) -> void:
	var slot = battle_manager.player_inventory._slots.get(item_id, {})
	var data: ItemData = slot.get("data", null)
	if data == null:
		_restore_failed_skill_selection.call_deferred(battle_manager.current_actor())
		return
	match data.item_type:
		ItemData.ItemType.HP_POTION:
			# 回血道具：让玩家选择存活队友
			_set_pending_ally(func(ally: BattleCharacter):
				battle_manager.player_use_item(item_id, ally)
			)
		ItemData.ItemType.MP_POTION:
			# 回蓝道具：让玩家选择存活队友
			_set_pending_ally(func(ally: BattleCharacter):
				battle_manager.player_use_item(item_id, ally)
			)
		ItemData.ItemType.REVIVE:
			# 复活道具：让玩家选择死亡队友
			_set_pending_dead_ally(func(ally: BattleCharacter):
				battle_manager.player_use_item(item_id, ally)
			)
		_:
			battle_manager.player_use_item(item_id, battle_manager.current_actor())
			_finish_action()

func _action_flee() -> void:
	battle_manager.player_flee()
	_finish_action()

func _action_summon() -> void:
	# 宠物不能召唤
	if battle_manager.current_actor().is_summoned_pet:
		battle_manager._push_log(GameData._T("BATTLE_PET_CANT_SUMMON"), "system")
		# 恢复面板，不能卡住		
		action_panel.set_enabled(true)
		action_panel.slide_in()
		action_panel.btn_attack.grab_focus()
		return
	# 只有召唤系角色才能召唤	
	if not CharacterStats.has_role(battle_manager.current_actor().stats.role, CharacterStats.Role.SUMMON):
		battle_manager._push_log(GameData._T("BATTLE_ONLY_SUMMONER"), "system")
		action_panel.set_enabled(true)
		action_panel.slide_in()
		action_panel.btn_attack.grab_focus()
		return
	if GameData.pet_team.is_empty():
		battle_manager.player_summon_fallback()
		_finish_action()
		return
	if battle_manager._count_summoned_pets() >= battle_manager.get_pet_slot_count():
		battle_manager._push_log("召唤位已满！", "system")
		action_panel.set_enabled(true)
		action_panel.slide_in()
		action_panel.btn_attack.grab_focus()
		return
	_summon_popup.open(battle_manager.summoned_pet_ids)

func _action_guard() -> void:
	_set_pending_ally(func(ally: BattleCharacter):
		battle_manager.player_guard(ally)
	, false)

func _action_capture() -> void:
	_set_pending_capture(func(target: BattleCharacter):
		battle_manager.player_capture(target)
	)

func _execute_selected_action(action: Callable, target: BattleCharacter) -> void:
	action.call(target)
	_finish_action()

func _finish_action() -> void:
	# 动作已取消（如技能失败回到 PLAYER_TURN）时不要禁用面板
	if battle_manager.state != BattleManager.BattleState.PLAYER_ACTION:
		if battle_manager.state == BattleManager.BattleState.PLAYER_TURN:
			_restore_failed_skill_selection.call_deferred(battle_manager.current_actor())
		return
	action_panel.refresh(battle_manager.current_actor(), false)

# ══════════════════════════════════════════════
# 快速施法（Alt+Q）# ══════════════════════════════════════════════

func _show_floating_text(text: String, color: Color = Color(1, 0.85, 0.1)) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.position = get_viewport().get_visible_rect().size * 0.5 - Vector2(200, 16)
	lbl.size = Vector2(400, 32)
	add_child(lbl)

	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(lbl, "position:y", lbl.position.y - 80, 1.2)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(lbl.queue_free)

func _play_wrong_sound() -> void:
	var snd := AudioStreamPlayer.new()
	snd.stream = load("res://Audio/SE/057-Wrong01.ogg")
	snd.bus = "SFX"
	add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)

func _try_quick_cast() -> bool:
	if battle_manager.state != BattleManager.BattleState.PLAYER_TURN:
		_show_floating_text(GameData._T("BATTLE_NOT_PLAYER_TURN"), Color(0.8, 0.8, 0.8))
		return false

	var actor := battle_manager.current_actor()
	if actor == null or actor.is_dead or actor.is_weakened or actor.is_frozen:
		_show_floating_text(GameData._T("BATTLE_CANNOT_ACT"), Color(0.8, 0.8, 0.8))
		return false

	var char_key := actor.member_id if not actor.member_id.is_empty() else actor.stats.character_name
	var skill_id: String = _quick_skill_per_char.get(char_key, "")
	if skill_id.is_empty():
		_show_floating_text(GameData._T("BATTLE_QUICK_CAST_NO_SKILL"), Color(0.8, 0.8, 0.8))
		return false

	# 检查冷却	
	if battle_manager.get_skill_cooldown(actor, skill_id) > 0:
		_show_floating_text(GameData._T("BATTLE_SKILL_CD"), Color(0.8, 0.8, 0.8))
		return false

	# 从 SkillManager 获取技能数据，确定目标类型	
	var data: SkillData = SkillManager.get_skill(skill_id)
	if data == null:
		_show_floating_text(GameData._T("BATTLE_SKILL_DATA_NOT_FOUND"), Color(0.8, 0.8, 0.8))
		return false

	var target_type = data.target_type
	var target: BattleCharacter = null

	match target_type:
		SkillData.TargetType.SINGLE_ENEMY:
			var enemies = battle_manager.alive_enemies()
			if not enemies.is_empty(): target = enemies[0]
		SkillData.TargetType.SINGLE_ALLY:
			var alive = battle_manager.alive_party()
			if not alive.is_empty(): target = alive[0]
		SkillData.TargetType.SELF:
			target = actor
		_:
			var enemies = battle_manager.alive_enemies()
			if not enemies.is_empty(): target = enemies[0]

	if target == null:
		_show_floating_text(GameData._T("BATTLE_QUICK_CAST_NO_TARGET"), Color(0.8, 0.8, 0.8))
		return false

	# 执行。先检查技能类型，如果是普通攻击就放普通攻击	
	if skill_id == "普通攻击":
		var enemies = battle_manager.alive_enemies()
		if not enemies.is_empty():
			action_panel.set_enabled(false)
			battle_manager.player_use_normal_attack(enemies[0])
		return true

	# 其他技能：直接通过 _action_skill 走正常流程	
	_action_skill(skill_id)
	# 自动选择目标丢出去	
	var data2: SkillData = SkillManager.get_skill(skill_id)
	if data2:
		match data2.target_type:
			SkillData.TargetType.SINGLE_ENEMY:
				var enemies = battle_manager.alive_enemies()
				if not enemies.is_empty() and _pending_action.is_valid():
					var cb = _pending_action
					_pending_action = Callable()
					action_panel.set_enabled(false)
					cb.call(enemies[0])
			SkillData.TargetType.SINGLE_ALLY:
				var alive = battle_manager.alive_party()
				if not alive.is_empty() and _pending_action.is_valid():
					var cb = _pending_action
					_pending_action = Callable()
					action_panel.set_enabled(false)
					cb.call(alive[0])
			SkillData.TargetType.SELF:
				pass  # _action_skill 已经处理了 SELF
	return true

# ══════════════════════════════════════════════
# 目标选择
# ══════════════════════════════════════════════

var _talisman_targets: Array[BattleCharacter] = []
var _talisman_select_idx: int = 0

## 符咒可跨阵营选择；复活符只接受阵亡目标。
func _set_pending_talisman(callback: Callable, prefer_allies: bool = false, dead_only: bool = false) -> void:
	_cancel_pending()
	_talisman_targets.clear()
	var first_side = battle_manager.party if prefer_allies else battle_manager.enemies
	var second_side = battle_manager.enemies if prefer_allies else battle_manager.party
	for side in [first_side, second_side]:
		for ch in side:
			if ch.is_dead == dead_only:
				_talisman_targets.append(ch)
	if _talisman_targets.is_empty():
		battle_manager._push_log(GameData._T("BATTLE_NO_REVIVE_TARGET") if dead_only else GameData._T("BATTLE_NO_TARGET"), "system")
		_finish_action()
		return
	_pending_action = callback
	_selection_mode = SelectionMode.TALISMAN
	actor_indicator.text = "左右切换敌我目标，确认施放符咒"
	action_panel.set_enabled(false)
	_talisman_select_idx = 0
	for ch in _talisman_targets:
		var nd = ch.get_parent()
		if nd == null: continue
		var btn = Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(80, 100)
		btn.modulate = Color(0, 0, 0, 0)
		btn.position = nd.global_position - btn.custom_minimum_size * 0.5
		btn.mouse_entered.connect(func(): _highlight_talisman_target(ch))
		btn.pressed.connect(func(): _confirm_talisman_target(ch))
		add_child(btn)
		_ally_pick_btns.append(btn)
		_ally_pick_nodes.append(nd)
	set_process(true)
	_highlight_talisman_target(_talisman_targets[0])

func _highlight_talisman_target(ch: BattleCharacter) -> void:
	_talisman_select_idx = _talisman_targets.find(ch)
	_clear_enemy_selection()
	_highlight_ally(ch)
	var nd = ch.get_parent()
	if nd: nd.set_selected(true)
	_set_cursor_selecting_ally(ch.is_player)

func _confirm_talisman_target(ch: BattleCharacter) -> void:
	if _selection_mode != SelectionMode.TALISMAN or not _pending_action.is_valid(): return
	var action = _pending_action
	_pending_action = Callable()
	_selection_mode = SelectionMode.NONE
	_enable_ally_selection(false)
	_enable_enemy_selection(false)
	_clear_enemy_selection()
	_set_cursor_selecting_ally(false)
	actor_indicator.text = ""
	_execute_selected_action(action, ch)

func _set_pending(callback: Callable) -> void:
	_pending_action = callback
	_selection_mode = SelectionMode.ENEMY
	actor_indicator.text = GameData._T("BATTLE_CLICK_ENEMY")
	_enable_enemy_selection(true)
	_enemy_select_idx = 0
	action_panel.set_enabled(false)
	var enemies = battle_manager.alive_enemies()
	if enemies.size() > 0:
		_highlight_enemy(enemies[0])
	else:
		_cancel_pending()

func _set_pending_capture(callback: Callable) -> void:
	_pending_action = callback
	_selection_mode = SelectionMode.ENEMY
	actor_indicator.text = GameData._T("BATTLE_CLICK_CAPTURE")
	_enable_enemy_selection(true)
	_enemy_select_idx = 0
	action_panel.set_enabled(false)
	var enemies = battle_manager.alive_enemies()
	if enemies.size() > 0:
		_highlight_enemy(enemies[0])
	else:
		_cancel_pending()

func _set_pending_ally(callback: Callable, include_self: bool = true) -> void:
	_pending_action = callback
	_selection_mode = SelectionMode.ALLY
	_ally_select_include_self = include_self
	actor_indicator.text = GameData._T("BATTLE_CLICK_ALLY")
	action_panel.set_enabled(false)
	_enable_ally_selection(true)
	_set_cursor_selecting_ally(true)
	_ally_select_idx = 0
	var allys = _selectable_allies()
	if allys.size() > 0:
		_highlight_ally(allys[0])
	else:
		_cancel_pending()

# 💀 复活模式：选择已死亡的队友 💀
var _dead_ally_pick_btns: Array = []
var _dead_ally_pick_nodes: Array = []
var _dead_ally_select_idx: int = 0

func _set_pending_dead_ally(callback: Callable) -> void:
	var dead_allies: Array[BattleCharacter] = []
	for ch in battle_manager.party:
		if ch.is_dead:
			dead_allies.append(ch)
	if dead_allies.is_empty():
		battle_manager._push_log(GameData._T("BATTLE_NO_REVIVE_TARGET"), "system")
		_cancel_pending()
		action_panel.set_enabled(true)
		action_panel.slide_in()
		action_panel.btn_attack.grab_focus()
		return
	_pending_action = callback
	_selection_mode = SelectionMode.DEAD_ALLY
	actor_indicator.text = GameData._T("BATTLE_CLICK_DEAD")
	action_panel.set_enabled(false)
	_enable_dead_ally_selection(true)
	_dead_ally_select_idx = 0
	_highlight_dead_ally(dead_allies[0])

func _enable_dead_ally_selection(val: bool) -> void:
	_clear_dead_ally_pick_btns()
	if not val: return
	for ch in battle_manager.party:
		if not ch.is_dead: continue
		var nd = ch.get_parent()
		if nd == null: continue
		nd.set_selected(true)
		var btn = Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(80, 100)
		btn.modulate = Color(0, 0, 0, 0)
		btn.pressed.connect(func():
			_enable_dead_ally_selection(false)
			if _pending_action.is_valid():
				var action = _pending_action
				_pending_action = Callable()
				actor_indicator.text = ""
				_execute_selected_action(action, ch)
		)
		btn.position = nd.global_position - btn.custom_minimum_size * 0.5
		add_child(btn)
		_dead_ally_pick_btns.append(btn)
		_dead_ally_pick_nodes.append(nd)
	set_process(true)

func _clear_dead_ally_pick_btns() -> void:
	for btn in _dead_ally_pick_btns:
		if is_instance_valid(btn): btn.queue_free()
	for nd in _dead_ally_pick_nodes:
		if is_instance_valid(nd): nd.set_selected(false)
	_dead_ally_pick_btns.clear()
	_dead_ally_pick_nodes.clear()
	if _ally_pick_btns.is_empty():
		set_process(false)

func _dead_selectable_allies() -> Array[BattleCharacter]:
	var result: Array[BattleCharacter] = []
	for ch in battle_manager.party:
		if ch.is_dead:
			result.append(ch)
	return result

func _highlight_dead_ally(ch: BattleCharacter) -> void:
	for p in battle_manager.party:
		if not p.is_dead: continue
		var nd = p.get_parent()
		if nd: nd.set_selected(p == ch)

func _on_enemy_sprite_clicked(char: BattleCharacter) -> void:
	if battle_manager.state != BattleManager.BattleState.PLAYER_TURN: return
	# 如果正在选队友（保护/治疗/复活），忽略敌人点击
	if not _ally_pick_btns.is_empty(): return
	if not _dead_ally_pick_btns.is_empty(): return
	_clear_enemy_selection()
	var nd = char.get_parent()
	if _pending_action.is_valid():
		_selection_mode = SelectionMode.NONE
		var action = _pending_action
		_pending_action = Callable()
		_enable_enemy_selection(false)
		_execute_selected_action(action, char)
	else:
		# 没有选择任何指令 → 直接普通攻击 / 符咒效果
		var actor := battle_manager.current_actor()
		if actor == null:
			return
		var ttype = actor.stats.talisman_type
		if ttype == CharacterStats.TalismanType.HASTE:
			_action_attack()
			return
		# 借尸符 → 选阵亡队友
		if ttype == CharacterStats.TalismanType.REVIVE:
			return
		# 主角远程：符咒多目标攻击
		if CharacterStats.has_role(actor.stats.role, CharacterStats.Role.MAIN) and actor.stats.is_ranged:
			if nd: nd.set_selected(true)
			_execute_talisman_attack(actor, char)
		else:
			if nd: nd.set_selected(true)
			_last_attack_target = char
			actor.apply_stacking_buff()
			battle_manager.player_use_normal_attack(char)

## 符咒多目标攻击（共享逻辑）
func _execute_talisman_attack(actor: BattleCharacter, target: BattleCharacter) -> void:
	if _talisman_attacking:
		return
	if battle_manager.state != BattleManager.BattleState.PLAYER_TURN:
		return
	_talisman_attacking = true
	action_panel.visible = false
	action_panel.set_enabled(false)
	print("[符咒攻击] actor=", actor.stats.get_display_name(), " target=", target.stats.get_display_name())
	_last_attack_target = target
	if actor:
		actor.apply_stacking_buff()
	if not _consume_talisman():
		_talisman_attacking = false
		_pending_action = Callable()
		_enable_enemy_selection(false)
		_clear_enemy_selection()
		action_panel.visible = true
		action_panel.set_enabled(true)
		action_panel.slide_in()
		action_panel.btn_attack.grab_focus()
		battle_manager._play_error_sound()
		battle_manager._push_log("符咒已用完！", "system")
		return
	_set_talisman_visible(false)
	var all_targets := battle_manager.talisman_targets(actor, target)
	var caster_nd = actor.get_parent()
	if caster_nd and caster_nd.has_method("play_ranged_attack"):
		caster_nd.play_ranged_attack()
	var caster_pos = caster_nd.global_position if caster_nd else Vector2.ZERO
	for t in all_targets:
		var t_node = t.get_parent()
		var t_pos = t_node.global_position if t_node else Vector2.ZERO
		var total_dmg := battle_manager.talisman_damage(actor, t)
		SpellProjectile.shoot(caster_pos, t_pos, t_node, func():
			if t_node:
				if t_node.has_method("play_hit_once"):
					t_node.play_hit_once()
				if t_node.has_method("play_hit_flash"):
					t_node.play_hit_flash()
			var actual_dmg := battle_manager.apply_talisman_damage(actor, t, total_dmg)
			t.sync_visual()
			battle_manager.damage_floated.emit(t, actual_dmg, "magic")
			battle_manager._push_log("%s 受到 %d 点伤害" % [t.stats.get_display_name(), actual_dmg], "player_action")
			var _t := t
			var _tn = t_node
			var _is_fire := actor and actor.stats.talisman_type == CharacterStats.TalismanType.FIRE
			if _tn and _tn.has_method("play_idle"):
				get_tree().create_timer(1.5).timeout.connect(func():
					if not is_instance_valid(_tn) or not _t: return
					if _t.is_dead: return
					if _t.has_buff("freeze") and _is_fire:
						_t.remove_buff("freeze")
						_t.sync_freeze_anim()
						var spr = _tn.get_node_or_null("Sprite2D") as Sprite2D
						if spr:
							var tw = _tn.create_tween()
							tw.tween_property(spr, "modulate", Color(2, 2, 2), 0.15)
							tw.tween_property(spr, "modulate", Color.WHITE, 0.3)
					if not _t.is_frozen and _tn.has_method("play_idle"):
						_tn.play_idle()
				, CONNECT_ONE_SHOT)
		, self, actor, actor.stats.talisman_type, _get_talisman_texture(actor), total_dmg, all_targets)
	while caster_nd and caster_nd.has_method("play_ranged_attack") and caster_nd._ranged_animating:
		await get_tree().process_frame
	_talisman_attacking = false
	battle_manager._finish_player_action()
	action_panel.visible = true
	action_panel.set_enabled(true)

func _clear_enemy_selection() -> void:
	for ch in battle_manager.enemies:
		var nd = ch.get_parent()
		if nd: nd.set_selected(false)

func _enable_enemy_selection(val: bool) -> void:
	for ch in battle_manager.enemies:
		if not ch.is_dead:
			var nd = ch.get_parent()
			if nd: nd.selectable = val

# 🛡️ 队友选择按钮（保护时显示）🛡️
var _ally_pick_btns: Array = []
var _ally_pick_nodes: Array = []


func _enable_ally_selection(val: bool) -> void:
	_clear_ally_pick_btns()
	if not val: return
	var allys := _selectable_allies()
	if allys.is_empty(): return
	for i in allys.size():
		var ch = allys[i]
		var nd = ch.get_parent()
		if nd == null: continue
		# 先高亮第一个
		nd.set_selected(i == 0)
		var btn = Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(80, 100)
		
		btn.modulate = Color(0, 0, 0, 0)
		var idx := i
		btn.mouse_entered.connect(func():
			_highlight_ally(ch)
			_ally_select_idx = idx
		)
		btn.pressed.connect(func():
			_enable_ally_selection(false)
			if _pending_action.is_valid():
				var action = _pending_action
				_pending_action = Callable()
				actor_indicator.text = ""
				_execute_selected_action(action, ch)
		)
		btn.position = nd.global_position - btn.custom_minimum_size * 0.5
	
		add_child(btn)
		_ally_pick_btns.append(btn)
		_ally_pick_nodes.append(nd)
	set_process(true)


func _clear_ally_pick_btns() -> void:
	for btn in _ally_pick_btns:
		if is_instance_valid(btn): btn.queue_free()
	for nd in _ally_pick_nodes:
		if is_instance_valid(nd): nd.set_selected(false)
	_ally_pick_btns.clear()
	_ally_pick_nodes.clear()
	if _dead_ally_pick_btns.is_empty():
		set_process(false)


func _process(_delta: float) -> void:
	# 目标选择界面会暂停 _process，行动条独立更新。
	# Alt+Q 快速施法（用物理按键避免 OS 拦截）	
	if Input.is_physical_key_pressed(KEY_Q) and Input.is_physical_key_pressed(KEY_ALT):
		if not _quick_cast_held:
			_quick_cast_held = true
			_try_quick_cast()
		elif _quick_cast_held:
			_quick_cast_held = false

	for i in _ally_pick_btns.size():
		var btn = _ally_pick_btns[i]
		var nd = _ally_pick_nodes[i]
		if is_instance_valid(btn) and is_instance_valid(nd):
			btn.position = nd.global_position - btn.custom_minimum_size * 0.5 
			btn.position.y -= 45
	for i in _dead_ally_pick_btns.size():
		var btn = _dead_ally_pick_btns[i]
		var nd = _dead_ally_pick_nodes[i]
		if is_instance_valid(btn) and is_instance_valid(nd):
			btn.position = nd.global_position - btn.custom_minimum_size * 0.5

	# 符咒切换（数字键 1-4，仅主角/远程角色）	
	if battle_manager.state == BattleManager.BattleState.PLAYER_TURN:
		var actor = battle_manager.current_actor()
		if actor and not actor.is_dead and actor.is_player and actor.stats.is_ranged:
			var pressed = -1
			if Input.is_physical_key_pressed(KEY_1): pressed = 0
			elif Input.is_physical_key_pressed(KEY_2): pressed = 1
			elif Input.is_physical_key_pressed(KEY_3): pressed = 2
			elif Input.is_physical_key_pressed(KEY_4): pressed = 3
			if pressed >= 0 and pressed != actor.stats.talisman_type:
				var names = ["星火篆", "五雷咒", "冰冻", "加速"]
				switch_talisman(actor, pressed)
				_push_log_to_battle("%s 切换符咒：%s" % [actor.stats.get_display_name(), names[pressed]])


func _push_log_to_battle(text: String):
	battle_manager._push_log(text, "turn")

func _on_ally_sprite_clicked(ch: BattleCharacter) -> void:
	if battle_manager.state != BattleManager.BattleState.PLAYER_TURN: return
	# 复活模式：忽略存活队友的点击
	if not _dead_ally_pick_btns.is_empty(): return
	_enable_ally_selection(false)
	_set_cursor_selecting_ally(false)
	if _pending_action.is_valid():
		_selection_mode = SelectionMode.NONE
		var action = _pending_action
		_pending_action = Callable()
		actor_indicator.text = ""
		_execute_selected_action(action, ch)

func _on_ally_card_clicked(ch: BattleCharacter, event: InputEvent) -> void:
	pass  # 不再使用卡片点击


func _ally_card_highlight() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.border_color = Color(0.3, 0.8, 1.0, 0.9)
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.bg_color = Color(0.15, 0.25, 0.4, 0.5)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb


# ⌨️ 键盘选择（保护队友 / 攻击选敌人）⌨️
enum SelectionMode { NONE, ENEMY, ALLY, DEAD_ALLY, TALISMAN }
var _selection_mode: SelectionMode = SelectionMode.NONE
var _ally_select_idx: int = 0
var _enemy_select_idx: int = 0
var _ally_select_include_self: bool = true

## 数字小键盘0 = 回车/空格（ui_accept）
func _is_accept(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventKey and event.keycode == KEY_KP_0 and event.is_pressed() and not event.is_echo():
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	# Alt+Q 快速施法
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var k: InputEventKey = event
		if k.keycode == KEY_Q and k.alt_pressed:
			var act = battle_manager.current_actor()
			if act == null or act.is_weakened or act.is_frozen or act.is_dead:
				_show_floating_text(GameData._T("BATTLE_CANNOT_ACT"), Color(0.8, 0.8, 0.8))
				get_viewport().set_input_as_handled()
				return
			_try_quick_cast()
			get_viewport().set_input_as_handled()
			return

		# Alt+A 快速攻击（优先上次目标，否则随机）
		if k.keycode == KEY_A and k.alt_pressed:
			var act = battle_manager.current_actor()
			if act == null or act.is_weakened or act.is_frozen or act.is_dead:
				_show_floating_text(GameData._T("BATTLE_CANNOT_ACT"), Color(0.8, 0.8, 0.8))
				get_viewport().set_input_as_handled()
				return
			# 上次目标有效就用它，否则随机选一个存活敌人
			if _last_attack_target == null or not is_instance_valid(_last_attack_target) or _last_attack_target.is_dead:
				var alive = battle_manager.alive_enemies()
				if alive.is_empty():
					_show_floating_text(GameData._T("BATTLE_NO_TARGET"), Color(0.8, 0.8, 0.8))
					get_viewport().set_input_as_handled()
					return
				_last_attack_target = alive[randi() % alive.size()]
			battle_manager.player_use_normal_attack(_last_attack_target)
			get_viewport().set_input_as_handled()
			return

		# Alt+E 道具
		if k.keycode == KEY_E and k.alt_pressed:
			var act = battle_manager.current_actor()
			if act == null or act.is_weakened or act.is_frozen or act.is_dead:
				_show_floating_text(GameData._T("BATTLE_CANNOT_ACT"), Color(0.8, 0.8, 0.8))
				get_viewport().set_input_as_handled()
				return
			_on_open_item_popup(act, battle_manager.player_inventory)
			get_viewport().set_input_as_handled()
			return

		# Alt+W 法术
		if k.keycode == KEY_W and k.alt_pressed:
			var act = battle_manager.current_actor()
			if act == null or act.is_weakened or act.is_frozen or act.is_dead:
				_show_floating_text(GameData._T("BATTLE_CANNOT_ACT"), Color(0.8, 0.8, 0.8))
				get_viewport().set_input_as_handled()
				return
			_on_open_skill_popup(act, func(actor, sid): return battle_manager.get_skill_cooldown(actor, sid))
			get_viewport().set_input_as_handled()
			return

		# Alt+R 上次道具
		if k.keycode == KEY_R and k.alt_pressed:
			var act = battle_manager.current_actor()
			if act == null or act.is_weakened or act.is_frozen or act.is_dead:
				_show_floating_text(GameData._T("BATTLE_CANNOT_ACT"), Color(0.8, 0.8, 0.8))
				get_viewport().set_input_as_handled()
				return
			if _last_item_id.is_empty():
				_show_floating_text(GameData._T("BATTLE_NO_ITEM"), Color(0.8, 0.8, 0.8))
				get_viewport().set_input_as_handled()
				return
			_action_item(_last_item_id)
			get_viewport().set_input_as_handled()
			return

		# Alt+Z 召唤
		if k.keycode == KEY_Z and k.alt_pressed:
			var act = battle_manager.current_actor()
			if act == null or act.is_weakened or act.is_frozen or act.is_dead or act.is_summoned_pet:
				_show_floating_text(GameData._T("BATTLE_CANNOT_ACT"), Color(0.8, 0.8, 0.8))
				get_viewport().set_input_as_handled()
				return
			_action_summon()
			get_viewport().set_input_as_handled()
			return

		# Alt+T 保护
		if k.keycode == KEY_T and k.alt_pressed:
			var act = battle_manager.current_actor()
			if act == null or act.is_weakened or act.is_frozen or act.is_dead:
				_show_floating_text(GameData._T("BATTLE_CANNOT_ACT"), Color(0.8, 0.8, 0.8))
				get_viewport().set_input_as_handled()
				return
			_action_guard()
			get_viewport().set_input_as_handled()
			return

		# Q — 上一个符咒
		if k.keycode == KEY_Q and not k.alt_pressed and not k.ctrl_pressed:
			var act = battle_manager.current_actor()
			if act and not act.is_dead and CharacterStats.has_role(act.stats.role, CharacterStats.Role.MAIN):
				_on_talisman_prev()
				get_viewport().set_input_as_handled()
				return

		# E — 下一个符咒
		if k.keycode == KEY_E and not k.alt_pressed and not k.ctrl_pressed:
			var act = battle_manager.current_actor()
			if act and not act.is_dead and CharacterStats.has_role(act.stats.role, CharacterStats.Role.MAIN):
				_on_talisman_next()
				get_viewport().set_input_as_handled()
				return

	# ESC 取消替换模式
	if event.is_action_pressed("ui_cancel") and _pending_summon_pet:
		_pending_summon_pet = null
		_enable_pet_replace_selection(false)
		get_viewport().set_input_as_handled()
		return

	# 替换宠物模式：左右切换 + 回车确认
	if _pending_summon_pet and not _pet_replace_targets.is_empty():
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			if event.is_action_pressed("ui_left"):
				_pet_replace_idx = (_pet_replace_idx - 1 + _pet_replace_targets.size()) % _pet_replace_targets.size()
			else:
				_pet_replace_idx = (_pet_replace_idx + 1) % _pet_replace_targets.size()
			_refresh_pet_replace_highlight()
			get_viewport().set_input_as_handled()
		elif _is_accept(event):
			var ch = _pet_replace_targets[_pet_replace_idx]
			var pet = _pending_summon_pet
			_pending_summon_pet = null
			_enable_pet_replace_selection(false)
			_do_replace_summon(ch, pet)
			get_viewport().set_input_as_handled()
		return

	# 铁甲替换模式
	if _pending_mech_name and not _mech_replace_targets.is_empty():
		if event.is_action_pressed("ui_cancel"):
			_pending_mech_name = ""
			_enable_mech_replace_selection(false)
			_on_mech_summon_cancelled()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			if event.is_action_pressed("ui_left"):
				_mech_replace_idx = (_mech_replace_idx - 1 + _mech_replace_targets.size()) % _mech_replace_targets.size()
			else:
				_mech_replace_idx = (_mech_replace_idx + 1) % _mech_replace_targets.size()
			_refresh_mech_replace_highlight()
			get_viewport().set_input_as_handled()
		elif _is_accept(event):
			var ch = _mech_replace_targets[_mech_replace_idx]
			var mech_name = _pending_mech_name
			_pending_mech_name = ""
			_enable_mech_replace_selection(false)
			battle_manager.player_summon_mech(mech_name, ch)
			_finish_action()
			get_viewport().set_input_as_handled()
		return

	# ESC 取消当前目标选择
	if event.is_action_pressed("ui_cancel") and _pending_action.is_valid():
		_cancel_pending()
		get_viewport().set_input_as_handled()
		return

	if not _pending_action.is_valid(): return

	# 点击空白处取消	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _is_mouse_over_selectable_target():
			_cancel_pending()
			get_viewport().set_input_as_handled()
		return

	if _selection_mode == SelectionMode.TALISMAN:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
			_talisman_select_idx = wrapi(_talisman_select_idx - 1, 0, _talisman_targets.size())
			_highlight_talisman_target(_talisman_targets[_talisman_select_idx])
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
			_talisman_select_idx = (_talisman_select_idx + 1) % _talisman_targets.size()
			_highlight_talisman_target(_talisman_targets[_talisman_select_idx])
			get_viewport().set_input_as_handled()
		elif _is_accept(event):
			_confirm_talisman_target(_talisman_targets[_talisman_select_idx])
			get_viewport().set_input_as_handled()
		return

	# 队友选择模式：保护 / 治疗 / Buff
	if not _ally_pick_btns.is_empty():
		var allys = _selectable_allies()
		if allys.is_empty(): return
		if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
			_ally_select_idx = (_ally_select_idx - 1 + allys.size()) % allys.size()
			_highlight_ally(allys[_ally_select_idx])
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
			_ally_select_idx = (_ally_select_idx + 1) % allys.size()
			_highlight_ally(allys[_ally_select_idx])
			get_viewport().set_input_as_handled()
		elif _is_accept(event):
			_selection_mode = SelectionMode.NONE
			_enable_ally_selection(false)
			action_panel.set_enabled(true)
			var action = _pending_action
			_pending_action = Callable()
			actor_indicator.text = ""
			_execute_selected_action(action, allys[_ally_select_idx])
			get_viewport().set_input_as_handled()
		return

	# 复活模式：选择已死亡的队友
	if not _dead_ally_pick_btns.is_empty():
		var dead_allies = _dead_selectable_allies()
		if dead_allies.is_empty(): return
		if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
			_dead_ally_select_idx = (_dead_ally_select_idx - 1 + dead_allies.size()) % dead_allies.size()
			_highlight_dead_ally(dead_allies[_dead_ally_select_idx])
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
			_dead_ally_select_idx = (_dead_ally_select_idx + 1) % dead_allies.size()
			_highlight_dead_ally(dead_allies[_dead_ally_select_idx])
			get_viewport().set_input_as_handled()
		elif _is_accept(event):
			_selection_mode = SelectionMode.NONE
			_enable_dead_ally_selection(false)
			action_panel.set_enabled(true)
			var action = _pending_action
			_pending_action = Callable()
			actor_indicator.text = ""
			_execute_selected_action(action, dead_allies[_dead_ally_select_idx])
			get_viewport().set_input_as_handled()
		return

	# 攻击/捕捉模式：选敌人	
	if _selection_mode == SelectionMode.ENEMY:
		var enemies = battle_manager.alive_enemies()
		if enemies.is_empty(): return
		if event.is_action_pressed("ui_left"):
			_enemy_select_idx = (_enemy_select_idx + 1) % enemies.size()
			_highlight_enemy(enemies[_enemy_select_idx])
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_enemy_select_idx = (_enemy_select_idx - 1 + enemies.size()) % enemies.size()
			_highlight_enemy(enemies[_enemy_select_idx])
			get_viewport().set_input_as_handled()
		elif _is_accept(event):
			_selection_mode = SelectionMode.NONE
			_clear_enemy_selection()
			_enable_enemy_selection(false)
			var target = enemies[_enemy_select_idx]
			var action = _pending_action
			_pending_action = Callable()
			actor_indicator.text = ""
			_execute_selected_action(action, target)
			get_viewport().set_input_as_handled()
		return

## 同步图标状态：是否正在选队友目标（控制 CursorController 的箭头光标）
func _set_cursor_selecting_ally(val: bool) -> void:
	var cc := _find_cursor_controller(get_tree().root)
	if cc:
		cc._selecting_ally = val


func _find_cursor_controller(from: Node) -> CursorController:
	for child in from.get_children():
		if child is CursorController:
			return child
		var found := _find_cursor_controller(child)
		if found:
			return found
	return null


func _cancel_pending() -> void:
	_pending_summon_pet = null
	_pending_mech_name = ""
	_pet_replace_targets.clear()
	_mech_replace_targets.clear()
	_talisman_targets.clear()
	_pending_action = Callable()
	_selection_mode = SelectionMode.NONE
	actor_indicator.text = ""
	_enable_enemy_selection(false)
	_enable_ally_selection(false)
	_enable_dead_ally_selection(false)
	_set_cursor_selecting_ally(false)
	_clear_enemy_selection()
	action_panel.visible = true
	action_panel.set_enabled(true)
	action_panel.slide_in()
	action_panel.btn_attack.grab_focus()
	_talisman_attacking = false
	if battle_manager.state == BattleManager.BattleState.PLAYER_TURN:
		actor_indicator.text = battle_manager.current_actor().stats.get_display_name() + " 选择行动"
		_enable_enemy_selection(true)


func _is_mouse_over_selectable_target() -> bool:
	for ch in battle_manager.enemies:
		if ch.is_dead: continue
		var nd = ch.get_parent()
		if nd and nd.selectable:
			var rect = Rect2(nd.global_position - Vector2(50, 60), Vector2(100, 120))
			if rect.has_point(get_viewport().get_mouse_position()):
		
				return true
	for btn in _ally_pick_btns:
		if is_instance_valid(btn) and btn.get_global_rect().has_point(get_viewport().get_mouse_position()):
			return true
	return false


func _selectable_allies() -> Array:
	var result: Array[BattleCharacter] = []
	for ch in battle_manager.party:
		if not ch.is_dead and (_ally_select_include_self or ch != battle_manager.current_actor()):
			result.append(ch)
	return result

func _highlight_ally(ch: BattleCharacter) -> void:
	for p in battle_manager.party:
		var nd = p.get_parent()
		if nd: nd.set_selected(p == ch)

func _highlight_enemy(ch: BattleCharacter) -> void:
	_clear_enemy_selection()
	var nd = ch.get_parent()
	if nd: nd.set_selected(true)


## 鼠标悬停敌人 — 火眼金睛：显示怪物状态 tooltip + 同步键盘高亮
func _on_enemy_hovered(ch: BattleCharacter) -> void:
	if _selection_mode == SelectionMode.TALISMAN:
		if ch in _talisman_targets: _highlight_talisman_target(ch)
		return
	if GameData.has_talent("main_true_sight"):
		_show_tooltip(ch)
	# 选敌模式下同步键盘高亮
	var enemies := battle_manager.alive_enemies()
	var idx := enemies.find(ch)
	if idx >= 0:
		_enemy_select_idx = idx
		_highlight_enemy(ch)


func _on_ally_hovered(ch: BattleCharacter) -> void:
	if _selection_mode == SelectionMode.TALISMAN and ch in _talisman_targets:
		_highlight_talisman_target(ch)
	_show_tooltip(ch)


# ══════════════════════════════════════════════
# Tooltip 悬浮提示
# ══════════════════════════════════════════════

func _build_tooltip() -> void:
	_tooltip = Panel.new()
	_tooltip.name = "Tooltip"
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tooltip.visible = false
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.02, 0.04, 0.12, 0.92)
	s.border_color = Color(0.3, 0.5, 0.8, 0.7)
	s.border_width_top = 1; s.border_width_bottom = 1
	s.border_width_left = 1; s.border_width_right = 1
	s.content_margin_top = 4; s.content_margin_bottom = 4
	s.content_margin_left = 6; s.content_margin_right = 6
	_tooltip.add_theme_stylebox_override("panel", s)
	add_child(_tooltip)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	_tooltip.add_child(vbox)

	for key in ["name", "hp", "mp", "buffs"]:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		vbox.add_child(lbl)
		_tooltip_labels[key] = lbl


func _show_tooltip(ch: BattleCharacter) -> void:
	if ch == null or _tooltip == null:
		return
	var eff_max_hp := ch.get_effective_max_hp()
	_tooltip_labels["name"].text = "%s  lv%d" % [ch.stats.get_display_name(), ch.stats.level]
	_tooltip_labels["name"].add_theme_color_override("font_color", Color(1, 0.85, 0.2))

	_tooltip_labels["hp"].text = "HP: %d / %d" % [ch.current_hp, eff_max_hp]
	_tooltip_labels["hp"].add_theme_color_override("font_color", Color(0.3, 1, 0.4))

	_tooltip_labels["mp"].text = "MP: %d / %d" % [ch.current_mp, ch.get_effective_max_mp()]
	_tooltip_labels["mp"].add_theme_color_override("font_color", Color(0.4, 0.7, 1))

	var buf_text := ""
	var has_debuff := false
	for bid in ch.buffs:
		var entry: Dictionary = ch.buffs[bid]
		var layers: Array = entry.get("layers", [])
		if layers.is_empty(): continue
		var name := _buff_display_name(bid)
		var layer_count := layers.size()
		if bid in ["burn", "freeze", "slow", "poison", "weakened"]:
			has_debuff = true
		for l in layers:
			var turns: int = l.get("turns", 0)
			if buf_text != "":
				buf_text += "\n"
			if bid == "ghost_shield":
				# 无敌盾：显示层数 xN 而非回合数
				var charges := int(l.get("value", 1.0))
				buf_text += "%s x%d" % [name, charges]
			else:
				buf_text += "%s (%d)" % [name, turns]
	_tooltip_labels["buffs"].add_theme_color_override("font_color", Color(1, 0.4, 0.2) if has_debuff else Color(0.5, 1, 0.4))
	_tooltip_labels["buffs"].text = buf_text if buf_text else ""
	_tooltip_labels["buffs"].visible = not buf_text.is_empty()

	_tooltip.visible = true
	_update_tooltip_position()
	_tooltip_hover_count += 1


func _hide_tooltip() -> void:
	_tooltip_hover_count = maxi(0, _tooltip_hover_count - 1)
	await get_tree().create_timer(0.08).timeout
	if _tooltip_hover_count == 0 and _tooltip:
		_tooltip.visible = false


func _update_tooltip_position() -> void:
	if _tooltip == null or not _tooltip.visible:
		return
	var pos := get_viewport().get_mouse_position() + Vector2(18, 12)
	var vs := get_viewport().get_visible_rect().size
	if pos.x + _tooltip.size.x > vs.x:
		pos.x = vs.x - _tooltip.size.x - 4
	if pos.y + _tooltip.size.y > vs.y:
		pos.y = vs.y - _tooltip.size.y - 4
	_tooltip.position = pos


## Buff ID → 显示名
func _buff_display_name(buff_id: String) -> String:
	match buff_id:
		"shield": return "护盾"
		"haste": return "加速"
		"hp_up": return "气血↑"
		"atk_up": return "攻击↑"
		"matk_up": return "法攻↑"
		"def_up": return "防御↑"
		"mdef_up": return "魔防↑"
		"lifesteal_up": return "吸血↑"
		"burn": return "灼烧"
		"freeze": return "冰封"
		"slow": return "减速"
		"sleep": return "催眠"
		"confuse": return "疯魔"
		"dmg_down": return "减伤"
		"poison": return "中毒"
		"weakened": return "虚弱"
		"def_broken": return "破甲"
		"mdef_broken": return "魔防破碎"
		"atk_down": return "降攻"
		"marked": return "割喉标记"
		"bleed": return "流血"
		"ghost_shield": return "鬼影护体"
		"ghost_boost": return "鬼煞附体"
		"ghost_gate": return "鬼门大开"
		"invincible": return "无敌"
		"失魂": return "失魂"
		"regen": return "持续回血"
		"sancai": return "三才阵·回蓝/双抗+30%"
		"silence": return "封印"
		_: return buff_id


# ══════════════════════════════════════════════
# 我方状态卡
# ══════════════════════════════════════════════


# ══════════════════════════════════════════════
# 行动顺序条（队友头像 + SP 平滑上下浮动）# ══════════════════════════════════════════════

const _ENTRY_SCENE = preload("res://tools/TurnOrderEntry.tscn")

func _make_turn_entry(c: BattleCharacter) -> void:
	if _turn_entries.has(c):
		return

	var entry := _ENTRY_SCENE.instantiate() as VBoxContainer
	var avatar := entry.get_node("Bg/Avatar")
	var pin := entry.get_node("AxisPin") as Polygon2D
	if not c.is_player:
		pin.position.y = entry.size.y
		pin.scale.y = -1.0
		pin.color = Color(1.0, 0.66, 0.48)
	_turn_order.add_child(entry)

	_turn_entries[c] = {
		"entry": entry,
		"avatar": avatar,
	}

	# 连接信号
	if not _turn_signal_connected.has(c):
		_turn_signal_connected.append(c)
		c.sp_changed.connect(_on_sp_changed.bind(c))
		c.hp_changed.connect(_on_hp_changed_for_portrait.bind(c))
		c.buff_added.connect(_on_buff_added_for_portrait.bind(c))
		c.died.connect(_on_turn_actor_died.bind(c))
	# 初始头像
	_update_avatar_for(c)

func _update_turn_order() -> void:
	_turn_progress_pending = false
	var current: BattleCharacter = null
	if battle_manager.state in [BattleManager.BattleState.PLAYER_TURN, BattleManager.BattleState.PLAYER_ACTION, BattleManager.BattleState.ENEMY_TURN]:
		current = battle_manager.current_actor()
	var occupants: Dictionary = {}
	var track := _turn_order.get_node("进度条") as Sprite2D
	var shown: Dictionary = {}
	var allies: Array[Control] = []
	var enemies: Array[Control] = []
	for actor in battle_manager.party + battle_manager.enemies:
		if actor.is_dead: continue
		if not _turn_entries.has(actor):
			_make_turn_entry(actor)
		var acting: bool = actor == current
		var progress := 1.0 if acting else clampf(actor.current_sp / 100.0, 0.0, 1.0)
		var inset := 20.0
		var x := lerpf(inset, _turn_order.size.x - inset, progress)
		var marker := _turn_entries[actor]["entry"] as Control
		var count_label := marker.get_node("Bg/Count") as Label
		# 同种敌人只有落在同一个像素才共用标记，速度不同便自然分开。
		if not actor.is_player and not acting:
			var cohort := "%s:%s:%d" % [actor.stats.character_name, actor.stats.was_base_path, roundi(x)]
			if occupants.has(cohort):
				var group: Dictionary = occupants[cohort]
				group.count += 1
				group.label.text = "×%d" % group.count
				group.label.show()
				continue
			occupants[cohort] = {"label": count_label, "count": 1}
		count_label.hide()
		shown[actor] = true
		marker.show()
		marker.scale = Vector2.ONE * (0.72 if acting else 0.56)
		var extent := marker.size * marker.scale
		var y := track.position.y + 5.0 if actor.is_player else track.position.y - 5.0 - extent.y
		marker.position = Vector2(x - extent.x * 0.5, y)
		if actor.is_player:
			allies.append(marker)
		else:
			enemies.append(marker)
		marker.z_index = 10 if acting else 1
		marker.modulate = Color.WHITE if acting else Color(0.92, 0.95, 1.0)
	for actor in _turn_entries:
		if not shown.has(actor):
			_turn_entries[actor]["entry"].hide()
	_space_turn_portraits(allies)
	_space_turn_portraits(enemies)


func _space_turn_portraits(row: Array[Control]) -> void:
	# 先从右向左留出实际头像宽度，再从左向右修正起点边界。
	row.sort_custom(func(a: Control, b: Control):
		var ax := a.position.x + a.size.x * a.scale.x * 0.5
		var bx := b.position.x + b.size.x * b.scale.x * 0.5
		if not is_equal_approx(ax, bx): return ax < bx
		if a.z_index != b.z_index: return a.z_index < b.z_index
		return a.get_instance_id() < b.get_instance_id()
	)
	var total_width := 0.0
	for marker in row:
		total_width += marker.size.x * marker.scale.x
	# 超出整条可容纳数量时，保持原来的进度位置；少人时尽量留 3 像素间隔。
	var room := _turn_order.size.x - total_width
	var gap := minf(3.0, room / maxi(1, row.size() - 1))
	var right := _turn_order.size.x
	var packed := PackedFloat32Array()
	packed.resize(row.size())
	for i in range(row.size() - 1, -1, -1):
		var marker := row[i]
		packed[i] = minf(marker.position.x, right - marker.size.x * marker.scale.x)
		right = packed[i] - gap
	var left := 0.0
	for i in row.size():
		var marker := row[i]
		var nominal_x := marker.position.x
		if room >= 0.0:
			marker.position.x = maxf(left, packed[i])
		left = marker.position.x + marker.size.x * marker.scale.x + gap
		var pin := marker.get_node("AxisPin") as Polygon2D
		pin.position.x = marker.size.x * 0.5 + (nominal_x - marker.position.x) / marker.scale.x
		var lead := marker.get_node("PinLead") as Line2D
		var edge_x := clampf(pin.position.x, 1.0, marker.size.x - 1.0)
		lead.visible = absf(edge_x - pin.position.x) > 1.0
		if lead.visible:
			lead.default_color = pin.color
			lead.points = PackedVector2Array([Vector2(edge_x, pin.position.y), pin.position])

# 🔄 SP 变化时更新进度条 🔄
func _on_sp_changed(_old: float, _new: float, _max: float, _actor: BattleCharacter) -> void:
	# 管理器逐个推进 SP；等这一帧所有参战者推进完再画时间轴。
	if not _turn_progress_pending:
		_turn_progress_pending = true
		_refresh_pending_turn_progress.call_deferred()

func _refresh_pending_turn_progress() -> void:
	if _turn_progress_pending:
		_update_turn_order()

# 💀 角色死亡时隐藏 💀
func _on_turn_actor_died(_c: BattleCharacter) -> void:
	_update_turn_order()

# 😠 HP 变化时更新头像（受击时换脸）😠
func _on_hp_changed_for_portrait(o: int, n: int, _m: int, c: BattleCharacter) -> void:
	if n < o:
		var e = _turn_entries.get(c)
		if e != null:
			var tex = _portrait_texture(c.stats.was_base_path, "x44", c.stats.portrait_path, c.stats.character_name)
			if tex:
				e["avatar"].texture = tex
	else:
		_update_avatar_for(c)

# ✨ 加buff状态时临时显示 buff 头像 + 左移 ✨
func _on_buff_added_for_portrait(buff_id: String, c: BattleCharacter) -> void:
	var e = _turn_entries.get(c)
	if e == null:
		return
	var tex = _portrait_texture(c.stats.was_base_path, "x44", c.stats.portrait_path, c.stats.character_name)
	if tex:
		e["avatar"].texture = tex

# ══════════════════════════════════════════════
# 飘字
# ══════════════════════════════════════════════

func _on_damage_floated(target: BattleCharacter, amount: int, float_type: String) -> void:
	var world_node: Node2D = target.get_parent()
	if world_node == null: return
	var screen_pos := world_node.get_global_transform_with_canvas().origin
	screen_pos += Vector2(randf_range(-20, 20), -10)

	var container := Node2D.new()
	container.position = screen_pos
	container.scale = Vector2(0.08, 0.08)
	# 避免 "Parent node is busy setting up children" 报错
	if is_inside_tree():
		add_child(container)
	else:
		call_deferred("add_child", container)

	# ── 数字图集切格参数（Graphic/UI/伤害and回血.png）──
	# 图集 4696×1189，两行十列；但数字不是均匀分布！以下为扫描得到的真实内容坐标
	# 顺序：数字1,2,3,4,5,6,7,8,9,0（0 在最后）
	var digit_content_x := [184, 608, 1056, 1500, 1972, 2412, 2841, 3190, 3608, 4022]   # 各数字内容起点
	var digit_content_r := [487, 943, 1406, 1910, 2371, 2787, 3188, 3563, 3961, 4403]   # 各数字内容右边界
	var digit_row_h := 594.5     # 每行高度（1189/2）
	var digit_row_offset := 0    # 行偏移（第一行伤害、第二行治疗；默认 0）
	var digit_disp_x := 0.0      # 显示位置 X 偏移（正数向右）
	var digit_disp_y := 0.0      # 显示位置 Y 偏移（正数向下）
	# 数字图集：两行十列（第一行伤害、第二行治疗）
	var atlas := load("res://Graphic/UI/伤害and回血.png") as Texture2D
	var atlas_row := 0
	var tint := Color(1, 1, 1)
	var is_crit := false
	match float_type:
		"heal":
			atlas_row = 1  # 第二行：治疗
		"crit":
			pass  # 暴击用普通数字样式，左侧加大号"暴击"字
		"mp":
			atlas_row = 1  # 第二行：治疗（回蓝）
			tint = Color(0.5, 0.7, 1.0)
		"magic":
			tint = Color(0.75, 0.45, 1.0)  # 法术伤害紫色
	container.modulate = tint

	# 暴击：左边加大号"暴击"字
	if is_crit:
		var crit_lbl := Label.new()
		crit_lbl.text = "暴击"
		crit_lbl.add_theme_font_size_override("font_size", 50)
		crit_lbl.add_theme_color_override("font_color", Color("#FFD700"))
		crit_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		crit_lbl.add_theme_constant_override("shadow_offset_x", 2)
		crit_lbl.add_theme_constant_override("shadow_offset_y", 2)
		var font: Font = load("res://Graphic/UI/Font/AaJianMingShouShu-2.ttf")
		crit_lbl.add_theme_font_override("font", font)
		crit_lbl.position = Vector2(-160, -28)
		container.add_child(crit_lbl)

	# 拆分数位
	var digits: Array[int] = []
	var n := amount
	if n == 0:
		digits = [0]
	else:
		while n > 0:
			digits.push_front(n % 10)
			n /= 10

	var total_width: float = 0.0
	var digit_specs: Array[Dictionary] = []
	for d in digits:
		# 图集顺序 1-9,0：数字 d 对应表中下标 = (d + 9) % 10
		var idx := (d + 9) % 10
		var cw: float = float(digit_content_r[idx]) - float(digit_content_x[idx])
		digit_specs.append({"d": d, "idx": idx, "w": cw})
		total_width += cw

	# 暴击时数字右移，给"暴击"字留空间
	var x_offset := -total_width * 0.1

	var digit_spacing := 4.0  # 数字间距
	for spec in digit_specs:
		var spr := Sprite2D.new()
		spr.texture = atlas
		spr.region_enabled = true
		var idx: int = spec["idx"]
		spr.region_rect = Rect2(
			digit_content_x[idx],
			(atlas_row + digit_row_offset) * digit_row_h,
			digit_content_r[idx] - digit_content_x[idx],
			digit_row_h
		)
		spr.position.x = x_offset + digit_disp_x
		spr.position.y = digit_disp_y
		x_offset += spec["w"] + digit_spacing
		container.add_child(spr)

	# 上浮渐隐
	var tween = create_tween()
	tween.tween_property(container, "position:y", container.position.y - 60, 0.9)
	tween.parallel().tween_property(container, "modulate:a", 0.0, 0.9)
	tween.tween_callback(container.queue_free)

# ══════════════════════════════════════════════
# 动画驱动
# ══════════════════════════════════════════════

func _on_character_animated(actor: BattleCharacter, anim_name: String, target: BattleCharacter) -> void:
	if actor.is_player:
		var nd = actor.get_parent()
		if nd:
			if anim_name == "attack" and target:
				var enemy_nd = target.get_parent()
				var target_pos = target.get_parent().global_position
				# 目标挨打				
				var ee = _turn_entries.get(target)
				if ee != null:
					var tex = _portrait_texture(target.stats.was_base_path, "x44", target.stats.portrait_path if target.stats else "", target.stats.character_name if target.stats else "")
					if tex: ee["avatar"].texture = tex
				# on_hit：攻击命中时立刻扣血，不等走回来
				# 斩杀特效：died 信号会触发（EnemyNode._on_died 处理冰冻碎冰/失魂离体）			
				var on_hit := func():
					battle_manager.flush_pending_damage()
				battle_manager.active_melee_animations += 1
				await nd.play_attack_sequence(target_pos, enemy_nd, on_hit)
				battle_manager.active_melee_animations -= 1
				battle_manager.flush_pending_damage()  # 兜底（on_hit 已清空则无操作）
				# 走回来后才刷新头像				
				if ee != null:
					_update_avatar_for(target)
			elif anim_name == "cast":
				var spell_name = nd._current_spell_anim
				# 目标进入挨打 + 闪白 + 法术特效（仅对敌人）
				var target_node: Node2D = target.get_parent() if target and is_instance_valid(target) else null
				if target_node and not target.is_player:
					if target_node.has_method("play_hit_once"):
						target_node.play_hit_once()
					if target_node.has_method("play_hit_flash"):
						target_node.play_hit_flash()
				if target and is_instance_valid(target):
					target.play_spell_effect(spell_name)
				# 施法者播放施法动画				
				await nd.play_cast_sequence(spell_name)
				nd._current_spell_anim = ""
				battle_manager.flush_pending_damage()
				# 斩杀特效：died 信号会触发
				if target_node and target_node.has_method("play_idle"):
					if target and is_instance_valid(target):
						if target.is_dead:
							pass  # 已死亡，不覆盖死亡动画
						elif target.is_frozen:
							target.sync_freeze_anim()
						elif target.is_weakened:
							target.show_debuff("虚弱")
						else:
							target_node.play_idle()
			elif anim_name == "ranged_attack" and target:
				# 远程攻击：原地播放攻击动画 → 命中结算
				var target_pos = target.get_parent().global_position
				var caster_pos = actor.get_parent().global_position if actor.get_parent() else Vector2.ZERO
			
				var ee = _turn_entries.get(target)
				if ee != null:
					var tex = _portrait_texture(target.stats.was_base_path, "x44", target.stats.portrait_path if target.stats else "", target.stats.character_name if target.stats else "")
					if tex: ee["avatar"].texture = tex
				nd.play_ranged_attack()
				var target_node: Node2D = target.get_parent()
				# 主角（主）用符咒飞行，命中时触发受击+伤害
				if CharacterStats.has_role(actor.stats.role, CharacterStats.Role.MAIN):
					var on_hit := func():
						if target_node:
							if target_node.has_method("play_hit_once"):
								target_node.play_hit_once()
							if target_node.has_method("play_hit_flash"):
								target_node.play_hit_flash()
						battle_manager.flush_pending_damage()
					await SpellProjectile.shoot(caster_pos, target_pos, target.get_parent(), on_hit, self, actor, actor.stats.talisman_type, _get_talisman_texture(actor))
					# 分裂符：额外投射物
					var fenlie_r = actor.talent_rank("fenliefu")
					if fenlie_r > 0:
						var extras := battle_manager.alive_enemies()
						extras.erase(target)
						extras.shuffle()
						for j in mini(fenlie_r, extras.size()):
							var et = extras[j]
							var et_node = et.get_parent()
							var et_pos = et_node.global_position if et_node else Vector2.ZERO
							SpellProjectile.shoot(caster_pos, et_pos, et_node, func():
								if et_node:
									if et_node.has_method("play_hit_once"):
										et_node.play_hit_once()
									if et_node.has_method("play_hit_flash"):
										et_node.play_hit_flash()
							, self, actor, actor.stats.talisman_type, _get_talisman_texture(actor))
				else:
					# 非主角远程无弹道，直接受击
					if target_node:
						if target_node.has_method("play_hit_once"):
							target_node.play_hit_once()
						if target_node.has_method("play_hit_flash"):
							target_node.play_hit_flash()
					if nd.has_method("play_ranged_hit_effect"):
						nd.play_ranged_hit_effect(target.get_parent(), actor.stats.was_base_path)
				battle_manager.flush_pending_damage()
				# 等施法者攻击动画播完
				while nd._ranged_animating:
					await get_tree().process_frame
				battle_manager.ranged_attack_completed.emit()
				if target_node and target_node.has_method("play_idle") and target and not target.is_dead:
					target_node.play_idle()
				if ee != null:
					_update_avatar_for(target)
			else:
				nd.play_animation(anim_name)
	else:
		var nd = actor.get_parent()
		if nd:
			if anim_name == "attack" and target:
				var has_guard = battle_manager.flush_guard_warp()
				var hero_nd = target.get_parent()
				var hit_target: Node2D = hero_nd if (hero_nd and not has_guard) else null
				var target_pos = target.get_parent().global_position
				# 目标挨打				
				var ee = _turn_entries.get(target)
				if ee != null:
					var tex = _portrait_texture(target.stats.was_base_path, "x44", target.stats.portrait_path if target.stats else "", target.stats.character_name if target.stats else "")
					if tex: ee["avatar"].texture = tex
				var on_hit := func():
					battle_manager.flush_pending_damage()
					battle_manager.flush_guard_return()
				await nd.play_attack_sequence(target_pos, hit_target, on_hit)
				battle_manager.flush_pending_damage()
				battle_manager.flush_guard_return()
				if actor and actor.is_weakened:
					actor.show_debuff("虚弱")

				if ee != null:
					_update_avatar_for(target)
			elif anim_name == "cast":
				var spell_name = nd._current_spell_anim
				var target_node: Node2D = target.get_parent() if target and is_instance_valid(target) else null
				if target_node:
					if target_node.has_method("play_hit_once"):
						target_node.play_hit_once()
					if target_node.has_method("play_hit_flash"):
						target_node.play_hit_flash()
				if target and is_instance_valid(target):
					target.play_spell_effect(spell_name)
				await nd.play_cast_sequence(spell_name)
				nd._current_spell_anim = ""
				battle_manager.flush_pending_damage()
				# 斩杀特效：died 信号会触发
				if target_node and target_node.has_method("play_idle"):
					if target and is_instance_valid(target):
						if target.is_dead:
							pass  # 已死亡，不覆盖死亡动画
						elif target.is_frozen:
							target.sync_freeze_anim()
						elif target.is_weakened:
							target.show_debuff("虚弱")
						else:
							target_node.play_idle()
			elif anim_name == "ranged_attack" and target:
				var has_guard = battle_manager.flush_guard_warp()
				var hero_nd = target.get_parent()
				var hit_target: Node2D = hero_nd if (hero_nd and not has_guard) else null
				var target_pos = target.get_parent().global_position
				var caster_pos = actor.get_parent().global_position if actor.get_parent() else Vector2.ZERO
				var ee = _turn_entries.get(target)
				if ee != null:
					var tex = _portrait_texture(target.stats.was_base_path, "x44", target.stats.portrait_path if target.stats else "", target.stats.character_name if target.stats else "")
					if tex: ee["avatar"].texture = tex
				nd.play_ranged_attack()
				var tgt_node: Node2D = target.get_parent()
				if CharacterStats.has_role(actor.stats.role, CharacterStats.Role.MAIN):
					var on_hit := func():
						if tgt_node:
							if tgt_node.has_method("play_hit_once"):
								tgt_node.play_hit_once()
							if tgt_node.has_method("play_hit_flash"):
								tgt_node.play_hit_flash()
						battle_manager.flush_pending_damage()
						battle_manager.flush_guard_return()
					await SpellProjectile.shoot(caster_pos, target_pos, hit_target, on_hit, self)
				else:
					# 非主角远程无弹道，直接受击
					if tgt_node:
						if tgt_node.has_method("play_hit_once"):
							tgt_node.play_hit_once()
						if tgt_node.has_method("play_hit_flash"):
							tgt_node.play_hit_flash()
					if hit_target and nd.has_method("play_ranged_hit_effect"):
						nd.play_ranged_hit_effect(hit_target, actor.stats.was_base_path)
				battle_manager.flush_pending_damage()
				battle_manager.flush_guard_return()
				# 等攻击动画播完
				while nd._ranged_animating:
					await get_tree().process_frame
				battle_manager.ranged_attack_completed.emit()
				await get_tree().create_timer(0.4).timeout
				if tgt_node and tgt_node.has_method("play_idle") and target and not target.is_dead:
					tgt_node.play_idle()
				if ee != null:
					_update_avatar_for(target)
			else:
				nd.play_animation(anim_name)

# ══════════════════════════════════════════════
# BattleManager 信号回调
# ══════════════════════════════════════════════

func _on_log_pushed(text: String, log_type: String) -> void:
	# 转义文本中的 BBCode 特殊字符，防止被解析成标签
	var escaped := text.replace("[", "[lb]").replace("]", "[rb]")
	var line := "[color=%s]%s[/color]\n" % [LOG_COLORS.get(log_type, "white"), escaped]
	battle_log.text += line
	if battle_log.text.length() > 5000:
		battle_log.text = battle_log.text.substr(battle_log.text.length() - 5000)
	call_deferred("_scroll_log")
	GameData.world_log_text += line
	if GameData.world_log_text.length() > 5000:
		GameData.world_log_text = GameData.world_log_text.substr(GameData.world_log_text.length() - 5000)
	var log_node := get_tree().current_scene.get_node_or_null("UI/BattleLog") as RichTextLabel
	if log_node:
		log_node.text += line
		if log_node.text.length() > 5000:
			log_node.text = log_node.text.substr(log_node.text.length() - 5000)

func _scroll_log() -> void:
	if battle_log and is_instance_valid(battle_log):
		battle_log.scroll_to_line(battle_log.get_line_count())


func _on_skill_failed(msg: String) -> void:
	_show_floating_text(msg, Color(0.8, 0.8, 0.8))
	_play_wrong_sound()
	# 有些前置检查直接失败，状态始终是 PLAYER_TURN，不会触发 state_changed。
	# 延迟到本次选择回调完成后恢复，也兼容先报错再切回玩家回合的分支。
	_restore_failed_skill_selection.call_deferred(battle_manager.current_actor())

func _restore_failed_skill_selection(actor: BattleCharacter) -> void:
	if not is_instance_valid(actor) or actor.is_dead: return
	if battle_manager.current_actor() != actor or battle_manager.state != BattleManager.BattleState.PLAYER_TURN: return
	_cancel_pending()
	_on_state_changed(BattleManager.BattleState.PLAYER_TURN)
	action_panel.btn_attack.grab_focus()

func _on_state_changed(new_state: BattleManager.BattleState) -> void:
	_update_turn_order()
	if new_state != BattleManager.BattleState.PLAYER_TURN:
		action_panel.set_enabled(false)
		_pending_action = Callable()
		_enable_enemy_selection(false)
		_enable_ally_selection(false)
		_enable_dead_ally_selection(false)
		_clear_enemy_selection()
		_set_cursor_selecting_ally(false)
		# 非玩家回合隐藏操作面板		
		action_panel.visible = false
		_set_talisman_visible(false)
	else:
		# 恢复操作面板，敌人默认可点击（直接点 = 普通攻击）
		action_panel.visible = true
		action_panel.set_enabled(true)
		_enable_enemy_selection(true)
		_set_cursor_selecting_ally(false)
		_check_threat_eye()
		# 恢复角色指示文字和技能面板
		var actor := battle_manager.current_actor()
		if actor and not actor.is_dead:
			actor_indicator.text = actor.stats.get_display_name() + " 选择行动"
			var actor_node := actor.get_parent()
			if actor_node:
				action_panel.show_near(actor_node.global_position)
			action_panel.refresh(actor, true)

func _on_actor_turn_started(actor: BattleCharacter, is_player: bool) -> void:
	for ch in battle_manager.party:
		var nd = ch.get_parent()
		if nd: nd.set_active_turn(false)
	for ch in battle_manager.enemies:
		var nd = ch.get_parent()
		if nd: nd.set_selected(false)

	if is_player:
		var nd = actor.get_parent()
		if nd: nd.set_active_turn(true)

		# 面板定位到角色右侧		
		var actor_node := actor.get_parent()
		if actor_node:
			action_panel.show_near(actor_node.global_position)

		# 远程角色显示当前符咒
		var talisman_info = ""
		if actor.stats.is_ranged:
			var idx = actor.stats.talisman_type
			if idx >= 0 and idx < _talisman_names.size():
				talisman_info = " " + _talisman_names[idx]
		actor_indicator.text = GameData._T("BATTLE_TURN_OF") % [actor.stats.get_display_name(), talisman_info]
		action_panel.refresh(actor, true)
		_enable_enemy_selection(true)
		# 自动聚焦攻击按钮
		action_panel.btn_attack.grab_focus()
	else:
		return
	#	actor_indicator.text = GameData._T("BATTLE_ACTING") % actor.stats.character_name

	# 头顶名字：只有当前行动者变色	
	for ch in battle_manager.party + battle_manager.enemies:
		ch.set_name_label_color(Color.WHITE)
	actor.set_name_label_color(Color.RED)

	_update_talisman_display()

func _on_bonus_attack_started() -> void:
	var actor = battle_manager.current_actor()
	if actor == null: return
	actor_indicator.text = actor.stats.get_display_name() + " ⚡双动"
	# 自动聚焦普通攻击按钮
	if action_panel and action_panel.btn_attack:
		action_panel.btn_attack.grab_focus()

func _on_battle_ended(player_won: bool, exp_gained: int, gold_gained: int, level_ups: Array) -> void:
	
	action_panel.set_enabled(false)
	_enable_enemy_selection(false)
	_pending_action = Callable()
	actor_indicator.text = ""
	if player_won:
		# 停掉战斗 BGM
		_stop_battle_bgm()
		# 播放胜利音效（挂在 root 上防止随战场销毁）
		var snd := AudioStreamPlayer.new()
		snd.stream = load("res://Audio/SE/胜利.wav")
		snd.bus = "SFX"
		snd.finished.connect(snd.queue_free)
		get_tree().root.add_child(snd)
		snd.play()
		battle_manager._push_log(GameData._T("BATTLE_VICTORY"), "turn")
		await _show_reward_popup(exp_gained, gold_gained)
		for lu in level_ups:
			await _show_level_up_popup(lu)
		await _show_battle_summary()
		battle_manager.recover_after_battle()
	else:
		battle_manager._push_log(GameData._T("BATTLE_DEFEAT"), "system")
		await get_tree().create_timer(1.0).timeout
		await _show_battle_summary()
	var battle_scene = get_parent()
	if battle_scene and battle_scene != get_tree().current_scene:
		var return_overlay = battle_scene.get_meta("return_overlay", null)
		if is_instance_valid(return_overlay):
			await return_overlay.cover()
		# 独立运行战斗场景时没有所属地图，直接结束；地图战斗共用同一块黑幕。

		battle_scene.queue_free()
		# 战后保存战损 + 恢复 5% 血蓝
		for c in battle_manager.party:
			if c.member_id.is_empty(): continue
			var s = GameData.party_db.get(c.member_id)
			if s == null: continue
			s.saved_hp = mini(c.current_hp + int(s.max_hp * 0.05), s.max_hp)
			s.saved_mp = mini(c.current_mp + int(s.max_mp * 0.05), s.max_mp)
			if s.saved_hp >= s.max_hp: s.saved_hp = 0
			if s.saved_mp >= s.max_mp: s.saved_mp = 0
		_damage_stats.clear()
		_healing_stats.clear()
	get_tree().current_scene.get_node("UI/BattleLog").visible = true
	var out_log := get_tree().current_scene.get_node_or_null("UI/BattleLog") as RichTextLabel
	if out_log:
		out_log.scroll_to_line(out_log.get_line_count())

## 战斗统计总结弹窗（胜/负后显示伤害和治疗排行）
func _show_battle_summary() -> void:
	var panel = preload("res://scenes/UI/BattleSummary.tscn").instantiate()
	add_child(panel)
	_populate_summary_section(panel.get_node("Body/Columns/Damage/Content"), _damage_stats, "damage")
	_populate_summary_section(panel.get_node("Body/Columns/Healing/Content"), _healing_stats, "heal")
	var ok: Button = panel.get_node("Body/Footer/Confirm")
	ok.text = GameData._T("BATTLE_CONFIRM")
	ok.grab_focus()
	await ok.pressed
	panel.queue_free()


func _populate_summary_section(content: Control, stats: Dictionary, category: String) -> void:
	var rows: VBoxContainer = content.get_node("Scroll/Rows")
	var entries: Array = []
	var total: int = 0
	for key in stats:
		var member_name: String = str(key)
		if GameData.party_db.has(key):
			member_name = GameData.party_db[key].get_display_name()
		var amount: int = int(stats[key])
		if amount <= 0: continue
		entries.append({"name": member_name, "value": amount})
		total += amount
	entries.sort_custom(func(a, b): return a.value > b.value)
	content.get_node("Total").text = "合计  %s" % total
	rows.get_node("Empty").visible = entries.is_empty()
	for entry in entries:
		# 条目数量由战斗数据决定，复用编辑器中配置的条目场景。
		var row = preload("res://scenes/UI/BattleStatsRow.tscn").instantiate()
		rows.add_child(row)
		row.display(entry.name, entry.value, entries[0].value, category)
		row.get_node("Fields/NameLabel").add_theme_color_override("font_color", Color.WHITE)
		row.get_node("Fields/ValueLabel").modulate = Color.WHITE
		row.get_node("Meter").modulate = Color("#9ec8ff") if category == "damage" else Color("#99e4cc")


## 战斗总结中的仇恨排序（仅显示角色名排序，不显示数值）
func _add_threat_summary(parent: Control) -> void:
	var tm := battle_manager._threat_mgr
	if tm == null:
		return
	var lbl := Label.new()
	lbl.text = "—— 仇恨 ——"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1, 0.5, 0.3))
	parent.add_child(lbl)

	var entries: Array = []
	for c in battle_manager.party:
		if c.is_dead:
			continue
		var val := tm.get_threat_value(c)
		entries.append({"name": c.stats.get_display_name(), "value": val})
	if entries.is_empty():
		var na := Label.new()
		na.text = "-"
		na.add_theme_font_size_override("font_size", 11)
		parent.add_child(na)
		return
	entries.sort_custom(func(a, b): return a.value > b.value)
	for e in entries:
		var line := Label.new()
		line.text = e.name
		line.add_theme_font_size_override("font_size", 12)
		parent.add_child(line)


## 停掉战斗场景的 BGM
func _stop_battle_bgm() -> void:
	
	var battle_scene = get_parent()
	if battle_scene == null: return
	for c in battle_scene.get_children():
		if c is AudioStreamPlayer:
			c.stop()

## 战斗胜利：经验和金币奖励弹窗
func _show_reward_popup(exp_gained: int, gold_gained: int) -> void:
	var panel = preload("res://scenes/UI/BattleResult.tscn").instantiate()
	add_child(panel)
	panel.get_node("Body/Card/Content/Rewards/Experience/Value").text = "+%d" % exp_gained
	panel.get_node("Body/Card/Content/Rewards/Gold/Value").text = "+%d" % gold_gained
	await _confirm_battle_result(panel)


## 升级弹窗：与奖励窗口共用场景和样式，技能列表超长时可滚动。
func _show_level_up_popup(lu: Dictionary) -> void:
	var panel = preload("res://scenes/UI/BattleResult.tscn").instantiate()
	add_child(panel)
	panel.get_node("Body/Title").text = "等级提升"
	panel.get_node("Body/Caption").text = str(lu.get("name", ""))
	panel.get_node("Body/Card/Content/Rewards").hide()
	var level: Label = panel.get_node("Body/Card/Content/Level")
	level.text = "%d 级  →  %d 级" % [int(lu["old_level"]), int(lu["new_level"])]
	level.show()
	var skills: Array = lu.get("new_skills", [])
	if not skills.is_empty():
		var section = panel.get_node("Body/Card/Content/SkillSection")
		section.get_node("Body/Heading").text = "习得新技能  %d" % skills.size()
		var list = section.get_node("Body/Scroll/Skills")
		for skill in skills:
			# 每次升级学会的技能数不固定，实例化可编辑的技能条目场景。
			var entry = preload("res://scenes/UI/BattleLearnedSkill.tscn").instantiate()
			list.add_child(entry)
			entry.get_node("Name").text = str(skill)
		section.show()
	await _confirm_battle_result(panel)


func _confirm_battle_result(panel: Control) -> void:
	var ok: Button = panel.get_node("Body/Footer/Confirm")
	ok.text = GameData._T("BATTLE_CONFIRM")
	ok.grab_focus()
	await ok.pressed
	panel.queue_free()


func _make_panel_style(bg_color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_color
	s.border_width_left = 2; s.border_width_right = 2
	s.border_width_top = 2; s.border_width_bottom = 2
	s.border_color = Color(0.8, 0.7, 0.3, 0.6)
	s.corner_radius_top_left = 12; s.corner_radius_top_right = 12
	s.corner_radius_bottom_left = 12; s.corner_radius_bottom_right = 12
	s.content_margin_left = 20; s.content_margin_right = 20
	s.content_margin_top = 16; s.content_margin_bottom = 16
	return s


## 每帧检查仇恨目标是否变化（由 _on_damage_stats 驱动）
func _check_threat_eye() -> void:
	if battle_manager._threat_mgr == null:
		return
	var alive := battle_manager.alive_party()
	if alive.is_empty():
		return
	var top := battle_manager._threat_mgr.get_top_target(alive)
	var top_key := top.member_id if (top and not top.member_id.is_empty()) else (top.stats.character_name if top else "")
	if _threat_eye_first:
		_threat_eye_first = false
		# 第一轮不显示眼睛，只记录当前最高目标方便后续对比
		if top_key != "":
			_last_top_threat_key = top_key
		return
	elif top_key != "" and top_key != _last_top_threat_key \
		and battle_manager._threat_mgr.get_threat_value(top) > 0:
		_show_threat_eye(top)
		_last_top_threat_key = top_key


## 仇恨目标变化时显示眼睛指示器（淡入 → 停留 → 淡出）
func _show_threat_eye(target: BattleCharacter) -> void:
	if target == null:
		return
	# 等攻击动画结束角色归位
	await get_tree().create_timer(0.5).timeout
	# 懒加载 eye 精灵
	if _threat_eye == null:
		_threat_eye = Sprite2D.new()
		_threat_eye.name = "ThreatEye"
		_threat_eye.texture = load("res://Graphic/RANDOM/eye.png")
		_threat_eye.visible = true
		_threat_eye.modulate.a = 1.0  # 先设为可见再淡
		_threat_eye.z_index = 500
		_threat_eye.scale.x = 0.3
		_threat_eye.scale.y = 0.3
		
		add_child(_threat_eye)
	# 定位到目标上方（找不到就放屏幕中上）
	var pos := Vector2(500, 0)
	var nd := target.get_parent() as Node2D
	if nd and nd.global_position.length() > 10:
		pos = nd.global_position + Vector2(0, -50)
	_threat_eye.global_position = pos

	# 音效
	var snd := AudioStreamPlayer.new()
	snd.stream = load("res://Audio/SE/087-Action02.ogg")
	snd.bus = "SFX"
	snd.finished.connect(snd.queue_free)
	add_child(snd)
	snd.play()

	# 动画：淡入 → 停留 1s → 淡出（打断旧动画，重新淡入）
	if _threat_eye.has_meta("_eye_tween"):
		var old := _threat_eye.get_meta("_eye_tween") as Tween
		if old and old.is_valid():
			old.kill()
	_threat_eye.modulate.a = 0.0
	var tw := create_tween()
	_threat_eye.set_meta("_eye_tween", tw)
	tw.tween_property(_threat_eye, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.0)
	tw.tween_property(_threat_eye, "modulate:a", 0.0, 0.3)



# ══════════════════════════════════════════════
# 技能弹窗# ══════════════════════════════════════════════

func _on_open_skill_popup(actor: BattleCharacter, get_cd_func: Callable) -> void:
	if _skill_popup == null:
		return
	_skill_popup.open(actor, get_cd_func)


func _on_popup_skill_selected(skill_id: String) -> void:
	action_panel.set_enabled(false)
	_action_skill(skill_id)


func _on_popup_cancelled() -> void:
	# 恢复操作面板
	_cancel_pending()


func _on_open_item_popup(actor: BattleCharacter, inventory: Inventory) -> void:
	if _skill_popup == null:
		return
	_skill_popup.open_for_items(actor, inventory)


func _on_popup_item_selected(item_id: String) -> void:
	action_panel.set_enabled(false)
	_last_item_id = item_id
	_action_item(item_id)

# ══════════════════════════════════════════════
# 召唤弹窗
# ══════════════════════════════════════════════

var _pending_summon_pet: PetData = null  # 替换模式：待召唤的宠物
var _pet_replace_idx: int = 0
var _pet_replace_targets: Array[BattleCharacter] = []

func _on_summon_pet_selected(pet: PetData) -> void:
	# 检查是否有空闲位	
	var scene = get_parent()
	if scene and scene.has_method("has_free_pet_slot") and not scene.has_free_pet_slot():
		# 没有空位 → 进入替换模式
		_pending_summon_pet = pet
		_enable_pet_replace_selection(true)
		return

	# 有空位 → 正常召唤
	action_panel.set_enabled(false)
	battle_manager.player_summon(pet)
	_finish_action()


func _enable_pet_replace_selection(val: bool) -> void:
	if val:
		actor_indicator.text = GameData._T("BATTLE_CLICK_REPLACE")
		action_panel.set_enabled(false)
	else:
		actor_indicator.text = ""
		action_panel.set_enabled(true)
		action_panel.slide_in()
		_clear_ally_pick_btns()

	if not val:
		_pending_summon_pet = null
		_pet_replace_targets.clear()
		_pet_replace_idx = 0
		return

	# 收集所有可替换的宠物	
	_pet_replace_targets.clear()
	for ch in battle_manager.party:
		if ch.is_summoned_pet and not ch.is_dead:
			_pet_replace_targets.append(ch)

	# 先高亮当前选中显示指示器	
	_pet_replace_idx = 0
	if _pet_replace_targets.is_empty():
		_cancel_pending()
		return

	# 创建透明按钮
	_rebuild_pet_replace_buttons()
	# 保留已建立的鼠标替换按钮。
	_refresh_pet_replace_highlight()
	set_process(true)


func _refresh_pet_replace_highlight() -> void:
	for i in _pet_replace_targets.size():
		var ch = _pet_replace_targets[i]
		var nd = ch.get_parent()
		if nd: nd.set_selected(i == _pet_replace_idx)


func _rebuild_pet_replace_buttons() -> void:
	_clear_ally_pick_btns()
	for i in _pet_replace_targets.size():
		var ch = _pet_replace_targets[i]
		var nd = ch.get_parent()
		if nd == null: continue
		var btn = Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(80, 100)
		btn.modulate = Color(0, 0, 0, 0)
		var target_ch = ch
		btn.pressed.connect(func():
			if not _pending_summon_pet: return
			var pet = _pending_summon_pet
			_pending_summon_pet = null
			_enable_pet_replace_selection(false)
			_do_replace_summon(target_ch, pet)
		)
		btn.position = nd.global_position - btn.custom_minimum_size * 0.5
		add_child(btn)
		_ally_pick_btns.append(btn)
		_ally_pick_nodes.append(nd)


func _do_replace_summon(old_bc: BattleCharacter, new_pet: PetData) -> void:
	action_panel.set_enabled(false)
	actor_indicator.text = ""
	# 保存旧位置再移除
	var old_pos = old_bc.get_parent().position if old_bc.get_parent() else Vector2.ZERO
	var old_node = old_bc.get_parent()
	if old_node:
		var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(old_node, "position:x", old_node.position.x + 300, 0.4)
		tween.parallel().tween_property(old_node, "modulate:a", 0.0, 0.35)
		await tween.finished
	battle_manager.remove_character(old_bc)
	if is_instance_valid(old_node):
		old_node.queue_free()
	# 新宠站在旧位置进场 + 攻击
	battle_manager.player_summon(new_pet, old_pos)
	_finish_action()


func _on_summon_cancelled() -> void:
	if _pending_summon_pet:
		_enable_pet_replace_selection(false)
		_pending_summon_pet = null
	_cancel_pending()


# ══════════════════════════════════════════════
# 铁甲兽召唤
# ══════════════════════════════════════════════

func _show_mech_summon_popup() -> void:
	if battle_manager.state != BattleManager.BattleState.PLAYER_TURN:
		return
	if GameData.mech_team.is_empty():
		battle_manager._push_log("没有可以召唤的铁甲兽！", "system")
		_finish_action()
		return
	_mech_summon_popup.open(battle_manager.summoned_mech_ids)


func _on_mech_selected(mech_name: String) -> void:
	action_panel.set_enabled(false)
	var scene = get_parent()
	if scene and scene.has_method("has_free_pet_slot") and not scene.has_free_pet_slot():
		_pending_mech_name = mech_name
		_enable_mech_replace_selection(true)
		return
	battle_manager.player_summon_mech(mech_name)
	_finish_action()


var _pending_mech_name: String = ""
var _mech_replace_idx: int = 0
var _mech_replace_targets: Array[BattleCharacter] = []


func _enable_mech_replace_selection(val: bool) -> void:
	if val:
		actor_indicator.text = GameData._T("BATTLE_CLICK_REPLACE")
		action_panel.set_enabled(false)
	else:
		actor_indicator.text = ""
		action_panel.set_enabled(true)
		action_panel.slide_in()
		_clear_ally_pick_btns()
	if not val:
		_pending_mech_name = ""
		_mech_replace_targets.clear()
		_mech_replace_idx = 0
		return
	_mech_replace_targets.clear()
	for ch in battle_manager.party:
		if ch.is_summoned_pet and not ch.is_dead:
			_mech_replace_targets.append(ch)
	_mech_replace_idx = 0
	if _mech_replace_targets.is_empty():
		_cancel_pending()
		return
	_rebuild_mech_replace_buttons()
	_refresh_mech_replace_highlight()
	set_process(true)


func _rebuild_mech_replace_buttons() -> void:
	_clear_ally_pick_btns()
	for i in _mech_replace_targets.size():
		var ch = _mech_replace_targets[i]
		var nd = ch.get_parent()
		if nd == null: continue
		var btn = Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(80, 100)
		btn.position.y += 45
		btn.modulate = Color(0, 0, 0, 0)
		var target_ch = ch
		var mech_name = _pending_mech_name
		btn.pressed.connect(func():
			_enable_mech_replace_selection(false)
			battle_manager.player_summon_mech(mech_name, target_ch)
			_finish_action()
		)
		btn.position = nd.global_position - btn.custom_minimum_size * 0.5
		add_child(btn)
		_ally_pick_btns.append(btn)
		_ally_pick_nodes.append(nd)


func _refresh_mech_replace_highlight() -> void:
	for i in _mech_replace_targets.size():
		var ch = _mech_replace_targets[i]
		var nd = ch.get_parent()
		if nd: nd.set_selected(i == _mech_replace_idx)


func _on_mech_summon_cancelled() -> void:
	if _pending_mech_name:
		_pending_mech_name = ""
		_enable_mech_replace_selection(false)
	_cancel_pending()


# —— 总血条刷新回调（信号参数匹配）——
func _on_enemy_hp_changed(_old: int, _new: int, _max: int) -> void:
	_refresh_enemy_total_hp()

func _on_enemy_died_for_bar() -> void:
	_refresh_enemy_total_hp()

func _on_damage_floated_for_bar(_target: BattleCharacter, _amount: int, _type: String) -> void:
	_refresh_enemy_total_hp()


## 战斗统计：累加每人造成的伤害和治疗（宠物归因到召唤者）
func _on_damage_stats(_actor: BattleCharacter, _target: BattleCharacter, _amount: int, kind: String) -> void:
	if (_stats_mode == "damage" and kind == "damage") or (_stats_mode == "heal" and kind in ["heal", "revive"]) or _stats_mode == "threat":
		_refresh_stats_display()
	_check_threat_eye()


# ══ 战斗统计面板 ══
func _build_stats_panel() -> void:
	for mode in STATS_TABS:
		var tab := _stats_panel.get_node(STATS_TABS[mode]) as Button
		tab.pressed.connect(_select_stats_tab.bind(mode))
	_stats_panel.show()
	_select_stats_tab("threat")


func _select_stats_tab(mode: String) -> void:
	_stats_mode = mode
	var tab := _stats_panel.get_node(STATS_TABS[mode]) as Button
	tab.button_pressed = true
	_refresh_stats_display()


func _refresh_stats_display() -> void:
	if not is_instance_valid(_stats_panel) or not _stats_panel.visible:
		return
	var entries: Array[Dictionary] = []
	var highest := 0
	if _stats_mode == "threat":
		var alive := battle_manager.alive_party()
		var threat := battle_manager._threat_mgr
		for actor in alive:
			var amount: int = threat.get_threat_value(actor) if threat else 0
			var state: String = threat.get_threat_state(actor, alive) if threat else ""
			entries.append({"name": actor.stats.get_display_name(), "amount": amount, "category": state})
			highest = maxi(highest, amount)
	else:
		var totals := _damage_stats if _stats_mode == "damage" else _healing_stats
		for key in totals:
			var member: CharacterStats = GameData.party_db.get(key)
			var member_name := member.get_display_name() if member else str(key)
			var amount := int(totals[key])
			entries.append({"name": member_name, "amount": amount, "category": _stats_mode})
			highest = maxi(highest, amount)
		entries.sort_custom(func(a, b): return a.amount > b.amount)

	var rows := _stats_panel.get_node("%Rows") as VBoxContainer
	while rows.get_child_count() > entries.size():
		var extra := rows.get_child(-1)
		rows.remove_child(extra)
		extra.queue_free()
	for i in entries.size():
		if i == rows.get_child_count():
			rows.add_child(STATS_ROW.instantiate())
		var entry := entries[i]
		rows.get_child(i).display(entry.name, entry.amount, highest, entry.category)
	_stats_panel.get_node("%Empty").visible = entries.is_empty()
	var scroll := _stats_panel.get_node("%ListScroll") as ScrollContainer
	var list_height := clampi(entries.size(), 1, 5) * 27
	if scroll.custom_minimum_size.y != list_height:
		scroll.custom_minimum_size.y = list_height
		_stats_panel.reset_size.call_deferred()


# ══ 符咒系统 ══
## 获取当前符咒的飞行贴图 —— 从失魂符.png 5×4 雪碧图取第 0 帧
func _get_talisman_texture(actor: BattleCharacter) -> Texture2D:
	return _tcp_to_texture("res://TCP/符咒/3290.tcp")

## 切换符咒类型
func switch_talisman(actor: BattleCharacter, ttype: int) -> void:
	if not actor or not actor.stats or ttype == actor.stats.talisman_type: return
	var old_idx := _talisman_types.find(actor.stats.talisman_type)
	var steps := posmod(_talisman_types.find(ttype) - old_idx, _talisman_types.size())
	var direction := 1 if steps * 2 <= _talisman_types.size() else -1
	var previous: Dictionary = _talisman_group.displayed_poses() if _talisman_group.visible else {}
	battle_manager.select_talisman(actor, ttype)
	_update_talisman_display()
	if _talisman_group.visible and not previous.is_empty():
		_talisman_group.slide_to_selection(previous, direction)


# ══ 三符咒显示 ══
var _talisman_types: Array[int] = [CharacterStats.TalismanType.FIRE, CharacterStats.TalismanType.SLEEP, CharacterStats.TalismanType.ICE, CharacterStats.TalismanType.HASTE, CharacterStats.TalismanType.CEASEFIRE, CharacterStats.TalismanType.REVIVE, CharacterStats.TalismanType.BASIC]
var _talisman_names: Array[String] = ["星火篆", "五雷咒", "冰冻", "加速", "止战", "借尸符", "无字符"]
var _talisman_item_ids: Array[String] = ["talisman_fire", "talisman_thunder", "talisman_ice", "talisman_haste", "talisman_ceasefire", "talisman_revive", "talisman_basic"]
var _talisman_attacking := false   # 防止重复点击

## 获取辅助天赋加成（全局查询函数）
static func get_support_talent_bonus(talent_id: String, base_val: float, per_rank: float) -> float:
	return preload("res://Script/Battle/TalentRules.gd").get_support_talent_bonus(talent_id, base_val, per_rank)

static func get_pet_stat_mult(stat: String) -> float:
	return preload("res://Script/Battle/TalentRules.gd").get_pet_stat_mult(stat)


## 消耗当前符咒（节约成本天赋可能跳过）
func _consume_talisman() -> bool:
	if not battle_manager.consume_talisman():
		return false
	# 刷新标签数量
	for name_prefix in ["符咒1", "符咒2", "符咒3"]:
		var nd = _find_talisman_node(name_prefix)
		if nd == null or not nd.visible: continue
		var type_idx: int = nd.get_meta("_talisman_type_idx", -1)
		if type_idx < 0 or type_idx >= _talisman_item_ids.size(): continue
		_update_talisman_label(nd, type_idx)
	return true

@onready var _talisman_group: Node2D = $"../FloatingTalismans"


func _setup_talisman_display() -> void:
	_talisman_group.get_node("符咒1/Button").pressed.connect(_on_talisman_prev)
	_talisman_group.get_node("符咒3/Button").pressed.connect(_on_talisman_next)
	_update_talisman_display()


func _find_talisman_node(slot_name: String) -> Node2D:
	return _talisman_group.get_node(slot_name)


func _update_talisman_display() -> void:
	var actor := battle_manager.current_actor()
	if actor == null or actor.is_dead or battle_manager.state != BattleManager.BattleState.PLAYER_TURN or not CharacterStats.has_role(actor.stats.role, CharacterStats.Role.MAIN):
		_set_talisman_visible(false)
		return
	_set_talisman_visible(true)
	var idx := _talisman_types.find(actor.stats.talisman_type)
	var total := _talisman_types.size()
	_set_talisman_slot("符咒1", posmod(idx - 1, total))
	_set_talisman_slot("符咒2", idx)
	_set_talisman_slot("符咒3", posmod(idx + 1, total))


func _set_talisman_slot(slot_name: String, type_idx: int) -> void:
	var slot := _find_talisman_node(slot_name)
	slot.set_meta("_talisman_type_idx", type_idx)
	slot.visible = type_idx >= 0
	if not slot.visible: return
	var item: ItemData = GameData.item_db.get(_talisman_item_ids[type_idx])
	var paper := slot.get_node("Sprite2D") as Sprite2D
	paper.texture = _tcp_to_texture(item.icon_path) if item else null
	if paper.texture:
		var box := Vector2(44, 50) if slot_name == "符咒2" else Vector2(30, 34)
		var fit := minf(box.x / paper.texture.get_width(), box.y / paper.texture.get_height())
		paper.scale = Vector2.ONE * fit
	_update_talisman_label(slot, type_idx)


func _update_talisman_label(slot: Node2D, type_idx: int) -> void:
	var unlimited := _talisman_types[type_idx] == CharacterStats.TalismanType.BASIC
	var count := battle_manager.player_inventory.get_count(_talisman_item_ids[type_idx])
	var shortcut := ""
	match str(slot.name):
		"符咒1": shortcut = "Q  "
		"符咒3": shortcut = "E  "
	var title := slot.get_node("Label") as Label
	title.text = "%s%s (%s)" % [shortcut, _talisman_names[type_idx], "∞" if unlimited else str(count)]
	slot.get_node("Sprite2D").modulate = Color.WHITE if unlimited or count > 0 else Color(0.55, 0.59, 0.65)
	var button := slot.get_node_or_null("Button") as Button
	if button:
		var item: ItemData = GameData.item_db.get(_talisman_item_ids[type_idx])
		button.tooltip_text = title.text + ("\n" + item.description if item else "")


func _set_talisman_visible(val: bool) -> void:
	var actor := battle_manager.current_actor() if val else null
	_talisman_group.follow(actor.get_parent() if actor else null)


func _tcp_to_texture(tcp_path: String) -> Texture2D:
	return preload("res://Script/Assets/AssetLoader.gd").tcp_texture(tcp_path)


func _on_talisman_prev() -> void:
	var actor = battle_manager.current_actor() if battle_manager else null
	if actor == null or actor.is_dead: return
	if not CharacterStats.has_role(actor.stats.role, CharacterStats.Role.MAIN): return
	_play_talisman_switch_sound()
	var ttype = actor.stats.talisman_type
	var total = _talisman_types.size()
	var prev = (ttype - 1 + total) % total
	switch_talisman(actor, prev)

func _on_talisman_next() -> void:
	var actor = battle_manager.current_actor() if battle_manager else null
	if actor == null or actor.is_dead: return
	if not CharacterStats.has_role(actor.stats.role, CharacterStats.Role.MAIN): return
	_play_talisman_switch_sound()
	var ttype = actor.stats.talisman_type
	var total = _talisman_types.size()
	var next = (ttype + 1) % total
	switch_talisman(actor, next)

func _play_talisman_switch_sound() -> void:
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://Audio/SE/064-Swing03.ogg")
	snd.bus = "SFX"
	add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)
