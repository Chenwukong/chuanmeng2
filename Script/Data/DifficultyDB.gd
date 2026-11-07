extends RefCounted
## 难度配置表：这里逐项调整，不再使用整档统一倍率。
## 0=简单，1=普通，2=困难；存档记录编号，不要改变排列顺序。
## 1.0=原始属性，0.8=80%，1.3=130%。在等级、首领、昼夜倍率之后计算。
## 只影响敌人；经验奖励、等级和捕捉后的宠物成长不受影响。
const PROFILES := [
	{
		"name": "简单",
		"protagonist_death_defeat": false,
		"enemy_stats": {
			"max_hp": 0.85,       # 最大生命
			"max_mp": 1.00,       # 最大法力
			"attack": 0.80,       # 物理攻击
			"magic_attack": 0.80, # 法术攻击
			"defense": 0.90,      # 物理防御
			"magic_defense": 0.90,# 法术防御
			"speed": 0.95,        # 速度
		},
	},
	{
		"name": "普通",
		"protagonist_death_defeat": false,
		"enemy_stats": {
			"max_hp": 1.00,
			"max_mp": 1.00,
			"attack": 1.00,
			"magic_attack": 1.00,
			"defense": 1.00,
			"magic_defense": 1.00,
			"speed": 1.00,
		},
	},
	{
		"name": "困难",
		"protagonist_death_defeat": true, # 主角死亡立即失败，优先于复生和敌方全灭。
		"enemy_stats": {
			"max_hp": 1.50,
			"max_mp": 1.20,
			"attack": 1.20,
			"magic_attack": 1.20,
			"defense": 1.10,
			"magic_defense": 1.10,
			"speed": 1.10,
		},
	},
]
const STAT_LABELS := {
	"max_hp": "生命", "max_mp": "法力", "attack": "物攻", "magic_attack": "法攻",
	"defense": "物防", "magic_defense": "法防", "speed": "速度",
}
static func enemy_multiplier(difficulty: int, stat: String) -> float:
	var index := difficulty if difficulty >= 0 and difficulty < PROFILES.size() else 1
	return maxf(0.0, float(PROFILES[index].enemy_stats.get(stat, 1.0)))
static func description(difficulty: int) -> String:
	var lines: PackedStringArray = []
	for stat in STAT_LABELS:
		lines.append("%s  %.0f%%" % [STAT_LABELS[stat], enemy_multiplier(difficulty, stat) * 100.0])
	if protagonist_death_defeat(difficulty): lines.append("主角死亡即失败")
	return "\n".join(lines)

static func protagonist_death_defeat(difficulty: int) -> bool:
	var index := difficulty if difficulty >= 0 and difficulty < PROFILES.size() else 1
	return bool(PROFILES[index].get("protagonist_death_defeat", false))
