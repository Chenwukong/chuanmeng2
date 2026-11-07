extends RefCounted
## GameData 统一入口委托的独立业务模块；运行状态由 facade 显式传入。

static func _register_skills(game_state) -> void:
	for sid in SkillDB.SKILL_DB:
		var row = SkillDB.SKILL_DB[sid]
		var sk = SkillData.new()
		sk.skill_id          = sid
		sk.skill_name        = sid
		sk.description       = row.get("desc", "")
		sk.icon_emoji        = row.get("icon", "✨")
		sk.skill_type        = row.type
		sk.target_type       = row.target
		sk.mp_cost           = row.get("mp", 0)
		sk.damage_multiplier = row.get("dmg", 0.0)
		sk.is_magic_damage   = row.get("magic", false)
		sk.hit_count         = row.get("hits", 1)
		sk.heal_multiplier   = row.get("heal", 0.0)
		sk.flat_heal         = row.get("flat", 0)
		sk.shield_pct        = row.get("shield", 0.0)
		sk.heal_size         = row.get("hsize", "medium")
		sk.flat_damage       = row.get("flat_dmg", 0)
		sk.ignore_defense_ratio = row.get("ignore_def", 0.0)
		sk.miss_chance = row.get("miss_chance", 0.0)
		sk.target_atk_dmg_mult = row.get("tatk_dmg", 0.0)
		sk.cooldown_turns    = row.get("cd", 0)
		sk.initial_wait_actions = row.get("initial_wait_actions", 0)
		sk.contact_radius = row.get("contact_radius", 90.0)
		sk.mana_regen_pct = row.get("mana_regen_pct", 0.0)
		sk.apply_buff_id     = row.get("buff", "")
		sk.apply_buff2_id    = row.get("buff2", "")
		sk.apply_buff_turns  = row.get("bturn", 0)
		sk.apply_buff_chance = row.get("bchance", 0.0)
		sk.apply_buff_value  = row.get("bvalue", 0.0)
		sk.self_buff_id      = row.get("self_buff", "")
		sk.self_buff_turns   = row.get("self_bturn", 0)
		sk.extra_targets    = row.get("extra", 0)
		sk.fullscreen_anim  = row.get("fullscreen", "")
		sk.sacrifice_hp_pct = row.get("sac_hp", 0.5)
		sk.sacrifice_def_pct = row.get("sac_def", 0.5)
		sk.ghost_cost = row.get("ghost_cost", 0)
		sk.ghosts_per_charge = row.get("ghosts_per_charge", 2)
		sk.boost_pct = row.get("boost_pct", 0.0)
		sk.sound_path        = row.get("sound", "")
		SkillManager.register_skill(sk)

# ══════════════════════════════════════════════
# 道具注册


