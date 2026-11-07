extends Control
var _values: Dictionary = {}

func _ready() -> void:
	var bar: VScrollBar = $Scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 8
	for state in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
		var skin := StyleBoxFlat.new()
		skin.bg_color = Color(0.28, 0.4, 0.61, 0.13) if state == "scroll" else Color(0.35, 0.5, 0.72, 0.72)
		skin.content_margin_left = 4
		skin.content_margin_right = 4
		skin.set_corner_radius_all(4)
		bar.add_theme_stylebox_override(state, skin)


func refresh(stats: CharacterStats, equipment: Dictionary, preview: Dictionary, potential: int) -> void:
	for child in $Scroll/Content/Rows.get_children():
		$Scroll/Content/Rows.remove_child(child)
		child.queue_free()
	_values.clear()
	$Character.text = "%s · Lv.%d · %s" % [stats.get_display_name(), stats.level, CharacterStats.element_name(stats.element)]
	var base: Dictionary = {}
	var special: Dictionary = {}
	for item in equipment.values():
		if not item is Dictionary: continue
		var additions: Dictionary = item.get("base", {})
		for key in additions: base[key] = int(base.get(key, 0)) + int(additions[key])
		for key in ["luck", "dodge", "lifesteal", "reflect", "true_dmg", "heal_up", "heal_targets", "night_dmg", "threat_reduce", "gold_boost"]:
			special[key] = int(special.get(key, 0)) + int(item.get(key, 0))
	var talent_bonuses := BattleCharacter.get_talent_stat_bonuses(stats)
	_section("气运与暴击")
	# 与进场装备合并一致：base.luck 加入基础属性，顶层 luck 作为额外运气。
	var equip_luck := int(base.get("luck", 0)) + int(special.get("luck", 0))
	var talent_luck := int((1.0 + float(talent_bonuses.get("crit_up", 0.0)) - 1.0) * 100.0)
	var luck := stats.luck + equip_luck + talent_luck
	_row("气运", str(luck), "角色自身 %d + 装备 %d + 天赋折算 %d；每点气运提供1%%基础暴击率。" % [stats.luck, equip_luck, talent_luck])
	_row("基础暴击率", "%.1f%%" % clampf(float(luck), 0.0, 100.0), "含装备与天赋，由气运计算，上限100%；未计技能书。")
	_row("暴击伤害", "%.0f%%" % (stats.crit_mult * 100.0), "角色基础暴击伤害倍率。法术暴击需相应技能书解锁。")
	_section("基础面板 · 含装备与天赋")
	var fields := [
		["气血上限", "max_hp", "hp"], ["灵力上限", "max_mp", "mp"],
		["物理攻击", "attack", "atk"], ["法术攻击", "magic_attack", "matk"],
		["物理防御", "defense", "def"], ["法术防御", "magic_defense", "mdef"],
		["速度", "speed", "spd"],
	]
	var talent_keys := {"hp": "hp_up", "mp": "mp_up", "atk": "atk_up", "matk": "matk_up", "def": "def_up", "mdef": "mdef_up", "spd": "haste"}
	for field in fields:
		var original: int = stats.get(field[1])
		var gear := int(base.get(field[2], 0))
		var pending := int(preview.get(field[2], 0))
		var before_talent := original + gear + pending
		var multiplier := 1.0 + float(talent_bonuses.get(talent_keys[field[2]], 0.0))
		var total := int(before_talent * multiplier)
		_row(field[0], str(total), "（角色 %d + 装备 %d + 本次预览 %d）× 天赋 %.0f%% = %d；天赋增加 %d" % [original, gear, pending, multiplier * 100.0, total, total - before_talent], pending > 0)
	_show_special_attributes(stats, special, base)
	_section("已分配属性点")
	for field in [["体质", "alloc_hp", "hp"], ["力量", "alloc_atk", "atk"], ["魔力", "alloc_magic", "magic"], ["耐力", "alloc_def", "def"], ["敏捷", "alloc_spd", "spd"]]:
		var pending := int(preview.get(field[2], 0))
		_row(field[0], str(int(stats.get(field[1])) + pending), "包含已确认分配与本次加点预览。", pending > 0)
	_row("剩余可分配点", str(potential))
	_section("每级成长")
	for field in [["气血", "hp_growth"], ["灵力", "mp_growth"], ["物攻", "atk_growth"], ["法攻", "matk_growth"], ["物防", "def_growth"], ["法防", "mdef_growth"], ["速度", "speed_growth"]]:
		_row(field[0], "+%d /级" % int(stats.get(field[1])))


