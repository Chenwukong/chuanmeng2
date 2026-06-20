# SkillData.gd
# 技能数据资源 - 在 Godot 编辑器中创建 .tres 文件配置每个技能
class_name SkillData
extends Resource

## 技能 ID（唯一标识，如 "thunder_strike"）
@export var skill_id: String = ""
@export var skill_name: String = "未命名技能"
@export var description: String = ""
@export var icon_emoji: String = "✨"

## 技能类型
enum SkillType {
	PHYSICAL,    # 物理攻击
	MAGIC,       # 法术攻击
	HEAL,        # 治疗
	BUFF,        # 增益（施加给己方）
	DEBUFF,      # 减益（施加给敌方）
	MULTI_HIT,   # 多段攻击
	AOE,         # 群体攻击（多敌战斗扩展用）
}
@export var skill_type: SkillType = SkillType.PHYSICAL

## 目标
enum TargetType { SINGLE_ENEMY, SINGLE_ALLY, SELF, ALL_ENEMIES, ALL_ALLIES }
@export var target_type: TargetType = TargetType.SINGLE_ENEMY

## 消耗
@export var mp_cost: int = 0
@export var hp_cost: int = 0       # 某些技能消耗 HP（如血咒）
@export var cooldown_turns: int = 0 # 冷却回合数（0=无冷却）

## 伤害参数
@export var damage_multiplier: float = 1.0    # 攻击力倍数
@export var flat_damage: int = 0              # 固定伤害（不受攻击力影响）
@export var hit_count: int = 1                # 多段攻击次数（MULTI_HIT 用）
@export var ignore_defense_ratio: float = 0.0 # 无视防御比例 0.0~1.0
@export var is_magic_damage: bool = false      # true=用法攻计算，false=物攻

## 治疗参数
@export var heal_multiplier: float = 0.0  # 基于最大 HP 的治疗比例
@export var flat_heal: int = 0            # 固定治疗量

## 效果（施加 Buff/Debuff）
@export var apply_buff_id: String = ""      # 施加的 Buff ID（空=不施加）
@export var apply_buff_turns: int = 3
@export var apply_buff_chance: float = 1.0  # 成功率 0.0~1.0
@export var apply_buff_value: float = 0.0   # Buff 携带的数值（如百分比）

## 动画标签（对应场景中的 AnimationPlayer 动画名）
@export var animation_name: String = "attack"
@export var vfx_scene_path: String = ""  # 粒子特效场景路径（可选）
@export var sound_path: String = ""       # 技能释放音效路径