static func _register_items(game_state) -> void:
	var basin = ItemData.new()
	basin.item_id = "treasure_basin"
	basin.item_name = "聚宝盆"
	basin.description = "聚四海之财，纳八方之宝。被动效果：放在背包即可生效，全部金币收入+30%，无需装备或使用。同种道具不叠加。"
	basin.icon_emoji = "💰"
	basin.item_type = ItemData.ItemType.SPECIAL
	basin.item_category = ItemData.ItemCategory.MISC
	basin.max_stack = 1
	basin.passive_gold_bonus = 30
	game_state.item_db[basin.item_id] = basin
	const HP = ItemData.ItemType.HP_POTION
	const MP = ItemData.ItemType.MP_POTION
	const BF = ItemData.ItemType.BUFF_ITEM
	const RV = ItemData.ItemType.REVIVE
	const BOOK = ItemData.ItemType.SKILL_BOOK
	const SP = ItemData.ItemType.SPECIAL

	var rows = [
		# ── 增益类 ──
		{ id = "atk_pill",    name = "大力仙丹", icon = "🟡", type = BF, buff_id = "atk_up", buff_turns = 3, desc = "攻击力提升3回合" },
		{ id = "shield_pill", name = "铁甲仙丹", icon = "🟤", type = BF, buff_id = "shield", buff_turns = 3, desc = "防御力提升3回合" },
		{ id = "haste_pill",  name = "追风仙丹", icon = "🟢", type = BF, buff_id = "haste",  buff_turns = 3, desc = "速度提升3回合" },
		# ── 复活类 ──
		{ id = "revive_pill", name = "九转金丹", icon = "⭕", type = RV, revive_pct = 0.5, desc = "复活并恢复50%气血" },
		# ── 宠物技能书 ──
		{ id = "book_haste_high",  name = "高级敏捷", icon = "⚡", type = BOOK, book_id = "高级敏捷", desc = "速度+30%" },
		{ id = "book_haste",       name = "敏捷",     icon = "⚡", type = BOOK, book_id = "敏捷",     desc = "速度+15%" },
		{ id = "book_hp_high",     name = "高级血量", icon = "❤️", type = BOOK, book_id = "高级血量", desc = "气血+25%" },
		{ id = "book_hp",          name = "血量",     icon = "❤️", type = BOOK, book_id = "血量",     desc = "气血+12%" },
		{ id = "book_def_high",    name = "高级物防", icon = "🛡️", type = BOOK, book_id = "高级物防", desc = "物防+25%" },
		{ id = "book_def",         name = "物防",     icon = "🛡️", type = BOOK, book_id = "物防",     desc = "物防+12%" },
		{ id = "book_mdef_high",   name = "高级魔防", icon = "🔮", type = BOOK, book_id = "高级魔防", desc = "魔防+25%" },
		{ id = "book_mdef",        name = "魔防",     icon = "🔮", type = BOOK, book_id = "魔防",     desc = "魔防+12%" },
		{ id = "book_atk_high",    name = "高级强力", icon = "💪", type = BOOK, book_id = "高级强力", desc = "攻击+25%" },
		{ id = "book_atk",         name = "强力",     icon = "💪", type = BOOK, book_id = "强力",     desc = "攻击+12%" },
		{ id = "book_matk_high",   name = "高级魔之心", icon = "💜", type = BOOK, book_id = "高级魔之心", desc = "法伤+25%" },
		{ id = "book_matk",        name = "魔之心",   icon = "💜", type = BOOK, book_id = "魔之心",   desc = "法伤+12%" },
		{ id = "book_crit_high",   name = "高级必杀", icon = "💥", type = BOOK, book_id = "高级必杀", desc = "运气+20" },
		{ id = "book_crit",        name = "必杀",     icon = "💥", type = BOOK, book_id = "必杀",     desc = "运气+10" },
		{ id = "book_mcrit_high",  name = "高级法术暴击", icon = "🌟", type = BOOK, book_id = "高级法术暴击", desc = "运气+20，法术可暴击" },
		{ id = "book_mcrit",       name = "法术暴击", icon = "🌟", type = BOOK, book_id = "法术暴击", desc = "运气+10，法术可暴击" },
		{ id = "book_regen_high",  name = "高级生命恢复", icon = "💚", type = BOOK, book_id = "高级生命恢复", desc = "每回合回血10%" },
		{ id = "book_regen",       name = "生命恢复", icon = "💚", type = BOOK, book_id = "生命恢复", desc = "每回合回血5%" },
		{ id = "book_double_atk",  name = "高级连击", icon = "👊", type = BOOK, book_id = "高级连击", desc = "普攻45%二连" },
		{ id = "book_double_mag",  name = "高级魔法连击", icon = "✨", type = BOOK, book_id = "高级魔法连击", desc = "法术35%二连" },
		{ id = "book_lifesteal_h", name = "高级吸血", icon = "🩸", type = BOOK, book_id = "高级吸血", desc = "吸收25%伤害" },
		{ id = "book_lifesteal",   name = "吸血",     icon = "🩸", type = BOOK, book_id = "吸血",     desc = "吸收15%伤害" },
		{ id = "book_reflect_h",   name = "高级反震", icon = "↩️", type = BOOK, book_id = "高级反震", desc = "反弹40%伤害" },
		{ id = "book_reflect",     name = "反震",     icon = "↩️", type = BOOK, book_id = "反震",     desc = "反弹25%伤害" },
		{ id = "book_revive_h",    name = "高级神佑复生", icon = "🕊️", type = BOOK, book_id = "高级神佑复生", desc = "30%满血复活" },
		{ id = "book_revive",      name = "神佑复生", icon = "🕊️", type = BOOK, book_id = "神佑复生", desc = "15%半血复活" },
		{ id = "book_venom_h",     name = "高级毒",   icon = "☠️", type = BOOK, book_id = "高级毒",   desc = "25%使目标中毒" },
		{ id = "book_venom",       name = "毒",       icon = "☠️", type = BOOK, book_id = "毒",       desc = "15%使目标中毒" },
		{ id = "book_mp_save_h",   name = "高级慧根", icon = "🧠", type = BOOK, book_id = "高级慧根", desc = "灵力消耗-40%" },
		{ id = "book_mp_save",     name = "慧根",     icon = "🧠", type = BOOK, book_id = "慧根",     desc = "灵力消耗-20%" },
		{ id = "book_immune_h",    name = "高级神迹", icon = "✨", type = BOOK, book_id = "高级神迹", desc = "免疫所有异常" },
		{ id = "book_immune",      name = "神迹",     icon = "✨", type = BOOK, book_id = "神迹",     desc = "50%抵抗异常" },
		{ id = "book_slow_h",      name = "高级迟钝", icon = "🐢", type = BOOK, book_id = "高级迟钝", desc = "速度-30% 气血+30%" },
		{ id = "book_slow",        name = "迟钝",     icon = "🐢", type = BOOK, book_id = "迟钝",     desc = "速度-20% 气血+15%" },
		{ id = "book_fluct_h",     name = "高级法波动", icon = "🌊", type = BOOK, book_id = "高级法波动", desc = "法伤70%~130%" },
		{ id = "book_fluct",       name = "法波动",   icon = "🌊", type = BOOK, book_id = "法波动",   desc = "法伤85%~115%" },
		{ id = "book_night_h",     name = "高级夜战", icon = "🌙", type = BOOK, book_id = "高级夜战", desc = "夜间伤害+20%速度+15%" },
		{ id = "book_night",       name = "夜战",     icon = "🌙", type = BOOK, book_id = "夜战",     desc = "夜间伤害+10%速度+8%" },
		{ id = "book_gold_h",      name = "高级来财", icon = "💰", type = BOOK, book_id = "高级来财", desc = "金币收益+100%" },
		{ id = "book_gold",        name = "来财",     icon = "💰", type = BOOK, book_id = "来财",     desc = "金币收益+50%" },
		# ── 符咒（消耗品）──
		{ id = "talisman_fire",      name = "星火篆", icon = "🔥", tcp = "res://TCP/符咒/3290.tcp", type = SP, dmg = 1.5, hit_sound = "res://Audio/SE/火1.ogg", desc = "造成火焰伤害并灼烧" },
		{ id = "talisman_thunder",   name = "五雷咒", icon = "⚡", tcp = "res://TCP/符咒/0865.tcp", type = SP, dmg = 1.8, hit_sound = "res://Audio/SE/124-Thunder02.ogg", desc = "造成雷电伤害并概率麻痹" },
		{ id = "talisman_ice",       name = "冰冻符咒", icon = "❄️", tcp = "res://TCP/符咒/3290.tcp", type = SP, dmg = 2.0, hit_sound = "res://Audio/SE/法术5.ogg", desc = "造成冰冻伤害并封印" },
		{ id = "talisman_haste",     name = "加速符咒", icon = "💨", tcp = "res://TCP/符咒/3290.tcp", type = SP, hit_sound = "res://Audio/SE/法术5.ogg", desc = "为队友施加加速效果" },
		{ id = "talisman_ceasefire", name = "止战符咒", icon = "🕊️", tcp = "res://TCP/符咒/3290.tcp", type = SP, hit_sound = "res://Audio/SE/法术5.ogg", desc = "削减敌人灵力" },
		{ id = "talisman_revive",    name = "借尸符",   icon = "💀", tcp = "res://TCP/符咒/3290.tcp", type = SP, hit_sound = "res://Audio/SE/heal 1.ogg", desc = "复活一名阵亡队友，恢复30%气血" },
		{ id = "talisman_basic",     name = "无字符", icon = "📜", tcp = "res://TCP/符咒/3290.tcp", type = SP, dmg = 0.6, hit_sound = "res://Audio/SE/法术5.ogg", desc = "主角保底符咒，无限使用（不消耗）" },
		# ── 洗髓丹（场外道具：返还能力点）──
		{ id = "item_xisuidan", name = "洗髓丹", tcp = "res://TCP/丹药/0677.tcp", cat = ItemData.ItemCategory.MISC, type = SP, desc = "使用后返还该角色全部已分配的能力点（在属性加点面板使用）" },
		# ── 恢复丹药（TCP/丹药，数值待定）──
		# ==================== HP ====================
		{ id = "0041", name = "金创药", tcp = "res://TCP/丹药/0041.tcp", type = HP, hp = 120, desc = "用云南白药制成的疗伤药，可以止血、消毒，是常见的药品，具有补充气血的作用。【功效】恢复气血400点" },
		{ id = "0042", name = "小还丹", tcp = "res://TCP/丹药/0042.tcp", type = HP, hp = 350, desc = "载于中国古老药书《千金方》，散发着香气的紫色药丸，具有疗伤的功效。【功效】治疗伤势=品质*18+200" },
		{ id = "0049", name = "金香玉", tcp = "res://TCP/丹药/0049.tcp", type = HP, hp = 550, desc = "仙子仙女常用的药物，除了可以养颜之外，服用后具有恢复气血的作用。【功效】恢复气血=品质*12+150" },
		{ id = "0051", name = "红雪散", tcp = "res://TCP/丹药/0051.tcp", type = HP, hp = 800, desc = "仙家灵药，用仙家红血制成，具有补充气血、解除毒类异常状态以及恢复战斗中某些情况下损失的防御的功效。【功效】解除毒类异常状态 恢复气血=品质*4 恢复防御=品质*0.4" },
		{ id = "0052", name = "五龙丹", tcp = "res://TCP/丹药/0052.tcp", type = HP, hp = 1200, cleanse_seal = true, desc = "来自东海龙宫的珍贵药品，是用五颗龙珠凝炼的，能解除任何封类异常状态，并补充气血。【功效】解除任何封类异常状态 恢复气血1200点" },
		{ id = "0029", name = "龙之心屑", tcp = "res://TCP/丹药/0029.tcp", type = HP, hp = 300, hp_pct = 0.20, desc = "用龙心提炼出的灵药，只在魔界存在，可以补充极大量的气血。【功效】恢复气血300点，并额外恢复最大气血20%" },
		{ id = "0043", name = "千年保心丹", tcp = "res://TCP/丹药/0043.tcp", type = HP, desc = "用大量名贵药品，经过名师的精心加工制成的药丹，具有补充气血和疗伤的功效。【功效】恢复气血=品质*8+100 治疗伤势=品质*8+100" },
	
		# ==================== MP ====================
		{ id = "0045", name = "定神香", tcp = "res://TCP/丹药/0045.tcp", type = MP, mp = 100, desc = "有定神凝气的功效，名贵药物，精心炼成的丹药，具有补充法力的功效。【功效】恢复魔法=品质*5+50" },
		{ id = "0032", name = "仙狐涎", tcp = "res://TCP/丹药/0032.tcp", type = MP, mp = 200, desc = "东方青丘国九尾仙狐的涎水制成的药草，可以补充些许法力。【功效】恢复魔法300点" },

		{ id = "0031", name = "天龙水", tcp = "res://TCP/丹药/0031.tcp", type = MP, mp = 400, desc = "九天真龙的血液炼成的药物，可以补充些许法力。【功效】恢复魔法150点" },
		{ id = "0046", name = "十香返生丸", tcp = "res://TCP/丹药/0046.tcp", type = MP, mp = 300, mp_pct = 0.1, desc = "用十种仙山上奇香的药草制成，奇异的药丸，具有补充法力和解除酒类异常状态的作用。【功效】解除酒类异常状态 恢复魔法=品质*3+50" },
	
		{ id = "0044", name = "风水混元丹", tcp = "res://TCP/丹药/0044.tcp", type = MP, mp= 400, mp_pct = 0.2, desc = "有混元之神效，用各类名贵药品精练的丹药，具有补充法力和恢复战斗中某些情况下损失的灵力的功效。【功效】恢复魔法=品质*3+50 恢复灵力=品质*0.3" },
		{ id = "0048", name = "蛇蝎美人", tcp = "res://TCP/丹药/0048.tcp", type = MP, mp = 800, desc = "魔王妖王常用的药物，具有补充法力的作用。【功效】恢复魔法=品质*5+100" },
	
		{ id = "0074", name = "黑玉云苓膏", tcp = "res://TCP/丹药/0074.tcp", type = MP, mp = 1200, desc = "用名贵药材熬制的奇妙药膏，温润如黑玉，具有补充魔法功效。【功效】从当前回合开始,持续三回合恢复目标魔法值与流失的速度。每回合恢复魔法=品质*1.5+50 每回合恢复速度=品质*0.1" },
		{ id = "0030", name = "火凤之睛", tcp = "res://TCP/丹药/0030.tcp", type = MP, mp = 600, mp_pct = 0.4, desc = "无色界天的火凤凰的眼睛，可以补充极大量的灵力。【功效】恢复灵力400点，并额外恢复最大灵力40%" },
		# ==================== RV ====================
		{ id = "0078", name = "生骨续命膏", tcp = "res://TCP/丹药/0078.tcp", type = RV, hp = 100, desc = "用名贵中药熬制七七四十九日而成的药膏，具有补充气血、疗伤和起死回生的功效。【功效】复活、恢复目标当前气血=品质*3+50，气血上限变为品质*3+50（不超过上限）。" },
		{ id = "0047", name = "佛光舍利子", tcp = "res://TCP/丹药/0047.tcp", type = RV, hp = 500, desc = "佛的舍利子具有补充气血、疗伤和起死回生的功效。【功效】复活、恢复气血=品质*3 临时气血上限变为品质*7+100" },
		{ id = "0077", name = "金石返魂丹", tcp = "res://TCP/丹药/0077.tcp", type = RV, hp = 400, revive_pct = 0.3, desc = "传说是根据华佗遗留的药方炼制而成的丹药，具有补充气血、疗伤和起死回生的功效。【功效】复活、恢复目标当前气血=品质*2+50 气血上限变为品质*9+100（不超过上限）" },
		{ id = "0050", name = "九转回魂丹", tcp = "res://TCP/丹药/0050.tcp", type = RV, hp = 500,  revive_pct = 0.5, desc = "炼过九转的仙丹，用极为珍贵而特殊的药物制成，具有补充气血、疗伤和起死回生的功效。【功效】复活、恢复气血=品质*5+100 临时气血上限变为品质*5+100" },
	]

	for row in rows:
		var d = ItemData.new()
		d.item_id           = row.id
		d.item_name         = row.name
		d.icon_emoji        = row.get("icon", "")
		d.icon_path         = row.get("tcp", "")
		d.item_type         = row.type
		d.item_category     = row.get("cat", ItemData.ItemCategory.CONSUMABLE)
		d.hp_restore        = row.get("hp", 0)
		d.hp_restore_percent = row.get("hp_pct", 0.0)
		d.mp_restore        = row.get("mp", 0)
		d.mp_restore_percent = row.get("mp_pct", 0.0)
		d.cleanse_seal      = row.get("cleanse_seal", false)
		d.buff_id           = row.get("buff_id", "")
		d.buff_turns        = row.get("buff_turns", 0)
		d.revive_hp_percent = row.get("revive_pct", 0.0)
		d.damage_multiplier = row.get("dmg", 1.0)
		d.hit_sound         = row.get("hit_sound", "")
		d.book_skill_id     = row.get("book_id", "")
		d.description       = row.desc
		d.max_stack         = 10
		# 宠物技能书统一图标：高级书用 3514，其余（低级）用 5159
		if d.item_type == BOOK and d.icon_path.is_empty():
			d.icon_path = "res://TCP/UI/3514.tcp" if d.item_name.begins_with("高级") else "res://TCP/UI/5159.tcp"
		game_state.item_db[d.item_id]  = d

	# ── 任务道具（悬赏用）──
	const QT = ItemData.ItemType.SPECIAL
	const QC = ItemData.ItemCategory.QUEST
	var quest_rows = [
		{ id = "quest_fox_tail",    name = "妖狐之尾", icon = "🦊", cat = QC, type = QT, desc = "从妖狐身上斩下的尾巴，散发着妖气。" },
		{ id = "quest_mandrill_fang", name = "山魈之牙", icon = "🦷", cat = QC, type = QT, desc = "山魈的獠牙，尚有余温。" },
		{ id = "quest_ghost_core",  name = "幽魂之核", icon = "💠", cat = QC, type = QT, desc = "厉鬼死后凝结的魂核，灵力充沛。" },
		{ id = "quest_golem_stone", name = "石傀之心", icon = "🪨", cat = QC, type = QT, desc = "石傀的核心石，坚硬无比。" },
		{ id = "quest_fire_feather",name = "火鸦之羽", icon = "🔥", cat = QC, type = QT, desc = "火鸦身上最亮的赤羽，依旧灼热。" },
		{ id = "quest_spider_silk", name = "幽蛛之丝", icon = "🕸️", cat = QC, type = QT, desc = "幽蛛吐出的灵丝，坚韧而透明。" },
		{ id = "quest_wind_fang",   name = "风狼之牙", icon = "🌪️", cat = QC, type = QT, desc = "风狼的利齿，刻着古老的风痕。" },
		{ id = "quest_ice_crystal", name = "寒魄冰晶", icon = "❄️", cat = QC, type = QT, desc = "寒魄幽灵消散后留下的不化冰晶。" },
	]
	for row in quest_rows:
		var d = ItemData.new()
		d.item_id       = row.id
		d.item_name     = row.name
		d.icon_emoji    = row.icon
		d.item_type     = row.type
		d.item_category = row.cat
		d.description   = row.desc
		d.max_stack     = 99
		game_state.item_db[d.item_id] = d


