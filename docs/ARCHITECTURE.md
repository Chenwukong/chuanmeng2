# 项目结构与开发入口

本轮重构将脚本按功能分组，GameData / BattleManager 作为统一业务入口。存档使用 version 4，角色数据只写入 characters，队伍通过 party_order 引用，不再保存重复的 party 快照或迁移旧版本。

## 目录

- Script/Battle：战斗状态、结算、技能行动、召唤、治疗、仇恨与角色。
- Script/UI：窗口与输入；Battle 子目录为战斗界面，Talents 为天赋界面。
- Script/World：地图加载、人物移动、地图导航、NPC 和主场景。
- Script/Data：GameData 统一入口、数据库、数据模型和业务服务。
- Script/Save：存档编解码、磁盘读写和当前格式验证。
- Script/Assets：TCP / WAS / 序列帧解码与缓存、战斗场景预热。
- scenes/Battle、scenes/World、scenes/UI：对应的场景与组件；MainScene 和现有地图保留原入口。
- tools/architecture_paths.json：本轮迁移的旧路径 → 新路径索引。

旧路径转发场景已移除。Component / Class 中可能保留原有素材、主题或编辑器临时文件；不要把新的功能脚本继续放回 Class / Only / Global。

## 战斗结算

数值变更从 BattleManager.apply_damage / apply_heal / apply_buff 进入 BattleResolution。普通攻击的 pending_damage 在动画命中时逐项交给同一结算器；符咒、全屏技能、多段攻击、召唤攻击及持续伤害同样走此入口。

新攻击示例：

```gdscript
manager.apply_damage(source, target, amount, {
    "is_magic": true,
    "is_aoe": false,
    "emit_float": true,
})
manager.apply_heal(source, ally, amount, false, {"emit_float": true})
```

- 默认 emit_float=false 兼容原有动画自行显示合并飘字的路径。不要既请求自动飘字又手动飘字。
- kind 表示 damage / heal / revive / shield；type 仅表示 normal / crit / magic 等飘字样式。不要根据 crit 判断伤害还是治疗。
- 来源必须显式传入；环境伤害可以用 null，不从 current_actor 猜测来源。
- secondary 用于反震 / 持续伤害等，防止再次触发反震、吸血和命中附加效果。
- 统计与仇恨在结算时记录一次，召唤物统计归到主人；UI 仅监听 effect_settled 后刷新显示。
- Character 承担护盾、分担、血量及死亡 / 复活信号等底层状态，业务调用者不要再次直接扣血。
- 处决 / 捕捉使用 Resolution.retire，捕捉不会触发死亡奖励信号。
- SkillManager.execute 计算技能结果及待应用 effects；BattleManager 应用 effects 一次后清空，UI 不应用规则。
- SkillActions 处理特殊技能流程，SummonActions 处理召唤流程，HealingRules 处理溅射治疗，TalismanRules 处理符咒消耗 / 目标 / 伤害。

## GameData 与存档

GameData 提供统一字段和方法供场景、对话脚本访问。业务实现委托至：

- PartyService：队伍、永久角色、成长、技能学习。
- EquipmentService：穿戴校验、卸下、装备属性汇总。
- ProgressService：成就、悬赏、金币奖励。
- DatabaseRegistry：技能 / 道具 / 敌人注册和初始背包。
- SaveService：save_game / load_game 等接口；serialize_state / restore_state 可直接做不写盘的往返测试。
- Data/Dialogue/DialogueDB.gd：NPC 对话配置；运行进度仍通过 GameData 的统一入口存取。

服务显式接收 game_state，避免复制出两份运行状态。修改规则时维护对应服务，不要在 facade 和服务各写一套实现。

## 资源加载与释放

AssetCache 是共享 LRU，预算 128 MiB / 256 项。为避免单个大序列无法预热，允许单项超过字节预算；此时其他项会被淘汰。控件 / 播放器持有的资源不因淘汰而销毁。

- TCP 静态图标：AssetLoader.tcp_texture；批量 UI 优先 request_tcp，按帧分批解码，约 3 ms 后让出下一帧。
- request_tcp 使用控件弱引用和请求路径校验，切页 / 关闭后的过期结果不会覆盖新图标。
- WAS：WASReader.shared_from_file 通过同一缓存服务管理弱引用，文件数据与帧纹理复用，播放方向 / 进度仍属于各自播放器。
- 全屏序列：先 await FullscreenAnimation.prepare，再 play；并发 prepare 合并等待，序列通过共享 LRU 淘汰。
- 战斗模板：BattleAssetLoader 后台预热固定的战斗场景和共用特效。
- AssetCache.diagnostics 可查看缓存项数和估算字节数；clear 仅释放缓存持有的引用。

帧预算不能拆开单个文件的一次解码，特别大的素材仍应控制尺寸。首次显示的未缓存图标会分帧补齐。

## 回归检查

使用 Godot --headless --path 项目目录 --script res://tools/测试脚本.gd；日志输出到可写目录。

核心新增检查：verify_battle_resolution、verify_skill_actions_integration、verify_save_schema、verify_asset_cache、verify_architecture_resources。

现有检查：verify_ui_keyboard、verify_ui_sounds、verify_achievements、verify_status_details、verify_battle_loading、verify_turn_progress、verify_mech_upgrade、verify_mech_summon_input、verify_confirm_actions。

目录迁移后编辑器若还显示旧节点脚本路径，应重新加载项目 / 从磁盘重新打开场景，避免把旧的内存副本保存回原目录。
