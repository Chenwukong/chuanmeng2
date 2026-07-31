# MaterialDB.gd — 打造材料 & 符咒配方
class_name MaterialDB
extends RefCounted

const MATERIAL_DB = {
	"black_ore": {
		"name": "黑曜石", "tcp_path": "res://TCP/矿石/黑曜石.tcp",
		"desc": "能增加武器伤害的矿石", "price": 200,
		"craft_type": "weapon", "stat": "atk", "min_boost": 7, "max_boost": 10,
	},
	"red_shell": {
		"name": "红壳", "tcp_path": "res://TCP/矿石/红壳.tcp",
		"desc": "能增加武器伤害的矿石", "price": 200,
		"craft_type": "weapon", "stat": "hp", "min_boost": 70, "max_boost": 100,
	},
	"cloud_herb": {
		"name": "飞云草", "tcp_path": "res://TCP/草药/飞云草.tcp",
		"desc": "能制造加速符咒的灵草", "price": 150,
		"craft_type": "talisman", "stat": "spd", "min_boost": 3, "max_boost": 6,
	},
	"blood_stone": {
		"name": "吸血石", "tcp_path": "res://TCP/矿石/吸血石.tcp",
		"desc": "攻击时按伤害百分比吸取生命", "price": 500,
		"craft_type": "weapon", "stat": "lifesteal", "min_boost": 5, "max_boost": 10,
	},
	"gold_ore": {
		"name": "黄金", "tcp_path": "res://TCP/矿石/黄金.tcp",
		"desc": "增加战斗获得的金币收益", "price": 400,
		"craft_type": "weapon", "stat": "gold_boost", "min_boost": 10, "max_boost": 20,
	},
	"shattered_green": {
		"name": "碎绿", "tcp_path": "res://TCP/矿石/碎绿.tcp",
		"desc": "增加治疗技能可治疗的单位数量", "price": 350,
		"craft_type": "weapon", "stat": "heal_targets", "min_boost": 1, "max_boost": 1,
	},
	"thorn_horn": {
		"name": "棘角", "tcp_path": "res://TCP/矿石/棘角.tcp",
		"desc": "受到物理攻击时反弹部分伤害", "price": 450,
		"craft_type": "weapon", "stat": "reflect", "min_boost": 5, "max_boost": 10,
	},
	"moon_stone": {
		"name": "月石", "tcp_path": "res://TCP/矿石/月石.tcp",
		"desc": "增加夜间造成的伤害", "price": 400,
		"craft_type": "weapon", "stat": "night_dmg", "min_boost": 10, "max_boost": 15,
	},
	"lake_heart": {
		"name": "湖泊之心", "tcp_path": "res://TCP/矿石/湖泊之心.tcp",
		"desc": "增加灵力上限", "price": 300,
		"craft_type": "weapon", "stat": "mp_up", "min_boost": 30, "max_boost": 50,
	},
	"vitality": {
		"name": "生机", "tcp_path": "res://TCP/矿石/生机.tcp",
		"desc": "增加治疗量", "price": 350,
		"craft_type": "weapon", "stat": "heal_up", "min_boost": 8, "max_boost": 15,
	},
	"talisman_paper": {
		"name": "符纸", "tcp_path": "res://TCP/符咒/3290.tcp",
		"desc": "制作符咒的基础材料，黄纸朱砂", "price": 80,
		"craft_type": "talisman", "stat": "", "min_boost": 0, "max_boost": 0,
	},
	"flame_herb": {
		"name": "火焰花", "tcp_path": "res://TCP/草药/飞云草.tcp",
		"desc": "蕴含火灵力的花朵，可用于制作星火篆", "price": 120,
		"craft_type": "talisman", "stat": "", "min_boost": 0, "max_boost": 0,
	},
	"thunder_wood": {
		"name": "雷击木", "tcp_path": "res://TCP/草药/飞云草.tcp",
		"desc": "被雷劈过的灵木，可用于制作五雷咒", "price": 130,
		"craft_type": "talisman", "stat": "", "min_boost": 0, "max_boost": 0,
	},
	"ice_crystal": {
		"name": "冰晶草", "tcp_path": "res://TCP/草药/飞云草.tcp",
		"desc": "生长在极寒之地的草药，可用于制作冰冻符", "price": 140,
		"craft_type": "talisman", "stat": "", "min_boost": 0, "max_boost": 0,
	},
	"peace_moss": {
		"name": "止战苔", "tcp_path": "res://TCP/草药/飞云草.tcp",
		"desc": "散发宁静气息的苔藓，可用于制作止战符", "price": 110,
		"craft_type": "talisman", "stat": "", "min_boost": 0, "max_boost": 0,
	},
}

const TALISMAN_RECIPES: Array[Dictionary] = [
	{
		"output": "talisman_haste",
		"output_name": "加速符",
		"materials": { "talisman_paper": 1, "cloud_herb": 3 }
	},
	{
		"output": "talisman_fire",
		"output_name": "星火篆",
		"materials": { "talisman_paper": 1, "flame_herb": 2, "black_ore": 1 }
	},
	{
		"output": "talisman_thunder",
		"output_name": "五雷咒",
		"materials": { "talisman_paper": 1, "thunder_wood": 2, "gold_ore": 1 }
	},
	{
		"output": "talisman_ice",
		"output_name": "冰冻符咒",
		"materials": { "talisman_paper": 1, "ice_crystal": 2, "moon_stone": 1 }
	},
	{
		"output": "talisman_ceasefire",
		"output_name": "止战符咒",
		"materials": { "talisman_paper": 1, "peace_moss": 2, "lake_heart": 1 }
	},
	{
		"output": "talisman_revive",
		"output_name": "借尸符",
		"materials": { "talisman_paper": 1, "ice_crystal": 1, "moon_stone": 1, "lake_heart": 1 }
	},
]
