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

const SKILL_POPUP = preload("res://Component/SkillPopup.tscn")
const SUMMON_POPUP = preload("res://Component/SummonPopup.tscn")
const MECH_SUMMON_POPUP = preload("res://Component/MechSummonPopup.tscn")
var _skill_popup: SkillPopup = null
var _summon_popup: SummonPopup = null
var _mech_summon_popup: MechSummonPopup = null

const LOG_COLORS = {
	"player_action":"cyan", "enemy_action":"tomato",
	"heal":"lightgreen",    "system":"gold",
	"turn":"gold",         "debuff":"orchid",
}
const BUFF_ICONS = {
	"shield": "🛡️",
	"atk_up": "⬆️",
	"atk_down": "⬇️",
	"poison": "☠️",
	"freeze": "❄️",
	"def_broken": "💢",
	"haste": "⚡",
	"slow": "🐢",
	"burn": "🔥",
}

var _pending_action: Callable  = Callable()
var _quick_cast_held: bool = false
var _quick_skill_per_char: Dictionary = {}  # character_name/member_id -> skill_id

# 🎨 头像变体缓存 🎨
var _portrait_cache: Dictionary = {}

func _portrait_texture(was_base: String, variant: String) -> Texture2D:
	var key := was_base + "/" + variant
	if _portrait_cache.has(key):
		return _portrait_cache[key]
	var path := was_base.trim_suffix("/") + "/头像/" + variant + ".was"
	if FileAccess.file_exists(path):
		var r := WASReader.new()
		if r.load_from_file(path):
			var d := r.decode_frame(0, 0)
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
	var r := WASReader.new()
	if not r.load_from_file(fallback_path):
		_portrait_cache[fallback_key] = null
		return null
	var d := r.decode_frame(0, 0)
	if d.is_empty() or not d.has("texture"):
		_portrait_cache[fallback_key] = null
		return null
	_portrait_cache[fallback_key] = d.texture
	return d.texture

func _update_avatar_for(c: BattleCharacter) -> void:
	var e = _turn_entries.get(c)
	if e == null:
		return
	var tex := _portrait_texture(c.stats.was_base_path, "x44")
	if tex:
		e["avatar"].texture = tex


# 📊 敌人总血量条 📊
var _enemy_total_hp_tween: Tween = null
var _enemy_total_hp_prev: float = 0.0  # 上一次血量，检测大额伤害
var _bar_shaking := false

func _refresh_enemy_total_hp() -> void:
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

# 📊 战斗统计
var _damage_stats: Dictionary = {}   # { member_id: int }
var _healing_stats: Dictionary = {}  # { member_id: int }
var _stats_list: VBoxContainer = null  # 统计条目容器
var _stats_mode: String = "damage"     # "damage" / "heal" / "threat"
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
	get_tree().current_scene.get_node("UI/BattleLog").visible = false
	battle_manager.log_pushed.connect(_on_log_pushed)
	battle_manager.damage_floated.connect(_on_damage_floated)
	battle_manager.state_changed.connect(_on_state_changed)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.actor_turn_started.connect(_on_actor_turn_started)
	battle_manager.character_animated.connect(_on_character_animated)

	actor_indicator.text = ""
	action_panel.set_enabled(false)

	# 延迟到下一帧执行 UI 初始化，确保 BattleScene._ready() 已调用 battle_manager.setup()
	call_deferred("init_ui")

# ══════════════════════════════════════════════
# BattleScene 调用的初始化入口
# ══════════════════════════════════════════════

