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
	# —— 草药（按 TCP/草药 文件夹编号注册）——
	"0001": {
		"name": "四叶花", "tcp_path": "res://TCP/草药/0001.tcp",
		"desc": "具有药性的中草药，长着四片叶子的药草，可补充少量气血。【功效】恢复气血40点",
	},
	"0002": {
		"name": "草果", "tcp_path": "res://TCP/草药/0002.tcp",
		"desc": "“香草高士意，兰花隐者心。”散发淡淡香气的药草，具有一定的疗伤作用。【功效】治疗伤势10点",
	},
	"0003": {
		"name": "山药", "tcp_path": "res://TCP/草药/0003.tcp",
		"desc": "直立草本，羽状复叶，花白色、黄色、蓝色或紫色，浆果紫色，常见药草，可补充少量气血,对疗伤有一定效果。【功效】恢复气血40点,治疗伤势10点",
	},
	"0005": {
		"name": "九香虫", "tcp_path": "res://TCP/草药/0005.tcp",
		"desc": "带有药性的虫，因为与异花生活在一起，通体散着浓浓的异香，具有一定疗伤作用。【功效】治疗伤势15点",
	},
	"0006": {
		"name": "八角莲叶", "tcp_path": "res://TCP/草药/0006.tcp",
		"desc": "八角形状的莲叶，是非常少见的药物，产自西牛贺洲，可补充少量气血，具有疗伤作用。【功效】恢复气血60点,治疗伤势15点",
	},
	"0007": {
		"name": "天青地白", "tcp_path": "res://TCP/草药/0007.tcp",
		"desc": "产于北方的药草，天青色的花，青白色的叶，具有药性。可补充少量气血。【功效】恢复气血80点",
	},
	"0008": {
		"name": "水黄莲", "tcp_path": "res://TCP/草药/0008.tcp",
		"desc": "产于南方水乡，非常少见，同样也非常珍贵，具有一定疗伤作用。【功效】治疗伤势20点",
	},
	"0009": {
		"name": "人参", "tcp_path": "res://TCP/草药/0009.tcp",
		"desc": "千年的老参，药性很强，可以补充些许气血，具有一定疗伤作用。【功效】恢复气血80点,治疗伤势20点",
	},
	"0010": {
		"name": "月见草", "tcp_path": "res://TCP/草药/0010.tcp",
		"desc": "生长在暗处的药草，由于吸取月华的缘故，阴气很重，可补充少量气血和法力。【功效】恢复气血40点,恢复魔法30点",
	},
	"0011": {
		"name": "紫丹罗", "tcp_path": "res://TCP/草药/0011.tcp",
		"desc": "产自东胜神州的药草，紫色的叶子上散发出淡淡的清香，可补充少量法力。【功效】恢复魔法20点",
	},
	"0012": {
		"name": "百色花", "tcp_path": "res://TCP/草药/0012.tcp",
		"desc": "海外仙草，原产于方壶岛，兼百花之灵气，可补充少量法力。【功效】恢复魔法30点",
	},
	"0013": {
		"name": "灵脂", "tcp_path": "res://TCP/草药/0013.tcp",
		"desc": "采天地灵气而生的药物，又称三秀，可补充少量法力。【功效】恢复魔法40点",
	},
	"0014": {
		"name": "佛手", "tcp_path": "res://TCP/草药/0014.tcp",
		"desc": "非常常见的药物，因其外貌酷似佛的手指而得名，可以补充少量法力。【功效】恢复魔法20点",
	},
	"0015": {
		"name": "香叶", "tcp_path": "res://TCP/草药/0015.tcp",
		"desc": "散发香气的药草叶子可以补充少量的法力。【功效】恢复魔法30点",
	},
	"0016": {
		"name": "白玉骨头", "tcp_path": "res://TCP/草药/0016.tcp",
		"desc": "东方白民国药兽的骨头，具有很强的药性，可以补充少量法力。【功效】恢复魔法40点",
	},
	"0017": {
		"name": "旋复花", "tcp_path": "res://TCP/草药/0017.tcp",
		"desc": "产于东海海滨的药草，花开三色，暗合三才之数，可以补充少量法力。【功效】恢复魔法20点",
	},
	"0018": {
		"name": "曼陀罗花", "tcp_path": "res://TCP/草药/0018.tcp",
		"desc": "常用的药草之一，华陀当年配制麻沸散的主要原料。可以补充少量法力。【功效】恢复魔法50点",
	},
	"0019": {
		"name": "龙须草", "tcp_path": "res://TCP/草药/0019.tcp",
		"desc": "《古今注》曰：“世称黄帝炼丹于凿砚山，乃得仙，乘龙上天。群臣援龙须，须堕而生草，曰龙须”，可以补充少量法力。【功效】恢复魔法30点",
	},
	"0020": {
		"name": "鬼切草", "tcp_path": "res://TCP/草药/0020.tcp",
		"desc": "产自阴间的药草，由于长年在阴湿之地，故而有很强的药力，可以补充少量法力。【功效】恢复魔法40点",
	},
	"0021": {
		"name": "凤凰尾", "tcp_path": "res://TCP/草药/0021.tcp",
		"desc": "“彩凤双飞翼，心犀一点通。”这是一根灵鸟鸾凤尾部的羽毛，可补充大量气血。【功效】恢复气血250点",
	},
	"0022": {
		"name": "天不老", "tcp_path": "res://TCP/草药/0022.tcp",
		"desc": "南瞻部州常见的药草，花期非常之长，故而得名，可以补充些许气血。【功效】恢复气血100点",
	},
	"0023": {
		"name": "血色茶花", "tcp_path": "res://TCP/草药/0023.tcp",
		"desc": "出自南方的野生茶花，可以补充些许气血。【功效】恢复气血150点",
	},
	"0024": {
		"name": "紫石英", "tcp_path": "res://TCP/草药/0024.tcp",
		"desc": "紫色的千年石英石，具有药性，可以补充些许气血。【功效】恢复气血100点",
	},
	"0025": {
		"name": "硫磺草", "tcp_path": "res://TCP/草药/0025.tcp",
		"desc": "在硫磺地长大的圣草，可以补充大量气血。【功效】恢复气血250点",
	},
	"0026": {
		"name": "鹿茸", "tcp_path": "res://TCP/草药/0026.tcp",
		"desc": "南极仙翁仙鹿之茸，可以补充些许气血。【功效】恢复气血150点",
	},
	"0027": {
		"name": "熊胆", "tcp_path": "res://TCP/草药/0027.tcp",
		"desc": "千年熊罴的胆，是十分难得可遇不可求的宝物，可以补充大量气血。【功效】恢复气血200点",
	},
	"0028": {
		"name": "六道轮回", "tcp_path": "res://TCP/草药/0028.tcp",
		"desc": "天宫的异花，六种颜色可以清楚的反映出六道的轮回，故而得名，可以补充大量气血。【功效】恢复气血200点",
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