func _show_special_attributes(stats: CharacterStats, special: Dictionary, base: Dictionary) -> void:
	_section("特殊属性")
	for field in [["闪避", "dodge"], ["吸血", "lifesteal"], ["治疗加成", "heal_up"], ["夜间伤害加成", "night_dmg"]]:
		_row(field[0], "%d%%" % int(special.get(field[1], 0)), "装备提供 %d%%；当前天赋未直接增加该属性。" % int(special.get(field[1], 0)))
	var reflect_gear := int(special.get("reflect", 0))
	var reflect_talent := int(minf(0.1 * preload("res://Script/Battle/TalentRules.gd").rank_for(stats, "guard_counter"), 0.6) * 100.0)
	_row("反震", "%d%%" % (reflect_gear + reflect_talent), "装备 %d%% + 天赋 %d%%；天赋部分上限60%%，按战斗规则合并。" % [reflect_gear, reflect_talent])
	var threat_gear := int(special.get("threat_reduce", 0))
	var threat_talent := 0
	if CharacterStats.has_role(stats.role, CharacterStats.Role.SUPPORT):
		threat_talent = int(minf(0.1 * preload("res://Script/Battle/TalentRules.gd").rank_for(stats, "support_threat_down"), 1.0) * 100.0)
	_row("仇恨降低", "%d%%" % mini(100, threat_gear + threat_talent), "装备 %d%% + 适用角色天赋 %d%%，展示上限100%%。" % [threat_gear, threat_talent])
	_row("额外真实伤害", str(int(special.get("true_dmg", 0)) + int(base.get("dmg", 0))), "装备真实伤害与基础伤害附加值合计。")
	var targets_gear := int(special.get("heal_targets", 0))
	var targets_talent := preload("res://Script/Battle/TalentRules.gd").rank_for(stats, "support_wider_heal")
	_row("额外治疗目标", str(maxi(0, targets_gear + targets_talent)), "装备 %d + 天赋 %d；按战斗治疗目标规则合并。" % [targets_gear, targets_talent])
	var gold_talent := 0.15 * GameData.get_talent_rank("main_gold_boost")
	_row("金币收入加成", "+%.0f%%" % ((GameData.get_gold_multiplier() * (1.0 + gold_talent) - 1.0) * 100.0), "全队装备与背包被动倍率 %.2f × 战斗金币天赋倍率 %.2f；不含夜间奖励。" % [GameData.get_gold_multiplier(), 1.0 + gold_talent])

	_row("无视防御", "%.0f%%" % (2.0 * preload("res://Script/Battle/TalentRules.gd").rank_for(stats, "attack_slay")), "一剑破万法：技能伤害计算时额外无视防御。")
	_row("连击触发率", "%.0f%%" % (5.0 * preload("res://Script/Battle/TalentRules.gd").rank_for(stats, "attack_combo")), "连斩：满足攻击条件时概率再次攻击。")
	_row("封印概率加成", "+%.0f%%" % (3.0 * preload("res://Script/Battle/TalentRules.gd").rank_for(stats, "support_seal_chance")), "封印精通：使用封印技能时生效。")
	if CharacterStats.has_role(stats.role, CharacterStats.Role.SUPPORT) or float(special.get("mp_cost_reduction", 0.0)) > 0.0:
		_row("耗蓝减免", "%.0f%%" % (minf(float(special.get("mp_cost_reduction", 0.0)) + 0.1 * preload("res://Script/Battle/TalentRules.gd").rank_for(stats, "support_mp_save"), 0.8) * 100.0), "装备与灵力节约天赋相加；总耗蓝减免上限80%。")
	if CharacterStats.has_role(stats.role, CharacterStats.Role.GUARD):
		_row("开局气血恢复", "%.0f%%" % (5.0 * preload("res://Script/Battle/TalentRules.gd").rank_for(stats, "guard_hp_up")), "铁壁当前实战效果为开局恢复气血，不增加气血上限。")
	_row("开局额外灵力", "+%d" % (10 * preload("res://Script/Battle/TalentRules.gd").rank_for(stats, "main_spirit")), "灵台清明：开局恢复灵力，不超过灵力上限。")
	_row("开局行动条", "+%d" % (10 * preload("res://Script/Battle/TalentRules.gd").rank_for(stats, "baochong")), "爆冲：行动条增加，不超过100。")
	_row("战斗经验加成", "+%.0f%%" % (15.0 * GameData.get_talent_rank("main_exp_boost")), "天赋异禀：战斗胜利结算时生效。")

func _section(title: String) -> void:
	var rows := $Scroll/Content/Rows
	if rows.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size.y = 10
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows.add_child(gap)
	var header := PanelContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.custom_minimum_size.y = 38
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.27, 0.40, 0.64, 0.94)
	skin.border_color = Color(0.65, 0.78, 0.97)
	skin.border_width_bottom = 1
	skin.set_corner_radius_all(4)
	skin.content_margin_left = 12
	skin.content_margin_right = 10
	skin.content_margin_top = 6
	skin.content_margin_bottom = 6
	header.add_theme_stylebox_override("panel", skin)
	var label := Label.new()
	label.text = title
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", preload("res://Graphic/UI/Font/尔雅趣宋体.ttf"))
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.87))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(label)
	rows.add_child(header)

func _row(title: String, value: String, hint: String = "", changed: bool = false) -> void:
	_values[title] = value
	var row := HBoxContainer.new()
	row.tooltip_text = hint
	row.custom_minimum_size.y = 28
	row.add_theme_constant_override("separation", 16)
	var key := Label.new()
	key.text = title
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key.add_theme_font_size_override("font_size", 15)
	key.add_theme_color_override("font_color", Color(0.18, 0.27, 0.44))
	row.add_child(key)
	var number := Label.new()
	number.text = value
	number.custom_minimum_size.x = 88
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.add_theme_font_size_override("font_size", 15)
	number.add_theme_color_override("font_color", Color(0.06, 0.43, 0.27) if changed else Color(0.12, 0.22, 0.40))
	row.add_child(number)
	$Scroll/Content/Rows.add_child(row)