func init_ui() -> void:
	# 重置仇恨 eye
	_threat_eye_first = true
	_last_top_threat_key = ""
	# 把外部 log 历史复制进战场 log
	battle_log.bbcode_enabled = true
	if not GameData.world_log_text.is_empty():
		battle_log.text = GameData.world_log_text
		battle_log.scroll_to_line(battle_log.get_line_count())
	# 连接敌人点击信号
	for ch in battle_manager.enemies:
		var nd = ch.get_parent()
		if nd:
			nd.clicked.connect(_on_enemy_sprite_clicked)
			nd.hovered.connect(_on_enemy_hovered)
			nd.mouse_left.connect(_hide_tooltip)
	# 连接队友点击信号（保护时选目标用）	
	for ch in battle_manager.party:
		var nd = ch.get_parent()
		if nd:
			nd.clicked.connect(_on_ally_sprite_clicked.bind(ch))
			nd.hovered.connect(_on_ally_hovered)
			nd.mouse_left.connect(_hide_tooltip)
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
	battle_manager.damage_floated.connect(_on_damage_stats)
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
	_turn_order.visible = true
	for c in battle_manager.party + battle_manager.enemies:
		_make_turn_entry(c)
	_update_turn_order()
	_build_stats_panel()
	_build_tooltip()
	# 延迟一帧确保 _threat_mgr 已创建，开局随机出 eye
	call_deferred("_check_threat_eye")

# ══════════════════════════════════════════════
# ActionPanel 回调
# ══════════════════════════════════════════════

