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
	"turn":"white",         "debuff":"orchid",
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
	# 平滑 tween 到新值	
	if _enemy_total_hp_tween and _enemy_total_hp_tween.is_valid():
		_enemy_total_hp_tween.kill()
		_enemy_total_hp_tween = create_tween().set_ease(Tween.EASE_OUT)
		_enemy_total_hp_tween.tween_property(_enemy_total_hp_bar, "value", maxi(0, total_cur), 0.3)
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

# ══════════════════════════════════════════════
func _ready() -> void:
	# 连接 BattleManager 信号
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
	# 连接敌人点击信号
	for ch in battle_manager.enemies:
		var nd = ch.get_parent()
		if nd:
			nd.clicked.connect(_on_enemy_sprite_clicked)
			nd.hovered.connect(_on_enemy_hovered)
	# 连接队友点击信号（保护时选目标用）	
	for ch in battle_manager.party:
		var nd = ch.get_parent()
		if nd: nd.clicked.connect(_on_ally_sprite_clicked.bind(ch))
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
		if not ch.hp_changed.is_connected(_on_enemy_hp_changed):
			ch.hp_changed.connect(_on_enemy_hp_changed)
		if not ch.died.is_connected(_on_enemy_died_for_bar):
			ch.died.connect(_on_enemy_died_for_bar)
	if not battle_manager.damage_floated.is_connected(_on_damage_floated_for_bar):
		battle_manager.damage_floated.connect(_on_damage_floated_for_bar)
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

# ══════════════════════════════════════════════
# ActionPanel 回调
# ══════════════════════════════════════════════

func _action_attack() -> void:
	_set_pending(func(target: BattleCharacter):
		battle_manager.player_use_normal_attack(target)
	)

func _action_skill(skill_id: String) -> void:
	# 记录快速施法（按角色分开）
	var actor := battle_manager.current_actor()
	if actor != null:
		var key := actor.member_id if not actor.member_id.is_empty() else actor.stats.character_name
		_quick_skill_per_char[key] = skill_id
	var data: SkillData = SkillManager.get_skill(skill_id)

	
	if skill_id == "召唤铁甲":
		var cd = battle_manager.get_skill_cooldown(battle_manager.current_actor(), skill_id)
		if cd > 0:
			battle_manager._push_log("【召唤铁甲兽】还剩%d 回合冷却 2 % cd ", "system")
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
		battle_manager._push_log("宠物无法使用召唤", "system")
		# 恢复面板，不能卡住		
		action_panel.set_enabled(true)
		action_panel.slide_in()
		action_panel.btn_attack.grab_focus()
		return
	# 只有召唤系角色才能召唤	
	if battle_manager.current_actor().stats.role != CharacterStats.Role.SUMMON:
		battle_manager._push_log("只有召唤系角色才能召唤", "system")
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
		_show_floating_text("不在玩家回合", Color(0.8, 0.8, 0.8))
		return false

	var actor := battle_manager.current_actor()
	if actor == null or actor.is_dead or actor.is_weakened or actor.is_frozen:
		_show_floating_text("当前角色无法行动", Color(0.8, 0.8, 0.8))
		return false

	var char_key := actor.member_id if not actor.member_id.is_empty() else actor.stats.character_name
	var skill_id: String = _quick_skill_per_char.get(char_key, "")
	if skill_id.is_empty():
		_show_floating_text("请先使用一次技能", Color(0.8, 0.8, 0.8))
		return false

	# 检查冷却	
	if battle_manager.get_skill_cooldown(actor, skill_id) > 0:
		_show_floating_text("技能冷却中", Color(0.8, 0.8, 0.8))
		return false

	# 从 SkillManager 获取技能数据，确定目标类型	
	var data: SkillData = SkillManager.get_skill(skill_id)
	if data == null:
		_show_floating_text("技能数据不存在", Color(0.8, 0.8, 0.8))
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
		_show_floating_text("没有合适的快速施法目标", Color(0.8, 0.8, 0.8))
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
	actor_indicator.text = "👆 点击或按左右方向键选择敌人（回车确认，ESC取消）"
	_enable_enemy_selection(true)
	_enemy_select_idx = 0
	action_panel.set_enabled(false)
	var enemies = battle_manager.alive_enemies()
	if enemies.size() > 0:
		_highlight_enemy(enemies[0])

func _set_pending_capture(callback: Callable) -> void:
	_pending_action = callback
	actor_indicator.text = "👆 点击或按左右方向键选择要捕捉的敌人（回车确认，ESC取消）"
	_enable_enemy_selection(true)
	_enemy_select_idx = 0
	action_panel.set_enabled(false)
	var enemies = battle_manager.alive_enemies()
	if enemies.size() > 0:
		_highlight_enemy(enemies[0])