# ══════════════════════════════════════════════
# 装备系统工具
# ══════════════════════════════════════════════


static func _init_inventory(game_state) -> void:
	game_state.player_inventory = Inventory.new()
	game_state.player_inventory.add_item(game_state.item_db["0041"], 3)  # 金创药
	game_state.player_inventory.add_item(game_state.item_db["0045"], 2)  # 定神香
	game_state.player_inventory.add_item(game_state.item_db["atk_pill"],    1)
	game_state.player_inventory.add_item(game_state.item_db["revive_pill"], 1)
	game_state.player_inventory.add_item(game_state.item_db["item_xisuidan"], 1)
	# 测试用宠物技能书（全部40本，每种2本）
	var all_book_ids = [
		"book_haste_high","book_haste","book_hp_high","book_hp",
		"book_def_high","book_def","book_mdef_high","book_mdef",
		"book_atk_high","book_atk","book_matk_high","book_matk",
		"book_crit_high","book_crit","book_mcrit_high","book_mcrit",
		"book_regen_high","book_regen","book_double_atk","book_double_mag",
		"book_lifesteal_h","book_lifesteal","book_reflect_h","book_reflect",
		"book_revive_h","book_revive","book_venom_h","book_venom",
		"book_mp_save_h","book_mp_save","book_immune_h","book_immune",
		"book_slow_h","book_slow","book_fluct_h","book_fluct",
		"book_night_h","book_night","book_gold_h","book_gold",
	]
	for bid in all_book_ids:
		if game_state.item_db.has(bid):
			game_state.player_inventory.add_item(game_state.item_db[bid], 2)
	# 测试用任务道具
	game_state.player_inventory.add_item(game_state.item_db["quest_fox_tail"],     3)
	game_state.player_inventory.add_item(game_state.item_db["quest_mandrill_fang"], 2)
	game_state.player_inventory.add_item(game_state.item_db["quest_ghost_core"],    1)
	game_state.player_inventory.add_item(game_state.item_db["quest_fire_feather"],  5)
	game_state.player_inventory.add_item(game_state.item_db["quest_spider_silk"],   2)
	# 测试用符咒
	game_state.player_inventory.add_item(game_state.item_db["talisman_fire"], 5)
	game_state.player_inventory.add_item(game_state.item_db["talisman_thunder"], 5)
	game_state.player_inventory.add_item(game_state.item_db["talisman_ice"], 5)
	game_state.player_inventory.add_item(game_state.item_db["talisman_haste"], 5)
	game_state.player_inventory.add_item(game_state.item_db["talisman_ceasefire"], 5)
	game_state.player_inventory.add_item(game_state.item_db["talisman_revive"], 5)
	# 测试用恢复丹药（全部，TCP/丹药；洗髓丹已在上面单独加入）
	var all_pill_ids = [
		"0029","0030","0031","0032","0034","0035",
		"0041","0042","0043","0044","0045","0046","0047","0048",
		"0049","0050","0051","0052","0074","0077","0078",
	]
	for pid in all_pill_ids:
		if game_state.item_db.has(pid):
			game_state.player_inventory.add_item(game_state.item_db[pid], 5)