func _action_attack() -> void:
	_set_pending(func(target: BattleCharacter):
		_last_attack_target = target
		# 愈战愈勇：普攻永久叠伤+速
		var actor := battle_manager.current_actor()
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
			return
	
		_show_mech_summon_popup()
		return
	if data == null: return
	match data.target_type:
		SkillData.TargetType.SINGLE_ENEMY:
			_set_pending(func(target: BattleCharacter):
				battle_manager.player_use_skill(skill_id, target)
			)
		SkillData.TargetType.SINGLE_ALLY:
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
	if data == null: return
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
	_summon_popup.open(battle_manager.summoned_pet_ids)

func _action_guard() -> void:
	_set_pending_ally(func(ally: BattleCharacter):
		battle_manager.player_guard(ally)
	, false)

func _action_capture() -> void:
	_set_pending_capture(func(target: BattleCharacter):
		battle_manager.player_capture(target)
	)

func _finish_action() -> void:
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
				action.call(ch)
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
	if nd: nd.set_selected(true)
	if _pending_action.is_valid():
		_selection_mode = SelectionMode.NONE
		var action = _pending_action
		_pending_action = Callable()
		_enable_enemy_selection(false)
		action.call(char)
	else:
		# 没有选择任何指令 → 直接普通攻击
		_last_attack_target = char
		# 愈战愈勇
		var actor := battle_manager.current_actor()
		if actor:
			actor.apply_stacking_buff()
		battle_manager.player_use_normal_attack(char)

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
				action.call(ch)
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
				var names = ["火焰", "雷电", "冰冻", "加速"]
				switch_talisman(actor, pressed)
				_push_log_to_battle("%s 切换符咒：%s" % [actor.stats.character_name, names[pressed]])


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
		action.call(ch)

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
enum SelectionMode { NONE, ENEMY, ALLY, DEAD_ALLY }
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
			action.call(allys[_ally_select_idx])
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
			action.call(dead_allies[_dead_ally_select_idx])
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
			action.call(target)
			get_viewport().set_input_as_handled()
		return

## 同步图标状态：是否正在选队友目标（控制 CursorController 的箭头光标）
func _set_cursor_selecting_ally(val: bool) -> void:
	var cc := _find_cursor_controller(get_tree().root)
	if cc:
		cc._selecting_ally = val


func _find_cursor_controller(from: Node) -> Control:
	for child in from.get_children():
		if child is CursorController:
			return child
		var found := _find_cursor_controller(child)
		if found:
			return found
	return null


func _cancel_pending() -> void:
	_pending_action = Callable()
	_selection_mode = SelectionMode.NONE
	actor_indicator.text = ""
	_enable_enemy_selection(false)
	_enable_ally_selection(false)
	_enable_dead_ally_selection(false)
	_set_cursor_selecting_ally(false)
	_clear_enemy_selection()
	action_panel.set_enabled(true)
	action_panel.slide_in()
	action_panel.btn_attack.grab_focus()


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


## 鼠标悬停敌人 — 同步更新 keyboard 选中
func _on_enemy_hovered(ch: BattleCharacter) -> void:
	_show_tooltip(ch)
	# 选敌模式下同步键盘高亮
	var enemies := battle_manager.alive_enemies()
	var idx := enemies.find(ch)
	if idx >= 0:
		_enemy_select_idx = idx
		_highlight_enemy(ch)


func _on_ally_hovered(ch: BattleCharacter) -> void:
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
	_tooltip_labels["name"].text = ch.stats.character_name
	_tooltip_labels["name"].add_theme_color_override("font_color", Color(1, 0.85, 0.2))

	_tooltip_labels["hp"].text = "HP: %d / %d" % [ch.current_hp, eff_max_hp]
	_tooltip_labels["hp"].add_theme_color_override("font_color", Color(0.3, 1, 0.4))

	_tooltip_labels["mp"].text = "MP: %d / %d" % [ch.current_mp, ch.stats.max_mp]
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
			var src: String = l.get("source", "")
			if buf_text != "":
				buf_text += "\n"
			if not src.is_empty():
				buf_text += "%s·%s (%d)" % [name, src, turns]
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
		"def_up": return "防御↑"
		"mdef_up": return "魔防↑"
		"burn": return "灼烧"
		"freeze": return "冰冻"
		"slow": return "减速"
		"poison": return "中毒"
		"weakened": return "虚弱"
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

func _update_turn_order() -> void:
	# 所有存活角色按 SP 降序排列
	var actors: Array = []
	for c in battle_manager.party + battle_manager.enemies:
		if not c.is_dead:
			actors.append(c)
	actors.sort_custom(func(a, b): return a.current_sp > b.current_sp)

	var _current := battle_manager._current_actor
	var current_alive := _current != null and not _current.is_dead

	# 构建显示列表：当前行动者始终在首位（最右），其余取 SP 最高的前 4 个	
	var display: Array = []
	var shown: Dictionary = {}
	if current_alive:
		display.append(_current)
		shown[_current] = true
	for c in actors:
		if shown.has(c):
			continue
		if display.size() >= 5:
			break
		display.append(c)
		shown[c] = true

	# 计算布局
	var slot_count := display.size()
	var panel_w := _turn_order.size.x
	if panel_w <= 0:
		panel_w = 800
	var entry_w := 52
	var gap := 2
	var slot_w := (panel_w - gap * 2 - entry_w) / maxi(1, slot_count - 1 if slot_count > 1 else 1)
	slot_w = mini(slot_w, 60)

	for i in range(slot_count):
		var c: BattleCharacter = display[i]
		var e = _turn_entries.get(c)
		if e == null:
			_make_turn_entry(c)
			e = _turn_entries.get(c)
			if e == null: continue

		e["entry"].visible = true
		e["entry"].position.y = 4

		var target_x := gap + float(slot_count - 1 - i) * slot_w
		var is_current := c == _current

		if is_current:
			e["entry"].position.x = target_x
			e["entry"].z_index = 15
			e["entry"].modulate = Color(1, 1, 1, 1)
			e["entry"].scale = Vector2(1.3, 1.3)
		else:
			e["entry"].position.x = target_x
			e["entry"].z_index = int(clampf(c.current_sp / 100.0, 0.0, 1.0) * 9)
			e["entry"].modulate = Color(0.65, 0.65, 0.65, 0.9)
			e["entry"].scale = Vector2(1.0, 1.0)

		_update_avatar_for(c)

	# 隐藏未显示的角色
	for c in _turn_entries.keys():
		var e = _turn_entries.get(c)
		if e:
			e["entry"].visible = shown.has(c)

	# 首帧懒加载 panel 宽度
	if panel_w == 800:
		await get_tree().process_frame
		_update_turn_order()

# 🔄 SP 变化时更新进度条 🔄
func _on_sp_changed(_old: float, _new: float, _max: float, c: BattleCharacter) -> void:
	_update_turn_order()

# 💀 角色死亡时隐藏 💀
func _on_turn_actor_died(_c: BattleCharacter) -> void:
	_update_turn_order()

# 😠 HP 变化时更新头像（受击时换脸）😠
func _on_hp_changed_for_portrait(o: int, n: int, _m: int, c: BattleCharacter) -> void:
	if n < o:
		var e = _turn_entries.get(c)
		if e != null:
			var tex := _portrait_texture(c.stats.was_base_path, "x44")
			if tex:
				e["avatar"].texture = tex
	else:
		_update_avatar_for(c)

# ✨ 加buff状态时临时显示 buff 头像 + 左移 ✨
func _on_buff_added_for_portrait(buff_id: String, c: BattleCharacter) -> void:
	var e = _turn_entries.get(c)
	if e == null:
		return
	var tex := _portrait_texture(c.stats.was_base_path, "x44")
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
	container.scale = Vector2(0.45, 0.45)
	add_child(container)

	var prefix: String = "23"
	match float_type:
		"heal":
			prefix = "21"
		"crit":
			prefix = "22"
		_:
			prefix = "23"

	# 如果是治疗量数字，前面加上"+" 小标记	
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
		var tex_path := "res://Graphic/RANDOM/%s-%d.png" % [prefix, d + 1]
		if not ResourceLoader.exists(tex_path):
			continue
		var tex := load(tex_path)
		if tex == null:
			continue
		digit_specs.append({"tex": tex, "w": tex.get_width()})
		total_width += tex.get_width()

	var x_offset := -total_width * 0.5
	for spec in digit_specs:
		var spr := Sprite2D.new()
		spr.texture = spec["tex"]
		spr.position.x = x_offset
		x_offset += spec["w"]
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
					var tex := _portrait_texture(target.stats.was_base_path, "x44")
					if tex: ee["avatar"].texture = tex
				# on_hit：攻击命中时立刻扣血，不等走回来
				# 斩杀特效：died 信号会触发（EnemyNode._on_died 处理冰冻碎冰/失魂离体）			
				var on_hit := func():
					battle_manager.flush_pending_damage()
				await nd.play_attack_sequence(target_pos, enemy_nd, on_hit)
				battle_manager.flush_pending_damage()  # 兜底（on_hit 已清空则无操作）
				# 走回来后才刷新头像				
				if ee != null:
					_update_avatar_for(target)
			elif anim_name == "cast":
				var spell_name = nd._current_spell_anim
				# 目标进入挨打 + 闪白 + 法术特效
				var target_node: Node2D = target.get_parent() if target and is_instance_valid(target) else null
				if target_node:
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
						if target.is_frozen:
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
					var tex := _portrait_texture(target.stats.was_base_path, "x44")
					if tex: ee["avatar"].texture = tex
				nd.play_ranged_attack()
				# 目标受击（与施法者动画同时进行）
				var target_node: Node2D = target.get_parent()
				if target_node:
					if target_node.has_method("play_hit_once"):
						target_node.play_hit_once()
					if target_node.has_method("play_hit_flash"):
						target_node.play_hit_flash()
				# 主角（主）用符咒飞行，其他远程直接播命中特效
				if CharacterStats.has_role(actor.stats.role, CharacterStats.Role.MAIN):
					var on_hit := func():
						battle_manager.flush_pending_damage()
					await SpellProjectile.shoot(caster_pos, target_pos, target.get_parent(), on_hit, self, actor, actor.stats.talisman_type, _get_talisman_texture(actor))
				else:
					if nd.has_method("play_ranged_hit_effect"):
						nd.play_ranged_hit_effect(target.get_parent(), actor.stats.was_base_path)
				battle_manager.flush_pending_damage()
				# 等施法者攻击动画播完再结束回合
				await nd.was_player.animation_finished
				battle_manager.ranged_attack_completed.emit()
				if target_node and target_node.has_method("play_idle"):
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
					var tex := _portrait_texture(target.stats.was_base_path, "x44")
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
						if target.is_frozen:
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
					var tex := _portrait_texture(target.stats.was_base_path, "x44")
					if tex: ee["avatar"].texture = tex
				nd.play_ranged_attack()
				# 目标受击动画
				var tgt_node: Node2D = target.get_parent()
				if tgt_node:
					if tgt_node.has_method("play_hit_once"):
						tgt_node.play_hit_once()
					if tgt_node.has_method("play_hit_flash"):
						tgt_node.play_hit_flash()
				if CharacterStats.has_role(actor.stats.role, CharacterStats.Role.MAIN):
					var on_hit := func():
						battle_manager.flush_pending_damage()
						battle_manager.flush_guard_return()
					await SpellProjectile.shoot(caster_pos, target_pos, hit_target, on_hit, self)
				else:
					if hit_target and nd.has_method("play_ranged_hit_effect"):
						nd.play_ranged_hit_effect(hit_target, actor.stats.was_base_path)
				battle_manager.flush_pending_damage()
				battle_manager.flush_guard_return()
				await nd.was_player.animation_finished
				battle_manager.ranged_attack_completed.emit()
				await get_tree().create_timer(0.4).timeout
				if tgt_node and tgt_node.has_method("play_idle"):
					tgt_node.play_idle()
				if ee != null:
					_update_avatar_for(target)
			else:
				nd.play_animation(anim_name)

# ══════════════════════════════════════════════
# BattleManager 信号回调
# ══════════════════════════════════════════════

func _on_log_pushed(text: String, log_type: String) -> void:
	var line := "[color=%s]%s[/color]\n" % [LOG_COLORS.get(log_type, "white"), text]
	battle_log.append_text(line)
	if battle_log.text.length() > 5000:
		battle_log.text = battle_log.text.substr(battle_log.text.length() - 5000)
	await get_tree().process_frame
	battle_log.scroll_to_line(battle_log.get_line_count())
	GameData.world_log_text += line
	# 限制长度，超了从前面截
	if GameData.world_log_text.length() > 5000:
		GameData.world_log_text = GameData.world_log_text.substr(GameData.world_log_text.length() - 5000)
	var log_node := get_tree().current_scene.get_node_or_null("UI/BattleLog") as RichTextLabel
	if log_node:
		log_node.append_text(line)
		if log_node.text.length() > 5000:
			log_node.text = log_node.text.substr(log_node.text.length() - 5000)

func _on_state_changed(new_state: BattleManager.BattleState) -> void:
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
	else:
		# 恢复操作面板，敌人默认可点击（直接点 = 普通攻击）
		action_panel.visible = true
		_enable_enemy_selection(true)
		_set_cursor_selecting_ally(false)
		_check_threat_eye()

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
		var talisman_names = ["[火焰]", "[雷电]", "[冰冻]", "[加速]"]
		var talisman_info = ""
		if actor.stats.is_ranged:
			talisman_info = " " + talisman_names[actor.stats.talisman_type]
		actor_indicator.text = GameData._T("BATTLE_TURN_OF") % [actor.stats.character_name, talisman_info]
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

	_update_turn_order()

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
	else:
		battle_manager._push_log(GameData._T("BATTLE_DEFEAT"), "system")
		await get_tree().create_timer(1.0).timeout
		await _show_battle_summary()
	var battle_scene = get_parent()
	if battle_scene and battle_scene != get_tree().current_scene:
		# 在自己 CanvasLayer 上覆盖一层黑幕渐显，然后销毁		
		var fade := ColorRect.new()
		fade.color = Color(0, 0, 0, 0)
		fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fade)
		var tw := get_tree().create_tween()
		tw.tween_property(fade, "color", Color.BLACK, 0.4)
		await tw.finished
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
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -160; panel.offset_top = -140
	panel.offset_right = 160; panel.offset_bottom = 140
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.set("theme_override_styles/panel", _make_panel_style(Color(0.06, 0.08, 0.20)))
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "战斗统计"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	vbox.add_child(title)

	# 伤害排行
	_add_summary_section(vbox, "伤害", _damage_stats)
	# 治疗排行
	_add_summary_section(vbox, "治疗", _healing_stats)

	# 点击关闭
	var ok := Button.new()
	ok.text = GameData._T("BATTLE_CONFIRM")
	ok.add_theme_font_size_override("font_size", 14)
	ok.custom_minimum_size = Vector2(100, 30)
	vbox.add_child(ok)

	ok.grab_focus()
	await ok.pressed
	panel.queue_free()


