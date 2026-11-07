extends RefCounted

## 剧情区域注册表：地图中的 StoryTriggerArea 自动登记，退出时移除。
## 无需手动添加配置或取 ID，直接在 Area 上填写 NPC、阶段和解锁检测。
## 自动标识来自地图场景路径与区域节点路径，各区域的完成记录独立存档。
## 下方条目仅兼容旧场景的手工 trigger_id，新区域无需添加。
const TRIGGERS = {
	"方寸山_机关人初见": {
		"target_npc": "方寸山_机关人",
		"check_unlock": true,
		"trigger_once": true,
		"enabled": true,
	},
}

static func create_database() -> Dictionary:
	return TRIGGERS.duplicate(true)
