# 临时验证：怪物等级区间
extends Node


func _ready() -> void:
	var ok := true

	# 1) 区间解析
	ok = _chk(EnemyDB.enemy_lv_range({ "lv": 5 }) == Vector2i(5, 5), "lv=5 → (5,5)") and ok
	ok = _chk(EnemyDB.enemy_lv_range({ "lv": "3-8" }) == Vector2i(3, 8), "lv=\"3-8\" → (3,8)") and ok
	ok = _chk(EnemyDB.enemy_lv_range({ "lv": "8-3" }) == Vector2i(3, 8), "反向 \"8-3\" → (3,8)") and ok
	ok = _chk(EnemyDB.enemy_lv_range({ "lv_min": 2, "lv_max": 6 }) == Vector2i(2, 6), "lv_min/max → (2,6)") and ok
	ok = _chk(EnemyDB.roll_enemy_level({ "lv": 7 }) == 7, "固定 lv=7 roll=7") and ok

	# 2) 区间 roll 落在区间内，且多次能取到不同值
	var seen := {}
	for i in 200:
		var l := EnemyDB.roll_enemy_level({ "lv": "3-8" })
		if l < 3 or l > 8:
			ok = _chk(false, "roll 越界 %d" % l) and ok
		seen[l] = true
	ok = _chk(seen.size() >= 2, "区间随机能取到多个等级（实际 %d 种）" % seen.size()) and ok

	# 3) create_enemy：区间怪等级在区间内
	GameData._enemy_db_cache["测试区间怪"] = { "name": "测试区间怪", "arch": "攻", "lv": "3-8", "skills": ["普通攻击"] }
	var lv_ok := true
	var lv_seen := {}
	for i in 100:
		var e := GameData.create_enemy("测试区间怪")
		lv_seen[e.level] = true
		if e.level < 3 or e.level > 8:
			lv_ok = false
	ok = _chk(lv_ok, "create_enemy 区间怪等级 ∈ [3,8]") and ok
	ok = _chk(lv_seen.size() >= 2, "create_enemy 能出多种等级（%d 种）" % lv_seen.size()) and ok

	# 4) get_random_enemy_id 不崩（区间怪参与筛选）
	var id := GameData.get_random_enemy_id(1, 5)
	ok = _chk(not id.is_empty(), "get_random_enemy_id 正常：%s" % id) and ok

	print("VERIFY " + ("PASS" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)


func _chk(got: bool, label: String) -> bool:
	if got:
		return true
	printerr("FAIL %s" % label)
	return false
