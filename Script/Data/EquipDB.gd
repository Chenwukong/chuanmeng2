# EquipDB.gd — 命名装备全量注册（对应 TCP/ 下的图标）
# 所有 register_named 都集中在这里维护：改 ID/名称/品质/基础属性/等级/价格即可生效。
# 武器类别 weapon_type 自动从 tcp_path 的 TCP 子目录推断；角色限制见 CharacterDB.weapons；
# 上架商店：把注册 id 填进 GameData.EQUIP_SHOP_TABLE 的对应等级档。
class_name EquipDB
extends RefCounted

## 在 GameData._init_equip_db 中调用
static func register_all() -> void:
	# ═══════════════════════════════════
	# 腰带（EquipData.SlotType.BELT）
	# ═══════════════════════════════════
	EquipData.register_named("缎带", EquipData.SlotType.BELT,
		"缎带", {"hp": 80}, "res://TCP/腰带/2902.tcp", 1, [], 100)
	EquipData.register_named("银腰带", EquipData.SlotType.BELT,
		"银腰带", {"hp": 60}, "res://TCP/腰带/2903.tcp", 1, [], 80)
	EquipData.register_named("琥珀腰带", EquipData.SlotType.BELT,
		"琥珀腰带", {"hp": 140}, "res://TCP/腰带/2906.tcp", 1, [], 300)
	EquipData.register_named("equip_2908", EquipData.SlotType.BELT,
		"犀皮腰带", {"hp": 180}, "res://TCP/腰带/2908.tcp", 1, [], 400)
	EquipData.register_named("攫魂铃", EquipData.SlotType.BELT,
		"攫魂铃", {"hp": 260}, "res://TCP/腰带/2910.tcp", 1, [], 800)
	EquipData.register_named("equip_2912", EquipData.SlotType.BELT,
		"龙鳞腰带", {"hp": 340}, "res://TCP/腰带/2912.tcp", 1, [], 1200)
	EquipData.register_named("幻彩玉带", EquipData.SlotType.BELT,
		"幻彩玉带", {"hp": 480}, "res://TCP/腰带/2950.tcp", 1, [], 2500)
	EquipData.register_named("珠翠玉环", EquipData.SlotType.BELT,
		"珠翠玉环", {"hp": 50}, "res://TCP/腰带/2952.tcp", 1, [], 50)
	EquipData.register_named("金蟾含珠", EquipData.SlotType.BELT,
		"金蟾含珠", {"hp": 70}, "res://TCP/腰带/2953.tcp", 1, [], 60)
	EquipData.register_named("乾坤紫玉带", EquipData.SlotType.BELT,
		"乾坤紫玉带", {"hp": 160}, "res://TCP/腰带/2954.tcp", 1, [], 350)
	EquipData.register_named("琉璃寒玉带", EquipData.SlotType.BELT,
		"琉璃寒玉带", {"hp": 440, "spd": 12}, "res://TCP/腰带/2955.tcp", 1, [], 3000)
	EquipData.register_named("蝉翼鱼佩带", EquipData.SlotType.BELT,
		"蝉翼鱼佩带", {"hp": 460, "atk": 15}, "res://TCP/腰带/2956.tcp", 1, [], 3200)
	EquipData.register_named("磐龙凤翔带", EquipData.SlotType.BELT,
		"磐龙凤翔带", {"hp": 600, "spd": 2000}, "res://TCP/腰带/2957.tcp", 1, [], 6000)
	EquipData.register_named("紫霄云芒带", EquipData.SlotType.BELT,
		"紫霄云芒带", {"hp": 750, "def": 30}, "res://TCP/腰带/2958.tcp", 1, [], 80000)

	# ═══════════════════════════════════
	# 衣服（EquipData.SlotType.BODY）
	# ═══════════════════════════════════
	EquipData.register_named("布衣", EquipData.SlotType.BODY,
		"布衣", {"hp": 150, "def": 30}, "res://TCP/衣服/2601.tcp", 1, [], 8000)
	EquipData.register_named("皮衣", EquipData.SlotType.BODY,
		"皮衣", {"hp": 750, "def": 30}, "res://TCP/衣服/2602.tcp", 1, [], 8000)
	EquipData.register_named("鳞甲", EquipData.SlotType.BODY,
		"鳞甲", {"hp": 750, "def": 30}, "res://TCP/衣服/2603.tcp", 1, [], 8000)
	EquipData.register_named("锁子甲", EquipData.SlotType.BODY,
		"锁子甲", {"hp": 750, "def": 30}, "res://TCP/衣服/2604.tcp", 1, [], 8000)
	EquipData.register_named("钢甲", EquipData.SlotType.BODY,
		"钢甲", {"hp": 750, "def": 30}, "res://TCP/衣服/2606.tcp", 1, [], 8000)
	EquipData.register_named("夜魔披风", EquipData.SlotType.BODY,
		"夜魔披风", {"hp": 750, "def": 30}, "res://TCP/衣服/2607.tcp", 1, [], 8000)
	EquipData.register_named("龙骨甲", EquipData.SlotType.BODY,
		"龙骨甲", {"hp": 750, "def": 30}, "res://TCP/衣服/2608.tcp", 1, [], 8000)
	EquipData.register_named("神谕披风", EquipData.SlotType.BODY,
		"神谕披风", {"hp": 750, "def": 30}, "res://TCP/衣服/2650.tcp", 1, [], 8000)
	EquipData.register_named("金蚕披风", EquipData.SlotType.BODY,
		"金蚕披风", {"hp": 750, "def": 30}, "res://TCP/衣服/2653.tcp", 1, [], 8000)
	EquipData.register_named("蝉翼金丝甲", EquipData.SlotType.BODY,
		"蝉翼金丝甲", {"hp": 750, "def": 30}, "res://TCP/衣服/2655.tcp", 70, [], 8000)
	EquipData.register_named("金丝鱼鳞甲", EquipData.SlotType.BODY,
		"金丝鱼鳞甲", {"hp": 750, "def": 30}, "res://TCP/衣服/2656.tcp", 70, [], 8000)
	EquipData.register_named("紫金磐龙甲", EquipData.SlotType.BODY,
		"紫金磐龙甲", {"hp": 750, "def": 30}, "res://TCP/衣服/2657tcp", 70, [], 8000)
	EquipData.register_named("混元一气甲", EquipData.SlotType.BODY,
		"混元一气甲", {"hp": 750, "def": 30}, "res://TCP/衣服/2658.tcp", 70, [], 8000)

	# ═══════════════════════════════════
	# 头盔（EquipData.SlotType.HEAD）
	# ═══════════════════════════════════
	EquipData.register_named("方巾", EquipData.SlotType.HEAD,
		"方巾", {}, "res://TCP/头盔/方巾.tcp", 1, [], 0)
	EquipData.register_named("面具", EquipData.SlotType.HEAD,
		"面具", {}, "res://TCP/头盔/面具.tcp", 1, [], 0)
	EquipData.register_named("羊角盔", EquipData.SlotType.HEAD,
		"羊角盔", {}, "res://TCP/头盔/羊角盔.tcp", 1, [], 0)
	EquipData.register_named("水晶帽", EquipData.SlotType.HEAD,
		"水晶帽", {}, "res://TCP/头盔/水晶帽.tcp", 1, [], 0)
	EquipData.register_named("白玉琉璃冠", EquipData.SlotType.HEAD,
		"白玉琉璃冠", {}, "res://TCP/头盔/白玉琉璃冠.tcp", 1, [], 0)
	EquipData.register_named("黑魔冠", EquipData.SlotType.HEAD,
		"黑魔冠", {}, "res://TCP/头盔/黑魔冠.tcp", 1, [], 0)
	EquipData.register_named("兽鬼珐琅面", EquipData.SlotType.HEAD,
		"兽鬼珐琅面", {}, "res://TCP/头盔/兽鬼珐琅面.tcp", 1, [], 0)
	EquipData.register_named("水晶夔帽", EquipData.SlotType.HEAD,
		"水晶夔帽", {}, "res://TCP/头盔/水晶夔帽.tcp", 1, [], 0)
	EquipData.register_named("金丝黑玉冠", EquipData.SlotType.HEAD,
		"金丝黑玉冠", {}, "res://TCP/头盔/金丝黑玉冠.tcp", 1, [], 0)
	EquipData.register_named("紫金磐龙冠", EquipData.SlotType.HEAD,
		"紫金磐龙冠", {}, "res://TCP/头盔/紫金磐龙冠.tcp", 1, [], 0)
	EquipData.register_named("浑天玄火盔", EquipData.SlotType.HEAD,
		"浑天玄火盔", {}, "res://TCP/头盔/浑天玄火盔.tcp", 1, [], 0)

	# 带（EquipData.SlotType.BELT）
	# ═══════════════════════════════════
	EquipData.register_named("带_1901", EquipData.SlotType.BELT,
		"带1901", {}, "res://TCP/带/1901.tcp", 1, [], 0)
	EquipData.register_named("带_1902", EquipData.SlotType.BELT,
		"带1902", {}, "res://TCP/带/1902.tcp", 1, [], 0)
	EquipData.register_named("带_1903", EquipData.SlotType.BELT,
		"带1903", {}, "res://TCP/带/1903.tcp", 1, [], 0)
	EquipData.register_named("带_1904", EquipData.SlotType.BELT,
		"带1904", {}, "res://TCP/带/1904.tcp", 1, [], 0)
	EquipData.register_named("带_1905", EquipData.SlotType.BELT,
		"带1905", {}, "res://TCP/带/1905.tcp", 1, [], 0)
	EquipData.register_named("带_1906", EquipData.SlotType.BELT,
		"带1906", {}, "res://TCP/带/1906.tcp", 1, [], 0)
	EquipData.register_named("带_1907", EquipData.SlotType.BELT,
		"带1907", {}, "res://TCP/带/1907.tcp", 1, [], 0)
	EquipData.register_named("带_1908", EquipData.SlotType.BELT,
		"带1908", {}, "res://TCP/带/1908.tcp", 1, [], 0)
	EquipData.register_named("带_1909", EquipData.SlotType.BELT,
		"带1909", {}, "res://TCP/带/1909.tcp", 1, [], 0)
	EquipData.register_named("带_1950", EquipData.SlotType.BELT,
		"带1950", {}, "res://TCP/带/1950.tcp", 1, [], 0)
	EquipData.register_named("带_1951", EquipData.SlotType.BELT,
		"带1951", {}, "res://TCP/带/1951.tcp", 1, [], 0)
	EquipData.register_named("带_1952", EquipData.SlotType.BELT,
		"带1952", {}, "res://TCP/带/1952.tcp", 1, [], 0)
	EquipData.register_named("带_1960", EquipData.SlotType.BELT,
		"带1960", {}, "res://TCP/带/1960.tcp", 1, [], 0)
	EquipData.register_named("带_1961", EquipData.SlotType.BELT,
		"带1961", {}, "res://TCP/带/1961.tcp", 1, [], 0)
	EquipData.register_named("带_1962", EquipData.SlotType.BELT,
		"带1962", {}, "res://TCP/带/1962.tcp", 1, [], 0)
	EquipData.register_named("带_1970", EquipData.SlotType.BELT,
		"带1970", {}, "res://TCP/带/1970.tcp", 1, [], 0)
	EquipData.register_named("带_1980", EquipData.SlotType.BELT,
		"带1980", {}, "res://TCP/带/1980.tcp", 1, [], 0)

	# ═══════════════════════════════════
	# 鞋子（EquipData.SlotType.SHOES）
	# ═══════════════════════════════════
	EquipData.register_named("布鞋", EquipData.SlotType.SHOES,
		"布鞋", {"spd": 5}, "res://TCP/鞋子/布鞋.tcp", 1, [], 0)
	EquipData.register_named("绿靴", EquipData.SlotType.SHOES,
		"绿靴", {}, "res://TCP/鞋子/绿靴.tcp", 1, [], 0)
	EquipData.register_named("马靴", EquipData.SlotType.SHOES,
		"马靴", {}, "res://TCP/鞋子/马靴.tcp", 1, [], 0)
	EquipData.register_named("平步青云", EquipData.SlotType.SHOES,
		"平步青云", {}, "res://TCP/鞋子/平步青云.tcp", 1, [], 0)
	EquipData.register_named("神行靴", EquipData.SlotType.SHOES,
		"神行靴", {}, "res://TCP/鞋子/神行靴.tcp", 1, [], 0)
	EquipData.register_named("踏雪无痕", EquipData.SlotType.SHOES,
		"踏雪无痕", {}, "res://TCP/鞋子/踏雪无痕.tcp", 1, [], 0)
	EquipData.register_named("追云逐电", EquipData.SlotType.SHOES,
		"追云逐电", {}, "res://TCP/鞋子/追云逐电.tcp", 1, [], 0)
	EquipData.register_named("碧霞流云履", EquipData.SlotType.SHOES,
		"碧霞流云履", {}, "res://TCP/鞋子/碧霞流云履.tcp", 1, [], 0)
	EquipData.register_named("金丝逐日履", EquipData.SlotType.SHOES,
		"金丝逐日履", {}, "res://TCP/鞋子/金丝逐日履.tcp", 1, [], 0)
	EquipData.register_named("七星逐月靴", EquipData.SlotType.SHOES,
		"七星逐月靴", {}, "res://TCP/鞋子/七星逐月靴.tcp", 1, [], 0)
	EquipData.register_named("乾坤天罡履", EquipData.SlotType.SHOES,
		"乾坤天罡履", {}, "res://TCP/鞋子/乾坤天罡履.tcp", 1, [], 0)
	EquipData.register_named("辟尘分光履", EquipData.SlotType.SHOES,
		"辟尘分光履", {}, "res://TCP/鞋子/辟尘分光履.tcp", 1, [], 0)
	# 饰品（EquipData.SlotType.NECKLACE）
	# ═══════════════════════════════════
	EquipData.register_named("饰品_2801", EquipData.SlotType.NECKLACE,
		"饰品2801", {}, "res://TCP/饰品/2801.tcp", 1, [], 0)
	EquipData.register_named("饰品_2802", EquipData.SlotType.NECKLACE,
		"饰品2802", {}, "res://TCP/饰品/2802.tcp", 1, [], 0)
	EquipData.register_named("饰品_2803", EquipData.SlotType.NECKLACE,
		"饰品2803", {}, "res://TCP/饰品/2803.tcp", 1, [], 0)
	EquipData.register_named("饰品_2804", EquipData.SlotType.NECKLACE,
		"饰品2804", {}, "res://TCP/饰品/2804.tcp", 1, [], 0)
	EquipData.register_named("饰品_2805", EquipData.SlotType.NECKLACE,
		"饰品2805", {}, "res://TCP/饰品/2805.tcp", 1, [], 0)
	EquipData.register_named("饰品_2806", EquipData.SlotType.NECKLACE,
		"饰品2806", {}, "res://TCP/饰品/2806.tcp", 1, [], 0)
	EquipData.register_named("饰品_2807", EquipData.SlotType.NECKLACE,
		"饰品2807", {}, "res://TCP/饰品/2807.tcp", 1, [], 0)
	EquipData.register_named("饰品_2808", EquipData.SlotType.NECKLACE,
		"饰品2808", {}, "res://TCP/饰品/2808.tcp", 1, [], 0)
	EquipData.register_named("饰品_2809", EquipData.SlotType.NECKLACE,
		"饰品2809", {}, "res://TCP/饰品/2809.tcp", 1, [], 0)
	EquipData.register_named("饰品_2810", EquipData.SlotType.NECKLACE,
		"饰品2810", {}, "res://TCP/饰品/2810.tcp", 1, [], 0)
	EquipData.register_named("饰品_2811", EquipData.SlotType.NECKLACE,
		"饰品2811", {}, "res://TCP/饰品/2811.tcp", 1, [], 0)
	EquipData.register_named("饰品_2812", EquipData.SlotType.NECKLACE,
		"饰品2812", {}, "res://TCP/饰品/2812.tcp", 1, [], 0)
	EquipData.register_named("饰品_2813", EquipData.SlotType.NECKLACE,
		"饰品2813", {}, "res://TCP/饰品/2813.tcp", 1, [], 0)
	EquipData.register_named("饰品_2814", EquipData.SlotType.NECKLACE,
		"饰品2814", {}, "res://TCP/饰品/2814.tcp", 1, [], 0)
	EquipData.register_named("饰品_2815", EquipData.SlotType.NECKLACE,
		"饰品2815", {}, "res://TCP/饰品/2815.tcp", 1, [], 0)
	EquipData.register_named("饰品_2850", EquipData.SlotType.NECKLACE,
		"饰品2850", {}, "res://TCP/饰品/2850.tcp", 1, [], 0)
	EquipData.register_named("饰品_2852", EquipData.SlotType.NECKLACE,
		"饰品2852", {}, "res://TCP/饰品/2852.tcp", 1, [], 0)
	EquipData.register_named("饰品_2853", EquipData.SlotType.NECKLACE,
		"饰品2853", {}, "res://TCP/饰品/2853.tcp", 1, [], 0)
	EquipData.register_named("饰品_2854", EquipData.SlotType.NECKLACE,
		"饰品2854", {}, "res://TCP/饰品/2854.tcp", 1, [], 0)
	EquipData.register_named("饰品_2855", EquipData.SlotType.NECKLACE,
		"饰品2855", {}, "res://TCP/饰品/2855.tcp", 1, [], 0)
	EquipData.register_named("饰品_2856", EquipData.SlotType.NECKLACE,
		"饰品2856", {}, "res://TCP/饰品/2856.tcp", 1, [], 0)
	EquipData.register_named("饰品_2857", EquipData.SlotType.NECKLACE,
		"饰品2857", {}, "res://TCP/饰品/2857.tcp", 1, [], 0)
	EquipData.register_named("饰品_2858", EquipData.SlotType.NECKLACE,
		"饰品2858", {}, "res://TCP/饰品/2858.tcp", 1, [], 0)


	# ═══════════════════════════════════
	# 符咒（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("基础符纸", EquipData.SlotType.WEAPON,
		"基础符纸", {"dmg": 10}, "res://TCP/符咒/3290.tcp", 1, [], 120, "最基础的符纸")
	EquipData.register_named("赦令符纸", EquipData.SlotType.WEAPON,
		"赦令符纸", {"dmg": 40}, "res://TCP/符咒/6016.tcp", 5, [], 450, "急急如律令，赦！")

	# ═══════════════════════════════════
	# 剑（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("青锋剑", EquipData.SlotType.WEAPON,
		"青锋剑", {"dmg": 10}, "res://TCP/剑/1001.tcp", 1, [], 120)
	EquipData.register_named("精钢剑", EquipData.SlotType.WEAPON,
		"精钢剑", {"dmg": 58}, "res://TCP/剑/1003.tcp", 5, [], 450)
	EquipData.register_named("寒光剑", EquipData.SlotType.WEAPON,
		"寒光剑", {"dmg": 110}, "res://TCP/剑/1005.tcp", 10, [], 1400)
	EquipData.register_named("剑_1002", EquipData.SlotType.WEAPON,
		"剑1002", {}, "res://TCP/剑/1002.tcp", 1, [], 0)
	EquipData.register_named("剑_1004", EquipData.SlotType.WEAPON,
		"剑1004", {}, "res://TCP/剑/1004.tcp", 1, [], 0)
	EquipData.register_named("剑_1006", EquipData.SlotType.WEAPON,
		"剑1006", {}, "res://TCP/剑/1006.tcp", 1, [], 0)
	EquipData.register_named("剑_1007", EquipData.SlotType.WEAPON,
		"剑1007", {}, "res://TCP/剑/1007.tcp", 1, [], 0)
	EquipData.register_named("剑_1008", EquipData.SlotType.WEAPON,
		"剑1008", {}, "res://TCP/剑/1008.tcp", 1, [], 0)
	EquipData.register_named("剑_1009", EquipData.SlotType.WEAPON,
		"剑1009", {}, "res://TCP/剑/1009.tcp", 1, [], 0)
	EquipData.register_named("剑_1050", EquipData.SlotType.WEAPON,
		"剑1050", {}, "res://TCP/剑/1050.tcp", 1, [], 0)
	EquipData.register_named("剑_1051", EquipData.SlotType.WEAPON,
		"剑1051", {}, "res://TCP/剑/1051.tcp", 1, [], 0)
	EquipData.register_named("剑_1052", EquipData.SlotType.WEAPON,
		"剑1052", {}, "res://TCP/剑/1052.tcp", 1, [], 0)
	EquipData.register_named("剑_1060", EquipData.SlotType.WEAPON,
		"剑1060", {}, "res://TCP/剑/1060.tcp", 1, [], 0)
	EquipData.register_named("剑_1061", EquipData.SlotType.WEAPON,
		"剑1061", {}, "res://TCP/剑/1061.tcp", 1, [], 0)
	EquipData.register_named("剑_1062", EquipData.SlotType.WEAPON,
		"剑1062", {}, "res://TCP/剑/1062.tcp", 1, [], 0)
	EquipData.register_named("剑_1070", EquipData.SlotType.WEAPON,
		"剑1070", {}, "res://TCP/剑/1070.tcp", 1, [], 0)
	EquipData.register_named("剑_1080", EquipData.SlotType.WEAPON,
		"剑1080", {}, "res://TCP/剑/1080.tcp", 1, [], 0)

	# ═══════════════════════════════════
	# 刀（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("朴刀", EquipData.SlotType.WEAPON,
		"朴刀", {"dmg": 10}, "res://TCP/刀/1101.tcp", 1, [], 120)
	EquipData.register_named("刀_1102", EquipData.SlotType.WEAPON,
		"刀1102", {}, "res://TCP/刀/1102.tcp", 1, [], 0)
	EquipData.register_named("刀_1103", EquipData.SlotType.WEAPON,
		"刀1103", {}, "res://TCP/刀/1103.tcp", 1, [], 0)
	EquipData.register_named("刀_1104", EquipData.SlotType.WEAPON,
		"刀1104", {}, "res://TCP/刀/1104.tcp", 1, [], 0)
	EquipData.register_named("刀_1105", EquipData.SlotType.WEAPON,
		"刀1105", {}, "res://TCP/刀/1105.tcp", 1, [], 0)
	EquipData.register_named("刀_1106", EquipData.SlotType.WEAPON,
		"刀1106", {}, "res://TCP/刀/1106.tcp", 1, [], 0)
	EquipData.register_named("刀_1107", EquipData.SlotType.WEAPON,
		"刀1107", {}, "res://TCP/刀/1107.tcp", 1, [], 0)
	EquipData.register_named("刀_1108", EquipData.SlotType.WEAPON,
		"刀1108", {}, "res://TCP/刀/1108.tcp", 1, [], 0)
	EquipData.register_named("刀_1109", EquipData.SlotType.WEAPON,
		"刀1109", {}, "res://TCP/刀/1109.tcp", 1, [], 0)
	EquipData.register_named("刀_1150", EquipData.SlotType.WEAPON,
		"刀1150", {}, "res://TCP/刀/1150.tcp", 1, [], 0)
	EquipData.register_named("刀_1151", EquipData.SlotType.WEAPON,
		"刀1151", {}, "res://TCP/刀/1151.tcp", 1, [], 0)
	EquipData.register_named("刀_1152", EquipData.SlotType.WEAPON,
		"刀1152", {}, "res://TCP/刀/1152.tcp", 1, [], 0)
	EquipData.register_named("刀_1160", EquipData.SlotType.WEAPON,
		"刀1160", {}, "res://TCP/刀/1160.tcp", 1, [], 0)
	EquipData.register_named("刀_1161", EquipData.SlotType.WEAPON,
		"刀1161", {}, "res://TCP/刀/1161.tcp", 1, [], 0)
	EquipData.register_named("刀_1162", EquipData.SlotType.WEAPON,
		"刀1162", {}, "res://TCP/刀/1162.tcp", 1, [], 0)
	EquipData.register_named("刀_1170", EquipData.SlotType.WEAPON,
		"刀1170", {}, "res://TCP/刀/1170.tcp", 1, [], 0)
	EquipData.register_named("刀_1180", EquipData.SlotType.WEAPON,
		"刀1180", {}, "res://TCP/刀/1180.tcp", 1, [], 0)

	# ═══════════════════════════════════
	# 双刀（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("双刀_2101", EquipData.SlotType.WEAPON,
		"双刀2101", {}, "res://TCP/双刀/2101.tcp", 1, [], 0)
	EquipData.register_named("双刀_2102", EquipData.SlotType.WEAPON,
		"双刀2102", {}, "res://TCP/双刀/2102.tcp", 1, [], 0)
	EquipData.register_named("双刀_2103", EquipData.SlotType.WEAPON,
		"双刀2103", {}, "res://TCP/双刀/2103.tcp", 1, [], 0)
	EquipData.register_named("双刀_2104", EquipData.SlotType.WEAPON,
		"双刀2104", {}, "res://TCP/双刀/2104.tcp", 1, [], 0)
	EquipData.register_named("双刀_2105", EquipData.SlotType.WEAPON,
		"双刀2105", {}, "res://TCP/双刀/2105.tcp", 1, [], 0)
	EquipData.register_named("双刀_2106", EquipData.SlotType.WEAPON,
		"双刀2106", {}, "res://TCP/双刀/2106.tcp", 1, [], 0)
	EquipData.register_named("双刀_2107", EquipData.SlotType.WEAPON,
		"双刀2107", {}, "res://TCP/双刀/2107.tcp", 1, [], 0)
	EquipData.register_named("双刀_2108", EquipData.SlotType.WEAPON,
		"双刀2108", {}, "res://TCP/双刀/2108.tcp", 1, [], 0)
	EquipData.register_named("双刀_2109", EquipData.SlotType.WEAPON,
		"双刀2109", {}, "res://TCP/双刀/2109.tcp", 1, [], 0)
	EquipData.register_named("双刀_2150", EquipData.SlotType.WEAPON,
		"双刀2150", {}, "res://TCP/双刀/2150.tcp", 1, [], 0)
	EquipData.register_named("双刀_2151", EquipData.SlotType.WEAPON,
		"双刀2151", {}, "res://TCP/双刀/2151.tcp", 1, [], 0)
	EquipData.register_named("双刀_2152", EquipData.SlotType.WEAPON,
		"双刀2152", {}, "res://TCP/双刀/2152.tcp", 1, [], 0)
	EquipData.register_named("双刀_2160", EquipData.SlotType.WEAPON,
		"双刀2160", {}, "res://TCP/双刀/2160.tcp", 1, [], 0)
	EquipData.register_named("双刀_2161", EquipData.SlotType.WEAPON,
		"双刀2161", {}, "res://TCP/双刀/2161.tcp", 1, [], 0)
	EquipData.register_named("双刀_2162", EquipData.SlotType.WEAPON,
		"双刀2162", {}, "res://TCP/双刀/2162.tcp", 1, [], 0)
	EquipData.register_named("双刀_2170", EquipData.SlotType.WEAPON,
		"双刀2170", {}, "res://TCP/双刀/2170.tcp", 1, [], 0)
	EquipData.register_named("双刀_2180", EquipData.SlotType.WEAPON,
		"双刀2180", {}, "res://TCP/双刀/2180.tcp", 1, [], 0)

	# ═══════════════════════════════════
	# 巨剑（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("巨剑_31001", EquipData.SlotType.WEAPON,
		"巨剑31001", {}, "res://TCP/巨剑/31001.tcp", 1, [], 0)
	EquipData.register_named("巨剑_31002", EquipData.SlotType.WEAPON,
		"巨剑31002", {}, "res://TCP/巨剑/31002.tcp", 1, [], 0)
	EquipData.register_named("巨剑_31003", EquipData.SlotType.WEAPON,
		"巨剑31003", {}, "res://TCP/巨剑/31003.tcp", 1, [], 0)
	EquipData.register_named("巨剑_31004", EquipData.SlotType.WEAPON,
		"巨剑31004", {}, "res://TCP/巨剑/31004.tcp", 1, [], 0)
	EquipData.register_named("巨剑_31005", EquipData.SlotType.WEAPON,
		"巨剑31005", {}, "res://TCP/巨剑/31005.tcp", 1, [], 0)
	EquipData.register_named("巨剑_31006", EquipData.SlotType.WEAPON,
		"巨剑31006", {}, "res://TCP/巨剑/31006.tcp", 1, [], 0)
	EquipData.register_named("巨剑_31007", EquipData.SlotType.WEAPON,
		"巨剑31007", {}, "res://TCP/巨剑/31007.tcp", 1, [], 0)
	EquipData.register_named("巨剑_31008", EquipData.SlotType.WEAPON,
		"巨剑31008", {}, "res://TCP/巨剑/31008.tcp", 1, [], 0)
	EquipData.register_named("巨剑_31009", EquipData.SlotType.WEAPON,
		"巨剑31009", {}, "res://TCP/巨剑/31009.tcp", 1, [], 0)
	EquipData.register_named("巨剑_31050", EquipData.SlotType.WEAPON,
		"巨剑31050", {}, "res://TCP/巨剑/31050.tcp", 1, [], 0)
	EquipData.register_named("巨剑_31051", EquipData.SlotType.WEAPON,
		"巨剑31051", {}, "res://TCP/巨剑/31051.tcp", 1, [], 0)
	EquipData.register_named("巨剑_31052", EquipData.SlotType.WEAPON,
		"巨剑31052", {}, "res://TCP/巨剑/31052.tcp", 1, [], 0)
	EquipData.register_named("巨剑_31060", EquipData.SlotType.WEAPON,
		"巨剑31060", {}, "res://TCP/巨剑/31060.tcp", 1, [], 0)
	EquipData.register_named("巨剑_31061", EquipData.SlotType.WEAPON,
		"巨剑31061", {}, "res://TCP/巨剑/31061.tcp", 1, [], 0)
	EquipData.register_named("巨剑_31062", EquipData.SlotType.WEAPON,
		"巨剑31062", {}, "res://TCP/巨剑/31062.tcp", 1, [], 0)
	EquipData.register_named("巨剑_31070", EquipData.SlotType.WEAPON,
		"巨剑31070", {}, "res://TCP/巨剑/31070.tcp", 1, [], 0)
	EquipData.register_named("巨剑_31080", EquipData.SlotType.WEAPON,
		"巨剑31080", {}, "res://TCP/巨剑/31080.tcp", 1, [], 0)

	# ═══════════════════════════════════
	# 扇（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("铁骨扇", EquipData.SlotType.WEAPON,
		"铁骨扇", {"dmg": 55}, "res://TCP/扇/1503.tcp", 5, [], 420)
	EquipData.register_named("扇_1501", EquipData.SlotType.WEAPON,
		"扇1501", {}, "res://TCP/扇/1501.tcp", 1, [], 0)
	EquipData.register_named("扇_1502", EquipData.SlotType.WEAPON,
		"扇1502", {}, "res://TCP/扇/1502.tcp", 1, [], 0)
	EquipData.register_named("扇_1504", EquipData.SlotType.WEAPON,
		"扇1504", {}, "res://TCP/扇/1504.tcp", 1, [], 0)
	EquipData.register_named("扇_1505", EquipData.SlotType.WEAPON,
		"扇1505", {}, "res://TCP/扇/1505.tcp", 1, [], 0)
	EquipData.register_named("扇_1506", EquipData.SlotType.WEAPON,
		"扇1506", {}, "res://TCP/扇/1506.tcp", 1, [], 0)
	EquipData.register_named("扇_1507", EquipData.SlotType.WEAPON,
		"扇1507", {}, "res://TCP/扇/1507.tcp", 1, [], 0)
	EquipData.register_named("扇_1508", EquipData.SlotType.WEAPON,
		"扇1508", {}, "res://TCP/扇/1508.tcp", 1, [], 0)
	EquipData.register_named("扇_1509", EquipData.SlotType.WEAPON,
		"扇1509", {}, "res://TCP/扇/1509.tcp", 1, [], 0)
	EquipData.register_named("扇_1550", EquipData.SlotType.WEAPON,
		"扇1550", {}, "res://TCP/扇/1550.tcp", 1, [], 0)
	EquipData.register_named("扇_1551", EquipData.SlotType.WEAPON,
		"扇1551", {}, "res://TCP/扇/1551.tcp", 1, [], 0)
	EquipData.register_named("扇_1552", EquipData.SlotType.WEAPON,
		"扇1552", {}, "res://TCP/扇/1552.tcp", 1, [], 0)
	EquipData.register_named("扇_1560", EquipData.SlotType.WEAPON,
		"扇1560", {}, "res://TCP/扇/1560.tcp", 1, [], 0)
	EquipData.register_named("扇_1561", EquipData.SlotType.WEAPON,
		"扇1561", {}, "res://TCP/扇/1561.tcp", 1, [], 0)
	EquipData.register_named("扇_1562", EquipData.SlotType.WEAPON,
		"扇1562", {}, "res://TCP/扇/1562.tcp", 1, [], 0)
	EquipData.register_named("扇_1570", EquipData.SlotType.WEAPON,
		"扇1570", {}, "res://TCP/扇/1570.tcp", 1, [], 0)
	EquipData.register_named("扇_1580", EquipData.SlotType.WEAPON,
		"扇1580", {}, "res://TCP/扇/1580.tcp", 1, [], 0)

	# ═══════════════════════════════════
	# 斧（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("斧_1401", EquipData.SlotType.WEAPON,
		"斧1401", {}, "res://TCP/斧/1401.tcp", 1, [], 0)
	EquipData.register_named("斧_1402", EquipData.SlotType.WEAPON,
		"斧1402", {}, "res://TCP/斧/1402.tcp", 1, [], 0)
	EquipData.register_named("斧_1403", EquipData.SlotType.WEAPON,
		"斧1403", {}, "res://TCP/斧/1403.tcp", 1, [], 0)
	EquipData.register_named("斧_1404", EquipData.SlotType.WEAPON,
		"斧1404", {}, "res://TCP/斧/1404.tcp", 1, [], 0)
	EquipData.register_named("斧_1405", EquipData.SlotType.WEAPON,
		"斧1405", {}, "res://TCP/斧/1405.tcp", 1, [], 0)
	EquipData.register_named("斧_1406", EquipData.SlotType.WEAPON,
		"斧1406", {}, "res://TCP/斧/1406.tcp", 1, [], 0)
	EquipData.register_named("斧_1407", EquipData.SlotType.WEAPON,
		"斧1407", {}, "res://TCP/斧/1407.tcp", 1, [], 0)
	EquipData.register_named("斧_1408", EquipData.SlotType.WEAPON,
		"斧1408", {}, "res://TCP/斧/1408.tcp", 1, [], 0)
	EquipData.register_named("斧_1409", EquipData.SlotType.WEAPON,
		"斧1409", {}, "res://TCP/斧/1409.tcp", 1, [], 0)
	EquipData.register_named("斧_1450", EquipData.SlotType.WEAPON,
		"斧1450", {}, "res://TCP/斧/1450.tcp", 1, [], 0)
	EquipData.register_named("斧_1451", EquipData.SlotType.WEAPON,
		"斧1451", {}, "res://TCP/斧/1451.tcp", 1, [], 0)
	EquipData.register_named("斧_1452", EquipData.SlotType.WEAPON,
		"斧1452", {}, "res://TCP/斧/1452.tcp", 1, [], 0)
	EquipData.register_named("斧_1460", EquipData.SlotType.WEAPON,
		"斧1460", {}, "res://TCP/斧/1460.tcp", 1, [], 0)
	EquipData.register_named("斧_1461", EquipData.SlotType.WEAPON,
		"斧1461", {}, "res://TCP/斧/1461.tcp", 1, [], 0)
	EquipData.register_named("斧_1462", EquipData.SlotType.WEAPON,
		"斧1462", {}, "res://TCP/斧/1462.tcp", 1, [], 0)
	EquipData.register_named("斧_1470", EquipData.SlotType.WEAPON,
		"斧1470", {}, "res://TCP/斧/1470.tcp", 1, [], 0)
	EquipData.register_named("斧_1480", EquipData.SlotType.WEAPON,
		"斧1480", {}, "res://TCP/斧/1480.tcp", 1, [], 0)

	# ═══════════════════════════════════
	# 杖（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("竹杖", EquipData.SlotType.WEAPON,
		"竹杖", {"dmg": 9}, "res://TCP/杖/2201.tcp", 1, [], 100)
	EquipData.register_named("蛇形杖", EquipData.SlotType.WEAPON,
		"蛇形杖", {"dmg": 105}, "res://TCP/杖/2205.tcp", 10, [], 1300)
	EquipData.register_named("杖_2202", EquipData.SlotType.WEAPON,
		"杖2202", {}, "res://TCP/杖/2202.tcp", 1, [], 0)
	EquipData.register_named("杖_2203", EquipData.SlotType.WEAPON,
		"杖2203", {}, "res://TCP/杖/2203.tcp", 1, [], 0)
	EquipData.register_named("杖_2204", EquipData.SlotType.WEAPON,
		"杖2204", {}, "res://TCP/杖/2204.tcp", 1, [], 0)
	EquipData.register_named("杖_2206", EquipData.SlotType.WEAPON,
		"杖2206", {}, "res://TCP/杖/2206.tcp", 1, [], 0)
	EquipData.register_named("杖_2207", EquipData.SlotType.WEAPON,
		"杖2207", {}, "res://TCP/杖/2207.tcp", 1, [], 0)
	EquipData.register_named("杖_2208", EquipData.SlotType.WEAPON,
		"杖2208", {}, "res://TCP/杖/2208.tcp", 1, [], 0)
	EquipData.register_named("杖_2209", EquipData.SlotType.WEAPON,
		"杖2209", {}, "res://TCP/杖/2209.tcp", 1, [], 0)
	EquipData.register_named("杖_2250", EquipData.SlotType.WEAPON,
		"杖2250", {}, "res://TCP/杖/2250.tcp", 1, [], 0)
	EquipData.register_named("杖_2251", EquipData.SlotType.WEAPON,
		"杖2251", {}, "res://TCP/杖/2251.tcp", 1, [], 0)
	EquipData.register_named("杖_2252", EquipData.SlotType.WEAPON,
		"杖2252", {}, "res://TCP/杖/2252.tcp", 1, [], 0)
	EquipData.register_named("杖_2260", EquipData.SlotType.WEAPON,
		"杖2260", {}, "res://TCP/杖/2260.tcp", 1, [], 0)
	EquipData.register_named("杖_2261", EquipData.SlotType.WEAPON,
		"杖2261", {}, "res://TCP/杖/2261.tcp", 1, [], 0)
	EquipData.register_named("杖_2262", EquipData.SlotType.WEAPON,
		"杖2262", {}, "res://TCP/杖/2262.tcp", 1, [], 0)
	EquipData.register_named("杖_2270", EquipData.SlotType.WEAPON,
		"杖2270", {}, "res://TCP/杖/2270.tcp", 1, [], 0)
	EquipData.register_named("杖_2280", EquipData.SlotType.WEAPON,
		"杖2280", {}, "res://TCP/杖/2280.tcp", 1, [], 0)

	# ═══════════════════════════════════
	# 枪（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("红缨枪", EquipData.SlotType.WEAPON,
		"红缨枪", {"dmg": 60}, "res://TCP/枪/1603.tcp", 5, [], 460)
	EquipData.register_named("枪_1601", EquipData.SlotType.WEAPON,
		"枪1601", {}, "res://TCP/枪/1601.tcp", 1, [], 0)
	EquipData.register_named("枪_1602", EquipData.SlotType.WEAPON,
		"枪1602", {}, "res://TCP/枪/1602.tcp", 1, [], 0)
	EquipData.register_named("枪_1604", EquipData.SlotType.WEAPON,
		"枪1604", {}, "res://TCP/枪/1604.tcp", 1, [], 0)
	EquipData.register_named("枪_1605", EquipData.SlotType.WEAPON,
		"枪1605", {}, "res://TCP/枪/1605.tcp", 1, [], 0)
	EquipData.register_named("枪_1606", EquipData.SlotType.WEAPON,
		"枪1606", {}, "res://TCP/枪/1606.tcp", 1, [], 0)
	EquipData.register_named("枪_1607", EquipData.SlotType.WEAPON,
		"枪1607", {}, "res://TCP/枪/1607.tcp", 1, [], 0)
	EquipData.register_named("枪_1608", EquipData.SlotType.WEAPON,
		"枪1608", {}, "res://TCP/枪/1608.tcp", 1, [], 0)
	EquipData.register_named("枪_1609", EquipData.SlotType.WEAPON,
		"枪1609", {}, "res://TCP/枪/1609.tcp", 1, [], 0)
	EquipData.register_named("枪_1650", EquipData.SlotType.WEAPON,
		"枪1650", {}, "res://TCP/枪/1650.tcp", 1, [], 0)
	EquipData.register_named("枪_1651", EquipData.SlotType.WEAPON,
		"枪1651", {}, "res://TCP/枪/1651.tcp", 1, [], 0)
	EquipData.register_named("枪_1652", EquipData.SlotType.WEAPON,
		"枪1652", {}, "res://TCP/枪/1652.tcp", 1, [], 0)
	EquipData.register_named("枪_1660", EquipData.SlotType.WEAPON,
		"枪1660", {}, "res://TCP/枪/1660.tcp", 1, [], 0)
	EquipData.register_named("枪_1661", EquipData.SlotType.WEAPON,
		"枪1661", {}, "res://TCP/枪/1661.tcp", 1, [], 0)
	EquipData.register_named("枪_1662", EquipData.SlotType.WEAPON,
		"枪1662", {}, "res://TCP/枪/1662.tcp", 1, [], 0)
	EquipData.register_named("枪_1670", EquipData.SlotType.WEAPON,
		"枪1670", {}, "res://TCP/枪/1670.tcp", 1, [], 0)
	EquipData.register_named("枪_1680", EquipData.SlotType.WEAPON,
		"枪1680", {}, "res://TCP/枪/1680.tcp", 1, [], 0)

	# ═══════════════════════════════════
	# 棍（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("棍_1801", EquipData.SlotType.WEAPON,
		"棍1801", {}, "res://TCP/棍/1801.tcp", 1, [], 0)
	EquipData.register_named("棍_1802", EquipData.SlotType.WEAPON,
		"棍1802", {}, "res://TCP/棍/1802.tcp", 1, [], 0)
	EquipData.register_named("棍_1803", EquipData.SlotType.WEAPON,
		"棍1803", {}, "res://TCP/棍/1803.tcp", 1, [], 0)
	EquipData.register_named("棍_1804", EquipData.SlotType.WEAPON,
		"棍1804", {}, "res://TCP/棍/1804.tcp", 1, [], 0)
	EquipData.register_named("棍_1805", EquipData.SlotType.WEAPON,
		"棍1805", {}, "res://TCP/棍/1805.tcp", 1, [], 0)
	EquipData.register_named("棍_1806", EquipData.SlotType.WEAPON,
		"棍1806", {}, "res://TCP/棍/1806.tcp", 1, [], 0)
	EquipData.register_named("棍_1807", EquipData.SlotType.WEAPON,
		"棍1807", {}, "res://TCP/棍/1807.tcp", 1, [], 0)
	EquipData.register_named("棍_1808", EquipData.SlotType.WEAPON,
		"棍1808", {}, "res://TCP/棍/1808.tcp", 1, [], 0)
	EquipData.register_named("棍_1809", EquipData.SlotType.WEAPON,
		"棍1809", {}, "res://TCP/棍/1809.tcp", 1, [], 0)
	EquipData.register_named("棍_1850", EquipData.SlotType.WEAPON,
		"棍1850", {}, "res://TCP/棍/1850.tcp", 1, [], 0)
	EquipData.register_named("棍_1851", EquipData.SlotType.WEAPON,
		"棍1851", {}, "res://TCP/棍/1851.tcp", 1, [], 0)
	EquipData.register_named("棍_1852", EquipData.SlotType.WEAPON,
		"棍1852", {}, "res://TCP/棍/1852.tcp", 1, [], 0)
	EquipData.register_named("棍_1860", EquipData.SlotType.WEAPON,
		"棍1860", {}, "res://TCP/棍/1860.tcp", 1, [], 0)
	EquipData.register_named("棍_1861", EquipData.SlotType.WEAPON,
		"棍1861", {}, "res://TCP/棍/1861.tcp", 1, [], 0)
	EquipData.register_named("棍_1862", EquipData.SlotType.WEAPON,
		"棍1862", {}, "res://TCP/棍/1862.tcp", 1, [], 0)
	EquipData.register_named("棍_1870", EquipData.SlotType.WEAPON,
		"棍1870", {}, "res://TCP/棍/1870.tcp", 1, [], 0)
	EquipData.register_named("棍_1880", EquipData.SlotType.WEAPON,
		"棍1880", {}, "res://TCP/棍/1880.tcp", 1, [], 0)

	# ═══════════════════════════════════
	# 灯（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("灯_31201", EquipData.SlotType.WEAPON,
		"灯31201", {}, "res://TCP/灯/31201.tcp", 1, [], 0)
	EquipData.register_named("灯_31202", EquipData.SlotType.WEAPON,
		"灯31202", {}, "res://TCP/灯/31202.tcp", 1, [], 0)
	EquipData.register_named("灯_31203", EquipData.SlotType.WEAPON,
		"灯31203", {}, "res://TCP/灯/31203.tcp", 1, [], 0)
	EquipData.register_named("灯_31204", EquipData.SlotType.WEAPON,
		"灯31204", {}, "res://TCP/灯/31204.tcp", 1, [], 0)
	EquipData.register_named("灯_31205", EquipData.SlotType.WEAPON,
		"灯31205", {}, "res://TCP/灯/31205.tcp", 1, [], 0)
	EquipData.register_named("灯_31206", EquipData.SlotType.WEAPON,
		"灯31206", {}, "res://TCP/灯/31206.tcp", 1, [], 0)
	EquipData.register_named("灯_31207", EquipData.SlotType.WEAPON,
		"灯31207", {}, "res://TCP/灯/31207.tcp", 1, [], 0)
	EquipData.register_named("灯_31208", EquipData.SlotType.WEAPON,
		"灯31208", {}, "res://TCP/灯/31208.tcp", 1, [], 0)
	EquipData.register_named("灯_31209", EquipData.SlotType.WEAPON,
		"灯31209", {}, "res://TCP/灯/31209.tcp", 1, [], 0)
	EquipData.register_named("灯_31250", EquipData.SlotType.WEAPON,
		"灯31250", {}, "res://TCP/灯/31250.tcp", 1, [], 0)
	EquipData.register_named("灯_31251", EquipData.SlotType.WEAPON,
		"灯31251", {}, "res://TCP/灯/31251.tcp", 1, [], 0)
	EquipData.register_named("灯_31252", EquipData.SlotType.WEAPON,
		"灯31252", {}, "res://TCP/灯/31252.tcp", 1, [], 0)
	EquipData.register_named("灯_31260", EquipData.SlotType.WEAPON,
		"灯31260", {}, "res://TCP/灯/31260.tcp", 1, [], 0)
	EquipData.register_named("灯_31261", EquipData.SlotType.WEAPON,
		"灯31261", {}, "res://TCP/灯/31261.tcp", 1, [], 0)
	EquipData.register_named("灯_31262", EquipData.SlotType.WEAPON,
		"灯31262", {}, "res://TCP/灯/31262.tcp", 1, [], 0)
	EquipData.register_named("灯_31270", EquipData.SlotType.WEAPON,
		"灯31270", {}, "res://TCP/灯/31270.tcp", 1, [], 0)
	EquipData.register_named("灯_31280", EquipData.SlotType.WEAPON,
		"灯31280", {}, "res://TCP/灯/31280.tcp", 1, [], 0)

	# ═══════════════════════════════════
	# 爪（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("爪_1301", EquipData.SlotType.WEAPON,
		"爪1301", {}, "res://TCP/爪/1301.tcp", 1, [], 0)
	EquipData.register_named("爪_1302", EquipData.SlotType.WEAPON,
		"爪1302", {}, "res://TCP/爪/1302.tcp", 1, [], 0)
	EquipData.register_named("爪_1303", EquipData.SlotType.WEAPON,
		"爪1303", {}, "res://TCP/爪/1303.tcp", 1, [], 0)
	EquipData.register_named("爪_1304", EquipData.SlotType.WEAPON,
		"爪1304", {}, "res://TCP/爪/1304.tcp", 1, [], 0)
	EquipData.register_named("爪_1305", EquipData.SlotType.WEAPON,
		"爪1305", {}, "res://TCP/爪/1305.tcp", 1, [], 0)
	EquipData.register_named("爪_1306", EquipData.SlotType.WEAPON,
		"爪1306", {}, "res://TCP/爪/1306.tcp", 1, [], 0)
	EquipData.register_named("爪_1307", EquipData.SlotType.WEAPON,
		"爪1307", {}, "res://TCP/爪/1307.tcp", 1, [], 0)
	EquipData.register_named("爪_1308", EquipData.SlotType.WEAPON,
		"爪1308", {}, "res://TCP/爪/1308.tcp", 1, [], 0)
	EquipData.register_named("爪_1309", EquipData.SlotType.WEAPON,
		"爪1309", {}, "res://TCP/爪/1309.tcp", 1, [], 0)
	EquipData.register_named("爪_1350", EquipData.SlotType.WEAPON,
		"爪1350", {}, "res://TCP/爪/1350.tcp", 1, [], 0)
	EquipData.register_named("爪_1351", EquipData.SlotType.WEAPON,
		"爪1351", {}, "res://TCP/爪/1351.tcp", 1, [], 0)
	EquipData.register_named("爪_1352", EquipData.SlotType.WEAPON,
		"爪1352", {}, "res://TCP/爪/1352.tcp", 1, [], 0)
	EquipData.register_named("爪_1360", EquipData.SlotType.WEAPON,
		"爪1360", {}, "res://TCP/爪/1360.tcp", 1, [], 0)
	EquipData.register_named("爪_1361", EquipData.SlotType.WEAPON,
		"爪1361", {}, "res://TCP/爪/1361.tcp", 1, [], 0)
	EquipData.register_named("爪_1362", EquipData.SlotType.WEAPON,
		"爪1362", {}, "res://TCP/爪/1362.tcp", 1, [], 0)
	EquipData.register_named("爪_1370", EquipData.SlotType.WEAPON,
		"爪1370", {}, "res://TCP/爪/1370.tcp", 1, [], 0)
	EquipData.register_named("爪_1380", EquipData.SlotType.WEAPON,
		"爪1380", {}, "res://TCP/爪/1380.tcp", 1, [], 0)

	# ═══════════════════════════════════
	# 锤（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("流星锤", EquipData.SlotType.WEAPON,
		"流星锤", {"dmg": 112}, "res://TCP/锤/1205.tcp", 10, [], 1350)
	EquipData.register_named("锤_1201", EquipData.SlotType.WEAPON,
		"锤1201", {}, "res://TCP/锤/1201.tcp", 1, [], 0)
	EquipData.register_named("锤_1202", EquipData.SlotType.WEAPON,
		"锤1202", {}, "res://TCP/锤/1202.tcp", 1, [], 0)
	EquipData.register_named("锤_1203", EquipData.SlotType.WEAPON,
		"锤1203", {}, "res://TCP/锤/1203.tcp", 1, [], 0)
	EquipData.register_named("锤_1204", EquipData.SlotType.WEAPON,
		"锤1204", {}, "res://TCP/锤/1204.tcp", 1, [], 0)
	EquipData.register_named("锤_1206", EquipData.SlotType.WEAPON,
		"锤1206", {}, "res://TCP/锤/1206.tcp", 1, [], 0)
	EquipData.register_named("锤_1207", EquipData.SlotType.WEAPON,
		"锤1207", {}, "res://TCP/锤/1207.tcp", 1, [], 0)
	EquipData.register_named("锤_1208", EquipData.SlotType.WEAPON,
		"锤1208", {}, "res://TCP/锤/1208.tcp", 1, [], 0)
	EquipData.register_named("锤_1209", EquipData.SlotType.WEAPON,
		"锤1209", {}, "res://TCP/锤/1209.tcp", 1, [], 0)
	EquipData.register_named("锤_1250", EquipData.SlotType.WEAPON,
		"锤1250", {}, "res://TCP/锤/1250.tcp", 1, [], 0)
	EquipData.register_named("锤_1251", EquipData.SlotType.WEAPON,
		"锤1251", {}, "res://TCP/锤/1251.tcp", 1, [], 0)
	EquipData.register_named("锤_1252", EquipData.SlotType.WEAPON,
		"锤1252", {}, "res://TCP/锤/1252.tcp", 1, [], 0)
	EquipData.register_named("锤_1260", EquipData.SlotType.WEAPON,
		"锤1260", {}, "res://TCP/锤/1260.tcp", 1, [], 0)
	EquipData.register_named("锤_1261", EquipData.SlotType.WEAPON,
		"锤1261", {}, "res://TCP/锤/1261.tcp", 1, [], 0)
	EquipData.register_named("锤_1262", EquipData.SlotType.WEAPON,
		"锤1262", {}, "res://TCP/锤/1262.tcp", 1, [], 0)
	EquipData.register_named("锤_1270", EquipData.SlotType.WEAPON,
		"锤1270", {}, "res://TCP/锤/1270.tcp", 1, [], 0)
	EquipData.register_named("锤_1280", EquipData.SlotType.WEAPON,
		"锤1280", {}, "res://TCP/锤/1280.tcp", 1, [], 0)

	# ═══════════════════════════════════
	# 鞭（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("鞭_1701", EquipData.SlotType.WEAPON,
		"鞭1701", {}, "res://TCP/鞭/1701.tcp", 1, [], 0)
	EquipData.register_named("鞭_1702", EquipData.SlotType.WEAPON,
		"鞭1702", {}, "res://TCP/鞭/1702.tcp", 1, [], 0)
	EquipData.register_named("鞭_1703", EquipData.SlotType.WEAPON,
		"鞭1703", {}, "res://TCP/鞭/1703.tcp", 1, [], 0)
	EquipData.register_named("鞭_1704", EquipData.SlotType.WEAPON,
		"鞭1704", {}, "res://TCP/鞭/1704.tcp", 1, [], 0)
	EquipData.register_named("鞭_1705", EquipData.SlotType.WEAPON,
		"鞭1705", {}, "res://TCP/鞭/1705.tcp", 1, [], 0)
	EquipData.register_named("鞭_1706", EquipData.SlotType.WEAPON,
		"鞭1706", {}, "res://TCP/鞭/1706.tcp", 1, [], 0)
	EquipData.register_named("鞭_1707", EquipData.SlotType.WEAPON,
		"鞭1707", {}, "res://TCP/鞭/1707.tcp", 1, [], 0)
	EquipData.register_named("鞭_1708", EquipData.SlotType.WEAPON,
		"鞭1708", {}, "res://TCP/鞭/1708.tcp", 1, [], 0)
	EquipData.register_named("鞭_1709", EquipData.SlotType.WEAPON,
		"鞭1709", {}, "res://TCP/鞭/1709.tcp", 1, [], 0)
	EquipData.register_named("鞭_1750", EquipData.SlotType.WEAPON,
		"鞭1750", {}, "res://TCP/鞭/1750.tcp", 1, [], 0)
	EquipData.register_named("鞭_1751", EquipData.SlotType.WEAPON,
		"鞭1751", {}, "res://TCP/鞭/1751.tcp", 1, [], 0)
	EquipData.register_named("鞭_1752", EquipData.SlotType.WEAPON,
		"鞭1752", {}, "res://TCP/鞭/1752.tcp", 1, [], 0)
	EquipData.register_named("鞭_1760", EquipData.SlotType.WEAPON,
		"鞭1760", {}, "res://TCP/鞭/1760.tcp", 1, [], 0)
	EquipData.register_named("鞭_1761", EquipData.SlotType.WEAPON,
		"鞭1761", {}, "res://TCP/鞭/1761.tcp", 1, [], 0)
	EquipData.register_named("鞭_1762", EquipData.SlotType.WEAPON,
		"鞭1762", {}, "res://TCP/鞭/1762.tcp", 1, [], 0)
	EquipData.register_named("鞭_1770", EquipData.SlotType.WEAPON,
		"鞭1770", {}, "res://TCP/鞭/1770.tcp", 1, [], 0)
	EquipData.register_named("鞭_1780", EquipData.SlotType.WEAPON,
		"鞭1780", {}, "res://TCP/鞭/1780.tcp", 1, [], 0)
