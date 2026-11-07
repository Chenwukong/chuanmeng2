extends SceneTree
func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var data = root.get_node("GameData")
	# 隔离可配置属性成就，避免角色初始高属性影响其他回归测试。
	for stats in data.character_roster.values():
		for field in ["max_hp", "attack", "magic_attack", "defense", "speed"]: stats.set(field, 1)
	data.achievement_stats = {}
	data.achievement_claimed = []
	data.achievement_step_remainder = 0.0
	var initial: int = data.talent_points
	assert(not data.claim_achievement("walk_50000"))
	data.record_walk_distance(19.0)
	assert(int(data.achievement_stats.get("steps", 0)) == 0)
	data.record_walk_distance(21.0)
	assert(data.achievement_stats.steps == 2)
	data.add_achievement_progress("steps", 49997)
	assert(not data.claim_achievement("walk_50000"))
	data.record_walk_distance(20.0)
	assert(data.claim_achievement("walk_50000"))
	assert(data.talent_points == initial + 1)
	assert(not data.claim_achievement("walk_50000"))
	assert(not data.claim_achievement("missing"))
	assert(data.talent_points == initial + 1)
	var popup = load("res://scenes/UI/AchievementPopup.tscn").instantiate()
	root.add_child(popup)
	assert(_card_count(popup) == load("res://Script/Data/AchievementDB.gd").ENTRIES.size())
	popup._set_filter(1)
	popup._set_filter(2)
	popup._set_filter(3)
	assert(_card_count(popup) == 1)
	assert(load("res://Script/World/MainScene.gd").can_instantiate())
	assert(load("res://Script/UI/Talents/talent_tree.gd").can_instantiate())
	assert(load("res://Script/World/MapWalker.gd").can_instantiate())
	# 财富成就：阈值、花钱后领取、背包被动、存档恢复与加成叠加。
	data.player_equipment = {}
	data.player_inventory.remove_item("treasure_basin")
	data.player_gold = 999999
	assert(not data.claim_achievement("gold_1000000"))
	assert(data.add_gold(1) == 1)
	assert(data.achievement_stats.gold_peak == 1000000)
	data.player_gold = 50
	assert(data.claim_achievement("gold_1000000"))
	assert(data.player_inventory.get_count("treasure_basin") == 1)
	assert(not data.claim_achievement("gold_1000000"))
	assert(is_equal_approx(data.get_gold_multiplier(), 1.3))
	assert(data.add_gold(100) == 130)
	assert(data.player_gold == 180)
	var saved_inventory: Dictionary = data.player_inventory.serialize()
	data.player_inventory = data.player_inventory.get_script().new()
	data.player_inventory.deserialize(saved_inventory, data.item_db)
	assert(is_equal_approx(data.get_gold_multiplier(), 1.3))
	data.player_equipment = {"test": {"weapon": {"gold_boost": 20}}}
	assert(data.add_gold(100) == 150)
	data.player_equipment = {}
	data.player_inventory.add_item(data.item_db.treasure_basin, 1)
	assert(is_equal_approx(data.get_gold_multiplier(), 1.3))
	assert(data.add_gold(0) == 0)
	assert(data.add_gold(-100) == 0)
	popup._set_filter(0)
	assert(_card_count(popup) == load("res://Script/Data/AchievementDB.gd").ENTRIES.size())
	# 未入队的可选角色已有独立数据，领取时立即获得属性点。
	var roster: Dictionary = load("res://Script/Data/CharacterDB.gd").CHARACTER_DB
	var ids: Array = CharacterDB.selectable_ids()
	assert(data.character_roster.size() == ids.size())
	data.party_db.clear()
	data.party_order.clear()
	data.achievement_level_ids = {}
	data.achievement_claim_counts = {}
	for stats in data.character_roster.values(): stats.level = 99
	data.refresh_level_achievements()
	assert(not data.claim_achievement("heroes_level_100"))
	data.add_party_by_name(roster[ids[0]].name)
	var hero = data.character_roster[ids[0]]
	assert(is_same(hero, data.party_db[ids[0]]))
	var before: Dictionary = {}
	for mid in ids: before[mid] = data.character_roster[mid].potential_left
	hero.level = 100
	data.refresh_level_achievements()
	assert(data.claim_achievement("heroes_level_100"))
	for mid in ids: assert(data.character_roster[mid].potential_left == before[mid] + 5)
	assert(data.party_db.size() == 1)
	assert(not data.claim_achievement("heroes_level_100"))
	# 入队与离队只改变引用，不新建数据、不补发、不重置已分配点。
	var reserve = data.character_roster[ids[1]]
	var reserve_points: int = reserve.potential_left
	data.add_party_by_name(roster[ids[1]].name)
	assert(is_same(reserve, data.party_db[ids[1]]))
	assert(reserve.potential_left == reserve_points)
	reserve.potential_left -= 2
	data.remove_party_member(ids[1])
	assert(not data.party_db.has(ids[1]))
	assert(is_same(reserve, data.character_roster[ids[1]]))
	data.add_party_by_name(roster[ids[1]].name)
	assert(is_same(reserve, data.party_db[ids[1]]))
	assert(reserve.potential_left == reserve_points - 2)
	reserve.level = 100
	data.refresh_level_achievements()
	assert(data.claim_achievement("heroes_level_100"))
	assert(data.character_roster[ids[2]].potential_left == before[ids[2]] + 10)
	data.remove_party_member(ids[0])
	data.add_party_by_name(roster[ids[0]].name)
	assert(not data.claim_achievement("heroes_level_100"))
	# 全名册 JSON 存档恢复，未入队者属性与已领次数不丢失、不重复加点。
	var snapshot := {"characters": {}, "party_order": data.party_order.duplicate()}
	for mid in ids: snapshot.characters[mid] = data.character_roster[mid].save_to_dict()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	data._restore_character_roster(saved)
	for mid in ids: assert(data.character_roster[mid].potential_left == int(saved.characters[mid].pot_left))
	for mid in data.party_db: assert(is_same(data.party_db[mid], data.character_roster[mid]))
	assert(not data.claim_achievement("heroes_level_100"))
	data._restore_character_roster(saved)
	for stats in data.character_roster.values(): stats.level = 100
	data.refresh_level_achievements()
	for i in ids.size() - 2: assert(data.claim_achievement("heroes_level_100"))
	assert(not data.claim_achievement("heroes_level_100"))
	assert(data.achievement_claim_counts.heroes_level_100 == ids.size())
	assert(data.character_roster[ids[2]].potential_left == before[ids[2]] + ids.size() * 5)
	var entry: Dictionary = load("res://Script/Data/AchievementDB.gd").ENTRIES.filter(func(e): return e.id == "heroes_level_100")[0]
	assert(data.get_achievement_state(entry).exhausted)
	popup._set_filter(3)
	assert(_card_count(popup) == 3)
	for i in ids.size(): assert(data.claim_achievement("heroes_level_50"))
	assert(data.claim_achievement("gold_10000"))
	assert(data.claim_achievement("gold_500000"))
	popup._set_filter(1)
	assert(popup.get_node("Content/Scroll/List").get_child(0).text == "暂无此类成就")
	print("ROSTER PASS: all %d heroes immediately rewarded, party shares data, rejoin preserves points, save roundtrip, repeat cap" % ids.size())
	print("TREASURE BASIN PASS: wealth threshold, retained unlock, unique reward, passive bonus, inventory restore, equipment stacking")
	print("ACHIEVEMENTS PASS: threshold, distance remainder, reward, duplicate claim, UI filters, integration scripts")
	# 配置阈值独立统计：49未达标，50仅达成半步圆满，100同时达成百炼成才。
	data.achievement_level_ids = {}
	data.achievement_claim_counts = {}
	for stats in data.character_roster.values(): stats.level = 49
	data.refresh_level_achievements()
	assert(not data.claim_achievement("heroes_level_50"))
	assert(not data.claim_achievement("heroes_level_100"))
	data.character_roster[ids[0]].level = 50
	data.refresh_level_achievements()
	assert(data.claim_achievement("heroes_level_50"))
	assert(not data.claim_achievement("heroes_level_50"))
	assert(not data.claim_achievement("heroes_level_100"))
	data.character_roster[ids[0]].level = 100
	data.refresh_level_achievements()
	assert(data.claim_achievement("heroes_level_100"))
	assert(not data.claim_achievement("heroes_level_50"))
	# 已领1/19次也属于“已领取”，不要求全部次数领完。
	popup._set_filter(3)
	assert(popup._groups.has("成长"))
	var claimed_group = popup._groups["成长"].body
	assert(claimed_group.has_node("heroes_level_50"))
	assert(claimed_group.has_node("heroes_level_100"))
	var partial_button = claimed_group.get_node("heroes_level_100").find_child("ClaimButton", true, false)
	assert(partial_button.text == "已领 1/%d" % ids.size())
	assert(partial_button.disabled)
	# 还有下一份奖励可领时，同时出现在“已领取”和“可领取”。
	data.character_roster[ids[1]].level = 100
	data.refresh_level_achievements()
	assert(popup._groups["成长"].body.has_node("heroes_level_100"))
	partial_button = popup._groups["成长"].body.get_node("heroes_level_100").find_child("ClaimButton", true, false)
	assert(not partial_button.disabled)
	popup._set_filter(1)
	assert(popup._groups["成长"].body.has_node("heroes_level_100"))
	popup._set_filter(3)
	assert(data.claim_achievement("heroes_level_100"))
	assert(popup._groups["成长"].body.has_node("heroes_level_100"))
	partial_button = popup._groups["成长"].body.get_node("heroes_level_100").find_child("ClaimButton", true, false)
	assert(partial_button.text == "已领 2/%d" % ids.size())
	assert(partial_button.disabled)
	popup._set_filter(0)
	print("CLAIMED FILTER PASS: partial claims visible, live count refresh, pending reward remains claimable")
	print("CONFIGURED LEVEL PASS: 49/50/100 boundaries, independent reward counts")
	# 通知只在新达成时出现，领取显示真实奖励，重复点击不会显示成功。
	var notices = data._achievement_notifications
	data.achievement_notice_requested.disconnect(notices._show_next)
	notices.dismiss_all()
	data.achievement_notice_queue.clear()
	data.achievement_notified_counts = {}
	data.achievement_claimed = []
	data.achievement_claim_counts = {"heroes_level_50": ids.size()}
	data.achievement_level_ids = {}
	for stats in data.character_roster.values(): stats.level = 99
	data.achievement_stats = {"steps": 49999}
	data.achievement_step_remainder = 0.0
	data.achievements_changed.emit()
	assert(data.achievement_notice_queue.is_empty())
	data.record_walk_distance(20.0)
	assert(data.achievement_notice_queue.size() == 1)
	assert(data.achievement_notice_queue[0].title == "成就达成")
	data.record_walk_distance(20.0)
	assert(data.achievement_notice_queue.size() == 1)
	assert(data.claim_achievement("walk_50000"))
	assert(data.achievement_notice_queue.size() == 2)
	assert("天赋点 +1" in data.achievement_notice_queue[1].message)
	assert(not data.claim_achievement("walk_50000"))
	assert(data.achievement_notice_queue.size() == 2)
	data.character_roster[ids[0]].level = 100
	data.refresh_level_achievements()
	assert(data.achievement_notice_queue.size() == 3)
	data.refresh_level_achievements()
	assert(data.achievement_notice_queue.size() == 3)
	data.character_roster[ids[1]].level = 100
	data.refresh_level_achievements()
	assert(data.achievement_notice_queue.size() == 4)
	assert(data.get_claimable_achievement_count() == 2)
	assert(data.claim_achievement("heroes_level_100"))
	assert("全体可选角色各 +5" in data.achievement_notice_queue[4].message)
	assert(("已领取 1/%d 次" % ids.size()) in data.achievement_notice_queue[4].message)
	assert(data.get_claimable_achievement_count() == 1)
	assert("【奖励已领取】" in data.world_log_text)
	# 读档期间只刷新待领数，不推送历史达成。
	var notice_count: int = data.achievement_notice_queue.size()
	data._achievement_notices_suspended = true
	data.achievement_stats.gold_peak = 1000000
	data.achievements_changed.emit()
	assert(data.achievement_notice_queue.size() == notice_count)
	data.achievement_notified_counts.gold_1000000 = 1
	data.achievement_notified_counts.gold_10000 = 1
	data.achievement_notified_counts.gold_500000 = 1
	data._achievement_notices_suspended = false
	data.achievements_changed.emit()
	assert(data.achievement_notice_queue.size() == notice_count)
	data.achievement_notice_requested.connect(notices._show_next)
	data.achievement_notice_queue.clear()
	print("NOTIFICATIONS PASS: threshold-only, repeated completion, reward details, no duplicate success, pending count, log, restore suppression")
	# 分类收起保持筛选、刷新和重开页面时的状态，待领数仍显示。
	popup._set_filter(0)
	assert(popup._groups.size() == 4)
	assert(popup._groups["成长"].body.get_child_count() == 7)
	assert(popup._groups["成长"].body.visible)
	popup._groups["成长"].header.pressed.emit()
	assert(not popup._groups["成长"].body.visible)
	assert("待领取" in popup._groups["成长"].header.text)
	data.achievements_changed.emit()
	assert(not popup._groups["成长"].body.visible)
	popup._set_filter(1)
	assert(not popup._groups["成长"].body.visible)
	popup._set_filter(0)
	var reopened = load("res://scenes/UI/AchievementPopup.tscn").instantiate()
	root.add_child(reopened)
	assert(not reopened._groups["成长"].body.visible)
	reopened.queue_free()
	popup._toggle_category("成长")
	assert(popup._groups["成长"].body.visible)
	assert(_card_count(popup) == load("res://Script/Data/AchievementDB.gd").ENTRIES.size())
	print("CATEGORY COLLAPSE PASS: grouped cards, clickable toggle, pending count, refresh/filter/reopen state")
	# 财富改发金币，确认实际到账、金币加成和防重复。
	data.achievement_claimed.erase("gold_10000")
	data.achievement_claimed.erase("gold_500000")
	data.player_equipment = {}
	data.player_inventory.remove_item("treasure_basin")
	data.achievement_stats.gold_peak = 9999
	data.player_gold = 9999
	assert(not data.claim_achievement("gold_10000"))
	data.add_gold(1)
	var cash: int = data.player_gold
	assert(data.claim_achievement("gold_10000"))
	assert(data.player_gold == cash + 10000)
	assert(data.player_inventory.get_count("treasure_basin") == 0)
	assert(not data.claim_achievement("gold_10000"))
	data.achievement_stats.gold_peak = 499999
	data.player_gold = 499999
	assert(not data.claim_achievement("gold_500000"))
	data.add_gold(1)
	data.player_inventory.add_item(data.item_db.treasure_basin, 1)
	cash = data.player_gold
	assert(data.claim_achievement("gold_500000"))
	assert(data.player_gold == cash + 65000)
	assert(not data.claim_achievement("gold_500000"))
	# 普通装备等级不是强化等级；非武器不能触发神兵成就。
	data.equip_bag.clear()
	data.player_equipment = {}
	data.achievement_stats.erase("weapon_upgrade_peak")
	assert(not data.claim_achievement("weapon_upgrade_10"))
	data.record_weapon_upgrade({"slot": 0, "level": 100})
	data.record_weapon_upgrade({"slot": 1, "_build_level": 10})
	assert(int(data.achievement_stats.get("weapon_upgrade_peak", 0)) == 0)
	data.record_weapon_upgrade({"slot": 0, "_build_level": 9})
	assert(not data.claim_achievement("weapon_upgrade_10"))
	data.record_weapon_upgrade({"slot": 0, "_build_level": 10})
	var points: int = data.talent_points
	assert(data.claim_achievement("weapon_upgrade_10"))
	assert(data.talent_points == points + 1)
	assert(not data.claim_achievement("weapon_upgrade_10"))
	# 载入后的背包和穿戴装备扫描都能识别强化+10。
	data.achievement_stats.erase("weapon_upgrade_peak")
	data.equip_bag.append({"slot": 0, "_build_level": 10})
	data.refresh_equipment_achievements()
	assert(data.achievement_stats.weapon_upgrade_peak == 10)
	data.equip_bag.clear()
	data.achievement_stats.erase("weapon_upgrade_peak")
	data.player_equipment = {"test": {"weapon": {"slot": 0, "_build_level": 10}}}
	data.refresh_equipment_achievements()
	assert(data.achievement_stats.weapon_upgrade_peak == 10)
	assert(load("res://Script/UI/BuildPopup.gd").can_instantiate())
	print("GOLD + WEAPON PASS: 10000/500000 thresholds, cash rewards, passive bonus, +9/+10 weapon-only, bag/worn scan, one-time talent reward")
	# 五种属性独立达标，装备/临时值不计，历史达成保留且只领一次。
	var definitions: Array = load("res://Script/Data/AchievementDB.gd").ENTRIES.filter(func(e): return e.has("stat_field"))
	assert(definitions.size() == 5)
	for stats in data.character_roster.values():
		for field in ["max_hp", "attack", "magic_attack", "defense", "speed"]: stats.set(field, 1)
	data.player_equipment = {ids[0]: {"weapon": {"slot": 0, "base": {"hp": 99999, "atk": 99999, "matk": 99999, "def": 99999, "spd": 99999}}}}
	for definition in definitions:
		data.achievement_stats.erase(definition.metric)
		data.achievement_claimed.erase(definition.id)
	data.refresh_attribute_achievements()
	for definition in definitions: assert(not data.claim_achievement(definition.id))
	var subject = data.character_roster[ids[2]]
	assert(not data.party_db.has(ids[2]))
	for definition in definitions:
		var threshold: int = definition.target
		subject.set(definition.stat_field, threshold - 1)
		data.refresh_attribute_achievements()
		assert(not data.claim_achievement(definition.id))
		subject.set(definition.stat_field, threshold)
		data.refresh_attribute_achievements()
		assert(data.get_achievement_state(definition).available == 1)
		var bonus_before: int = data.talent_points
		assert(data.claim_achievement(definition.id))
		assert(data.talent_points == bonus_before + 1)
		assert(not data.claim_achievement(definition.id))
		subject.set(definition.stat_field, 1)
		data.refresh_attribute_achievements()
		assert(data.get_achievement_state(definition).exhausted)
		assert(data.get_achievement_state(definition).progress == threshold)
	assert(load("res://Script/UI/StatusPopup.gd").can_instantiate())
	print("ATTRIBUTE ACHIEVEMENTS PASS: five fields, target boundary, inactive hero, equipment excluded, permanent progress, one reward per save")
	if "--preview" in OS.get_cmdline_user_args():
		popup._set_filter(0)
		popup._toggle_category("游历")
		popup._toggle_category("财富")
		await create_timer(0.3).timeout
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/achievement_preview.png")
	popup.queue_free()
	quit()

func _card_count(popup: CanvasLayer) -> int:
	var count := 0
	for group in popup.get_node("Content/Scroll/List").get_children():
		if group.has_node("Entries"): count += group.get_node("Entries").get_child_count()
	return count
