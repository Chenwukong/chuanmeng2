# 赏金任务弹窗 + 道具分类系统

## 1. 扩展道具系统，增加分类与任务道具
   - 在 ItemData.gd 中添加 `ItemCategory` 枚举（CONSUMABLE/QUEST/MATERIAL/SPECIAL）
   - 在 ItemData.gd 中添加 `category` 导出字段
   - 在 GameData._register_items() 中注册一批任务道具（quest items）
   - 在 GameData._init_inventory() 中给玩家一些任务道具用于测试

## 2. 创建赏金任务数据系统
   - 新建 `Script/Global/BountyData.gd` 定义任务字典
   - 每个任务：id, name, description, rank(甲/乙/丙/丁), required_item_id, required_count, reward_gold, repeatable
   - 实现 `get_random_bounties(rank, count)` 从对应等级池随机抽取
   - 在 GameData 中挂载 bounty 状态（active_bounties, completed_bounties）

## 3. 构建赏金弹窗 UI 场景
   - 新建 `Component/BountyPopup.tscn`（CanvasLayer）
   - 蓝色水晶风格 UI：半透蓝色背景、亮蓝边框、标题装饰
   - 四栏布局（甲/乙/丙/丁），每栏显示任务卡片
   - 任务卡片：名称、描述、需求道具×数量、奖励金币
   - 确认对话框（接受/取消）
   - 入场/退场动画（_pop_in/_pop_out）

## 4. 实现 BountyPopup.gd 逻辑并接入游戏
   - 新建 `Script/Class/BountyPopup.gd`（class_name BountyPopup extends CanvasLayer）
   - open() 时从 BountyData 抽取任务渲染四栏
   - 点击任务 → 确认对话框 → 接受任务
   - 接受后检测背包道具，满足条件自动完成
   - 发放奖励、扣除道具
   - 不可重复任务标记完成不再出现
   - 在 MainScene 或 Player 上添加入口按钮
