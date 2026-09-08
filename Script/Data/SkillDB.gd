# SkillDB.gd — 技能定义、宠物技能书、技能学习表
class_name SkillDB
extends RefCounted

## 全部技能定义 — 按类型分组
const SKILL_DB := {

# ═══ 物理攻击 ═══
	"普通攻击": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 0, "dmg": 1.0, "hits": 1, "sound": "res://Audio/SE/男-枪.ogg",
		"desc": "对目标造成 100% 物理伤害",
	},
	"破防击": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 8, "dmg": 1.2, "buff": "def_broken", "bturn": 2, "bchance": 0.90, "bvalue": 0.5,
		"desc": "击破防御，造成 120% 伤害，90% 概率破防 2 回合",
	},
	"毒刺": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 10, "dmg": 1.2, "cd": 1,
		"buff": "poison", "bturn": 3, "bchance": 0.6,
		"sound":"res://Audio/SE/男-枪.ogg",
		"desc": "近战刺击 120% 伤害，60% 概率使目标中毒 3 回合（每回合扣 5% 最大气血，对首领无效）",
	},
	"御剑气": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 15, "dmg": 1.8, "cd": 1, "sound": "res://Audio/SE/男-枪.ogg",
		"desc": "凝聚剑气，对目标造成 180% 物理伤害",
	},
	"寂静剑法": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 30, "dmg": 1.3, "cd": 2, "sound": "res://Audio/SE/男-枪.ogg",
		"fullscreen": "寂静剑法",
		"desc": "寂静剑气覆盖全场，对所有敌人造成 130% 物理伤害",
	},
	"铁甲出击": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 10, "dmg": 0, "cd": 1,
		"desc": "指挥所有铁甲兽对目标发动一次联合攻击",
	},
	"力劈华山": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 25, "dmg": 2.0, "cd": 3,
		"ignore_def": 1.0, "tatk_dmg": 1.0,
		"desc": "力劈华山，无视防御并根据目标攻击力追加伤害（目标攻越高追加越低）",
	},
	"割喉之战": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "dmg": 2.5, "cd": 1,
		"ignore_def": 1.0, "sound": "res://Audio/SE/兵器-入肉.ogg",
		"desc": "瞬移到敌人背后发动致命一击，造成 250% 物理伤害（无视防御）",
	},
	"摄魂痛击": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 25, "dmg": 2.0, "cd": 1,
		"desc": "摄魂痛击，杀死敌人后本场战斗伤害永久提升 20%（可叠加）",
	},
	"双生": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 30, "dmg": 3.5, "cd": 5,
		"sound": "res://Audio/SE/兵器-入肉.ogg",
		"desc": "与姐妹协同攻击，造成 350% 物理伤害（需要骨精灵和影精灵同时在场）",
	},
	"瞬狱影杀阵": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 50, "dmg": 2.5, "cd": 1,
	
		"desc": "瞬狱影杀阵，全屏黑暗隐匿，对单体造成 250% 伤害后处决 5% 以下血量的敌人",
	},


