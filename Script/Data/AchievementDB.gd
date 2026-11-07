extends RefCounted
## id 发布后勿修改；metric 为累计统计名，rewards 可配置多项奖励。
## 奖励类型：talent_points 天赋点、gold 金币、item 道具（填写 item_id）。
const PIXELS_PER_STEP: float = 20.0
const ENTRIES: Array[Dictionary] = [
	{"id": "walk_50000", "name": "始于足下", "category": "游历",
	"description": "累计行走五万步。", "metric": "steps", "target": 50000,
	"rewards": [{"type": "talent_points", "amount": 1}]},
	{"id": "walk_500000", "name": "过万重山", "category": "游历",
	"description": "累计行走五十万步。", "metric": "steps", "target": 500000,
	"rewards": [{"type": "talent_points", "amount": 1}]},	
	{"id": "walk_1000000", "name": "行遍山海", "category": "游历",
	"description": "累计行走五十万步。", "metric": "steps", "target": 1000000,
	"rewards": [{"type": "talent_points", "amount": 1}]},		
	
	{"id": "gold_10000", "name": "腰缠万贯", "category": "财富",
	"description": "持有金币达到一万，再奖励你点钱",
	"metric": "gold_peak", "target": 10000,
	"rewards": [{"type": "gold", "amount": 10000}]},	
	{"id": "gold_500000", "name": "行走的", "category": "财富",
	"description": "持有金币达到五十万，再奖励你点钱",
	"metric": "gold_peak", "target": 500000,
	"rewards": [{"type": "gold", "amount": 50000}]},	
	{"id": "gold_1000000", "name": "资本家", "category": "财富",
	"description": "持有金币达到一百万，获得聚宝盆：放在背包即使全部金币收入增加30%。",
	"metric": "gold_peak", "target": 1000000,
	"rewards": [{"type": "item", "item_id": "treasure_basin", "amount": 1}]},
	
	
	
	
	
	{"id": "heroes_level_50", "name": "半步圆满", "category": "成长",
	"description": "每位可选角色首次达到{level}级，全部可选角色各获5个可分配属性点，未入队角色同时获得。每位角色仅计一次。",
	"metric": "characters_lv50", "required_level": 50, "target": 1, "repeat_per_character": true,
	"rewards": [{"type": "all_potential", "amount": 5}]},	
	
	{"id": "heroes_level_100", "name": "百炼成才", "category": "成长",
	"description": "每位可选角色首次达到{level}级，全部可选角色各获5个可分配属性点，未入队角色同时获得。每位角色仅计一次。",
	"metric": "characters_lv100", "required_level": 100, "target": 1, "repeat_per_character": true,
	"rewards": [{"type": "all_potential", "amount": 5}]},
	
	
	{"id": "weapon_upgrade_10", "name": "一刀流", "category": "神兵",
	"description": "将任意一件武器强化至满级（+10）。",
	"metric": "weapon_upgrade_peak", "target": 10,
	"rewards": [{"type": "talent_points", "amount": 1}]},
	{"id": "weapon2_upgrade_10", "name": "双刀流", "category": "神兵",
	"description": "将第二件武器强化至满级（+10）。",
	"metric": "weapon_upgrade_peak", "target": 10,
	"rewards": [{"type": "talent_points", "amount": 1}]},
	{"id": "weapon3_upgrade_10", "name": "三刀流", "category": "神兵",
	"description": "将第三件武器强化至满级（+10）。",
	"metric": "weapon_upgrade_peak", "target": 10,
	"rewards": [{"type": "talent_points", "amount": 1}]},
	{"id": "weapon4_upgrade_10", "name": "四刀流", "category": "神兵",
	"description": "将第四件武器强化至满级（+10）。",
	"metric": "weapon_upgrade_peak", "target": 10,
	"rewards": [{"type": "talent_points", "amount": 1}]},	
	{"id": "weapon5_upgrade_10", "name": "五刀流", "category": "神兵",
	"description": "将第五件武器强化至满级（+10）。",
	"metric": "weapon_upgrade_peak", "target": 10,
	"rewards": [{"type": "talent_points", "amount": 1}]},	
		
	
	{"id": "growth_hp_1000", "name": "气血充盈", "category": "成长",
	"description": "任意可选角色的体质永久属性达到{target}（不含装备及临时加成）。",
	"metric": "stat_max_hp_peak", "stat_field": "max_hp", "target": 1000,
	"rewards": [{"type": "talent_points", "amount": 1}]},
	{"id": "growth_atk_1000", "name": "力破千钧", "category": "成长",
	"description": "任意可选角色的力量永久属性达到{target}（不含装备及临时加成）。",
	"metric": "stat_attack_peak", "stat_field": "attack", "target": 1000,
	"rewards": [{"type": "talent_points", "amount": 1}]},
	{"id": "growth_magic_1000", "name": "法力无边", "category": "成长",
	"description": "任意可选角色的魔力永久属性达到{target}（不含装备及临时加成）。",
	"metric": "stat_magic_attack_peak", "stat_field": "magic_attack", "target": 1000,
	"rewards": [{"type": "talent_points", "amount": 1}]},
	{"id": "growth_def_1000", "name": "坚如磐石", "category": "成长",
	"description": "任意可选角色的耐力永久属性达到{target}（不含装备及临时加成）。",
	"metric": "stat_defense_peak", "stat_field": "defense", "target": 1000,
	"rewards": [{"type": "talent_points", "amount": 1}]},
	{"id": "growth_spd_1000", "name": "疾风迅雷", "category": "成长",
	"description": "任意可选角色的敏捷永久属性达到{target}（不含装备及临时加成）。",
	"metric": "stat_speed_peak", "stat_field": "speed", "target": 1000,
	"rewards": [{"type": "talent_points", "amount": 1}]},
]
const REWARD_NAMES := {"talent_points": "天赋点", "gold": "金币", "item": "道具", "all_potential": "全体可分配属性点"}

## 等级条件以 required_level 为准；旧配置兼容从 metric 后缀读取。
static func required_level(entry: Dictionary) -> int:
	if entry.has("required_level"): return maxi(1, int(entry.required_level))
	var metric: String = entry.get("metric", "")
	return maxi(1, int(metric.trim_prefix("characters_lv")))