func _add_summary_section(parent: Control, label_text: String, stats: Dictionary) -> void:
	var lbl := Label.new()
	lbl.text = "—— %s ——" % label_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	parent.add_child(lbl)

	if stats.is_empty():
		var na := Label.new()
		na.text = "-"
		na.add_theme_font_size_override("font_size", 11)
		parent.add_child(na)
		return

	var entries: Array = []
	for key in stats:
		var name = key
		if GameData.party_db.has(key):
			name = GameData.party_db[key].character_name
		entries.append({"name": name, "value": stats[key]})
	entries.sort_custom(func(a, b): return a.value > b.value)
	for e in entries:
		var line := Label.new()
		line.text = "%s: %d" % [e.name, e.value]
		line.add_theme_font_size_override("font_size", 12)
		parent.add_child(line)


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
		entries.append({"name": c.stats.character_name, "value": val})
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
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -180; panel.offset_top = -110
	panel.offset_right = 180; panel.offset_bottom = 110
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.set("theme_override_styles/panel", _make_panel_style(Color(0.06, 0.08, 0.15)))
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = GameData._T("BATTLE_VICTORY").replace("🎉 ", "").replace("⚔️ ", "")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title)

	var exp_label := Label.new()
	exp_label.text = GameData._T("BATTLE_EXP") % exp_gained
	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_label.add_theme_font_size_override("font_size", 24)
	exp_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	vbox.add_child(exp_label)

	var gold_label := Label.new()
	gold_label.text = GameData._T("BATTLE_GOLD") % gold_gained
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 24)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(gold_label)

	var ok := Button.new()
	ok.text = GameData._T("BATTLE_CONFIRM")
	ok.add_theme_font_size_override("font_size", 20)
	ok.custom_minimum_size = Vector2(120, 40)
	ok.focus_mode = Control.FOCUS_ALL
	vbox.add_child(ok)

	ok.grab_focus()
	await ok.pressed

	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, 0.3)
	await tw.finished
	panel.queue_free()

