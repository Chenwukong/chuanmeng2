extends RefCounted
## 通用效果资源与剧情试播分开配置。移除临时调用不影响通用演出。
const EFFECTS = {"金符蓄力": preload("res://Resources/StoryEffects/GoldenTalismanBurst.tres")}
const CUES = {
	# 保留旧调用名兼容，测试已移至 scenes/Tests/StoryEffectPlayground.tscn。
	"机关人初见_临时金符测试": {"effect": "金符蓄力", "source": "主角", "target": "机关人", "enabled": false},
}

## 测试场自动生成选单。新增条目即可接入已有 StoryDirector 方法或多步片段。
## 参数中的 $施术者、$目标 由测试场替换。
const PREVIEWS = {
	"金符蓄力": {"description":"金符环绕蓄力，多批发射与镜头震动。", "parameters":"golden", "steps":[{"method":"talisman_burst","args":["$施术者","$目标","$参数"]}]},
	"发现目标": {"description":"发现目标、转向并显示惊叹提示。", "steps":[{"method":"notice","args":["$施术者","$目标"]}]},
	"迎上拦路": {"description":"目标主动走近施术者，在面前停下并相互转向。", "steps":[{"method":"block","args":["$目标","$施术者",58.0]}]},
	"普通飞符": {"description":"播放攻击动作，发射一张符纸并命中闪光。", "steps":[{"method":"cast","args":["$施术者","$目标"]}]},
	"初见演出片段": {"description":"发现目标 → 对方迎上拦路 → 施术者发符，演示多步连续演出。", "steps":[{"method":"notice","args":["$施术者","$目标"]},{"method":"block","args":["$目标","$施术者",58.0]},{"method":"cast","args":["$施术者","$目标"]}]},
}
