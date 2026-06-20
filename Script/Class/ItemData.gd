# ItemData.gd
# 道具数据资源
class_name ItemData
extends Resource

enum ItemType {
	HP_POTION,   # 回气血
	MP_POTION,   # 回灵力
	BUFF_ITEM,   # 施加增益
	REVIVE,      # 复活
	SPECIAL,     # 特殊效果
	SKILL_BOOK,  # 宠物技能书
}

enum ItemCategory {
	CONSUMABLE,    # 消耗品（战斗用药剂等）
	QUEST,         # 任务道具（悬赏需求）
	MATERIAL,      # 材料（合成用）
	MISC,          # 特殊 / 杂项
}

@export var item_id: String = ""
@export var item_name: String = "未命名道具"
@export var description: String = ""
@export var icon_emoji: String = "📦"
@export var item_type: ItemType = ItemType.HP_POTION
@export var item_category: ItemCategory = ItemCategory.CONSUMABLE
@export var max_stack: int = 10  # 最大叠加数量

## 效果参数
@export var hp_restore: int = 0           # 回复固定 HP
@export var hp_restore_percent: float = 0.0 # 回复 HP 百分比
@export var mp_restore: int = 0
@export var mp_restore_percent: float = 0.0
@export var buff_id: String = ""          # 施加的 Buff ID
@export var buff_turns: int = 3
@export var revive_hp_percent: float = 0.5 # 复活时恢复 HP 百分比
@export var book_skill_id: String = ""     # 技能书对应的 book skill ID