# ═══ 法术攻击 ═══

	"妖术": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "dmg": 1.6, "magic": true,
		"desc": "施展妖术，造成 160% 法术伤害",
	},
	"灼焰术": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 18, "dmg": 1.3, "magic": true,
		"buff": "burn", "bturn": 2, "bchance": 0.75,
		"desc": "喷吐烈焰，造成 130% 法术伤害，75% 概率灼烧 2 回合",
	},
	"龙腾": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 25, "dmg": 2, "magic": true,
		"bturn": 1,
		"sound": "res://Audio/SE/法术18.ogg",
		"desc": "蛟龙出海，造成 200% 法术伤害",
	},
	"龙啸九天": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 350, "dmg": 6, "magic": true,
		"bturn": 3,
		"sound": "res://Audio/SE/法术18.ogg",
		"desc": "龙震九重天，造成 600% 法术伤害",
	},
	"龙怒": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 350, "dmg": 5, "magic": true,
		"extra":3,
		"bturn": 3,
		"sound": "res://Audio/SE/法术16.ogg",
		"desc": "龙之逆鳞，寸草不生，对 4 个目标造成 500% 法术伤害",
	},
	"水漫金山": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "dmg": 1.7, "magic": true,
		"fullscreen": "水漫金山",
		"bturn": 1,
		"sound":"res://Audio/SE/法术-气势强.ogg",
		"desc": "水漫金山，造成 170% 法术伤害",
	},
	"龙卷雨击": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 25, "dmg": 4, "cd": 2, "magic": true,
		"fullscreen": "龙卷雨击", "miss_chance": 0.40,
		"sound":"res://Audio/SE/法术13.ogg",
		"desc": "龙卷雨击，对所有敌人造成400%法术伤害，40%概率落空",
	},
		
	
	
	"雷霆诀": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "dmg": 2.0, "cd": 2, "magic": true, "sound": "res://Audio/SE/男-枪.ogg",
		"desc": "召来雷霆，对目标造成 200% 法术伤害",
	},
	"地烈火": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 30, "dmg": 2.5, "cd": 3, "magic": true,
		"sound": "res://Audio/SE/119-Fire03.ogg",
		"desc": "地底涌出烈火，对目标造成 250% 法术伤害",
	},
	"飞沙走石": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 10, "dmg": 2.2, "cd": 3, "magic": true, "extra": 4,
		"sound": "res://Audio/SE/火2.ogg",
		"desc": "飞沙走石，对4名目标造成 220% 法术伤害",
	},
	"阎王令": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 30, "dmg": 1.0, "cd": 3,
		"desc": "号令所有鬼魂攻击敌人，每个鬼魂额外造成 50% 伤害后鬼魂数量归零",
	},
	"鬼影护体": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SELF,
		"mp": 15, "cd": 4, "buff": "ghost_shield", "ghosts_per_charge": 3,
		"desc": "消耗全部鬼魂抵挡攻击，每 3 层鬼魂抵挡 1 次",
	},
	"鬼煞附体": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SELF,
		"mp": 20, "cd": 4, "buff": "ghost_boost", "boost_pct": 0.05, "bturn": 6,
		"desc": "消耗全部鬼魂，6 回合内每层鬼魂提升 5% 伤害",
	},
	"判官令": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "dmg": 0, "flat_dmg": 200, "cd": 2, "magic": true, "ignore_def": 1.0,
		"desc": "判官令出，固定造成 200 点伤害",
	},
	"鬼门大开": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SELF,
		"mp": 25, "cd": 5, "buff": "ghost_gate", "bturn": 4,
		"desc": "鬼门大开，4 回合内每次使用技能额外获得 1 层鬼魂",
	},
	"天焰葬礼": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 10, "dmg": 3, "cd": 5, "magic": true, "extra": 8,
		"sound": "res://Audio/SE/火 5.ogg",
		"desc": "飞落陨石将敌人埋葬，对8名目标造成 300% 法术伤害",
	},	
	"火之炼狱": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 30, "dmg": 1.3, "cd": 2, "sound": "res://Audio/SE/男-枪.ogg",
		"fullscreen": "火之炼狱", "buff": "burn", "bturn": 2, "bchance": 1.0,
		"desc": "火之炼狱覆盖全场，对所有敌人造成 130% 伤害，必定烧伤",
	},	
	"唧唧歪歪": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 25, "dmg": 1.3, "cd": 3, "magic": true, "extra": 4,
		"sound": "res://Audio/SE/法术19.ogg",
		"desc": "唧唧歪歪，对5名目标造成 130% 法术伤害",
	},
	"神罚": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 25, "dmg": 7.5, "cd": 0, "magic": true, "extra": 5,
		"sound": "res://Audio/SE/136-Light02.ogg",
		"desc": "神降天罚，对6名目标造成 750% 法术伤害",
	},	
	"圣瀑": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 25, "dmg": 12, "cd": 0, "magic": true,
		"sound": "res://Audio/SE/137-Light03.ogg",
		"desc": "圣光瀑布，对目标造成 1200% 法术伤害",
	},		
	"灵魂冲击": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 25, "dmg": 8.5, "cd": 0, "magic": false, "extra": 4,
		"sound": "res://Audio/SE/杀.ogg",
		"desc": "直戳灵魂，对5名目标造成 850% 物理伤害",
	},		
	"四面楚歌": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 25, "dmg": 12, "cd": 0, "magic": false,
		"sound": "res://Audio/SE/法术 爆炸.ogg",
		"desc": "从四面八方攻击，对目标造成 1200% 物理伤害",
	},			
	
	
	
	"毒瘴": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "dmg": 1.0, "magic": true, "cd": 2,
		"buff": "poison", "bturn": 4, "bchance": 0.3,
		"desc": "释放毒瘴侵蚀敌人，造成 100% 法术伤害并 100% 使目标中毒 4 回合",
	},
	"虚沉冰封": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 18, "dmg": 1.4, "cd": 3, "magic": true, "sound": "res://Audio/SE/法术13.ogg",
		"buff": "freeze", "bturn": 1, "bchance": 0.4,
		"desc": "冰封敌人，造成 140% 法术伤害，100% 概率冰冻 1 回合",
	},
	"失魂符": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 22, "dmg": 1.6, "cd": 3, "magic": true, "sound": "res://Audio/SE/法术5.ogg",
		"buff": "失魂", "bturn": 1, "bchance": 0.7,
		"desc": "以符咒摄取敌人魂魄，造成 160% 法术伤害，100% 封印 1 回合",
	},
	"墨染花": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "dmg": 2.5, "cd": 1, "extra": 1,
		"desc": "墨影染花，对 2 名敌人造成 250% 物理伤害",
		"sound":"res://Audio/SE/140-Darkness03.ogg"
	},
	"花雾": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "dmg": 1.5, "cd": 0, "magic": true, "extra": 1,
		"desc": "花粉成雾，对 2 名敌人造成 150% 法术伤害",
		"sound":"res://Audio/SE/法术12.ogg"
	},
	"雾非雾": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "dmg": 2, "cd": 0, "magic": true, "extra": 4,
		"desc": "花粉成大雾，对 5 名敌人造成 200% 法术伤害",
		"sound":"res://Audio/SE/法术12.ogg"
	},