## 升级弹窗
func _show_level_up_popup(lu: Dictionary) -> void:
	var name_str: String = lu.get("name", "???")
	var new_level: int = lu.get("new_level", 1)
	var new_skills: Array = lu.get("new_skills", [])

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -200; panel.offset_top = -140
	panel.offset_right = 200; panel.offset_bottom = 140
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.set("theme_override_styles/panel", _make_panel_style(Color(0.04, 0.05, 0.12)))
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = GameData._T("BATTLE_LV_UP")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title)

	var name_label := Label.new()
	name_label.text = name_str
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)

	var lv_label := Label.new()
	lv_label.text = GameData._T("BATTLE_LV_REACH") % new_level
	lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_label.add_theme_font_size_override("font_size", 22)
	lv_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	vbox.add_child(lv_label)

	if not new_skills.is_empty():
		var skill_text := "新技能："
		for sk in new_skills:
			skill_text += GameData._T("BATTLE_NEW_SKILL") + "【%s】" % sk
		var skill_label := Label.new()
		skill_label.text = skill_text
		skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_label.add_theme_font_size_override("font_size", 18)
		skill_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2))
		vbox.add_child(skill_label)

	var ok := Button.new()
	ok.text = GameData._T("BATTLE_CONFIRM")
	ok.add_theme_font_size_override("font_size", 20)
	ok.custom_minimum_size = Vector2(120, 40)
	ok.focus_mode = Control.FOCUS_ALL
	vbox.add_child(ok)

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
		# 开局全部仇恨为 0 → 随机选一人，记下 key 避免后续平局覆盖
		var all_zero := true
		for c in alive:
			if battle_manager._threat_mgr.get_threat_value(c) > 0:
				all_zero = false
				break
		if all_zero:
			alive.shuffle()
			top = alive[0]
			top_key = top.member_id if (top and not top.member_id.is_empty()) else (top.stats.character_name if top else "")
			_show_threat_eye(top)
			_last_top_threat_key = top_key
			return
		_show_threat_eye(top)
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
	action_panel.slide_in()
	action_panel.set_enabled(true)
	action_panel.btn_attack.grab_focus()


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

	# 创建透明按钮
	_rebuild_pet_replace_buttons()
	# 在按钮创建后再刷新指示器避免错位
	_clear_ally_pick_btns()
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
	action_panel.slide_in()
	action_panel.set_enabled(true)
	action_panel.btn_attack.grab_focus()


