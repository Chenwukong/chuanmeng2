# 待办 / 未完成事项

> 规则：凡是「暂时没做完、留待后续」的事项，都记录在本文件里；完成后删除对应条目。
> 记录格式：`- [ ] 事项 —— 背景/原因（相关文件）`

---

## 异常状态系统重构后遗留

- [ ] **技能 ↔ 新状态配置**：`sleep`(催眠) / `confuse`(疯魔) / `dmg_down`(减伤) 的机制已就绪，但目前**没有任何技能会施加它们**。需在 `Script/Data/SkillDB.gd` 给对应技能配 `apply_buff_id` / `apply_buff_turns` / `apply_buff_chance`。待确认「哪个技能 → 哪个状态」。（`Script/Data/SkillDB.gd`、`Script/Class/SkillManager.gd`）
- [ ] **新状态视觉资源**：`Component/debuff.tscn` 目前只有 `冰封 / 虚弱 / 失魂 / 中毒` 四个动画。**催眠 / 疯魔 / 减伤 / 封技能 / 减速** 缺身上动画，暂时只有 `battleUI` 的 emoji 图标（💤 / 🌀 / 🔻 / 🔒）占位。需美术补 AnimatedSprite2D 帧并接线。（`Component/debuff.tscn`、`Script/Class/BattleCharacter.gd` 的 `show_debuff`）
- 更新道具描述


---

## 通用备注

- 本机**无 Godot 运行环境**：以上改动仅做过 grep 静态验证，未实机跑战斗，回归需实测。
- 日志位置：`%APPDATA%/Godot/app_userdata/<项目名>/logs/godot.log`。
