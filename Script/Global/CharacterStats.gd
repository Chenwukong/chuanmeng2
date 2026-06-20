# CharacterStats.gd
# 角色属性数据资源 - 所有角色（玩家/敌人）共用此数据结构
class_name CharacterStats
extends Resource

## 基础信息
@export var character_name: String = "未命名"
@export var character_class: String = "剑修"
@export var emoji_icon: String = "🧙"

## 五行：金、木、水、火、土
enum Element { METAL, WOOD, WATER, FIRE, EARTH }
static func element_name(e: Element) -> String:
	match e:
		Element.METAL: return "金"
		Element.WOOD:  return "木"
		Element.WATER: return "水"
		Element.FIRE:  return "火"
		_:              return "土"
@export var element: Element = Element.METAL

## 定位：主、攻、辅、召、护
enum Role { MAIN, ATTACK, SUPPORT, SUMMON, GUARD }
static func role_name(r: Role) -> String:
	match r:
		Role.MAIN:    return "主"
		Role.ATTACK:  return "攻"
		Role.SUPPORT: return "辅"
		Role.SUMMON:  return "召"
		_:             return "护"
@export var role: Role = Role.ATTACK

## 战斗属性
@export var max_hp: int = 100
@export var max_mp: int = 80
@export var attack: int = 25       # 物理攻击
@export var magic_attack: int = 20 # 法术攻击
@export var defense: int = 10      # 物理防御
@export var magic_defense: int = 8 # 法术防御
@export var speed: int = 12        # 速度（决定行动顺序）
@export var crit_rate: float = 0.15  # 暴击率 0.0~1.0
@export var crit_mult: float = 1.5   # 暴击倍率

## 成长属性（玩家专用）
@export var level: int = 1
@export var exp: int = 0
@export var exp_to_next: int = 156

## 升级成长系数（每级提升量）
@export var hp_growth: int = 15
@export var mp_growth: int = 8
@export var atk_growth: int = 4
@export var def_growth: int = 2
@export var speed_growth: int = 1

## AI 策略（敌人专用）：balanced / aggressive / healer
@export var ai_strategy: String = "balanced"

## 是否远程攻击（true=原地发射投射物，false=走过去打）
@export var is_ranged: bool = false

## 符咒类型（主角羽灵神专用）
enum TalismanType { FIRE, SLEEP, ICE, HASTE }
@export var talisman_type: TalismanType = TalismanType.FIRE

## WAS 动画基础路径（目录路径，其下的文件按约定命名）
## 文件约定：idle.was, attack.was, hit.was, die.was
@export var was_base_path: String = ""

## WAS 动画方向索引（0-7，视素材而定）
@export var was_direction: int = 0

## 击败后获得的经验（怪物专用，0=自动计算）
@export var exp_reward: int = 0

## 攻击音效文件路径（各自角色不同）
@export var attack_sound_path: String = ""
@export var cast_sound_path: String = ""

## 捕捉资质（敌人专用，进场时随机。0=丁 1=丙 2=乙 3=甲 -1=未设定）
var capture_aptitude: int = -1

## 技能列表（技能 ID 数组）
@export var skill_ids: Array = []

## 宠物被动技能书
@export var book_skills: Array[String] = []

## 升级所需经验公式：100+50×lv+6×lv²，再乘阶段系数
## 阶段：1-9×1, 10-19×1.5, 20-29×2, 30-39×2.5, 40-49×3,
##       50-59×3.5, 60-69×4, 70-79×4.5, 80-89×5, 90-99×5.5
static func calc_exp_to_next(lv: int) -> int:
	var base = 100 + 50 * lv + 6 * lv * lv
	var mul: float
	if lv <= 9:     mul = 1.0
	elif lv <= 19:  mul = 1.5
	elif lv <= 29:  mul = 2.0
	elif lv <= 39:  mul = 2.5
	elif lv <= 49:  mul = 3.0
	elif lv <= 59:  mul = 3.5
	elif lv <= 69:  mul = 4.0
	elif lv <= 79:  mul = 4.5
	elif lv <= 89:  mul = 5.0
	else:           mul = 5.5
	return int(base * mul)