# ══════════════════════════════════════════════
# 铁甲兽召唤
# ══════════════════════════════════════════════

func _show_mech_summon_popup() -> void:
	if battle_manager.state != BattleManager.BattleState.PLAYER_TURN:
		return
	if GameData.mech_team.is_empty():
		battle_manager._push_log("没有可以召唤的铁甲兽！", "system")
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
	action_panel.slide_in()
	action_panel.set_enabled(true)
	action_panel.btn_attack.grab_focus()


# —— 总血条刷新回调（信号参数匹配）——
func _on_enemy_hp_changed(_old: int, _new: int, _max: int) -> void:
	_refresh_enemy_total_hp()

func _on_enemy_died_for_bar() -> void:
	_refresh_enemy_total_hp()

func _on_damage_floated_for_bar(_target: BattleCharacter, _amount: int, _type: String) -> void:
	_refresh_enemy_total_hp()


## 战斗统计：累加每人造成的伤害和治疗（宠物归因到召唤者）
func _on_damage_stats(target: BattleCharacter, amount: int, float_type: String) -> void:
	var actor := battle_manager.current_actor()
	if actor == null or not actor.is_player:
		return
	# 宠物/召唤物的伤害和治疗归到主人
	var key := actor.member_id
	if actor.is_summoned_pet and not actor.summoner_member_id.is_empty():
		key = actor.summoner_member_id
	if key.is_empty():
		return
	if float_type == "heal":
		_healing_stats[key] = _healing_stats.get(key, 0) + amount
	else:
		_damage_stats[key] = _damage_stats.get(key, 0) + amount
	# 如果当前面板正显示对应类型，自动刷新
	if (_stats_mode == "damage" and float_type != "heal") or (_stats_mode == "heal" and float_type == "heal"):
		_refresh_stats_display()
	# 威胁面板自动刷新
	if _stats_mode == "threat":
		_refresh_stats_display()
	# 仇恨 eye 检查
	_check_threat_eye()