# ══════════════════════════════════════════════
# 赏金任务接口
# ══════════════════════════════════════════════

## 接受一个悬赏任务


static func _build_enemy_db(game_state) -> void:
	for row in EnemyDB.ENEMY_DB:
		var key = row.get("id", row.name)
		game_state._enemy_db_cache[key] = row


## 进场随机资质


static func create_enemy(game_state, enemy_name: String) -> CharacterStats:
	var row = game_state._enemy_db_cache.get(enemy_name)
	if row == null:
		push_error("GameData: 未知怪物 '%s'，使用默认怪物" % enemy_name)
		row = game_state._enemy_db_cache.values()[0]
	var s = CharacterStats.new()
	s.character_name = row.name
	var lv = EnemyDB.roll_enemy_level(row)
	if row.get("scale_to_player", false):
		# 以主角为准，避免队伍顺序或高等级队友影响试炼等级。
		for member in game_state.party_db.values():
			if CharacterStats.has_role(member.role, CharacterStats.Role.MAIN):
				lv = maxi(1, member.level)
				break
	# 总倍率 = 夜晚加成(×1.3) × 等级档倍率（EnemyDB.LEVEL_STAT_MUL，档位取总倍率，不累乘）
	var nm = (1.3 if game_state.is_night_time() else 1.0) * EnemyDB.level_stat_mul(lv)
	# 属性来源：敌表里显式写了该属性 → 用它；没写 → 按分类模板（arch）× 等级推导（boss 额外加成）
	var arch = str(row.get("arch", EnemyDB.DEFAULT_ARCH))
	var d: Dictionary = EnemyDB.derive_arch_stats(arch, lv)
	var boss_mul: float = EnemyDB.BOSS_MUL if str(row.get("rank", "")) == "boss" else 1.0
	var v = func(key: String, fallback: int) -> int:
		if row.has(key):
			return int(row.get(key))
		return int(int(d.get(key, fallback)) * boss_mul)
	s.max_hp         = int(v.call("hp", 90) * nm);   s.max_mp = int(v.call("mp", 30) * nm)
	s.attack         = int(v.call("atk", 20) * nm)
	s.defense        = int(v.call("def", 8) * nm)
	s.speed          = int(v.call("spd", 10) * nm);  s.level = lv
	s.skill_ids      = row.get("skills", ["普通攻击"]).duplicate()
	s.ai_strategy    = row.get("ai_strategy", "balanced")
	s.luck           = row.get("luck", 0)
	# 法伤/法防：显式优先 → 否则沿用旧规则（参考攻击/物防）→ 否则模板
	var ma_fallback = int(row.get("atk", int(int(d.get("matk", 20)) * boss_mul)))
	var md_fallback = int(row.get("def", int(d.get("def", 8))) * 0.8) if row.has("def") else int(int(d.get("mdef", 12)) * boss_mul)
	s.magic_attack   = int(row.get("matk", ma_fallback) * nm)
	s.magic_defense  = int(row.get("mdef", md_fallback) * nm)
	s.was_base_path  = row.get("was_base_path", "")
	s.was_direction  = row.get("was_direction", 0)
	s.portrait_path  = row.get("portrait_path", "")
	s.portrait_offset = row.get("portrait_offset", Vector2.ZERO)
	s.team_offset     = row.get("team_offset", Vector2.ZERO)
	s.exp_reward     = int(row.get("exp", 0) * nm)
	s.attack_sound_path = row.get("attack_sound", "")
	s.cast_sound_path   = row.get("cast_sound", "")
	s.rank             = row.get("rank", "")
	s.element = game_state._parse_element(row.get("elem", "金"))
	s.role    = game_state._parse_role(row.get("role", "护"))
	s.traits  = row.get("traits", {}).duplicate()
	s.use_png = row.get("use_png", false)
	# 进场时随机资质（捕捉时保留）
	s.capture_aptitude = game_state._roll_aptitude(row.get("rank", ""), lv)
	# 难度只调整战斗属性；等级、经验奖励、资质和捕捉后的宠物成长不变。
	for property in ["max_hp", "max_mp", "attack", "magic_attack", "defense", "magic_defense", "speed"]:
		s.set(property, maxi(1 if property == "max_hp" else 0, int(s.get(property) * game_state.get_enemy_difficulty_multiplier(property))))
	return s