func _set_pending_ally(callback: Callable, include_self: bool = true) -> void:
	_pending_action = callback
	_ally_select_include_self = include_self
	actor_indicator.text = "👆 点击或按方向键选择队友（回车确认，ESC取消）"
	action_panel.set_enabled(false)
	_enable_ally_selection(true)
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
		battle_manager._push_log("没有需要复活的队友", "system")
		action_panel.set_enabled(true)
		action_panel.slide_in()
		action_panel.btn_attack.grab_focus()
		return
	_pending_action = callback
	actor_indicator.text = "👆 点击或按方向键选择要复活的队友（回车确认，ESC取消）"
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
		var action = _pending_action
		_pending_action = Callable()
		_enable_enemy_selection(false)
		action.call(char)

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
	battle_log.append_text("[color=gold]%s[/color]\n" % text)

func _on_ally_sprite_clicked(ch: BattleCharacter) -> void:
	if battle_manager.state != BattleManager.BattleState.PLAYER_TURN: return
	# 复活模式：忽略存活队友的点击
	if not _dead_ally_pick_btns.is_empty(): return
	_enable_ally_selection(false)
	if _pending_action.is_valid():
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
var _ally_select_idx: int = 0
var _enemy_select_idx: int = 0
var _ally_select_include_self: bool = true

func _unhandled_input(event: InputEvent) -> void:
	# Alt+Q 快速施法
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var k: InputEventKey = event
		if k.keycode == KEY_Q and k.alt_pressed:
			var act = battle_manager.current_actor()
			if act == null or act.is_weakened or act.is_frozen or act.is_dead:
				_show_floating_text("当前角色无法行动", Color(0.8, 0.8, 0.8))
				get_viewport().set_input_as_handled()
				return
			_try_quick_cast()
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
		elif event.is_action_pressed("ui_accept"):
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
		elif event.is_action_pressed("ui_accept"):
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
		elif event.is_action_pressed("ui_accept"):
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
		elif event.is_action_pressed("ui_accept"):
			_enable_dead_ally_selection(false)
			action_panel.set_enabled(true)
			var action = _pending_action
			_pending_action = Callable()
			actor_indicator.text = ""
			action.call(dead_allies[_dead_ally_select_idx])
			get_viewport().set_input_as_handled()
		return

	# 攻击/捕捉模式：选敌人	
	if actor_indicator.text.contains("点击") or actor_indicator.text.contains("敌人") or actor_indicator.text.contains("捕捉"):
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
		elif event.is_action_pressed("ui_accept"):
			_clear_enemy_selection()
			_enable_enemy_selection(false)
			var target = enemies[_enemy_select_idx]
			var action = _pending_action
			_pending_action = Callable()
			actor_indicator.text = ""
			action.call(target)
			get_viewport().set_input_as_handled()
		return

func _cancel_pending() -> void:
	_pending_action = Callable()
	actor_indicator.text = ""
	_enable_enemy_selection(false)
	_enable_ally_selection(false)
	_enable_dead_ally_selection(false)
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
	# 只在选敌人的模式下响应	
	if not (actor_indicator.text.contains("点击") or actor_indicator.text.contains("敌人") or actor_indicator.text.contains("捕捉")):
		return
	var enemies := battle_manager.alive_enemies()
	var idx := enemies.find(ch)
	if idx >= 0:
		_enemy_select_idx = idx
		_highlight_enemy(ch)

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
				# 远程攻击：原地播放攻击动画 → 发射投射物 → 命中结算
				var target_pos = target.get_parent().global_position
				var caster_pos = actor.get_parent().global_position if actor.get_parent() else Vector2.ZERO
				var from_pos = caster_pos
			
				var ee = _turn_entries.get(target)
				if ee != null:
					var tex := _portrait_texture(target.stats.was_base_path, "x44")
					if tex: ee["avatar"].texture = tex
				nd.play_ranged_attack()
				var on_hit := func():
					battle_manager.flush_pending_damage()
				await get_tree().create_timer(0.5).timeout
				await SpellProjectile.shoot(from_pos, target_pos, target.get_parent(), on_hit, self, actor, actor.stats.talisman_type, _get_talisman_texture(actor))
				battle_manager.flush_pending_damage()
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
				var from_pos = caster_pos
				var ee = _turn_entries.get(target)
				if ee != null:
					var tex := _portrait_texture(target.stats.was_base_path, "x44")
					if tex: ee["avatar"].texture = tex
				nd.play_ranged_attack()
				var on_hit := func():
					battle_manager.flush_pending_damage()
					battle_manager.flush_guard_return()
				await get_tree().create_timer(0.5).timeout
				await SpellProjectile.shoot(from_pos, target_pos, hit_target, on_hit, self)
				battle_manager.flush_pending_damage()
				battle_manager.flush_guard_return()
				if ee != null:
					_update_avatar_for(target)
			else:
				nd.play_animation(anim_name)