# ═══ 多段攻击 ═══
	"横扫千军": {
		"type": SkillData.SkillType.MULTI_HIT, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 12, "dmg": 2, "hits": 3, 
		"desc": "快速攻击 3 次，每次造成 50% 物理伤害",
	},
	"破釜沉舟": {
		"type": SkillData.SkillType.MULTI_HIT, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 15, "dmg": 2.2, "hits": 2, "cd": 2,
		"desc": "破釜沉舟，连续攻击 2 次，共造成 220% 物理伤害",
	},
	"二连击": {
		"type": SkillData.SkillType.MULTI_HIT, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 15, "dmg": 2, "hits": 2, "cd": 1,
		"desc": "连续攻击 2 次，共造成 200% 物理伤害",
	},
		
	
	"暗影突袭": {
		"type": SkillData.SkillType.MULTI_HIT, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 2, "dmg": 3.0, "hits": 8, "cd": 1,
		"sound": "res://Audio/SE/打击2.ogg",
		"desc": "暗影突袭，高速环绕突袭 8 次，共造成 300% 物理伤害",
	},

# ═══ 治疗 ═══
	"回元术": {
		"type": SkillData.SkillType.HEAL, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 12, "heal": 0.25, "flat": 10, "cd": 2, "sound": "res://Audio/SE/heal 1.ogg",
		"hsize": "medium",
		"desc": "恢复自身 25% 最大气血 + 10 点",
	},
	"五气朝元": {
		"type": SkillData.SkillType.HEAL, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 12, "heal": 0.25, "flat": 10, "cd": 2, "sound": "res://Audio/SE/heal 1.ogg",
		"hsize": "medium",
		"extra": 3,
		"buff": "regen", "bturn": 3, "bvalue": 0.05, "bchance": 1.0,
		"desc": "恢复 4 名目标 25% 最大气血 + 10 点，并附加 3 回合持续回血（每回合 5%）",
	},
	"妖气回复": {
		"type": SkillData.SkillType.HEAL, "target": SkillData.TargetType.SELF,
		"mp": 15, "heal": 0.2,
		"desc": "吸取妖气，恢复 20% 最大气血",
	},
	"灯耀": {
		"type": SkillData.SkillType.HEAL, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 30, "heal": 0, "flat": 50, "shield": 0.3, "cd": 1,
		"sound": "res://Audio/SE/heal 1.ogg",
		"desc": "为队友恢复  50 气血并施加 20% 最大气血的护盾",
	},
	"喂蟠桃": {
		"type": SkillData.SkillType.HEAL, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 30, "heal": 0.1, "flat": 50, "cd": 1,
		#"hsize": "revive",
		"sound": "res://Audio/SE/heal 1.ogg",
		"desc": "喂一名队友吃蟠桃，恢复 10% + 50 气血",
	},
	"蟠桃宴": {
		"type": SkillData.SkillType.HEAL, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 100, "heal": 0.2, "flat": 200, "cd": 2,
		#"hsize": "revive",
		"extra": 3,
		"sound": "res://Audio/SE/heal 1.ogg",
		"desc": "喂三名队友吃蟠桃，恢复 20% + 100 气血",
	},
	"桃李满天下": {
		"type": SkillData.SkillType.HEAL, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 300, "heal": 0.2, "flat": 300, "cd": 3, "sound": "res://Audio/SE/heal 1.ogg",
		"hsize": "group", "extra": 8,
		"desc": "喂全体队友吃蟠桃，恢复 20% + 300 气血",
	},
	"李代桃僵": {
		"type": SkillData.SkillType.HEAL, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 200, "heal": 0.2, "flat": 0, "cd": 2,
		"hsize": "revive",
		"sound": "res://Audio/SE/HEAL 8.ogg",
		"desc": "桃中复生，复活一名队友并且恢复其 20% 血量",
	},
	"借尸还魂": {
		"type": SkillData.SkillType.HEAL, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 30, "heal": 0.2, "flat": 0, "cd": 5,
		"hsize": "revive",
		"sound": "res://Audio/SE/heal 1.ogg",
		"desc": "复活一名阵亡队友，恢复 20% 最大气血",
	},
	"推血过宫": {
		"type": SkillData.SkillType.HEAL, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 40, "heal": 0.05 , "flat": 100, "cd": 2, "extra": 3, "hsize": "group", 
		"sound": "res://Audio/SE/heal 1.ogg",
		"desc": "推血过宫，恢复自身及3名队友 5% + 100 点气血",
	},
	"舍生取义": {
		"type": SkillData.SkillType.HEAL, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 200, "heal": 1.0, "cd": 4,
		"sac_hp": 0.5, "sac_def": 0.5,
		"hsize": "large",
		"desc": "牺牲 50% 最大气血，完全恢复一名队友的气血（气血不足 50% 不可用）",
	},
	"我佛慈悲": {
		"type": SkillData.SkillType.HEAL, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 100, "heal": 0.3, "cd": 5,
		"hsize": "revive",
		"sound": "res://Audio/SE/HEAL 8.ogg",
		"desc": "我佛慈悲，复活一名队友并恢复 30% 最大气血",
	},

