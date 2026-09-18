# EnemyDB.gd — 敌人数据库 & 遭遇配置
class_name EnemyDB
extends RefCounted

const ENEMY_DB := [
	{ name = "妖狐·赤尾", arch = "法", hp = 90,  mp = 40,  atk = 22, def = 8,  spd = 10, lv = 1, skills = ["普通攻击","妖术","妖气回复"] },
	{ name = "山魈·獠牙", arch = "攻",  hp = 110, mp = 30,  atk = 28, def = 12, spd = 9,  lv = 1, skills = ["普通攻击","妖术"] },
	{ name = "厉鬼·幽魂", arch = "法",  hp = 80,  mp = 60,  atk = 20, def = 5,  spd = 14, lv = 2, skills = ["普通攻击","妖术","蛊毒咒"], traits = {"_revive": 20} },
	{ name = "石傀·巨岩", arch = "肉",  hp = 160, atk = 32, def = 22, spd = 5,  lv = 3, skills = ["普通攻击","破防击"] },
	{ name = "火鸦·灼羽", arch = "法",  hp = 70,  mp = 80,  atk = 18, def = 6,  mdef = 4,  spd = 16, lv = 3, skills = ["普通攻击","妖术","灼焰术"] },
	{ name = "幽蛛·织网", arch = "法",  hp = 100, mp = 50,  atk = 24, def = 10, mdef = 6,  spd = 12, lv = 4, skills = ["普通攻击","蛊毒咒","妖术"] },
	{ name = "风狼·疾牙", arch = "速",  hp = 120, mp = 30,  atk = 30, def = 8,  mdef = 5,  spd = 18, lv = 4, skills = ["普通攻击","三连击"] },
	{ name = "寒魄·幽灵", arch = "法",  hp = 90,  mp = 90,  atk = 22, def = 6,  mdef = 12, spd = 13, lv = 5, skills = ["普通攻击","冰封诀","妖术"], traits = {"_revive": 25} },
	{ name = "九尾妖狐", arch = "法",    hp = 200, mp = 80,  atk = 35, def = 15, mdef = 18, spd = 12, lv = 6, skills = ["普通攻击","妖术","妖气回复","蛊毒咒","起死回生"] },
	{ name = "魔将·煞星", arch = "攻",  hp = 250, mp = 60,  atk = 42, def = 22, mdef = 12, spd = 10, lv = 7, skills = ["普通攻击","三连击","破防击","护体真气"] },
	{ name = "骷髅王", arch = "攻",      hp = 220, mp = 70,  atk = 38, def = 12, mdef = 18, spd = 11, lv = 7, skills = ["普通攻击","妖术","破防击"], traits = {"_revive": 30} },
	{ name = "熔岩魔人", arch = "肉",    hp = 280, mp = 50,  atk = 45, def = 28, mdef = 10, spd = 7,  lv = 8, skills = ["普通攻击","灼焰术","破防击"] },
	{ name = "九幽魔王", arch = "法",    hp = 400, mp = 120, atk = 50, def = 22, mdef = 22, spd = 11, lv = 10, rank = "boss", skills = ["普通攻击","妖术","妖气回复","冰封诀","蛊毒咒","起死回生"], traits = {"_revive": 40} },
	{ name = "蛟龙·渊王", arch = "攻",   hp = 500, mp = 100, atk = 58, def = 28, mdef = 24, spd = 13, lv = 12, rank = "boss", skills = ["普通攻击","妖术","三连击","灼焰术","破防击"] },
	{ name = "上古神魔", arch = "肉",    hp = 600, mp = 150, atk = 65, def = 30, mdef = 30, spd = 15, lv = 15, rank = "boss", skills = ["普通攻击","妖术","妖气回复","冰封诀","三连击","蛊毒咒"] },
	{ name = "超级赤焰兽", arch = "法",  hp = 200, mp = 80,  atk = 30, def = 15, mdef = 10, spd = 20, lv = 5, skills = ["普通攻击","妖术"], was_base_path = "res://WAS/超级赤焰兽" },
	{ name = "毒云龟", arch = "肉",  hp = 200, mp = 80,  atk = 30, def = 15, mdef = 10, spd = 20, lv = 5, skills = ["普通攻击","妖术"], was_base_path = "res://WAS/毒云龟" },	
	{ name = "谛听", arch = "法",  hp = 200, mp = 80,  atk = 30, def = 15, mdef = 10, spd = 20, lv = 5, skills = ["普通攻击","妖术"], was_base_path = "res://WAS/谛听" },	
	{ name = "草龟", arch = "肉",  hp = 200, mp = 80,  atk = 30, def = 15, mdef = 10, spd = 20, lv = 5, skills = ["普通攻击","妖术"], was_base_path = "res://WAS/草龟" },
	{ name = "超级大鹏", arch = "速",  hp = 200, mp = 80,  atk = 30, def = 15, mdef = 10, spd = 20, lv = 20, skills = ["普通攻击","妖术"], was_base_path = "res://WAS/超级大鹏" },
	{ name = "黑熊", arch = "肉",  hp = 200, mp = 80,  atk = 30, def = 15, mdef = 10, spd = 20, lv = 20, skills = ["普通攻击","妖术"], was_base_path = "res://WAS/黑熊" },
	{ name = "火沙虫", arch = "肉", lv = 10, skills = ["普通攻击","妖术"], was_base_path = "res://WAS/火沙虫" },
]

