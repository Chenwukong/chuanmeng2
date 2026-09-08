# EnemyDB.gd — 敌人数据库 & 遭遇配置
class_name EnemyDB
extends RefCounted

const ENEMY_DB := [
	{ name = "妖狐·赤尾", hp = 90,  mp = 40,  atk = 22, def = 8,  spd = 10, lv = 1, skills = ["普通攻击","妖术","妖气回复"] },
	{ name = "山魈·獠牙",  hp = 110, mp = 30,  atk = 28, def = 12, spd = 9,  lv = 1, skills = ["普通攻击","妖术"] },
	{ name = "厉鬼·幽魂",  hp = 80,  mp = 60,  atk = 20, def = 5,  spd = 14, lv = 2, skills = ["普通攻击","妖术","蛊毒咒"], traits = {"_revive": 20} },
	{ name = "石傀·巨岩",  hp = 160, atk = 32, def = 22, spd = 5,  lv = 3, skills = ["普通攻击","破防击"] },
	{ name = "火鸦·灼羽",  hp = 70,  mp = 80,  atk = 18, def = 6,  mdef = 4,  spd = 16, lv = 3, skills = ["普通攻击","妖术","灼焰术"] },
	{ name = "幽蛛·织网",  hp = 100, mp = 50,  atk = 24, def = 10, mdef = 6,  spd = 12, lv = 4, skills = ["普通攻击","蛊毒咒","妖术"] },
	{ name = "风狼·疾牙",  hp = 120, mp = 30,  atk = 30, def = 8,  mdef = 5,  spd = 18, lv = 4, skills = ["普通攻击","三连击"] },
	{ name = "寒魄·幽灵",  hp = 90,  mp = 90,  atk = 22, def = 6,  mdef = 12, spd = 13, lv = 5, skills = ["普通攻击","冰封诀","妖术"], traits = {"_revive": 25} },
	{ name = "九尾妖狐",    hp = 200, mp = 80,  atk = 35, def = 15, mdef = 18, spd = 12, lv = 6, skills = ["普通攻击","妖术","妖气回复","蛊毒咒","起死回生"] },
	{ name = "魔将·煞星",  hp = 250, mp = 60,  atk = 42, def = 22, mdef = 12, spd = 10, lv = 7, skills = ["普通攻击","三连击","破防击","护体真气"] },
	{ name = "骷髅王",      hp = 220, mp = 70,  atk = 38, def = 12, mdef = 18, spd = 11, lv = 7, skills = ["普通攻击","妖术","破防击"], traits = {"_revive": 30} },
	{ name = "熔岩魔人",    hp = 280, mp = 50,  atk = 45, def = 28, mdef = 10, spd = 7,  lv = 8, skills = ["普通攻击","灼焰术","破防击"] },
	{ name = "九幽魔王",    hp = 400, mp = 120, atk = 50, def = 22, mdef = 22, spd = 11, lv = 10, rank = "boss", skills = ["普通攻击","妖术","妖气回复","冰封诀","蛊毒咒","起死回生"], traits = {"_revive": 40} },
	{ name = "蛟龙·渊王",   hp = 500, mp = 100, atk = 58, def = 28, mdef = 24, spd = 13, lv = 12, rank = "boss", skills = ["普通攻击","妖术","三连击","灼焰术","破防击"] },
	{ name = "上古神魔",    hp = 600, mp = 150, atk = 65, def = 30, mdef = 30, spd = 15, lv = 15, rank = "boss", skills = ["普通攻击","妖术","妖气回复","冰封诀","三连击","蛊毒咒"] },
	{ name = "超级赤焰兽",  hp = 200, mp = 80,  atk = 30, def = 15, mdef = 10, spd = 20, lv = 5, skills = ["普通攻击","妖术"], was_base_path = "res://WAS/超级赤焰兽" },
	{ name = "毒云龟",  hp = 200, mp = 80,  atk = 30, def = 15, mdef = 10, spd = 20, lv = 5, skills = ["普通攻击","妖术"], was_base_path = "res://WAS/毒云龟" },	
	{ name = "谛听",  hp = 200, mp = 80,  atk = 30, def = 15, mdef = 10, spd = 20, lv = 5, skills = ["普通攻击","妖术"], was_base_path = "res://WAS/谛听" },	
	{ name = "草龟",  hp = 200, mp = 80,  atk = 30, def = 15, mdef = 10, spd = 20, lv = 5, skills = ["普通攻击","妖术"], was_base_path = "res://WAS/草龟" },
	{ name = "超级大鹏",  hp = 200, mp = 80,  atk = 30, def = 15, mdef = 10, spd = 20, lv = 5, skills = ["普通攻击","妖术"], was_base_path = "res://WAS/超级大鹏" },
	{ name = "黑熊",  hp = 200, mp = 80,  atk = 30, def = 15, mdef = 10, spd = 20, lv = 100, skills = ["普通攻击","妖术"], was_base_path = "res://WAS/黑熊" },
	{ name = "火沙虫",  hp = 200, mp = 80,  atk = 30, def = 15, mdef = 10, spd = 20, lv = 100, skills = ["普通攻击","妖术"], was_base_path = "res://WAS/火沙虫" },
]