# ══ 战斗统计面板 ══
func _build_stats_panel() -> void:
	var panel := Control.new()
	panel.name = "StatsPanel"
	panel.offset_left = 4; panel.offset_top = 340
	panel.offset_right = 180; panel.offset_bottom = 460
	add_child(panel)

	# 按钮行
	var hbox := HBoxContainer.new()
	hbox.position.y -= 40
	hbox.add_theme_constant_override("separation", 2)
	panel.add_child(hbox)

	var btn_threat := Button.new()
	btn_threat.text = "仇恨"
	btn_threat.custom_minimum_size = Vector2(52, 32)
	btn_threat.add_theme_font_size_override("font_size", 10)
	btn_threat.pressed.connect(func(): _stats_mode = "threat"; _refresh_stats_display())
	hbox.add_child(btn_threat)

	var btn_dmg := Button.new()
	btn_dmg.text = "伤害"
	btn_dmg.custom_minimum_size = Vector2(52, 32)
	btn_dmg.add_theme_font_size_override("font_size", 10)
	btn_dmg.pressed.connect(func(): _stats_mode = "damage"; _refresh_stats_display())
	hbox.add_child(btn_dmg)

	var btn_heal := Button.new()
	btn_heal.text = "治疗"
	btn_heal.custom_minimum_size = Vector2(52, 32)
	btn_heal.add_theme_font_size_override("font_size", 10)
	btn_heal.pressed.connect(func(): _stats_mode = "heal"; _refresh_stats_display())
	hbox.add_child(btn_heal)

	# 分割线
	var sep := HSeparator.new()
	panel.add_child(sep)

	# 统计条目容器
	_stats_list = VBoxContainer.new()
	_stats_list.add_theme_constant_override("separation", 1)
	panel.add_child(_stats_list)

	_refresh_stats_display()
	# 默认显示仇恨
	_stats_mode = "threat"
	_refresh_stats_display()


