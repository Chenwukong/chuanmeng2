# 临时验证：怪物等级区间随队伍等级收束
extends Node


func _ready() -> void:
	var ok := true

	# 临时把全队等级设为 4（记录/恢复）
	var saved := {}
	for k in GameData.party_db:
		var st = GameData.party_db[k]
		saved[k] = st.level
		st.level = 4
	ok = _chk(GameData.highest_party_level() == 4, "队最高=4，实际 %d" % GameData.highest_party_level()) and ok

	# 案例1：区间 1-9，队4 → 1..8（上限 8）
	var seen1 := {}
	for i in 200:
		var l := EnemyDB.roll_enemy_level({ "lv": "1-9" })
		seen1[l] = true
		if l < 1 or l > 8:
			ok = _chk(false, "案例1 越界 %d" % l) and ok
	ok = _chk(seen1.has(8), "案例1 能取到上限 8") and ok

	# 案例2：区间 5-10，队4（下限 5 > 队最高）→ 不受限，仍 5..10
	var seen2 := {}
	for i in 200:
		var l := EnemyDB.roll_enemy_level({ "lv": "5-10" })
		seen2[l] = true
		if l < 5 or l > 10:
			ok = _chk(false, "案例2 越界 %d" % l) and ok
	ok = _chk(seen2.has(10), "案例2 仍能到 10") and ok

	# 案例3：队9，区间 1-9 → 6..9（下限抬到 6）
	for k in GameData.party_db:
		GameData.party_db[k].level = 9
	var seen3 := {}
	for i in 200:
		var l := EnemyDB.roll_enemy_level({ "lv": "1-9" })
		seen3[l] = true
		if l < 6 or l > 9:
			ok = _chk(false, "案例3 越界 %d" % l) and ok
	ok = _chk(seen3.has(6), "案例3 能取到下限 6") and ok
	ok = _chk(seen3.has(9), "案例3 能取到 9") and ok

	# 恢复等级
	for k in saved:
		GameData.party_db[k].level = saved[k]

	print("VERIFY " + ("PASS" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)


func _chk(got: bool, label: String) -> bool:
	if got:
		return true
	printerr("FAIL %s" % label)
	return false
