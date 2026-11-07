GGE WPAL 染色移植

运行 res://scenes/DyePreview.tscn 查看虎头怪原色与三组染色动画。

WASAnimationPlayer 编辑器属性：
  dye_palette：与素材匹配的 .wpal 文件，空字符串表示原色。
  dye_choices：各调色板分段的方案编号，从 0 开始。省略的段采用方案 0。

运行时示例：
  var player = $WASAnimationPlayer
  player.set_dye("res://Resources/Dye/wpal/6.wpal", PackedInt32Array([1, 2, 3, 0]))
  player.clear_dye()

set_dye 返回 bool；失败保留现有外观。配置对已加载和后续加载的动作生效。
每次从素材原始调色板计算；不会累积变色，也不会污染共享原色缓存。
切换染色不会重置当前帧、朝向或动画计时。

资源来自 D:/GGE/梦战初版0.2版本/Projects/梦战/wpal。
保留原文件名；index.txt 已从 GBK 转为 UTF-8，列出了旧版素材映射。
共 130 个调色文件：129 个标准 wpal；128.wpal 实际为 wsln，暂不支持。
常见映射：1 逍遥生、2 剑侠客、6 虎头怪、8 骨精灵、65 黑熊。
新角色、高清重绘或重新排列过索引的 WAS 需要专用调色板。
目前接入实际使用的 WASAnimationPlayer；TCP/RP、PNG 动画没有接入。
本次未加入染色商店、价格、存档字段或默认角色染色。
已验证 Godot 中实际图像变化、透明度、缓存隔离、恢复原色和延迟加载。
GGE 底层 ChangePal 位于二进制模块；尚未与其输出逐像素比对。

游霄云白衣：已按各动作的独立调色板生成专用 WPAL，并在地图和战斗中启用。
路径模板 res://Resources/Dye/游霄云白衣/{file}.wpal，{file} 自动替换为动画源文件名。
256 个分段全部选方案 1；方案 0 为原色。按最新立绘参考调整为黑紫头发、淡紫白衣、藏蓝内衬和金色护甲饰边；皮肤和独立武器层保持原样。
生成源 artifacts/build_hero_white.gd；动作验证 artifacts/verify_hero_white.gd。