# ══════════════════════════════════════════════
# BattleManager 信号回调
# ══════════════════════════════════════════════

func _on_log_pushed(text: String, log_type: String) -> void:
	battle_log.append_text("[color=%s]%s[/color]\n" % [LOG_COLORS.get(log_type, "white"), text])
	await get_tree().process_frame
	battle_log.scroll_to_line(battle_log.get_line_count())

func _on_state_changed(new_state: BattleManager.BattleState) -> void:
	if new_state != BattleManager.BattleState.PLAYER_TURN:
		action_panel.set_enabled(false)
		_pending_action = Callable()
		_enable_enemy_selection(false)
		_enable_ally_selection(false)
		_enable_dead_ally_selection(false)
		_clear_enemy_selection()
		# 非玩家回合隐藏操作面板		
		action_panel.visible = false
	else:
		# 恢复操作面板
		action_panel.visible = true

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
		actor_indicator.text = "—— %s 的回合 %s" % [actor.stats.character_name, talisman_info]
		action_panel.refresh(actor, true)
		_enable_enemy_selection(false)
		# 自动聚焦攻击按钮
		action_panel.btn_attack.grab_focus()
	else:
		return
	#	actor_indicator.text = "—— %s 行动中..." % actor.stats.character_name

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
		battle_log.append_text("[color=gold]🎉 战斗胜利！[/color]\n")
		await _show_reward_popup(exp_gained, gold_gained)
		for lu in level_ups:
			await _show_level_up_popup(lu)
	else:
		battle_log.append_text("[color=red]💀 全员阵亡，战斗失败...[/color]\n")
		await get_tree().create_timer(1.0).timeout
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
	title.text = "战斗胜利"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title)

	var exp_label := Label.new()
	exp_label.text = "经验  +%d" % exp_gained
	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_label.add_theme_font_size_override("font_size", 24)
	exp_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	vbox.add_child(exp_label)

	var gold_label := Label.new()
	gold_label.text = "金币  +%d" % gold_gained
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 24)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(gold_label)

	var ok := Button.new()
	ok.text = "确认"
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
	title.text = "🌟 境界提升 🌟"
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
	lv_label.text = "升至 %d 重天" % new_level
	lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_label.add_theme_font_size_override("font_size", 22)
	lv_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	vbox.add_child(lv_label)

	if not new_skills.is_empty():
		var skill_text := "新技能："
		for sk in new_skills:
			skill_text += "【%s】" % sk
		var skill_label := Label.new()
		skill_label.text = skill_text
		skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_label.add_theme_font_size_override("font_size", 18)
		skill_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2))
		vbox.add_child(skill_label)

	var ok := Button.new()
	ok.text = "确认"
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
		actor_indicator.text = "👆 点击要替换的宠物（← → 选择，回车确认）"
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
# 铁甲兽召唤# ══════════════════════════════════════════════

func _show_mech_summon_popup() -> void:
	if battle_manager.state != BattleManager.BattleState.PLAYER_TURN:
		return
	if GameData.mech_team.is_empty():
		battle_manager._push_log("没有可以召唤的铁甲兽！", "system")
		return
	var scene = get_parent()
	var has_slot = true
	if scene and scene.has_method("has_free_pet_slot"):
		has_slot = scene.has_free_pet_slot()
	if not has_slot:
		_mech_summon_popup.open()
		return
	_mech_summon_popup.open()


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
		actor_indicator.text = "👆 点击要替换的宠物（← → 选择，回车确认）"
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


# ══ 符咒系统 ══
## 获取当前符咒的贴图
func _get_talisman_texture(actor: BattleCharacter) -> Texture2D:
	var tex_path = "res://Graphic/BattleAnimation/失魂.png"

	if !ResourceLoader.exists(tex_path):
		return null

	var sheet := load(tex_path)

	var atlas := AtlasTexture.new()
	atlas.atlas = sheet

	var columns := 5
	var rows := 4

	var frame_width = sheet.get_width() / columns
	var frame_height = sheet.get_height() / rows

	var frame := 2  # 想显示哪一帧
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