# ═══ 增益 Buff ═══
	"护体真气": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 100, "cd": 8, "buff": "def_up", "bturn": 2, "bvalue": 2.0, "extra": 3,
		"desc": "运转真气护体，全体队友 2 回合内物理防御翻倍",
	},
	"一苇渡江": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 15, "cd": 2, "buff": "haste", "bturn": 5, "bvalue": 1.15, "extra": 4,
		"desc": "选定目标加速并随机增益 3 名未加速队友，5 回合速度提升 15%",
	},
	"神行步": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 15, "cd": 2, "buff": "haste", "bturn": 3, "bvalue": 1.25, "extra": 3,
		"desc": "选定目标加速并随机增益 3 名未加速队友，3 回合速度提升 25%",
	},
	"天神护体": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 120, "cd": 3, "buff": "def_up", "buff2": "mdef_up", "bturn": 5, "bvalue": 1.2, "extra": 7,
		"sound":"res://Audio/SE/法术16.ogg",
		"desc": "对 全体目标生效，5 回合双抗提升 20%",
	},
	
	"神明之躯": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SELF,
		"mp": 50, "cd": 5, "buff": "hp_up", "bturn": 8, "bvalue": 1.3, "extra":0,
		"sound":"res://Audio/SE/法术16.ogg",
		"desc": "施法者 8 回合气血上限提升 30%",
	},	
	
	
	"达摩护体": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 20, "cd": 3, "buff": "hp_up", "bturn": 8, "bvalue": 1.15, "extra":4,
		"sound":"res://Audio/SE/法术16.ogg",
		"desc": "选定目标并随机护体 3 名队友，8 回合气血上限提升 15%",
	},
	"金刚护体": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 20, "cd": 3, "buff": "def_up", "buff2": "mdef_up", "bturn": 5, "bvalue": 1.15, "extra": 4,
		"sound":"res://Audio/SE/法术16.ogg",
		"desc": "选定目标并随机护体 3 名队友，5 回合双抗提升 15%",
	},
	"金刚护法": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 20, "cd": 3, "buff": "atk_up", "buff2": "matk_up", "bturn": 5, "bvalue": 1.15, "extra": 4,
		"sound":"res://Audio/SE/法术16.ogg",
		"desc": "选定目标并随机护法 3 名队友，5 回合双攻提升 15%",
	},
	"金刚护魂": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 20, "cd": 3, "buff": "mdef_up", "bturn": 5, "bvalue": 1.2, "extra": 3,
		"desc": "选定目标并随机护魂 3 名队友，5 回合魔防提升 20%",
	},
	"火神咒": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SELF,
		"mp": 20, "cd": 3, "buff": "matk_up", "bturn": 5, "bvalue": 1.2,
		"sound": "res://Audio/SE/法术19.ogg",
		"desc": "运转火神之力，4 回合内法术伤害提升 20%",
	},
	"嘲讽": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SELF,
		"mp": 10, "cd": 2,
		"desc": "嘲讽全场敌人，强制攻击自己 2 回合",
	},
	"战神诀": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SELF,
		"mp": 15, "cd": 3,
		"buff": "atk_up", "bturn": 4, "bvalue": 1.2,
		"sound":"res://Audio/SE/法术16.ogg",
		"desc": "战神附体，5 回合内物理伤害提升 20%",
	},
	"龙附": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SELF,
		"mp": 100, "cd": 3,
		"buff": "matk_up", "bturn": 4, "bvalue": 1.25,
		"sound":"res://Audio/SE/法术16.ogg",
		"desc": "神龙附体，5 回合内法术伤害提升 25%",
	},
	"影化": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SELF,
		"mp": 20, "cd": 4,
		"buff": "lifesteal_up", "bturn": 3, "bvalue": 0.3,
		"sound": "res://Audio/SE/139-Darkness02.ogg",
		"desc": "影化，3 回合内吸血提高 30%，速度提升",
	},
	"金甲护体": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SELF,
		"mp": 15, "cd": 5,
		"buff": "def_up", "bturn": 5, "bvalue": 1.3,
		"sound":"res://Audio/SE/法术16.ogg",
		"desc": "黄金盔甲护体，5 回合内物理防御提升 30%",
	},
	"不灭金身": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SELF,
		"mp": 120, "cd": 8,  "bvalue": 1.2,
		"self_buff": "invincible", "self_bturn": 3,
		"sound":"res://Audio/SE/法术16.ogg",
		"desc": "自身 3 回合无敌（免疫所有伤害）",
	},
