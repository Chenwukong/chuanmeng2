# PetData.gd
# 宠物数据 — 捕捉的敌人变成宠物
class_name PetData
extends RefCounted

## 资质等级
enum Aptitude { 丁, 丙, 乙, 甲, 特 }
static func apt_name(a: Aptitude) -> String:
	match a:
		Aptitude.特: return "特"
		Aptitude.甲: return "甲"
		Aptitude.乙: return "乙"
		Aptitude.丙: return "丙"
		_:            return "丁"

## 资质成长倍率
const APT_GROWTH_MUL := {
	Aptitude.丁: 0.8,
	Aptitude.丙: 1.0,
	Aptitude.乙: 1.2,
	Aptitude.甲: 1.5,
	Aptitude.特: 2.0,
}

var pet_id: String = ""           # 唯一ID
var enemy_name: String = ""       # 来源敌人名
var aptitude: Aptitude = Aptitude.丁
var character_name: String = ""
var level: int = 1
var max_hp: int = 100
var max_mp: int = 50
var attack: int = 20
var magic_attack: int = 15
var defense: int = 10
var magic_defense: int = 8
var speed: int = 10
var skill_ids: Array = []
var book_skills: Array[String] = []  # 已学习的被动技能书

## 资质对应可学书数量
static func max_book_skills(a: Aptitude) -> int:
	match a:
		Aptitude.特: return 6
		Aptitude.甲: return 4
		Aptitude.乙: return 3
		Aptitude.丙: return 2
		_:           return 1  # 丁
var was_base_path: String = ""
var emoji_icon: String = "🐾"
var devour_count: int = 0

## 吞噬需求：各资质升下一级需要的同资质数量
const DEVOUR_REQUIRED := {
	Aptitude.丁: 5,
	Aptitude.丙: 5,
	Aptitude.乙: 5,
	Aptitude.甲: 5,
}

## 吞噬贡献值：按被吞噬者的资质等级给分，同资质=1，高一级=2...
static func devour_value(feeder_apt: Aptitude, food_apt: Aptitude) -> int:
	var diff = int(food_apt) - int(feeder_apt)
	return clampi(diff + 1, 1, 5)

## 从敌人数据创建宠物。rank: "boss"=甲 / "special"=特 / 其他=随机丁丙乙甲
func from_enemy(row: Dictionary, base_lv: int, rank: String = "") -> void:
	enemy_name = row.name
	character_name = row.name
	level = base_lv

	match rank:
		"boss":    aptitude = Aptitude.甲
		"special": aptitude = Aptitude.特
		_:         aptitude = _random_aptitude()

	var mul = APT_GROWTH_MUL[aptitude]

	max_hp        = int(row.hp * mul);   max_mp        = int(row.get("mp", 0) * mul)
	attack        = int(row.atk * mul)
	magic_attack  = int(row.get("matk", row.atk) * mul)
	defense       = int(row.def * mul)
	magic_defense = int(row.get("mdef", int(row.def * 0.8)) * mul)
	speed         = int(row.spd * mul)
	skill_ids     = row.skills.duplicate()
	was_base_path = row.get("was_base_path", "")

## 从敌人数据创建宠物（指定资质，不随机）
func from_enemy_with_apt(row: Dictionary, base_lv: int, forced_apt: Aptitude) -> void:
	enemy_name = row.name
	character_name = row.name
	level = base_lv
	aptitude = forced_apt
	var mul = APT_GROWTH_MUL[aptitude]
	max_hp        = int(row.hp * mul);   max_mp        = int(row.get("mp", 0) * mul)
	attack        = int(row.atk * mul)
	magic_attack  = int(row.get("matk", row.atk) * mul)
	defense       = int(row.def * mul)
	magic_defense = int(row.get("mdef", int(row.def * 0.8)) * mul)
	speed         = int(row.spd * mul)
	skill_ids     = row.skills.duplicate()
	was_base_path = row.get("was_base_path", "")

## 转换为 CharacterStats（战斗中召唤用）
func to_character_stats() -> CharacterStats:
	var s = CharacterStats.new()
	s.character_name  = character_name
	s.character_class = "宠物"
	s.emoji_icon      = emoji_icon
	s.max_hp          = max_hp
	s.max_mp          = max_mp
	s.attack          = attack
	s.magic_attack    = magic_attack
	s.defense         = defense
	s.magic_defense   = magic_defense
	s.speed           = speed
	s.level           = level
	s.role            = CharacterStats.Role.SUMMON
	s.skill_ids       = skill_ids.duplicate()
	s.book_skills     = book_skills.duplicate()
	s.was_base_path   = was_base_path
	s.was_direction   = 2  # 朝左上方向，与队友一致
	return s

## 随机资质（丁丙乙，各50/30/20%）
func _random_aptitude() -> Aptitude:
	var r = randi() % 100
	if r < 45:  return Aptitude.丁
	if r < 75:  return Aptitude.丙
	if r < 93:  return Aptitude.乙
	return Aptitude.甲