## 克隆一份运行时数据（避免修改原始资源）
func duplicate_for_battle() -> CharacterStats:
	var copy = CharacterStats.new()
	copy.character_name  = character_name
	copy.character_class = character_class
	copy.emoji_icon      = emoji_icon
	copy.max_hp          = max_hp
	copy.max_mp          = max_mp
	copy.attack          = attack
	copy.magic_attack    = magic_attack
	copy.defense         = defense
	copy.magic_defense   = magic_defense
	copy.speed           = speed
	copy.crit_rate       = crit_rate
	copy.crit_mult       = crit_mult
	copy.level           = level
	copy.exp             = exp
	copy.exp_to_next     = exp_to_next
	copy.hp_growth       = hp_growth
	copy.mp_growth       = mp_growth
	copy.atk_growth      = atk_growth
	copy.def_growth      = def_growth
	copy.speed_growth    = speed_growth
	copy.ai_strategy     = ai_strategy
	copy.was_base_path   = was_base_path
	copy.was_direction   = was_direction
	copy.exp_reward      = exp_reward
	copy.attack_sound_path = attack_sound_path
	copy.cast_sound_path   = cast_sound_path
	copy.element          = element
	copy.role             = role
	copy.skill_ids       = skill_ids.duplicate()
	copy.book_skills     = book_skills.duplicate()
	copy.is_ranged       = is_ranged
	copy.talisman_type   = talisman_type
	copy.book_skills     = book_skills.duplicate()
	return copy


## 存档 → 字典
func save_to_dict() -> Dictionary:
	return {
		"name":    character_name,
		"class":   character_class,
		"emoji":   emoji_icon,
		"hp":      max_hp,
		"mp":      max_mp,
		"atk":     attack,
		"matk":    magic_attack,
		"def":     defense,
		"mdef":    magic_defense,
		"spd":     speed,
		"crit":    crit_rate,
		"critmul": crit_mult,
		"lv":      level,
		"exp":     exp,
		"to_next": exp_to_next,
		"hp_g":    hp_growth,
		"mp_g":    mp_growth,
		"atk_g":   atk_growth,
		"def_g":   def_growth,
		"spd_g":   speed_growth,
		"elem":    element,
		"role":    role,
		"skills":  skill_ids,
		"books":   book_skills,
		"was":     was_base_path,
		"wasdir":  was_direction,
		"atk_snd": attack_sound_path,
		"cast_snd": cast_sound_path,
		"ai":      ai_strategy,
		"ranged":  is_ranged,
		"talisman": talisman_type,
	}


## 存档 ← 字典
func load_from_dict(d: Dictionary) -> void:
	character_name  = d.get("name", "未命名")
	character_class = d.get("class", "")
	emoji_icon      = d.get("emoji", "")
	max_hp          = d.get("hp", 100)
	max_mp          = d.get("mp", 50)
	attack          = d.get("atk", 10)
	magic_attack    = d.get("matk", 10)
	defense         = d.get("def", 5)
	magic_defense   = d.get("mdef", 5)
	speed           = d.get("spd", 10)
	crit_rate       = d.get("crit", 0.1)
	crit_mult       = d.get("critmul", 1.5)
	level           = d.get("lv", 1)
	exp             = d.get("exp", 0)
	exp_to_next     = d.get("to_next", CharacterStats.calc_exp_to_next(maxi(1, level)))
	hp_growth       = d.get("hp_g", 15)
	mp_growth       = d.get("mp_g", 8)
	atk_growth      = d.get("atk_g", 4)
	def_growth      = d.get("def_g", 2)
	speed_growth    = d.get("spd_g", 1)
	element         = d.get("elem", Element.METAL)
	role            = d.get("role", Role.ATTACK)
	is_ranged       = d.get("ranged", false)
	talisman_type   = d.get("talisman", TalismanType.FIRE)
	var arr: Array = d.get("skills", [])
	skill_ids.clear()
	skill_ids.assign(arr)
	arr = d.get("books", [])
	book_skills.clear()
	book_skills.assign(arr)
	was_base_path   = d.get("was", "")
	was_direction   = d.get("wasdir", 0)
	attack_sound_path = d.get("atk_snd", "")
	ai_strategy     = d.get("ai", "balanced")