# ═══ 减益 Debuff ═══
	"蛊毒咒": {
		"type": SkillData.SkillType.DEBUFF, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 16, "buff": "poison", "bturn": 3, "bchance": 0.85,
		"desc": "下蛊毒咒，85% 概率使目标中毒 3 回合",
	},
	"沉戈断戟": {
		"type": SkillData.SkillType.DEBUFF, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 16, "buff": "atk_down", "bturn": 3, "bchance": 1, "bvalue": 0.1,
		"sound":"res://Audio/SE/法术16.ogg",
		"desc": "以战戟沉戈之势震慑敌人，令其物理攻击降低 10%，持续 3 回合",
	},	
	"老化": {
		"type": SkillData.SkillType.DEBUFF, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 250, "buff": "atk_down", "bturn": 3, "bchance": 1,"buff2": "haste", "bvalue": 0.15,
		"sound":"res://Audio/SE/法术16.ogg",
		"desc": "使敌人老化，3 回合内双攻和速度降低 15%",
	},
	"破甲术": {
		"type": SkillData.SkillType.DEBUFF, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "buff": "def_broken", "bturn": 5, "bchance": 1, "bvalue": 0.2,
		"sound":"res://Audio/SE/法术16.ogg",
		"desc": "击破敌人护甲，5 回合内物理防御降低 20%",
	},
	"识破弱点": {
		"type": SkillData.SkillType.DEBUFF, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "buff": "def_broken", "buff2": "mdef_broken", "bturn": 5, "bchance": 1, "bvalue": 0.2,
		"sound":"res://Audio/SE/法术16.ogg",
		"desc": "攻击敌人弱点，5 回合内双抗降低 20%",
	},
	"死亡宣告": {
		"type": SkillData.SkillType.DEBUFF, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "buff": "marked", "bturn": 5, "bchance": 1,
		"desc": "标记一名敌人，下次对其造成伤害时双倍并消耗标记",
	},
	"似玉生香": {
		"type": SkillData.SkillType.DEBUFF, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 18, "buff": "silence", "bturn": 1, "bchance": 1,
		"sound":"res://Audio/SE/法术16.ogg",
		"desc": "封印敌人，下回合无法施法（对首领无效）",
	},
	"破法术": {
		"type": SkillData.SkillType.DEBUFF, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 12, "buff": "mdef_broken", "bturn": 5, "bchance": 1, "bvalue": 0.5,
		"sound":"res://Audio/SE/法术16.ogg",
		"desc": "降低敌方法术防御，5 回合内魔防降低 50%",
	},
	"伤筋断骨": {
		"type": SkillData.SkillType.PHYSICAL, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 15, "dmg": 1.6, "cd": 2,
		"buff": "atk_down", "buff2": "def_broken", "bturn": 3, "bchance": 1, "bvalue": 0.2,
		"sound":"res://Audio/SE/男-枪.ogg",
		"desc": "单体伤害 160%，附加疲倦：3 回合攻击和防御降低 20%",
	},
	"灭魂咒": {
		"type": SkillData.SkillType.MAGIC, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 20, "dmg": 1.4, "cd": 2, "extra": 2, "magic": true,
		"sound":"res://Audio/SE/法术19.ogg",
		"desc": "对 3 名敌人造成 140% 法术伤害",
	},	
	# 刀解其足（英女侠专属）
	# 数值调整说明：extra=额外目标数（+1 即共 2 名）、bturn=持续回合、bvalue=减速后速度倍率（0.6=降 40%，越小越慢）、bchance=基础命中率、mp/cd=消耗与冷却
	"刀解其足": {
		"type": SkillData.SkillType.DEBUFF, "target": SkillData.TargetType.SINGLE_ENEMY,
		"mp": 15, "cd": 3, "extra": 1,
		"buff": "slow", "bturn": 3, "bchance": 1.0, "bvalue": 0.6,
		"sound": "res://Audio/SE/兵器-入肉.ogg",
		"desc": "刀光斩足，令 2 名敌人移动速度降低 40%，持续 3 回合",
	},

