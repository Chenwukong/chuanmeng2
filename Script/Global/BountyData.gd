# BountyData.gd
# 赏金任务数据系统 — 定义甲乙丙丁四栏任务池
class_name BountyData
extends RefCounted

## 任务等级枚举
enum Rank { DING, BING, YI, JIA }

## 全任务池：按等级分组
static var TASK_POOL: Dictionary = {
	Rank.DING: [
		{ id = "bounty_ding_1", name = "除狐患",   desc = "最近妖狐在村落附近出没，带回狐尾以证功绩。", item_id = "quest_fox_tail",    count = 2, gold = 200,  repeatable = true },
		{ id = "bounty_ding_2", name = "驱山魈",   desc = "山魈骚扰路人，需要它的獠牙做护符。",        item_id = "quest_mandrill_fang", count = 1, gold = 250,  repeatable = true },
		{ id = "bounty_ding_3", name = "收集蛛丝", desc = "幽蛛之丝是上好的纺织材料，大量收购。",        item_id = "quest_spider_silk", count = 3, gold = 300,  repeatable = true },
		{ id = "bounty_ding_4", name = "清剿游魂", desc = "野外幽魂渐多，带回魂核以削弱其势力。",        item_id = "quest_ghost_core",  count = 1, gold = 350,  repeatable = false },
	],
	Rank.BING: [
		{ id = "bounty_bing_1", name = "猎火鸦",   desc = "火鸦群在火山口筑巢，收集其赤羽。",              item_id = "quest_fire_feather", count = 3, gold = 500,  repeatable = true },
		{ id = "bounty_bing_2", name = "破石傀",   desc = "石傀挡了商路，取核心石来换赏金。",            item_id = "quest_golem_stone", count = 1, gold = 600,  repeatable = false },
		{ id = "bounty_bing_3", name = "疾风之牙", desc = "风狼之牙是打造武器的好材料。",                item_id = "quest_wind_fang",   count = 2, gold = 700,  repeatable = true },
		{ id = "bounty_bing_4", name = "寒魄之晶", desc = "寒魄冰晶可制灵药，急需一批。",              item_id = "quest_ice_crystal", count = 2, gold = 800,  repeatable = true },
	],
	Rank.YI: [
		{ id = "bounty_yi_1",  name = "妖狐之祸", desc = "大量妖狐聚集，需要 5 条狐尾交差。",             item_id = "quest_fox_tail",    count = 5, gold = 1200, repeatable = true },
		{ id = "bounty_yi_2",  name = "蛛网迷阵", desc = "幽蛛在密林中布下巨网，取丝破阵。",              item_id = "quest_spider_silk", count = 5, gold = 1500, repeatable = false },
		{ id = "bounty_yi_3",  name = "烈火燎原", desc = "火鸦王出现，需要 5 根赤羽。",                  item_id = "quest_fire_feather",count = 5, gold = 1800, repeatable = false },
	],
	Rank.JIA: [
		{ id = "bounty_jia_1", name = "四凶之征", desc = "集齐妖狐之尾、山魈之牙、幽魂之核、火鸦之羽各 3 份。", item_id = "quest_fox_tail",     count = 3, gold = 3000, repeatable = false },
		{ id = "bounty_jia_2", name = "元素之心", desc = "石傀之心与寒魄冰晶各 3 份，研究元素之力。",           item_id = "quest_golem_stone",  count = 3, gold = 3500, repeatable = false },
		{ id = "bounty_jia_3", name = "终极狩猎", desc = "每种凶兽之证各 2 份（尾/牙/核/羽/丝/牙/晶）。",     item_id = "quest_fox_tail",     count = 2, gold = 5000, repeatable = false },
	],
}