# ══════════════════════════════════════════════
# 怪物分类模板（arch）：按分类 + 等级推导属性（create_enemy 使用）
# base = 1 级基础值，growth = 每级成长；敌表里显式写了某属性则优先用显式值
# ══════════════════════════════════════════════
const DEFAULT_ARCH := "攻"
const BOSS_MUL := 1.4   # rank=boss 时，模板推导的属性额外 ×1.4
const ENEMY_ARCHETYPE := {
	"攻": {  # 物理输出：物攻高、均衡
		"base":   { "hp": 90,  "mp": 30, "atk": 30, "matk": 18, "def": 8,  "mdef": 6,  "spd": 12 },
		"growth": { "hp": 24,  "mp": 4,  "atk": 6,  "matk": 3,  "def": 2,  "mdef": 2,  "spd": 1 },
	},
	"法": {  # 法师：法伤/法防成长高，血少物防低
		"base":   { "hp": 200,  "mp": 80, "atk": 18, "matk": 36, "def": 6,  "mdef": 16, "spd": 10 },
		"growth": { "hp": 18,  "mp": 12, "atk": 3,  "matk": 9,  "def": 2,  "mdef": 5,  "spd": 1 },
	},
	"肉": {  # 坦克：血量/物防高，速度低
		"base":   { "hp": 200, "mp": 40, "atk": 22, "matk": 16, "def": 18, "mdef": 12, "spd": 8 },
		"growth": { "hp": 15,  "mp": 5,  "atk": 4,  "matk": 3,  "def": 5,  "mdef": 4,  "spd": 0 },
	},
	"速": {  # 敏捷：速度高、物攻中等
		"base":   { "hp": 85,  "mp": 40, "atk": 26, "matk": 18, "def": 8,  "mdef": 8,  "spd": 20 },
		"growth": { "hp": 20,  "mp": 5,  "atk": 5,  "matk": 3,  "def": 2,  "mdef": 3,  "spd": 3 },
	},
}

## 按分类模板 + 等级推导属性（返回 hp/mp/atk/matk/def/mdef/spd）
## 成长随等级分段递增：每跨 10 级，该段每级成长额外 +10%（1-10 级 ×1.0，11-20 ×1.1，21-30 ×1.2 …）
static func derive_arch_stats(arch: String, lv: int) -> Dictionary:
	var cfg: Dictionary = ENEMY_ARCHETYPE.get(arch, ENEMY_ARCHETYPE[DEFAULT_ARCH])
	var base: Dictionary = cfg.get("base", {})
	var g: Dictionary = cfg.get("growth", {})
	var n := maxi(1, lv) - 1          # 升级步数
	var full_segs := n / 10            # 完整 10 级段数
	var rem := n % 10                  # 余下不足 10 级的步数
	var out := {}
	for k in ["hp", "mp", "atk", "matk", "def", "mdef", "spd"]:
		var gv := float(g.get(k, 0))
		var total := 0.0
		for s in range(full_segs):
			total += gv * (1.0 + 0.1 * s) * 10.0
		total += gv * (1.0 + 0.1 * full_segs) * rem
		out[k] = int(base.get(k, 0) + total)
	return out