# ═══ 召唤技能 ═══
	"召唤铁甲兽": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SELF,
		"mp": 30, "cd": 3,
		"desc": "打开铁甲界面，召唤机关兽或机关鸟助战",
	},

# ═══ 变身技能 ═══
	"千变万化": {
		"type": SkillData.SkillType.BUFF, "target": SkillData.TargetType.SINGLE_ALLY,
		"mp": 30, "cd": 5,
		"desc": "千面千相，变化为一名队友的外貌和技能（不含主角）",
	},
}

# ── 宠物技能书库（被动技能）──
const BOOK_SKILL_DB := {
	# ── 速度 ──
	"高级敏捷": {"name":"高级敏捷","icon":"⚡","type":"haste","desc":"速度永久提升 30%","value":1.3},
	"敏捷":     {"name":"敏捷","icon":"⚡","type":"haste","desc":"速度永久提升 15%","value":1.15},
	# ── 气血 ──
	"高级血量": {"name":"高级血量","icon":"❤️","type":"hp_up","desc":"气血上限永久提升 25%","value":1.25},
	"血量":     {"name":"血量","icon":"❤️","type":"hp_up","desc":"气血上限永久提升 12%","value":1.12},
	# ── 物防 ──
	"高级物防": {"name":"高级物防","icon":"🛡️","type":"def_up","desc":"物防永久提升 25%","value":1.25},
	"物防":     {"name":"物防","icon":"🛡️","type":"def_up","desc":"物防永久提升 12%","value":1.12},
	# ── 魔防 ──
	"高级魔防": {"name":"高级魔防","icon":"🔮","type":"mdef_up","desc":"魔防永久提升 25%","value":1.25},
	"魔防":     {"name":"魔防","icon":"🔮","type":"mdef_up","desc":"魔防永久提升 12%","value":1.12},
	# ── 攻击 ──
	"高级强力": {"name":"高级强力","icon":"💪","type":"atk_up","desc":"攻击永久提升 25%","value":1.25},
	"强力":     {"name":"强力","icon":"💪","type":"atk_up","desc":"攻击永久提升 12%","value":1.12},
	# ── 法伤 ──
	"高级魔之心": {"name":"高级魔之心","icon":"💜","type":"matk_up","desc":"法术伤害永久提升 25%","value":1.25},
	"魔之心":     {"name":"魔之心","icon":"💜","type":"matk_up","desc":"法术伤害永久提升 12%","value":1.12},
	# ── 暴击 ──
	"高级必杀": {"name":"高级必杀","icon":"💥","type":"crit_up","desc":"运气永久提升 20","value":0.20},
	"必杀":     {"name":"必杀","icon":"💥","type":"crit_up","desc":"运气永久提升 10","value":0.10},
	# ── 法术暴击 ──
	"高级法术暴击": {"name":"高级法术暴击","icon":"🌟","type":"mcrit_up","desc":"运气永久提升 20，且法术技能可以暴击","value":0.20},
	"法术暴击":     {"name":"法术暴击","icon":"🌟","type":"mcrit_up","desc":"运气永久提升 10，且法术技能可以暴击","value":0.10},
	# ── 恢复 ──
	"高级生命恢复": {"name":"高级生命恢复","icon":"💚","type":"regen","desc":"每回合自动恢复 10% 最大气血","value":0.10},
	"生命恢复":     {"name":"生命恢复","icon":"💚","type":"regen","desc":"每回合自动恢复 5% 最大气血","value":0.05},
	# ── 连击 ──
	"高级连击":     {"name":"高级连击","icon":"👊","type":"double_attack","desc":"普通攻击有 45% 概率连击两次","value":0.45},
	"高级魔法连击": {"name":"高级魔法连击","icon":"✨","type":"double_magic","desc":"法术技能有 35% 概率施放两次","value":0.35},
	# ── 吸血 ──
	"高级吸血": {"name":"高级吸血","icon":"🩸","type":"lifesteal","desc":"物理攻击时吸收 25% 伤害为气血","value":0.25},
	"吸血":     {"name":"吸血","icon":"🩸","type":"lifesteal","desc":"物理攻击时吸收 15% 伤害为气血","value":0.15},
	# ── 反震 ──
	"高级反震": {"name":"高级反震","icon":"↩️","type":"reflect","desc":"受到物理攻击时反弹 40% 伤害","value":0.40},
	"反震":     {"name":"反震","icon":"↩️","type":"reflect","desc":"受到物理攻击时反弹 25% 伤害","value":0.25},
	# ── 神佑复生 ──
	"高级神佑复生": {"name":"高级神佑复生","icon":"🕊️","type":"revive","desc":"阵亡时有 30% 概率满血复活","value":0.30},
	"神佑复生":     {"name":"神佑复生","icon":"🕊️","type":"revive","desc":"阵亡时有 15% 概率半血复活","value":0.15},
	# ── 毒 ──
	"高级毒": {"name":"高级毒","icon":"☠️","type":"venom","desc":"物理攻击有 25% 概率使目标中毒3回合","value":0.25},
	"毒":     {"name":"毒","icon":"☠️","type":"venom","desc":"物理攻击有 15% 概率使目标中毒3回合","value":0.15},
	# ── 慧根 ──
	"高级慧根": {"name":"高级慧根","icon":"🧠","type":"mp_save","desc":"技能灵力消耗减少 40%","value":0.40},
	"慧根":     {"name":"慧根","icon":"🧠","type":"mp_save","desc":"技能灵力消耗减少 20%","value":0.20},
	# ── 神迹 ──
	"高级神迹": {"name":"高级神迹","icon":"✨","type":"immune","desc":"免疫所有异常状态","value":1.0},
	"神迹":     {"name":"神迹","icon":"✨","type":"immune","desc":"50% 概率抵抗异常状态","value":0.50},
	# ── 迟钝 ──
	"高级迟钝": {"name":"高级迟钝","icon":"🐢","type":"slow_tank","desc":"速度降低 30%，气血上限提升 30%","value":{"speed":0.70,"hp":1.45}},
	"迟钝":     {"name":"迟钝","icon":"🐢","type":"slow_tank","desc":"速度降低 20%，气血上限提升 15%","value":{"speed":0.80,"hp":1.15}},
	# ── 法波动 ──
	"高级法波动": {"name":"高级法波动","icon":"🌊","type":"magic_fluctuate","desc":"法术伤害在 70%~130% 间浮动","value":{"low":0.70,"high":1.30}},
	"法波动":     {"name":"法波动","icon":"🌊","type":"magic_fluctuate","desc":"法术伤害在 85%~115% 间浮动","value":{"low":0.85,"high":1.15}},
	# ── 夜战 ──
	"高级夜战": {"name":"高级夜战","icon":"🌙","type":"night","desc":"夜间伤害+20%、速度+15%","value":{"dmg":1.20,"spd":1.15}},
	"夜战":     {"name":"夜战","icon":"🌙","type":"night","desc":"夜间伤害+10%、速度+8%","value":{"dmg":1.10,"spd":1.08}},
	# ── 来财 ──
	"高级来财": {"name":"高级来财","icon":"💰","type":"gold_boost","desc":"战斗金币收益提升 100%","value":2.0},
	"来财":     {"name":"来财","icon":"💰","type":"gold_boost","desc":"战斗金币收益提升 50%","value":1.5},
}

