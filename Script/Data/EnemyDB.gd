# EnemyDB.gd — 敌人数据库 & 遭遇配置
class_name EnemyDB
extends RefCounted

## 怪物数据库：lv 支持固定值（如 5）或区间（如 "3-8"，每次生成随机取一个）；
## 未写的属性按 arch 分类模板 × 等级推导（见 ENEMY_ARCHETYPE）
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
	{ name = "火沙虫", arch = "肉", lv = "1-3", skills = ["普通攻击","妖术"], was_base_path = "res://WAS/火沙虫" },
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
		"growth": { "hp": 15,  "mp": 4,  "atk": 6,  "matk": 3,  "def": 2,  "mdef": 2,  "spd": 2 },
	},
	"法": {  # 法师：法伤/法防成长高，血少物防低
		"base":   { "hp": 200,  "mp": 80, "atk": 18, "matk": 36, "def": 6,  "mdef": 16, "spd": 10 },
		"growth": { "hp": 10,  "mp": 12, "atk": 3,  "matk": 9,  "def": 2,  "mdef": 2,  "spd": 2 },
	},
	"肉": {  # 坦克：血量/物防高，速度低
		"base":   { "hp": 200, "mp": 40, "atk": 22, "matk": 16, "def": 18, "mdef": 12, "spd": 8 },
		"growth": { "hp": 20,  "mp": 5,  "atk": 4,  "matk": 3,  "def": 4,  "mdef": 4,  "spd": 1 },
	},
	"速": {  # 敏捷：速度高、物攻中等
		"base":   { "hp": 85,  "mp": 40, "atk": 26, "matk": 18, "def": 8,  "mdef": 8,  "spd": 20 },
		"growth": { "hp": 20,  "mp": 5,  "atk": 5,  "matk": 3,  "def": 2,  "mdef": 2,  "spd": 3 },
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
			total += gv * (1.0 + 0.2 * s) * 10.0
		total += gv * (1.0 + 0.1 * full_segs) * rem
		out[k] = int(base.get(k, 0) + total)
	return out


# ══════════════════════════════════════════════
# 怪物等级档属性倍率：怪物等级 ≥ 档位时，属性整体 × 该倍率（档位取总倍率，不累乘）
# 例：30 级起 ×1.2、60 级起 ×1.5。默认表不影响 20 级及以下的怪（可自行加档）
# ══════════════════════════════════════════════
const LEVEL_STAT_MUL := {
	1:  1.0,
	#10: 1.1,
	#20: 1.2,
	
	#60: 1.5,
	#90: 1.8,
	#100: 2,
}

## 取某等级对应的属性倍率（≤lv 的最大档；无匹配时 1.0）
static func level_stat_mul(lv: int) -> float:
	var best := 1.0
	var best_key := 0
	for k in LEVEL_STAT_MUL:
		if lv >= int(k) and int(k) > best_key:
			best_key = int(k)
			best = float(LEVEL_STAT_MUL[k])
	return best


## 解析某怪行等级区间：支持 lv=5（固定）、lv="3-8"（字符串区间）、lv_min/lv_max 字段；返回 Vector2i(min, max)
static func enemy_lv_range(row: Dictionary) -> Vector2i:
	if row.has("lv_min") or row.has("lv_max"):
		var lo := int(row.get("lv_min", 1))
		var hi := int(row.get("lv_max", lo))
		return Vector2i(mini(lo, hi), maxi(lo, hi))
	var raw = row.get("lv", 1)
	if raw is String and String(raw).contains("-"):
		var parts := String(raw).split("-")
		if parts.size() == 2:
			var a := int(parts[0]); var b := int(parts[1])
			return Vector2i(mini(a, b), maxi(a, b))
	if raw is int and int(raw) < 1:
		push_warning("怪物 \"%s\" 的 lv=%s 疑似区间漏了引号（lv = 1-3 会被当成减法 = -2）；正确写法：lv = \"1-3\"" % [row.get("name", "?"), str(raw)])
	var only := maxi(1, int(raw))
	return Vector2i(only, only)


## 等级随队伍收束的幅度：怪物上限 = 队伍最高 + LV_ABOVE_PARTY；下限 = 队伍最高 - LV_BELOW_PARTY
const LV_ABOVE_PARTY := 4
const LV_BELOW_PARTY := 3

## 随机取该怪的一个等级（区间怪每次生成在区间内随机；固定则原值）
## 随队伍收束：上限 ≤ 队伍最高+4、下限 ≥ 队伍最高-3；
## 但若设定下限本身已高于队伍最高，则不限制（保持原区间）
static func roll_enemy_level(row: Dictionary) -> int:
	var r := enemy_lv_range(row)
	var lo := r.x
	var hi := r.y
	var top := GameData.highest_party_level()
	if top > 0 and lo <= top:
		var nlo := maxi(lo, top - LV_BELOW_PARTY)
		var nhi := mini(hi, top + LV_ABOVE_PARTY)
		# 仅当收束后区间仍有效才应用；若冲突（设定的区间整体远低于队伍等级）→ 保持原区间
		if nlo <= nhi:
			lo = nlo
			hi = nhi
	return randi_range(lo, hi)


## 解析某怪行的有效属性：显式写了就用；没写则按分类模板 × 等级（boss 额外加成）
## 返回 hp/mp/atk/matk/def/mdef/spd（不含夜晚/等级档倍率，需要时由调用方乘）
static func resolve_enemy_stats(row: Dictionary) -> Dictionary:
	var lv := roll_enemy_level(row)
	var arch := str(row.get("arch", DEFAULT_ARCH))
	var d := derive_arch_stats(arch, lv)
	var boss_mul: float = BOSS_MUL if str(row.get("rank", "")) == "boss" else 1.0
	var out := {}
	for k in ["hp", "mp", "atk", "matk", "def", "mdef", "spd"]:
		if row.has(k):
			out[k] = int(row.get(k))
		else:
			out[k] = int(int(d.get(k, 0)) * boss_mul)
	return out


## 解析某怪行的技能列表（缺省给普通攻击）
static func resolve_enemy_skills(row: Dictionary) -> Array:
	return Array(row.get("skills", ["普通攻击"]))