func _refresh_stats_display() -> void:
	if _stats_list == null:
		return
	for c in _stats_list.get_children():
		c.queue_free()

	if _stats_mode == "threat":
		var header := Label.new()
		header.text = "—— 仇恨 ——"
		header.add_theme_font_size_override("font_size", 12)
		_stats_list.add_child(header)

		var alive := battle_manager.alive_party()
		if alive.is_empty():
			var na := Label.new()
			na.text = "-"
			na.add_theme_font_size_override("font_size", 11)
			_stats_list.add_child(na)
			return

		var tm := battle_manager._threat_mgr
		for c in alive:
			var lbl := Label.new()
			var state := tm.get_threat_state(c, alive)
			lbl.text = "%s: %d" % [c.stats.character_name, tm.get_threat_value(c)]
			match state:
				"red":    lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
				"yellow": lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
				_:        lbl.add_theme_color_override("font_color", Color(0.3, 1, 0.4))
			lbl.add_theme_font_size_override("font_size", 11)
			_stats_list.add_child(lbl)
		return

	var src: Dictionary = _damage_stats if _stats_mode == "damage" else _healing_stats
	var title := "伤害" if _stats_mode == "damage" else "治疗"

	var header := Label.new()
	header.text = "—— %s ——" % title
	header.add_theme_font_size_override("font_size", 12)
	_stats_list.add_child(header)

	if src.is_empty():
		var na := Label.new()
		na.text = "-"
		na.add_theme_font_size_override("font_size", 11)
		_stats_list.add_child(na)
		return

	var entries: Array = []
	for key in src:
		var value: int = src[key]
		var name = key
		if GameData.party_db.has(key):
			name = GameData.party_db[key].character_name
		entries.append({ "name": name, "value": value })
	entries.sort_custom(func(a, b): return a.value > b.value)
	for e in entries:
		var lbl := Label.new()
		lbl.text = "%s: %d" % [e.name, e.value]
		lbl.add_theme_font_size_override("font_size", 11)
		_stats_list.add_child(lbl)


# ══ 符咒系统 ══
## 获取当前符咒的飞行贴图 —— 从失魂符.png 5×4 雪碧图取第 0 帧
func _get_talisman_texture(actor: BattleCharacter) -> Texture2D:
	var tex_path = "res://Graphic/BattleAnimation/失魂符.png"

	if !ResourceLoader.exists(tex_path):
		return null

	var sheet := load(tex_path)

	var atlas := AtlasTexture.new()
	atlas.atlas = sheet

	var columns := 5
	var rows := 4

	var frame_width = sheet.get_width() / columns
	var frame_height = sheet.get_height() / rows

	var frame := 0  # 第 0 帧
	var x := frame % columns
	var y := frame / columns

	atlas.region = Rect2(
		x * frame_width,
		y * frame_height,
		frame_width,
		frame_height
	)

	return atlas

## 切换符咒类型
func switch_talisman(actor: BattleCharacter, ttype: int) -> void:
	if actor and actor.stats:
		actor.stats.talisman_type = ttype as CharacterStats.TalismanType