## 技能学习表：{ member_id: [{ level: N, skills: ["id1","id2"] }] }
const SKILL_LEARN_DB := {
	"youxiaoyun": [
		{ "level": 1,  "skills": ["寂静剑法","一苇渡江","金刚护体","起死回生",] },
		{ "level": 3,  "skills": ["横扫千军"] },
		{ "level": 5,  "skills": ["达摩护体"] },
		{ "level": 7,  "skills": ["如沐春风"] },
		{ "level": 9,  "skills": ["虚沉冰封"] },
		{ "level": 11, "skills": ["失魂符"] },
		{ "level": 13, "skills": ["毒瘴"] },
		{ "level": 15, "skills": ["神行步"] },
	],
	"duoshiyi": [
		{ "level": 1,  "skills": ["召唤铁甲兽","铁甲出击","金刚护法","金刚护魂"] },
		{ "level": 4,  "skills": ["寂静剑法"] },
		{ "level": 7,  "skills": ["铁甲修复"] },
		{ "level": 10, "skills": ["铁甲狂暴"] },
		{ "level": 13, "skills": ["灵甲护体"] },
		{ "level": 16, "skills": ["天机术"] },
	],
	"qianmian": [
		{ "level": 1,  "skills": ["妖术","蛊毒咒","千变万化"] },
		{ "level": 4,  "skills": ["妖气回复"] },
		{ "level": 7,  "skills": ["冰封诀"] },
		{ "level": 10, "skills": ["毒瘴"] },
		{ "level": 13, "skills": ["幻影步"] },
		{ "level": 16, "skills": ["千幻术"] },
	],
	"dingdong": [
		{ "level": 1,  "skills": ["召唤铁甲兽"] },
		{ "level": 4,  "skills": ["如来神掌"] },
		{ "level": 7,  "skills": ["大悲咒"] },
		{ "level": 10, "skills": ["金刚护法"] },
		{ "level": 13, "skills": ["金刚护魂"] },
		{ "level": 16, "skills": ["不动明王"] },
	],
	"jumowang": [
		{ "level": 1,  "skills": ["地烈火" ] },
		{ "level": 5,  "skills": ["火神咒"] },
		{ "level": 10,  "skills": ["飞沙走石"] },
		{ "level": 25, "skills": ["沉戈断戟"] },
		{ "level": 40, "skills": ["天焰葬礼"] },
		{ "level": 65, "skills": ["火之炼狱"] },
	],
	"taoyaoyao": [
		{ "level": 1,  "skills": ["花雾"] },
		{ "level": 5,  "skills": ["喂蟠桃"] },
		{ "level": 15,  "skills": ["灯耀"] },
		{ "level": 25, "skills": ["蟠桃宴"] },
		{ "level": 35, "skills": ["李代桃僵"] },
		{ "level": 45,  "skills": ["雾非雾",] },
		{ "level": 65, "skills": ["桃李满天下"] },
		
	],
	"dajiangjun": [
		{ "level": 1,  "skills": ["战神诀","破釜沉舟","横扫千军","破甲术","力劈华山",] },
		{ "level": 5, "skills": ["破釜沉舟"] },
		{ "level": 25, "skills": ["横扫千军"] },
		{ "level": 40, "skills": ["破甲术",] },
		{ "level": 50, "skills": ["金甲护体",] },
		{ "level": 65, "skills": ["力劈华山",] },
	],
	"yingjingling": [
		{ "level": 1,  "skills": ["割喉之战","墨染花","影化","暗影突袭","死亡宣告","双生","瞬狱影杀阵"] },
		{ "level": 5, "skills": ["破釜沉舟"] },
		{ "level": 10, "skills": ["影化"] },
		{ "level": 25, "skills": ["横扫千军"] },
		{ "level": 40, "skills": ["破甲术",] },
		{ "level": 50, "skills": ["金甲护体",] },
		{ "level": 65, "skills": ["力劈华山",] },
	],	
	
	"xiaoyaosheng": [
		{ "level": 1,  "skills": ["推血过宫",] },
		{ "level": 5,  "skills": ["唧唧歪歪",] },
		{ "level": 15,  "skills": ["金刚护体"] },
		{ "level": 20, "skills": ["金刚护法",] },
		{ "level": 30, "skills": ["我佛慈悲"] },
		{ "level": 40, "skills": ["一苇渡江"] },
		{ "level": 60, "skills": ["舍生取义"] },
	],

	"gujingling": [
		{ "level": 1,  "skills": ["摄魂痛击","阎王令","鬼影护体","鬼煞附体","判官令","鬼门大开"] },
		{ "level": 5,  "skills": ["鬼煞附体"] },
		{ "level": 15,  "skills": ["鬼影护体"] },
		{ "level": 20, "skills": ["判官令","双生"] },
		{ "level": 30, "skills": ["阎王令"] },
		{ "level": 40, "skills": ["双生"] },
		{ "level": 60, "skills": ["鬼门大开"] },		
	],

	"aobai": [
		{ "level": 1,  "skills": ["龙腾","龙卷雨击","龙附","龙啸九天","水漫金山","龙怒"] },
		{ "level": 5,  "skills": ["龙附"] },
		{ "level": 15,  "skills": ["龙卷雨击"] },
		{ "level": 30, "skills": ["水漫金山"] },
		{ "level": 45, "skills": ["龙啸九天"] },
		{ "level": 60, "skills": ["龙怒"] },
	],
	"lingti": [
		{ "level": 1,  "skills": ["唧唧歪歪","神罚","圣瀑","四面楚歌","灵魂冲击"] },
		{ "level": 75, "skills": ["神罚","圣瀑","四面楚歌","灵魂冲击"] },
	],
	"shentianbing": [
		{ "level": 1,  "skills": ["五气朝元","护体真气","不灭金身","二连击","天神护体","神明之躯"] },
		{ "level": 5,  "skills": ["五气朝元"] },
		{ "level": 15,  "skills": ["天神护体"] },
		{ "level": 30, "skills": ["护体真气"] },
		{ "level": 40, "skills": ["嘲讽"] },
		{ "level": 45, "skills": ["神明之躯"] },
		{ "level": 60, "skills": ["不灭金身"] },
	],	
	"yingnvxia": [
		{ "level": 1,  "skills": ["刀解其足","识破弱点","神行步","老化","二连击","毒刺"] },
		{ "level": 5,  "skills": ["刀解其足"] },
		{ "level": 15,  "skills": ["识破弱点"] },
		{ "level": 30, "skills": ["毒刺"] },
		{ "level": 45, "skills": ["神行步"] },
		{ "level": 60, "skills": ["老化"] },
	],	
		
	
}