static func _roll_aptitude(game_state, rank: String, lv: int = 1) -> int:
	match rank:
		"boss":    return PetData.Aptitude.甲
		"special": return PetData.Aptitude.特
	var lv_mod = clampf(lv / 50.0, 0.0, 1.0)
	if game_state.is_night_time():
		lv_mod = minf(lv_mod * 1.3, 1.0)
	# 甲 = lv_mod × 15%，乙 = lv_mod × 25%，丙 = lv_mod × 30%，剩余丁
	var jia  = int(lv_mod * 15)
	var yi   = jia + int(lv_mod * 25)
	var bing = yi  + int(lv_mod * 30)
	var r = randi() % 100
	if r < jia:    return PetData.Aptitude.甲
	if r < yi:     return PetData.Aptitude.乙
	if r < bing:   return PetData.Aptitude.丙
	return PetData.Aptitude.丁

# ══════════════════════════════════════════════


static func get_random_enemy_id(game_state, min_lv: int = 1, max_lv: int = 99) -> String:
	var candidates = EnemyDB.ENEMY_DB.filter(func(row):
		var r: Vector2i = EnemyDB.enemy_lv_range(row)
		return r.y >= min_lv and r.x <= max_lv)
	if candidates.is_empty():
		return EnemyDB.ENEMY_DB[0].name
	return candidates[randi() % candidates.size()].name


