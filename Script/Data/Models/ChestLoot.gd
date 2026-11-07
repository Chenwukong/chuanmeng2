class_name ChestLoot
extends Resource
## 宝箱奖励条目：资源可在宝箱的 loot 列表内创建并编辑。
enum Kind { GOLD, ITEM, EQUIPMENT, MATERIAL, EXPERIENCE, TALENT_POINT }
@export var kind: Kind = Kind.ITEM
## 道具ID、命名装备ID或材料ID；金币/经验/天赋点无需填写。
@export var reward_id: String = ""
@export_range(1, 999999, 1) var amount: int = 1
## 经验接收者的成员ID。
@export var member_id: String = "youxiaoyun"