static func highest_party_level(game_state) -> int:
	var ids: Array = []
	if game_state.has_meta("pending_party"):
		ids = game_state.get_meta("pending_party")
	if ids.is_empty():
		ids = game_state.party_order
	var top = 0
	for mid in ids:
		var s = game_state.party_db.get(mid)
		if s is CharacterStats:
			top = maxi(top, int((s as CharacterStats).level))
	return top


static func capture_pet(game_state, enemy_name: String, enemy_stats: CharacterStats) -> String:
	var row = game_state._enemy_db_cache.get(enemy_name)
	if row == null: return ""
	var apt = enemy_stats.capture_aptitude
	if apt < 0: apt = PetData.Aptitude.丁
	var pet = PetData.new()
	pet.from_enemy_with_apt(row, enemy_stats.level, apt as PetData.Aptitude)
	pet.pet_id = "pet_%d" % Time.get_unix_time_from_system()
	game_state.pet_db[pet.pet_id] = pet
	print("[宠物] 成功捕捉 %s，资质：%s" % [pet.character_name, PetData.apt_name(pet.aptitude)])
	return pet.pet_id

## 获取第一个宠物（召唤用）


static func get_first_pet(game_state) -> PetData:
	if game_state.pet_db.is_empty(): return null
	return game_state.pet_db.values()[0]

## 宠物转字典


static func _init_mech_pets(game_state) -> void:
	game_state.mech_db["机关兽"] = {
		"role": CharacterStats.Role.GUARD,
		"name": "机关兽", "was_base_path": "res://WAS/机关兽",
		"description": "近战机关 · 护定位 · 攻守兼备",
		"level": 1, "exp": 0, "atk": 30, "def_": 20, "spd": 8,
		"atk_g": 4, "def_g": 3, "spd_g": 1, "skills": ["普通攻击", "破防击"],
	}
	game_state.mech_db["机关鸟"] = {
		"role": CharacterStats.Role.ATTACK,
		"name": "机关鸟", "was_base_path": "res://WAS/机关鸟",
		"description": "飞行机关 · 攻定位 · 迅捷灵动",
		"level": 1, "exp": 0, "atk": 20, "def_": 8, "spd": 22,
		"atk_g": 3, "def_g": 1, "spd_g": 4, "skills": ["普通攻击", "三连击"],
	}
	game_state.mech_team.assign(["机关兽", "机关鸟"])


# ══════════════════════════════════════════════
# 技能库 API
# ══════════════════════════════════════════════

## 解锁技能给指定角色
