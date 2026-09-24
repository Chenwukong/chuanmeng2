# EquipDB.gd — 命名装备全量注册（对应 TCP/ 下的图标）
# 所有 register_named 都集中在这里维护：改 ID/名称/品质/基础属性/等级/价格即可生效。
# 武器类别 weapon_type 自动从 tcp_path 的 TCP 子目录推断；角色限制见 CharacterDB.weapons；
# 上架商店：把注册 id 填进 GameData.EQUIP_SHOP_TABLE 的对应等级档。


#枚举	名称	效果（calc_stats 里） 词缀
#LIFESTEAL	吸血	吸血 +N%
#STRENGTH	力量	攻击 ×(1+N%)
#INTELLECT	智力	法防 ×(1+N%)
#CRIT_RATE	暴击率	运气 +N
#CRIT_DMG	暴击伤害	暴伤 +N%
#HASTE	急速	速度 ×(1+N%)
#PENETRATION	穿透	穿透 +N%
#MAX_HP	气血	气血 ×(1+N%)
#MAX_MP	灵力	灵力 ×(1+N%)
#LUCK	运气	运气 +N

class_name EquipDB
extends RefCounted

## 在 GameData._init_equip_db 中调用
static func register_all() -> void:
	# ═══════════════════════════════════
	# 腰带（EquipData.SlotType.BELT）
	# ═══════════════════════════════════
	EquipData.register_named("缎带", EquipData.SlotType.BELT,
		"缎带", {"hp": 80}, "res://TCP/腰带/2902.tcp", 1, [], 100, "高级丝绸制成的腰带，能起到不错的防御作用")
	EquipData.register_named("银腰带", EquipData.SlotType.BELT,
		"银腰带", {"hp": 60}, "res://TCP/腰带/2903.tcp", 1, [], 80, "银制的腰带，可以起到防御的作用")
	EquipData.register_named("琥珀腰带", EquipData.SlotType.BELT,
		"琥珀腰带", {"hp": 140}, "res://TCP/腰带/2906.tcp", 1, [], 300, "用琥珀制的腰链，能起到较强的防御作用")
	EquipData.register_named("equip_2908", EquipData.SlotType.BELT,
		"乱牙咬", {"hp": 180}, "res://TCP/腰带/2908.tcp", 1, [], 400, "神铁制的腰箍，能起到较强的防御作用")
	EquipData.register_named("攫魂铃", EquipData.SlotType.BELT,
		"攫魂铃", {"hp": 260}, "res://TCP/腰带/2910.tcp", 1, [], 800, "来自阴间的魔铃，佩在腰间，能起到极强的防御作用")
	EquipData.register_named("equip_2912", EquipData.SlotType.BELT,
		"兽王腰带", {"hp": 340}, "res://TCP/腰带/2912.tcp", 1, [], 1200,"	兽王曾使用过的腰饰，能起到较强的防御作用")
	EquipData.register_named("幻彩玉带", EquipData.SlotType.BELT,
		"幻彩玉带", {"hp": 480}, "res://TCP/腰带/2950.tcp", 1, [], 2500, "以集天界灵气之幻彩宝玉制成，有强大的护佑作用")
	EquipData.register_named("珠翠玉环", EquipData.SlotType.BELT,
		"珠翠玉环", {"hp": 50}, "res://TCP/腰带/2952.tcp", 1, [], 50, "集合千年地气生出的翡翠宝珠雕琢而成的腰带，有强大的庇佑作用。")
	EquipData.register_named("金蟾含珠", EquipData.SlotType.BELT,
		"金蟾含珠", {"hp": 70, "gold_boost": 5}, "res://TCP/腰带/2953.tcp", 1, [{"type": EquipData.AffixType.MAX_HP, "value": 10}], 60, "相传“蟾”能口吐金钱为旺财之物。由金身蟾口含夜光珠再辅以金丝编织而成的腰带，世间少有，绝非人界之物。")
	EquipData.register_named("乾坤紫玉带", EquipData.SlotType.BELT,
		"乾坤紫玉带", {"hp": 160}, "res://TCP/腰带/2954.tcp", 1, [], 350, "千年紫玉雕琢而成的腰带，相传为道家失传的宝物，有极强的庇佑作用。")
	EquipData.register_named("琉璃寒玉带", EquipData.SlotType.BELT,
		"琉璃寒玉带", {"hp": 440, "spd": 12}, "res://TCP/腰带/2955.tcp", 1, [], 3000, "天界银河之水经亿万年凝结而成的玉石制成的腰带，不为寻常仙物。")
	EquipData.register_named("蝉翼鱼佩带", EquipData.SlotType.BELT,
		"蝉翼鱼佩带", {"hp": 460, "atk": 15}, "res://TCP/腰带/2956.tcp", 1, [], 3200, "月宫桂树上的灵蝉身上的蝉翼以及金丝编织而成的腰带，所散发出来的灵气能抵御极强的伤害。")
	EquipData.register_named("磐龙凤翔带", EquipData.SlotType.BELT,
		"磐龙凤翔带", {"hp": 600, "spd": 2000}, "res://TCP/腰带/2957.tcp", 1, [], 6000, "远古天神遗物，龙飞凤舞呈吉祥之态，佩戴起来能受到上古神兽的庇护。")
	EquipData.register_named("紫霄云芒带", EquipData.SlotType.BELT,
		"紫霄云芒带", {"hp": 750, "def": 30}, "res://TCP/腰带/2958.tcp", 1, [], 80000, "以云霞束起雷电所制成的腰带，会散发出闪电自行防御来袭的攻击。")

	# ═══════════════════════════════════
	# 衣服（EquipData.SlotType.BODY）
	# ═══════════════════════════════════
	EquipData.register_named("布衣", EquipData.SlotType.BODY,
		"布衣", {"hp": 150, "def": 30}, "res://TCP/衣服/2601.tcp", 1, [], 8000, "普通的布衣，可以起到防御的作用")
	EquipData.register_named("皮衣", EquipData.SlotType.BODY,
		"皮衣", {"hp": 750, "def": 30}, "res://TCP/衣服/2602.tcp", 1, [], 8000, "用兽皮制的皮衣，防御力较布衣要好的多")
	EquipData.register_named("鳞甲", EquipData.SlotType.BODY,
		"鳞甲", {"hp": 750, "def": 30}, "res://TCP/衣服/2603.tcp", 1, [], 8000, "用铁鳞制成的铠甲，有相当的防御力")
	EquipData.register_named("锁子甲", EquipData.SlotType.BODY,
		"锁子甲", {"hp": 750, "def": 30}, "res://TCP/衣服/2604.tcp", 1, [], 8000, "胸部是铁环，如铁锁加身，防御力相当不错")
	EquipData.register_named("钢甲", EquipData.SlotType.BODY,
		"钢甲", {"hp": 750, "def": 30}, "res://TCP/衣服/2606.tcp", 1, [], 8000, "用精钢制成的铠甲，防御能力较强")
	EquipData.register_named("夜魔披风", EquipData.SlotType.BODY,
		"夜魔披风", {"hp": 750, "def": 30}, "res://TCP/衣服/2607.tcp", 1, [], 8000, "来自阴间的披风，隐隐透出神秘的幽冥气息")
	EquipData.register_named("龙骨甲", EquipData.SlotType.BODY,
		"龙骨甲", {"hp": 750, "def": 30}, "res://TCP/衣服/2608.tcp", 1, [], 8000, "以龙骨制成的宝甲，有惊人的防御力")
	EquipData.register_named("神谕披风", EquipData.SlotType.BODY,
		"神谕披风", {"hp": 750, "def": 30}, "res://TCP/衣服/2650.tcp", 1, [], 8000, "受到神谕祝福的银色披风，带有灵动之气")
	EquipData.register_named("金蚕披风", EquipData.SlotType.BODY,
		"金蚕披风", {"hp": 750, "def": 30}, "res://TCP/衣服/2653.tcp", 1, [], 8000, "由千年玉桑上的金蚕吐丝为材料缝制而成的衣甲，有极强的韧性。")
	EquipData.register_named("蝉翼金丝甲", EquipData.SlotType.BODY,
		"蝉翼金丝甲", {"hp": 750, "def": 30}, "res://TCP/衣服/2655.tcp", 70, [], 8000, "月宫桂树上的灵蝉身上的蝉翼辅以金丝编织而成的铠甲。绝非寻常仙家之物。")
	EquipData.register_named("金丝鱼鳞甲", EquipData.SlotType.BODY,
		"金丝鱼鳞甲", {"hp": 750, "def": 30}, "res://TCP/衣服/2656.tcp", 70, [], 8000, "水神遗留之物。时隔千年，依然充满着灵气。")
	EquipData.register_named("紫金磐龙甲", EquipData.SlotType.BODY,
		"紫金磐龙甲", {"hp": 750, "def": 30}, "res://TCP/衣服/2657.tcp", 70, [], 8000, "相传为黄帝的遗物。紫金磐龙，四周散发着神奇的力量。")
	EquipData.register_named("混元一气甲", EquipData.SlotType.BODY,
		"混元一气甲", {"hp": 750, "def": 30}, "res://TCP/衣服/2658.tcp", 70, [], 8000, "混元一气所凝成的宝甲，至坚不摧之物，可与天地同寿。")

	# ═══════════════════════════════════
	# 头盔（EquipData.SlotType.HEAD）
	# ═══════════════════════════════════
	EquipData.register_named("方巾", EquipData.SlotType.HEAD,
		"方巾", {}, "res://TCP/头盔/方巾.tcp", 1, [], 0, "普通人常带的帽子")
	EquipData.register_named("面具", EquipData.SlotType.HEAD,
		"面具", {}, "res://TCP/头盔/面具.tcp", 1, [], 0, "用皮制的面具，可以起到防御的作用")
	EquipData.register_named("羊角盔", EquipData.SlotType.HEAD,
		"羊角盔", {}, "res://TCP/头盔/羊角盔.tcp", 1, [], 0, "以羊角为装饰的盔，有非常强的防御力")
	EquipData.register_named("水晶帽", EquipData.SlotType.HEAD,
		"水晶帽", {}, "res://TCP/头盔/水晶帽.tcp", 1, [], 0, "水晶制成的帽子，因为坚硬，有相当强的防御力")
	EquipData.register_named("白玉琉璃冠", EquipData.SlotType.HEAD,
		"白玉琉璃冠", {}, "res://TCP/头盔/白玉琉璃冠.tcp", 1, [], 0, "太上老君曾佩戴过的冠帽，用仙界白玉与琉璃珠辅以天丝编织而成。")
	EquipData.register_named("黑魔冠", EquipData.SlotType.HEAD,
		"黑魔冠", {}, "res://TCP/头盔/黑魔冠.tcp", 1, [], 0, "魔王妖王常戴的冠帽，有相当强的防御力")
	EquipData.register_named("兽鬼珐琅面", EquipData.SlotType.HEAD,
		"兽鬼珐琅面", {}, "res://TCP/头盔/兽鬼珐琅面.tcp", 1, [], 0, "上古神魔所戴，虽经几千年，面具独角四周仍散发着神奇的魔力。")
	EquipData.register_named("水晶夔帽", EquipData.SlotType.HEAD,
		"水晶夔帽", {}, "res://TCP/头盔/水晶夔帽.tcp", 1, [], 0, "“其状如牛,苍色无角,一足能走,出入水即风雨,目光如日月,其声如雷,名曰夔。黄帝杀之,取皮以冒鼓,声闻五百里。”相传远古奇兽夔牛皮最终为一能工巧匠所得，辅以水晶玉石经千锤百炼雕琢编制而成一件冠帽。据传此帽拥有奇兽的庇佑，千年不坏。")
	EquipData.register_named("金丝黑玉冠", EquipData.SlotType.HEAD,
		"金丝黑玉冠", {}, "res://TCP/头盔/金丝黑玉冠.tcp", 1, [], 0, "远古盘古开天辟地，混沌初开时凝结而成的玉石雕琢而成的冠帽，充满着神奇的灵气。")
	EquipData.register_named("紫金磐龙冠", EquipData.SlotType.HEAD,
		"紫金磐龙冠", {}, "res://TCP/头盔/紫金磐龙冠.tcp", 1, [], 0, "火神遗留之物。冠上用金雕琢为吉龙盘云，四周散发着神奇的力量。需要有一定修为之人方能佩戴。")
	EquipData.register_named("浑天玄火盔", EquipData.SlotType.HEAD,
		"浑天玄火盔", {}, "res://TCP/头盔/浑天玄火盔.tcp", 1, [], 0, "黄帝征伐四方之时所配战盔，刀枪不入，水火不侵，瘟邪难近，更添无尽战意。")

	# 带（EquipData.SlotType.BELT）
	# ═══════════════════════════════════
	EquipData.register_named("五色缎带", EquipData.SlotType.BELT,
		"五色缎带", {}, "res://TCP/带/1901.tcp", 1, [], 0, "五色蚕丝织成的彩缎")
	EquipData.register_named("幻彩银纱", EquipData.SlotType.BELT,
		"幻彩银纱", {}, "res://TCP/带/1902.tcp", 1, [], 0, "上等蚕丝与银丝混织成的纱带")
	EquipData.register_named("金丝彩带", EquipData.SlotType.BELT,
		"金丝彩带", {}, "res://TCP/带/1903.tcp", 1, [], 0, "金丝与彩缎编成的丝带")
	EquipData.register_named("无极丝", EquipData.SlotType.BELT,
		"无极丝", {}, "res://TCP/带/1904.tcp", 1, [], 0, "天地无极尽收于其间")
	EquipData.register_named("天蚕丝带", EquipData.SlotType.BELT,
		"天蚕丝带", {}, "res://TCP/带/1905.tcp", 1, [], 0, "以名贵天蚕丝制成，可通生命之灵气")
	EquipData.register_named("云龙绸带", EquipData.SlotType.BELT,
		"云龙绸带", {}, "res://TCP/带/1906.tcp", 1, [], 0, "绸如云彩，龙隐其间")
	EquipData.register_named("七彩罗刹", EquipData.SlotType.BELT,
		"七彩罗刹", {}, "res://TCP/带/1907.tcp", 1, [], 0, "用各式丝绸编织而成的丝带")
	EquipData.register_named("缚神绫", EquipData.SlotType.BELT,
		"缚神绫", {}, "res://TCP/带/1908.tcp", 1, [], 0, "丝带可紧可松，传言可缚神灵")
	EquipData.register_named("九天仙绫", EquipData.SlotType.BELT,
		"九天仙绫", {}, "res://TCP/带/1909.tcp", 1, [], 0, "存于九天，吸日月玄灵")
	EquipData.register_named("彩虹", EquipData.SlotType.BELT,
		"彩虹", {}, "res://TCP/带/1950.tcp", 1, [], 0, "以七彩天蚕丝制成，似天边彩虹")
	EquipData.register_named("流云", EquipData.SlotType.BELT,
		"流云", {}, "res://TCP/带/1951.tcp", 1, [], 0, "流光溢彩，似天边云彩幻生幻灭")
	EquipData.register_named("碧波", EquipData.SlotType.BELT,
		"碧波", {}, "res://TCP/带/1952.tcp", 1, [], 0, "聚海之灵气，碧波起，天地清")
	EquipData.register_named("秋水落霞", EquipData.SlotType.BELT,
		"秋水落霞", {}, "res://TCP/带/1960.tcp", 1, [], 0, "“落霞与孤鹜齐飞，秋水共长天一色。”此带乃天女掬长空之色，染落霞之艳织成。展开绚烂无比，使人俗念顿消，心无点尘。")
	EquipData.register_named("晃金仙绳", EquipData.SlotType.BELT,
		"晃金仙绳", {}, "res://TCP/带/1961.tcp", 1, [], 0, "此物可随主人意捆住神仙魔怪，令其不能再施展变化之术。且此绳坚韧异常，火烧刀砍不断。")
	EquipData.register_named("此最相思", EquipData.SlotType.BELT,
		"此最相思", {}, "res://TCP/带/1962.tcp", 1, [], 0, "“道是无情却有情，从来最苦是相思。”此物乃太虚幻境警幻仙子敕令还情债之物，一旦缠住，至死方休；虽有金石心，也顿为绕指柔，神仙难逃。")
	EquipData.register_named("揽月摘星", EquipData.SlotType.BELT,
		"揽月摘星", {}, "res://TCP/带/1970.tcp", 1, [], 0, "翩若惊鸿，婉若游龙，仿佛兮若轻云之蔽月，飘飖兮若流风之回雪。三垣为画布，此带为软毫，可清夜起舞，拟为漫天星宿平添花鸟虫鱼。")
	EquipData.register_named("九霄", EquipData.SlotType.BELT,
		"九霄", {}, "res://TCP/带/1980.tcp", 1, [], 0, "九霄澄云所凝，诸天护佑，乾坤氤氲。形随意动，其高则冠盖乎九霄，其旷则笼罩乎八隅，祥瑞纷现，异香扑鼻。")

	# ═══════════════════════════════════
	# 鞋子（EquipData.SlotType.SHOES）
	# ═══════════════════════════════════
	EquipData.register_named("布鞋", EquipData.SlotType.SHOES,
		"布鞋", {"spd": 5}, "res://TCP/鞋子/布鞋.tcp", 1, [], 0, "布缝制的鞋子，可以起到防御的作用")
	EquipData.register_named("绿靴", EquipData.SlotType.SHOES,
		"绿靴", {}, "res://TCP/鞋子/绿靴.tcp", 1, [], 0, "绿水晶制成的鞋子，防御作用非常的强")
	EquipData.register_named("马靴", EquipData.SlotType.SHOES,
		"马靴", {}, "res://TCP/鞋子/马靴.tcp", 1, [], 0, "皮制的马靴，可以起到防御的作用")
	EquipData.register_named("平步青云", EquipData.SlotType.SHOES,
		"平步青云", {}, "res://TCP/鞋子/平步青云.tcp", 1, [], 0, "寻常仙界之物，穿上此靴可平步青云，借风云飞腾。")
	EquipData.register_named("神行靴", EquipData.SlotType.SHOES,
		"神行靴", {}, "res://TCP/鞋子/神行靴.tcp", 1, [], 0, "非常轻便的靴子，可以起到防御的作用")
	EquipData.register_named("踏雪无痕", EquipData.SlotType.SHOES,
		"踏雪无痕", {}, "res://TCP/鞋子/踏雪无痕.tcp", 1, [], 0, "包蓄地之灵气，穿之幻影如风，踏雪无痕")
	EquipData.register_named("追云逐电", EquipData.SlotType.SHOES,
		"追云逐电", {}, "res://TCP/鞋子/追云逐电.tcp", 1, [], 0, "相传为雷公电母经过千万年炼化而成，穿上后可以追逐云电，日行万里。")
	EquipData.register_named("碧霞流云履", EquipData.SlotType.SHOES,
		"碧霞流云履", {}, "res://TCP/鞋子/碧霞流云履.tcp", 1, [], 0, "相传天界神匠以五彩天霞为材料，缝制而成的靴子。")
	EquipData.register_named("金丝逐日履", EquipData.SlotType.SHOES,
		"金丝逐日履", {}, "res://TCP/鞋子/金丝逐日履.tcp", 1, [], 0, "相传神匠为纪念夸父特造此靴。穿上可追逐太阳，风云皆抛于脑后。")
	EquipData.register_named("七星逐月靴", EquipData.SlotType.SHOES,
		"七星逐月靴", {}, "res://TCP/鞋子/七星逐月靴.tcp", 1, [], 0, "天罡星所穿之靴。穿之及疾如风，三界之地任我遨游。")
	EquipData.register_named("乾坤天罡履", EquipData.SlotType.SHOES,
		"乾坤天罡履", {}, "res://TCP/鞋子/乾坤天罡履.tcp", 1, [], 0, "相传为太上老君所穿。乃天地之气编织而成。")
	EquipData.register_named("辟尘分光履", EquipData.SlotType.SHOES,
		"辟尘分光履", {}, "res://TCP/鞋子/辟尘分光履.tcp", 1, [], 0, "上古秘宝，着此履者可于星尘间穿梭，与霞光相竞逐。")
	# 饰品（EquipData.SlotType.NECKLACE）
	# ═══════════════════════════════════
	EquipData.register_named("护身符", EquipData.SlotType.NECKLACE,
		"护身符", {}, "res://TCP/饰品/2801.tcp", 1, [], 0, "一块护身符，佩带在身上有一定法力作用")
	EquipData.register_named("五色飞石", EquipData.SlotType.NECKLACE,
		"五色飞石", {}, "res://TCP/饰品/2802.tcp", 1, [], 0, "仙人炼制的饰品，佩带在身上有极强的法力作用")
	EquipData.register_named("珍珠链", EquipData.SlotType.NECKLACE,
		"珍珠链", {}, "res://TCP/饰品/2803.tcp", 1, [], 0, "一串珍珠，佩带在身上有一定法力作用")
	EquipData.register_named("骷髅吊坠", EquipData.SlotType.NECKLACE,
		"骷髅吊坠", {}, "res://TCP/饰品/2804.tcp", 1, [], 0, "皮绳上吊着一个骷髅，佩带在身上有一定法力作用")
	EquipData.register_named("苍魂珠", EquipData.SlotType.NECKLACE,
		"苍魂珠", {}, "res://TCP/饰品/2805.tcp", 1, [], 0, "据说珠里附有魂魄，佩带在身上有较强的法力作用")
	EquipData.register_named("江湖夜雨", EquipData.SlotType.NECKLACE,
		"江湖夜雨", {}, "res://TCP/饰品/2806.tcp", 1, [], 0, "流传于中土的奇异饰物，佩带在身上有较强的法力作用")
	EquipData.register_named("九宫坠", EquipData.SlotType.NECKLACE,
		"九宫坠", {}, "res://TCP/饰品/2807.tcp", 1, [], 0, "以九宫制成的坠子，佩带在身上有较强的法力作用")
	EquipData.register_named("荧光坠子", EquipData.SlotType.NECKLACE,
		"荧光坠子", {}, "res://TCP/饰品/2808.tcp", 1, [], 0, "有荧光的宝石，佩带在身上有相当强的法力作用")
	EquipData.register_named("高速之星", EquipData.SlotType.NECKLACE,
		"高速之星", {}, "res://TCP/饰品/2809.tcp", 1, [], 0, "神秘的项圈，来历至今无人知晓")
	EquipData.register_named("风月宝链", EquipData.SlotType.NECKLACE,
		"风月宝链", {}, "res://TCP/饰品/2810.tcp", 1, [], 0, "名家制成的精致饰品，佩带在身上有较强的法力作用")
	EquipData.register_named("八卦坠", EquipData.SlotType.NECKLACE,
		"八卦坠", {}, "res://TCP/饰品/2811.tcp", 1, [], 0, "以八卦制成的饰物，佩带在身上有较强的法力作用")
	EquipData.register_named("碧水青龙", EquipData.SlotType.NECKLACE,
		"碧水青龙", {}, "res://TCP/饰品/2812.tcp", 1, [], 0, "龙形环状可戴在项部，有相当的法力作用")
	EquipData.register_named("鬼牙攫魂", EquipData.SlotType.NECKLACE,
		"鬼牙攫魂", {}, "res://TCP/饰品/2813.tcp", 1, [], 0, "来自阴间的饰物，佩带在身上有较强的法力作用")
	EquipData.register_named("万里卷云", EquipData.SlotType.NECKLACE,
		"万里卷云", {}, "res://TCP/饰品/2814.tcp", 1, [], 0, "据说是大禹留下的宝物，佩带在身上有极强的法力作用")
	EquipData.register_named("疾风之铃", EquipData.SlotType.NECKLACE,
		"疾风之铃", {}, "res://TCP/饰品/2815.tcp", 1, [], 0, "来历不详的神秘饰物，佩带在身上有极强的法力作用")
	EquipData.register_named("七彩玲珑", EquipData.SlotType.NECKLACE,
		"七彩玲珑", {}, "res://TCP/饰品/2850.tcp", 1, [], 0, "串有七彩玲珑的珍珠，集海之灵气，给予佩戴者祥瑞祝福")
	EquipData.register_named("黄玉琉佩", EquipData.SlotType.NECKLACE,
		"黄玉琉佩", {}, "res://TCP/饰品/2852.tcp", 1, [], 0, "女娲补天遗留下的神石雕琢而成，拥有神奇的灵力。")
	EquipData.register_named("鸾飞凤舞", EquipData.SlotType.NECKLACE,
		"鸾飞凤舞", {}, "res://TCP/饰品/2853.tcp", 1, [], 0, "仙界仙女们常佩之物。呈祥瑞和平之气，定能给佩戴者带来好运。")
	EquipData.register_named("衔珠金凤佩", EquipData.SlotType.NECKLACE,
		"衔珠金凤佩", {}, "res://TCP/饰品/2854.tcp", 1, [], 0, "相传曾为嫦娥仙子佩戴之物。此物寓示着美好的追求与向往。")
	EquipData.register_named("七璜珠玉佩", EquipData.SlotType.NECKLACE,
		"七璜珠玉佩", {}, "res://TCP/饰品/2855.tcp", 1, [], 0, "以七个天珠以及天丝编制而成的坠子。集天地之灵气，能给予佩戴者吉祥如意。")
	EquipData.register_named("鎏金点翠佩", EquipData.SlotType.NECKLACE,
		"鎏金点翠佩", {}, "res://TCP/饰品/2856.tcp", 1, [], 0, "玉皇大帝平常佩戴之物，集合了仙界之力，给予佩戴者神奇的魔力。")
	EquipData.register_named("紫金碧玺佩", EquipData.SlotType.NECKLACE,
		"紫金碧玺佩", {}, "res://TCP/饰品/2857.tcp", 1, [], 0, "上古神兽遗留之物。四颗碧玉珠似乎依附着神奇的魔力。")
	EquipData.register_named("落霞陨星坠", EquipData.SlotType.NECKLACE,
		"落霞陨星坠", {}, "res://TCP/饰品/2858.tcp", 1, [], 0, "以陨落的星辰制成的宝玉，带有莫名的灵气与能量。")


	# ═══════════════════════════════════
	# 符咒（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("基础符纸", EquipData.SlotType.WEAPON,
		"基础符纸", {"dmg": 10}, "res://TCP/符咒/3290.tcp", 1, [], 120, "最基础的符纸")
	EquipData.register_named("赦令符纸", EquipData.SlotType.WEAPON,
		"赦令符纸", {"dmg": 40}, "res://TCP/符咒/6016.tcp", 10, [], 450, "急急如律令，赦！")
	EquipData.register_named("朱砂符纸", EquipData.SlotType.WEAPON,
		"朱砂符纸", {"dmg": 80}, "res://TCP/符咒/3147.tcp", 20, [{"type": EquipData.AffixType.CRIT_RATE, "value": 8}], 450, "朱砂有镇妖之能")
	EquipData.register_named("疯文符纸", EquipData.SlotType.WEAPON,
		"疯文符纸", {"dmg": 120}, "res://TCP/符咒/0846.tcp", 30, [], 450, "天然印有疯癫文字的原符，竟有奇效")		
	EquipData.register_named("青铜符纸", EquipData.SlotType.WEAPON,
		"青铜符纸", {"dmg": 200}, "res://TCP/符咒/3153.tcp", 40, [], 450, "青铜所做的符纸，已经不能算是纸了吧，打人疼的是符咒本身还是法术呢")		
	EquipData.register_named("魔印符纸", EquipData.SlotType.WEAPON,
		"魔印符纸", {"dmg": 260}, "res://TCP/符咒/3078.tcp", 50, [], 450, "西域传进来的稀有符纸，似乎加上了点他们的法术")					
	EquipData.register_named("耀黑符纸", EquipData.SlotType.WEAPON,
		"耀黑符纸", {"dmg": 320}, "res://TCP/符咒/0865.tcp", 60, [], 70000, "黑色代表着不详，这符纸散发出令人畏惧的气息")			
	EquipData.register_named("八卦符纸", EquipData.SlotType.WEAPON,
		"八卦符纸", {"dmg": 500}, "res://TCP/符咒/0876.tcp", 70, [], 200000, "传闻是仙界之品，三清之作")			
		
	# ═══════════════════════════════════
	# 剑（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("青铜短剑", EquipData.SlotType.WEAPON,
		"青铜短剑", {"dmg": 10}, "res://TCP/剑/1001.tcp", 1, [], 120, "青铜制成，上铸有简单的图案纹饰，初学者练习常用")
	EquipData.register_named("吴越剑", EquipData.SlotType.WEAPON,
		"吴越剑", {"dmg": 58}, "res://TCP/剑/1003.tcp", 5, [], 450, "吴越之地产名剑，极其锐利")
	EquipData.register_named("龙泉剑", EquipData.SlotType.WEAPON,
		"龙泉剑", {"dmg": 110}, "res://TCP/剑/1005.tcp", 10, [], 1400, "精铁铸造，又以龙泉之水淬制，上刻青龙，其利无比。")
	EquipData.register_named("铁齿剑", EquipData.SlotType.WEAPON,
		"铁齿剑", {}, "res://TCP/剑/1002.tcp", 1, [], 0, "铁制的短剑，边缘带齿")
	EquipData.register_named("青锋剑", EquipData.SlotType.WEAPON,
		"青锋剑", {}, "res://TCP/剑/1004.tcp", 1, [], 0, "剑长三尺，用起来方便灵活，是常用的兵器")
	EquipData.register_named("黄金剑", EquipData.SlotType.WEAPON,
		"黄金剑", {}, "res://TCP/剑/1006.tcp", 1, [], 0, "真金铸脊，精钢淬锋，其光灿烂夺人眼，魔障远避不及；沉于渭水，可镇河魔。")
	EquipData.register_named("游龙剑", EquipData.SlotType.WEAPON,
		"游龙剑", {}, "res://TCP/剑/1007.tcp", 1, [], 0, "剑体九曲如龙形，覆鳞片，手弹其锋刃，鸣如龙吟。")
	EquipData.register_named("北斗七星剑", EquipData.SlotType.WEAPON,
		"北斗七星剑", {}, "res://TCP/剑/1008.tcp", 1, [], 0, "精炼白金之铁铸造，有北斗七星之纹饰")
	EquipData.register_named("碧玉剑", EquipData.SlotType.WEAPON,
		"碧玉剑", {}, "res://TCP/剑/1009.tcp", 1, [], 0, "以寒冰碧玉制成，剑身如竹节，刚硬无比，是难得的奇珍。")
	EquipData.register_named("鱼肠", EquipData.SlotType.WEAPON,
		"鱼肠", {}, "res://TCP/剑/1050.tcp", 1, [], 0, "上古名剑，细短柔软，可入鱼腹")
	EquipData.register_named("倚天", EquipData.SlotType.WEAPON,
		"倚天", {}, "res://TCP/剑/1051.tcp", 1, [], 0, "上古名剑，雾中山神铁所制，剑光如电，切金如泥")
	EquipData.register_named("湛卢", EquipData.SlotType.WEAPON,
		"湛卢", {}, "res://TCP/剑/1052.tcp", 1, [], 0, "上古名剑，剑身宽大，湛然如墨，骨锻其脊，血淬其锋，成绝世名剑。")
	EquipData.register_named("魏武青虹", EquipData.SlotType.WEAPON,
		"魏武青虹", {}, "res://TCP/剑/1060.tcp", 1, [], 0, "通体青亮如玉，长八尺余，可于千里外取人首级，吸血如虹。曾为魏王曹操配剑，后在战乱中失传，如今又重现江湖。")
	EquipData.register_named("灵犀神剑", EquipData.SlotType.WEAPON,
		"灵犀神剑", {}, "res://TCP/剑/1061.tcp", 1, [], 0, "剑长七寸，有鼻有眼，与主人心有灵犀。常藏于宝葫芦内，主人有令，则出三丈白光扣敌泥丸宫，尽斩仙魔鬼神。")
	EquipData.register_named("四法青云", EquipData.SlotType.WEAPON,
		"四法青云", {}, "res://TCP/剑/1062.tcp", 1, [], 0, "上有符印，分别为地，火，风，水四字。挥舞时天昏地暗，火蛇狂舞，飞沙走石，龙腾海啸。")
	EquipData.register_named("霜冷九州", EquipData.SlotType.WEAPON,
		"霜冷九州", {}, "res://TCP/剑/1070.tcp", 1, [], 0, "冰晶雪魄，浑然天成；出则霜华满地，朔风回舞。其气凛冽，砭人肌骨；其意萧条，山川寂寥。乃天下至寒至洁之物，惟赤子心可驭之。")
	EquipData.register_named("擒龙", EquipData.SlotType.WEAPON,
		"擒龙", {}, "res://TCP/剑/1080.tcp", 1, [], 0, "上古魔神所铸神兵，可抗八部天龙。型如鱼骨，伸缩随心；刃化千万剑丝，柔如春蚕吐丝，韧如天地经纬。")

	# ═══════════════════════════════════
	# 刀（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("柳叶刀", EquipData.SlotType.WEAPON,
		"柳叶刀", {"dmg": 10}, "res://TCP/刀/1101.tcp", 1, [], 120, "形如柳叶的细弯刀")
	EquipData.register_named("苗刀", EquipData.SlotType.WEAPON,
		"苗刀", {}, "res://TCP/刀/1102.tcp", 1, [], 0, "苗疆常用的兵器，极细极尖锐")
	EquipData.register_named("夜魔弯刀", EquipData.SlotType.WEAPON,
		"夜魔弯刀", {}, "res://TCP/刀/1103.tcp", 1, [], 0, "精钢制成的细弯刀，刀背密布细齿，如夜魔之牙。")
	EquipData.register_named("金背大砍刀", EquipData.SlotType.WEAPON,
		"金背大砍刀", {}, "res://TCP/刀/1104.tcp", 1, [], 0, "刀身挺直，以黄金镶背，刀道沉猛")
	EquipData.register_named("雁翅刀", EquipData.SlotType.WEAPON,
		"雁翅刀", {}, "res://TCP/刀/1105.tcp", 1, [], 0, "刀背布满粗大的锯齿，上挂银环，铿锵入耳如雁过九天")
	EquipData.register_named("破天宝刀", EquipData.SlotType.WEAPON,
		"破天宝刀", {}, "res://TCP/刀/1106.tcp", 1, [], 0, "刀光八面，劈风破天")
	EquipData.register_named("狼牙刀", EquipData.SlotType.WEAPON,
		"狼牙刀", {}, "res://TCP/刀/1107.tcp", 1, [], 0, "精钢打造，刀背密布狼牙锯齿")
	EquipData.register_named("龙鳞宝刀", EquipData.SlotType.WEAPON,
		"龙鳞宝刀", {}, "res://TCP/刀/1108.tcp", 1, [], 0, "百炼寒钢打造，以龙鳞为饰，是身份的象征。")
	EquipData.register_named("黑炎魔刀", EquipData.SlotType.WEAPON,
		"黑炎魔刀", {}, "res://TCP/刀/1109.tcp", 1, [], 0, "刀身透出森森鬼气，有着摄人心魄的魔力")
	EquipData.register_named("冷月", EquipData.SlotType.WEAPON,
		"冷月", {}, "res://TCP/刀/1150.tcp", 1, [], 0, "夜清冷，月露眉尖，笑引幽冥路")
	EquipData.register_named("屠龙", EquipData.SlotType.WEAPON,
		"屠龙", {}, "res://TCP/刀/1151.tcp", 1, [], 0, "上古神兵，宝刀屠龙")
	EquipData.register_named("血刃", EquipData.SlotType.WEAPON,
		"血刃", {}, "res://TCP/刀/1152.tcp", 1, [], 0, "血红的刃，血红的光，以血洗天地")
	EquipData.register_named("偃月青龙", EquipData.SlotType.WEAPON,
		"偃月青龙", {}, "res://TCP/刀/1160.tcp", 1, [], 0, "关公之配刀，青龙化刀柄，刀身如半月，百万军中取上将首级如探囊取物。关公死，刀柄不知去向，唯余此刀身。")
	EquipData.register_named("晓风残月", EquipData.SlotType.WEAPON,
		"晓风残月", {}, "res://TCP/刀/1161.tcp", 1, [], 0, "迅如晓风，刃如残月。此非中土大唐之物，乃海外大食国宝刀，其上蛩伏可实现愿望之神明。但如何召唤已不可知。")
	EquipData.register_named("斩妖泣血", EquipData.SlotType.WEAPON,
		"斩妖泣血", {}, "res://TCP/刀/1162.tcp", 1, [], 0, "大唐名匠半生心血所成的宝刀，因其妻子被妖魔所害，故将满腔愤恨倾注于刀中。谁能为他复仇，便以此刀相赠。")
	EquipData.register_named("业火三灾", EquipData.SlotType.WEAPON,
		"业火三灾", {}, "res://TCP/刀/1170.tcp", 1, [], 0, "周身暗红如浴血池，刃裂三线引为三灾，中有赤瞳勾人心火。敌心神既失，十方俱灭，惟余红莲：“汝一念起，业火炽然，非人燔汝，乃汝自燔。”")
	EquipData.register_named("鸣鸿", EquipData.SlotType.WEAPON,
		"鸣鸿", {}, "res://TCP/刀/1180.tcp", 1, [], 0, "刀长三尺，与轩辕剑同炉而成。黄帝见其刀意过盛，恐反噬刀主，欲以轩辕剑毁之；此刀乃化玄红云鹊，穿霞而逝。")

	# ═══════════════════════════════════
	# 双刀（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("双短剑", EquipData.SlotType.WEAPON,
		"双短剑", {}, "res://TCP/双刀/2101.tcp", 1, [], 0, "青铜制的双短剑，制造简单，是练习常用的兵器")
	EquipData.register_named("镔铁双剑", EquipData.SlotType.WEAPON,
		"镔铁双剑", {}, "res://TCP/双刀/2102.tcp", 1, [], 0, "铁制双短剑，轻巧实用")
	EquipData.register_named("龙凤双剑", EquipData.SlotType.WEAPON,
		"龙凤双剑", {}, "res://TCP/双刀/2103.tcp", 1, [], 0, "双剑剑身一刻龙纹一刻凤饰，可同入一鞘")
	EquipData.register_named("竹节双剑", EquipData.SlotType.WEAPON,
		"竹节双剑", {}, "res://TCP/双刀/2104.tcp", 1, [], 0, "精钢制成，剑身似竹节般伸长")
	EquipData.register_named("狼牙双剑", EquipData.SlotType.WEAPON,
		"狼牙双剑", {}, "res://TCP/双刀/2105.tcp", 1, [], 0, "剑身向前方密布粗长的狼牙锯齿，令人胆寒")
	EquipData.register_named("鱼骨双剑", EquipData.SlotType.WEAPON,
		"鱼骨双剑", {}, "res://TCP/双刀/2106.tcp", 1, [], 0, "剑身似鱼骨，长满倒钩刺")
	EquipData.register_named("赤焰双剑", EquipData.SlotType.WEAPON,
		"赤焰双剑", {}, "res://TCP/双刀/2107.tcp", 1, [], 0, "剑身赤红，齿如焰苗窜动，有一股刚烈之势")
	EquipData.register_named("墨玉双剑", EquipData.SlotType.WEAPON,
		"墨玉双剑", {}, "res://TCP/双刀/2108.tcp", 1, [], 0, "体采寒冰墨玉所制，暗光流动")
	EquipData.register_named("梅花双剑", EquipData.SlotType.WEAPON,
		"梅花双剑", {}, "res://TCP/双刀/2109.tcp", 1, [], 0, "千年古木所制，剑似梅枝")
	EquipData.register_named("阴阳", EquipData.SlotType.WEAPON,
		"阴阳", {}, "res://TCP/双刀/2150.tcp", 1, [], 0, "赤阳之铁成阳，玄冰之玉成阴，两仪相生，气韵非凡")
	EquipData.register_named("月光", EquipData.SlotType.WEAPON,
		"月光", {}, "res://TCP/双刀/2151.tcp", 1, [], 0, "皎洁如白玉，清明如月光。")
	EquipData.register_named("灵蛇", EquipData.SlotType.WEAPON,
		"灵蛇", {}, "res://TCP/双刀/2152.tcp", 1, [], 0, "采千年寒冰碧玉制成，通体碧绿，剑出似灵蛇出洞")
	EquipData.register_named("金龙双剪", EquipData.SlotType.WEAPON,
		"金龙双剪", {}, "res://TCP/双刀/2160.tcp", 1, [], 0, "传说乃是一对金龙所化，头并头如剑，尾交尾如股。从半空中呼啸而下，一绞之力无人能挡。")
	EquipData.register_named("连理双树", EquipData.SlotType.WEAPON,
		"连理双树", {}, "res://TCP/双刀/2161.tcp", 1, [], 0, "一对痴情男女坟前精魂所化双树，攀枝连理，象征在世虽不能合枕，来世愿永无分离。以此木为剑，因至情贯其中，也可成绕指柔，也可以断金玉。")
	EquipData.register_named("祖龙对剑", EquipData.SlotType.WEAPON,
		"祖龙对剑", {}, "res://TCP/双刀/2162.tcp", 1, [], 0, "三国时蜀帝刘备所用双剑。据说一为白龙所化，一为赤龙所化。白龙乃是秦皇，赤龙乃是汉祖。执之者当有九五之尊。")
	EquipData.register_named("紫电青霜", EquipData.SlotType.WEAPON,
		"紫电青霜", {}, "res://TCP/双刀/2170.tcp", 1, [], 0, "鸿蒙灵气所钟，诸天精魄所禳。异器天生，一派自然。紫电稚弱，性如婴孩；青霜老沉，俨如兄长。翛忽隐现，捷如流星，啾啾呢喃，紫燕青虬。")
	EquipData.register_named("浮犀", EquipData.SlotType.WEAPON,
		"浮犀", {}, "res://TCP/双刀/2180.tcp", 1, [], 0, "九天玄女以夔牛之角所制双剑，锋锐无双，轻如无物，曾助黄帝擒杀蚩尤。其上书天书密咒，丹血为文，翠莹如碧。")

	# ═══════════════════════════════════
	# 巨剑（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("钝铁重剑", EquipData.SlotType.WEAPON,
		"钝铁重剑", {}, "res://TCP/巨剑/31001.tcp", 1, [], 0, "废铁弃料打造的重剑，价格低廉，适宜新手。")
	EquipData.register_named("桃印铁刃", EquipData.SlotType.WEAPON,
		"桃印铁刃", {}, "res://TCP/巨剑/31002.tcp", 1, [], 0, "常见铁剑，以桃木为剑柄。")
	EquipData.register_named("赭石巨剑", EquipData.SlotType.WEAPON,
		"赭石巨剑", {}, "res://TCP/巨剑/31003.tcp", 1, [], 0, "以赭石去杂质煅淬而成，色泽沉郁。")
	EquipData.register_named("璧玉长铗", EquipData.SlotType.WEAPON,
		"璧玉长铗", {}, "res://TCP/巨剑/31004.tcp", 1, [], 0, "精铁重剑，剑身嵌美玉，碧波流光，颇有君子之风。")
	EquipData.register_named("青铜古剑", EquipData.SlotType.WEAPON,
		"青铜古剑", {}, "res://TCP/巨剑/31005.tcp", 1, [], 0, "青铜宝剑，古朴大气，然剑锋凌厉，不可小觑。")
	EquipData.register_named("金错巨刃", EquipData.SlotType.WEAPON,
		"金错巨刃", {}, "res://TCP/巨剑/31006.tcp", 1, [], 0, "铁匠采丹阳铜矿冶炼锻造，剑身以镶金包裹，工艺精湛，灼灼夺目。")
	EquipData.register_named("惊涛雪", EquipData.SlotType.WEAPON,
		"惊涛雪", {}, "res://TCP/巨剑/31007.tcp", 1, [], 0, "铸剑师偶得深海晶石一块，冶炼成剑。挥斩之时，流光溢彩。")
	EquipData.register_named("醉浮生", EquipData.SlotType.WEAPON,
		"醉浮生", {}, "res://TCP/巨剑/31008.tcp", 1, [], 0, "浮生若梦，一醉解忧。以布裹之，掩锋芒，平杀气，大巧不工，颇具豪侠之意。")
	EquipData.register_named("沉戟天戉", EquipData.SlotType.WEAPON,
		"沉戟天戉", {}, "res://TCP/巨剑/31009.tcp", 1, [], 0, "原为沙场断戟，后经人收敛重铸，以缅忠魂。握之，勇武无惧。")
	EquipData.register_named("昆吾", EquipData.SlotType.WEAPON,
		"昆吾", {}, "res://TCP/巨剑/31050.tcp", 1, [], 0, "前朝君主雄才大略，文治武功皆成鼎盛，有邦国朝献天降陨铁，以为祥瑞，遂寻当世铸剑高手，炼化成剑，彪炳功勋。")
	EquipData.register_named("弦歌", EquipData.SlotType.WEAPON,
		"弦歌", {}, "res://TCP/巨剑/31051.tcp", 1, [], 0, "乐师师旷以剑为胆，棹伏羲木，铺天蚕丝，制成琴身重剑，以酬知己，友人闻弦歌而知雅意，奏高山流水，成一段佳话。")
	EquipData.register_named("鸦九", EquipData.SlotType.WEAPON,
		"鸦九", {}, "res://TCP/巨剑/31052.tcp", 1, [], 0, "剑痴鸦九得欧冶子所遗铸剑秘法，铸长剑无名。因不舍爱剑磨损，剑成当日，即以冰匣封之。十余年后得人点拨开悟，欲拔剑出匣，然而冰匣早已与剑芯融为一体，不可分离，寻得熔岩炼化三年，方重铸此剑，剑身自此薄雾缭绕。后人得之，为此剑冠以剑痴鸦九之名。")
	EquipData.register_named("秋水澄流", EquipData.SlotType.WEAPON,
		"秋水澄流", {}, "res://TCP/巨剑/31060.tcp", 1, [], 0, "泑山之畔盛产婴垣之玉，得蓐收赤足踏过而成金秋之色，胜碧玉琼瑶。有人界巧匠偶得之，不知何物，投剑炉一试，不想即刻炉毁剑成，更一日入秋，遂得此名。")
	EquipData.register_named("腾蛇郁刃", EquipData.SlotType.WEAPON,
		"腾蛇郁刃", {}, "res://TCP/巨剑/31061.tcp", 1, [], 0, "中山之州有赤目飞蛇，乘雾游云，于柴桑之山嬉戏，疲乏后盘松石小憩，留蛇蜕一副，化为巨剑，此乃王道之剑。")
	EquipData.register_named("墨骨枯麟", EquipData.SlotType.WEAPON,
		"墨骨枯麟", {}, "res://TCP/巨剑/31062.tcp", 1, [], 0, "东海龙冢有龙骨万千，尤以黑龙龙骨为尊，取其残骨，熔以业火，成墨骨重剑。弹触剑身，争鸣作响，似有龙吟。")
	EquipData.register_named("百辟镇魂", EquipData.SlotType.WEAPON,
		"百辟镇魂", {}, "res://TCP/巨剑/31070.tcp", 1, [], 0, "千年以前，世间妖魔横行，有神将除妖邪，斩厉鬼，力竭而亡，然其精魂不灭，附于生前所用神兵重剑，继续护佑四方。此剑祭出，则正气浩然冲天，可诛邪平患，可定历熄灾。")
	EquipData.register_named("长息", EquipData.SlotType.WEAPON,
		"长息", {}, "res://TCP/巨剑/31080.tcp", 1, [], 0, "洪水滔天，鲧窃帝之息壤以堙洪水，息壤生生不息，却于疏洪无益。帝令祝融取息壤，复命禹布土疏洪，以定九州。此时山川逼仄，水塞不出。禹借祝融火龙之力，熔炼息壤成重剑之体，以之开山疏浚，方江河倾泻，洪水东去。")

	# ═══════════════════════════════════
	# 扇（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("精钢扇", EquipData.SlotType.WEAPON,
		"精钢扇", {"dmg": 55}, "res://TCP/扇/1503.tcp", 5, [], 420, "精钢制的扇骨，可以格挡锋利的兵器攻击")
	EquipData.register_named("折扇", EquipData.SlotType.WEAPON,
		"折扇", {}, "res://TCP/扇/1501.tcp", 1, [], 0, "普通的纸扇改装而成，可以此练习最基本的使扇方法")
	EquipData.register_named("铁骨扇", EquipData.SlotType.WEAPON,
		"铁骨扇", {}, "res://TCP/扇/1502.tcp", 1, [], 0, "铁制的扇骨会对敌人造成较大的威胁")
	EquipData.register_named("铁面扇", EquipData.SlotType.WEAPON,
		"铁面扇", {}, "res://TCP/扇/1504.tcp", 1, [], 0, "连扇面也用铁片构成，更易格挡，晃动可出声，乱敌耳目")
	EquipData.register_named("百折扇", EquipData.SlotType.WEAPON,
		"百折扇", {}, "res://TCP/扇/1505.tcp", 1, [], 0, "采用非常多的扇骨，扇面百折，非常坚固")
	EquipData.register_named("劈水扇", EquipData.SlotType.WEAPON,
		"劈水扇", {}, "res://TCP/扇/1506.tcp", 1, [], 0, "挥舞之下可使狂风止，水断流")
	EquipData.register_named("神火扇", EquipData.SlotType.WEAPON,
		"神火扇", {}, "res://TCP/扇/1507.tcp", 1, [], 0, "扇面用红绸制，此扇动则似神火四起，使敌人心不能宁")
	EquipData.register_named("阴风扇", EquipData.SlotType.WEAPON,
		"阴风扇", {}, "res://TCP/扇/1508.tcp", 1, [], 0, "扇骨采玄冰制，阴风习习，让人不寒而粟")
	EquipData.register_named("风云雷电", EquipData.SlotType.WEAPON,
		"风云雷电", {}, "res://TCP/扇/1509.tcp", 1, [], 0, "气势勇猛的大型折扇，扇开似风云突变，扇出似雷鸣电闪")
	EquipData.register_named("太极", EquipData.SlotType.WEAPON,
		"太极", {}, "res://TCP/扇/1550.tcp", 1, [], 0, "包容太极于其内，博采天地之灵气")
	EquipData.register_named("玉龙", EquipData.SlotType.WEAPON,
		"玉龙", {}, "res://TCP/扇/1551.tcp", 1, [], 0, "白玉制的扇骨，优雅灵巧，似白龙出海")
	EquipData.register_named("秋风", EquipData.SlotType.WEAPON,
		"秋风", {}, "res://TCP/扇/1552.tcp", 1, [], 0, "一纸折扇，荡平天下事，一缕秋风，吹尽凡尘心")
	EquipData.register_named("画龙点睛", EquipData.SlotType.WEAPON,
		"画龙点睛", {}, "res://TCP/扇/1560.tcp", 1, [], 0, "本是一把普通的折扇，只因张僧繇画神龙于上，并点其睛，挥动时则隐有风雷之声、云雨之气，展开更有神龙奔出。")
	EquipData.register_named("秋水人家", EquipData.SlotType.WEAPON,
		"秋水人家", {}, "res://TCP/扇/1561.tcp", 1, [], 0, "扇面上所画《秋水人家图》出神入化，栩栩如生；展扇更可进入其中，游山玩水，身临其境。其中定有道家仙法无疑。")
	EquipData.register_named("逍遥江湖", EquipData.SlotType.WEAPON,
		"逍遥江湖", {}, "res://TCP/扇/1562.tcp", 1, [], 0, "持此扇行走江湖，可预先知晓福祸吉凶。据说是钦天监台正先生袁天罡书奇门妙法于其上，方使此扇有逍遥美名。")
	EquipData.register_named("浩气长舒", EquipData.SlotType.WEAPON,
		"浩气长舒", {}, "res://TCP/扇/1570.tcp", 1, [], 0, "持之若登高望远，五湖四海俱在眼前。不以物喜，不以己悲，心旷神怡，宠辱偕忘。感浩然之气至大至刚，以直养而无害，充盈天地。不亦快哉！")
	EquipData.register_named("星瀚", EquipData.SlotType.WEAPON,
		"星瀚", {}, "res://TCP/扇/1580.tcp", 1, [], 0, "三垣中坠，不知其故。展则漫天星辰失色，收则幽渺万籁无声。万顷星瀚，无始无终，无他无我，怎不使人目眩神驰？")

	# ═══════════════════════════════════
	# 斧（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("青铜斧", EquipData.SlotType.WEAPON,
		"青铜斧", {}, "res://TCP/斧/1401.tcp", 1, [], 0, "以硬木和青铜制造的大斧，是常用的兵器")
	EquipData.register_named("开山斧", EquipData.SlotType.WEAPON,
		"开山斧", {}, "res://TCP/斧/1402.tcp", 1, [], 0, "铁铸的巨大战斧，沉重无比，力大者用以开石裂碑")
	EquipData.register_named("双面斧", EquipData.SlotType.WEAPON,
		"双面斧", {}, "res://TCP/斧/1403.tcp", 1, [], 0, "两面均制成半月状锋刃，双面制敌，力猛势强")
	EquipData.register_named("双弦钺", EquipData.SlotType.WEAPON,
		"双弦钺", {}, "res://TCP/斧/1404.tcp", 1, [], 0, "铁杆黝黑，银月如弦，舞动时眩人眼目")
	EquipData.register_named("精钢禅钺", EquipData.SlotType.WEAPON,
		"精钢禅钺", {}, "res://TCP/斧/1405.tcp", 1, [], 0, "精钢打造，环随舞动，铿锵入耳，震人心魄")
	EquipData.register_named("黄金钺", EquipData.SlotType.WEAPON,
		"黄金钺", {}, "res://TCP/斧/1406.tcp", 1, [], 0, "以华丽的黄金装饰,使其更加沉重威猛,金光起处血光飞溅")
	EquipData.register_named("乌金鬼头镰", EquipData.SlotType.WEAPON,
		"乌金鬼头镰", {}, "res://TCP/斧/1407.tcp", 1, [], 0, "乌金打造的巨镰，透出森森鬼气，令人不寒而栗")
	EquipData.register_named("狂魔镰", EquipData.SlotType.WEAPON,
		"狂魔镰", {}, "res://TCP/斧/1408.tcp", 1, [], 0, "沉于万魔之地，染魔性，映魔心，挥之即魔瘴四起")
	EquipData.register_named("恶龙之齿", EquipData.SlotType.WEAPON,
		"恶龙之齿", {}, "res://TCP/斧/1409.tcp", 1, [], 0, "寒钢为柄，龙齿为刃，风过龙鸣，摄破敌胆")
	EquipData.register_named("破魄", EquipData.SlotType.WEAPON,
		"破魄", {}, "res://TCP/斧/1450.tcp", 1, [], 0, "集艳日与阴月之精华，挥舞如日月同晖，中者形神俱灭")
	EquipData.register_named("肃魂", EquipData.SlotType.WEAPON,
		"肃魂", {}, "res://TCP/斧/1451.tcp", 1, [], 0, "吸取无尽黑暗之气，肃清无规、无序、无章之魂")
	EquipData.register_named("无敌", EquipData.SlotType.WEAPON,
		"无敌", {}, "res://TCP/斧/1452.tcp", 1, [], 0, "斧杆以千年古木之根打造，盘桓虬曲；寒铁锻造的双面巨斧发出魔气逼人的暗光。")
	EquipData.register_named("五丁开山", EquipData.SlotType.WEAPON,
		"五丁开山", {}, "res://TCP/斧/1460.tcp", 1, [], 0, "古蜀有五力士奉命凿通群山，见一大蛇尾在洞外，乃曳之出，其身长数十里。惊讶间，山崩，五丁与蛇俱死，化为神斧，执之者有开山之力。")
	EquipData.register_named("元神禁锢", EquipData.SlotType.WEAPON,
		"元神禁锢", {}, "res://TCP/斧/1461.tcp", 1, [], 0, "阴司轮转王司过之宝。若有鬼仙犯大恶，即以此物拟其头，吸尽元神，再无转生可能。细看刃缘，可见无数痛苦鬼脸。")
	EquipData.register_named("护法灭魔", EquipData.SlotType.WEAPON,
		"护法灭魔", {}, "res://TCP/斧/1462.tcp", 1, [], 0, "佛门护法之武器，柄为鲁班所雕吴刚伐桂之枝，斧为老君所炼炉中千年玄铁，上有佛门梵文，妖怪见之退避三舍。")
	EquipData.register_named("碧血干戚", EquipData.SlotType.WEAPON,
		"碧血干戚", {}, "res://TCP/斧/1470.tcp", 1, [], 0, "刑天与帝争神，身首异处，碧血零落，干缺戚残；后人冶于一炉乃得神兵。长戚舞处，风云雷动，碧波流转，巨盾透体而出，其鸣呜咽，如英雄泣。")
	EquipData.register_named("裂天", EquipData.SlotType.WEAPON,
		"裂天", {}, "res://TCP/斧/1480.tcp", 1, [], 0, "蚩尤随身魔武之一，取大荒四极异兽骨所制，形如巨镰，镰刃淬海皇兽魂，隐然有嘶鸣之声，裂天笞地，割风断雨。")

	# ═══════════════════════════════════
	# 杖（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("曲柳杖", EquipData.SlotType.WEAPON,
		"曲柳杖", {"dmg": 9}, "res://TCP/杖/2201.tcp", 1, [], 100, "柳木雕凿的法杖，蕴含一点法力，适合新手使用。")
	EquipData.register_named("玄铁牛角杖", EquipData.SlotType.WEAPON,
		"玄铁牛角杖", {"dmg": 105}, "res://TCP/杖/2205.tcp", 10, [], 1300, "用寒铁锻冶的牛角状法杖，尖锐坚硬，闪着寒光，隐含奇妙的法力。")
	EquipData.register_named("红木杖", EquipData.SlotType.WEAPON,
		"红木杖", {}, "res://TCP/杖/2202.tcp", 1, [], 0, "用上好红木刻成的法杖，十分坚硬，内含一点奇妙的法力。")
	EquipData.register_named("白椴杖", EquipData.SlotType.WEAPON,
		"白椴杖", {}, "res://TCP/杖/2203.tcp", 1, [], 0, "用极佳的椴木精心雕凿而成的法杖，杖身光滑，蕴含着奇妙的法力。")
	EquipData.register_named("墨铁拐", EquipData.SlotType.WEAPON,
		"墨铁拐", {}, "res://TCP/杖/2204.tcp", 1, [], 0, "墨铁打造而成的法杖，冰冷坚硬，似乎含有奇妙的力量。")
	EquipData.register_named("鹰眼法杖", EquipData.SlotType.WEAPON,
		"鹰眼法杖", {}, "res://TCP/杖/2206.tcp", 1, [], 0, "孤鹰展翅，划破长空，依照孤鹰之形打造的法杖，蕴含神奇法力。")
	EquipData.register_named("腾云杖", EquipData.SlotType.WEAPON,
		"腾云杖", {}, "res://TCP/杖/2207.tcp", 1, [], 0, "仙人踏云而至，有着祥云之形的云母石法杖，有着奇妙法力。")
	EquipData.register_named("引魂杖", EquipData.SlotType.WEAPON,
		"引魂杖", {}, "res://TCP/杖/2208.tcp", 1, [], 0, "点点萤光，引路幽魂，指引迷途幽魂的法杖，有着强大的法力。")
	EquipData.register_named("碧玺杖", EquipData.SlotType.WEAPON,
		"碧玺杖", {}, "res://TCP/杖/2209.tcp", 1, [], 0, "碧霞莹莹，玉暖生烟，浑然天成的碧玉法杖，神妙异常。")
	EquipData.register_named("业焰", EquipData.SlotType.WEAPON,
		"业焰", {}, "res://TCP/杖/2250.tcp", 1, [], 0, "取地狱燧石锻冶，燃万年业火之杖。“以业火乾枯，酬其宿债”，业焰之舞，焚尽世间罪孽。")
	EquipData.register_named("玉辉", EquipData.SlotType.WEAPON,
		"玉辉", {}, "res://TCP/杖/2251.tcp", 1, [], 0, "琉璃玉辉，星降人间，熠熠生辉的琉璃法杖，挥舞时如繁星落尽，蕴含无限灵力。")
	EquipData.register_named("鹿鸣", EquipData.SlotType.WEAPON,
		"鹿鸣", {}, "res://TCP/杖/2252.tcp", 1, [], 0, "牡鹿凄鸣，风云雷动，天下至寒之墨玉炼成鹿角之形，夹风雷之势，让敌人闻之色变。")
	EquipData.register_named("碧海潮生", EquipData.SlotType.WEAPON,
		"碧海潮生", {}, "res://TCP/杖/2260.tcp", 1, [], 0, "应龙伏旱魃，寻深海冰晶，取潮涌奔腾之势，融白浪连山之气，吐龙息为灵珠，成龙神逐珠之形，终获一杖，名曰“碧海潮生”。")
	EquipData.register_named("弦月", EquipData.SlotType.WEAPON,
		"弦月", {}, "res://TCP/杖/2261.tcp", 1, [], 0, "盘古开天辟地之时，一外化陨铁落于不周山之巅，沐月华，吸星魄，尽得天地清明之气，化一杖，清辉万丈，疏影琉璃，曰之“弦月”。")
	EquipData.register_named("杖_2262", EquipData.SlotType.WEAPON,
		"杖2262", {}, "res://TCP/杖/2262.tcp", 1, [], 0)
	EquipData.register_named("杖_2270", EquipData.SlotType.WEAPON,
		"杖2270", {}, "res://TCP/杖/2270.tcp", 1, [], 0)
	EquipData.register_named("杖_2280", EquipData.SlotType.WEAPON,
		"杖2280", {}, "res://TCP/杖/2280.tcp", 1, [], 0)

	# ═══════════════════════════════════
	# 枪（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("锯齿矛", EquipData.SlotType.WEAPON,
		"锯齿矛", {"dmg": 60}, "res://TCP/枪/1603.tcp", 5, [], 460, "枪尖三陷三突，枪杆红绸缠绕，彩缨闪动令人眼花瞭乱")
	EquipData.register_named("红缨枪", EquipData.SlotType.WEAPON,
		"红缨枪", {}, "res://TCP/枪/1601.tcp", 1, [], 0, "白腊木制成的枪杆，柔韧有弹性")
	EquipData.register_named("曲尖枪", EquipData.SlotType.WEAPON,
		"曲尖枪", {}, "res://TCP/枪/1602.tcp", 1, [], 0, "采用上等合木，枪尖九曲，是常用的兵器")
	EquipData.register_named("乌金三叉戟", EquipData.SlotType.WEAPON,
		"乌金三叉戟", {}, "res://TCP/枪/1604.tcp", 1, [], 0, "玄铁长枪，头部以乌金打造，气势如虹")
	EquipData.register_named("火焰枪", EquipData.SlotType.WEAPON,
		"火焰枪", {}, "res://TCP/枪/1605.tcp", 1, [], 0, "以火焰状的精铁代替枪缨，焰缘锋利无比")
	EquipData.register_named("墨杆金钩", EquipData.SlotType.WEAPON,
		"墨杆金钩", {}, "res://TCP/枪/1606.tcp", 1, [], 0, "乌金铁杆，枪尖粗大且制有金色的粗大倒钩，威猛无比")
	EquipData.register_named("玄铁矛", EquipData.SlotType.WEAPON,
		"玄铁矛", {}, "res://TCP/枪/1607.tcp", 1, [], 0, "枪头玄铁制成，宽大沉重，可刺可砍，威势不可挡")
	EquipData.register_named("金蛇信", EquipData.SlotType.WEAPON,
		"金蛇信", {}, "res://TCP/枪/1608.tcp", 1, [], 0, "神木制杆，弯曲似蛇形，金枪透甲，腥红双叉似金蛇出信")
	EquipData.register_named("丈八点钢矛", EquipData.SlotType.WEAPON,
		"丈八点钢矛", {}, "res://TCP/枪/1609.tcp", 1, [], 0, "通体百精纯钢，如天雷击落、蛟龙出海")
	EquipData.register_named("暗夜", EquipData.SlotType.WEAPON,
		"暗夜", {}, "res://TCP/枪/1650.tcp", 1, [], 0, "通体乌黑,极细的枪尖无形中直抵咽喉,如暗夜中引魂之手")
	EquipData.register_named("梨花", EquipData.SlotType.WEAPON,
		"梨花", {}, "res://TCP/枪/1651.tcp", 1, [], 0, "锋刃五裂似梨花绽放,粉红的枪缨银白的枪,尽显潇洒风流")
	EquipData.register_named("霹雳", EquipData.SlotType.WEAPON,
		"霹雳", {}, "res://TCP/枪/1652.tcp", 1, [], 0, "以万古溶岩之火锤炼，枪杆似古树盘结，枪尖似雷霆霹雳")
	EquipData.register_named("刑天之逆", EquipData.SlotType.WEAPON,
		"刑天之逆", {}, "res://TCP/枪/1660.tcp", 1, [], 0, "刑天应劫而出，劫分天兵火水土，此即为其应兵劫之武器。形长两丈，刃如月牙，锋似寒星，身雕百龙蟠纹，挥舞直欲搅碎银汉，号为枪中霸君。")
	EquipData.register_named("五虎断魂", EquipData.SlotType.WEAPON,
		"五虎断魂", {}, "res://TCP/枪/1661.tcp", 1, [], 0, "出如虎奔，刺如虎爪，扫如虎尾，锁如虎噬，声如虎啸；使敌魂断胆破，不战自溃，谓之“五虎断魂”，有枪中王者之气。")
	EquipData.register_named("飞龙在天", EquipData.SlotType.WEAPON,
		"飞龙在天", {}, "res://TCP/枪/1662.tcp", 1, [], 0, "曾为文殊菩萨降妖密宝，如今幻化为一杆金龙宝枪。此枪掷出可化为飞龙，从万丈高空俯冲而下，撕碎敌人。")
	EquipData.register_named("天龙破城", EquipData.SlotType.WEAPON,
		"天龙破城", {}, "res://TCP/枪/1670.tcp", 1, [], 0, "天外陨石炼九日九夜，雷生地底、天坠神龙，乃成此戟。霸王项羽持之横行当世，睥睨天下，故名“天龙破城”。霸王既殁，佚于乌江，龙衔乃出。")
	EquipData.register_named("弑皇", EquipData.SlotType.WEAPON,
		"弑皇", {}, "res://TCP/枪/1680.tcp", 1, [], 0, "炎黄之战，杀怨之气俱归此兵。黄帝得胜，以此兵祭祀天地，誓曰:若治下三界失靖、四海不宁，则天下之人皆可持此兵取吾之首级！")

	# ═══════════════════════════════════
	# 棍（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("细木棒", EquipData.SlotType.WEAPON,
		"细木棒", {}, "res://TCP/棍/1801.tcp", 1, [], 0, "看似细小却有不小的威力，可以当作兵器防身")
	EquipData.register_named("金丝魔棒", EquipData.SlotType.WEAPON,
		"金丝魔棒", {}, "res://TCP/棍/1802.tcp", 1, [], 0, "棒身缠以金丝，显得华丽")
	EquipData.register_named("玉如意", EquipData.SlotType.WEAPON,
		"玉如意", {}, "res://TCP/棍/1803.tcp", 1, [], 0, "细长的白玉棒，白玉使魔棒能力得到加强")
	EquipData.register_named("点金棒", EquipData.SlotType.WEAPON,
		"点金棒", {}, "res://TCP/棍/1804.tcp", 1, [], 0, "华丽的蛇形棒，相传作法之人常用其点石成金")
	EquipData.register_named("云龙棒", EquipData.SlotType.WEAPON,
		"云龙棒", {}, "res://TCP/棍/1805.tcp", 1, [], 0, "棒身九曲，似云龙腾跃")
	EquipData.register_named("幽路引魂", EquipData.SlotType.WEAPON,
		"幽路引魂", {}, "res://TCP/棍/1806.tcp", 1, [], 0, "通体乌黑，引魂归冥")
	EquipData.register_named("满天星", EquipData.SlotType.WEAPON,
		"满天星", {}, "res://TCP/棍/1807.tcp", 1, [], 0, "棒头细密的镶嵌了无数宝石，闪闪发光，似满天星辰")
	EquipData.register_named("水晶棒", EquipData.SlotType.WEAPON,
		"水晶棒", {}, "res://TCP/棍/1808.tcp", 1, [], 0, "通体以水晶制成，棒头镶嵌了纯净的水晶球，灵光闪闪")
	EquipData.register_named("日月光华", EquipData.SlotType.WEAPON,
		"日月光华", {}, "res://TCP/棍/1809.tcp", 1, [], 0, "棒端有日月神珠，半黑半白，收太极其内，五行其间")
	EquipData.register_named("沧海", EquipData.SlotType.WEAPON,
		"沧海", {}, "res://TCP/棍/1850.tcp", 1, [], 0, "静如海之渊深博从，动似海之激荡翻腾。")
	EquipData.register_named("红莲", EquipData.SlotType.WEAPON,
		"红莲", {}, "res://TCP/棍/1851.tcp", 1, [], 0, "碧杆红莲，阅众生相，度众生孽")
	EquipData.register_named("盘龙", EquipData.SlotType.WEAPON,
		"盘龙", {}, "res://TCP/棍/1852.tcp", 1, [], 0, "身若九曲盘龙，口吞八卦金珠")
	EquipData.register_named("降魔玉杵", EquipData.SlotType.WEAPON,
		"降魔玉杵", {}, "res://TCP/棍/1860.tcp", 1, [], 0, "乃一块绝世好玉雕刻而成，杵头刻有仙家符咒。拿在手中，轻如鸿毛，打在人身，重如泰山。")
	EquipData.register_named("青藤玉树", EquipData.SlotType.WEAPON,
		"青藤玉树", {}, "res://TCP/棍/1861.tcp", 1, [], 0, "翡翠藤蔓缠绕于碧玉树干之上，红宝石所雕的鲜花正怒放枝头；它是完美的艺术品，更是仙家妙宝、除魔利器。")
	EquipData.register_named("墨玉骷髅", EquipData.SlotType.WEAPON,
		"墨玉骷髅", {}, "res://TCP/棍/1862.tcp", 1, [], 0, "魔棒上镶嵌着一个刻画精美的墨水晶骷髅，流露出神秘的死亡气息，似乎与地府有很深的渊源。")
	EquipData.register_named("丝萝乔木", EquipData.SlotType.WEAPON,
		"丝萝乔木", {}, "res://TCP/棍/1870.tcp", 1, [], 0, "上古仙侣所化，丝萝出尘，花分五色；中为桐木，曾栖彩凤。千秋万载，其情不泯。仙气缠绕，百邪不侵：“醉向丝萝惊自醒，与君清耳听松湍。”")
	EquipData.register_named("醍醐", EquipData.SlotType.WEAPON,
		"醍醐", {}, "res://TCP/棍/1880.tcp", 1, [], 0, "天地未分时，混沌有异树，亿万年长成，亿万年花开，亿万年结果，果落化为醍醐。持此杖者洞悉天地，与万物同息。")

	# ═══════════════════════════════════
	# 灯（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("素纸灯", EquipData.SlotType.WEAPON,
		"素纸灯", {}, "res://TCP/灯/31201.tcp", 1, [], 0, "轻巧的纸灯笼，最适合新手练习使用。")
	EquipData.register_named("竹骨灯", EquipData.SlotType.WEAPON,
		"竹骨灯", {}, "res://TCP/灯/31202.tcp", 1, [], 0, "以竹骨扎成的灯笼，看起来精致又风雅。")
	EquipData.register_named("红灯笼", EquipData.SlotType.WEAPON,
		"红灯笼", {}, "res://TCP/灯/31203.tcp", 1, [], 0, "节日时方才悬挂起来的红灯笼，看到它就能感到喜庆的氛围！")
	EquipData.register_named("鲤鱼灯", EquipData.SlotType.WEAPON,
		"鲤鱼灯", {}, "res://TCP/灯/31204.tcp", 1, [], 0, "仿照锦鲤的样子精致而成的花灯，说不定会和锦鲤一样带给人好运呢！")
	EquipData.register_named("芙蓉花灯", EquipData.SlotType.WEAPON,
		"芙蓉花灯", {}, "res://TCP/灯/31205.tcp", 1, [], 0, "晶莹剔透的白瓷灯笼，更有名家所绘制之工笔芙蓉，美轮美奂。")
	EquipData.register_named("如意宫灯", EquipData.SlotType.WEAPON,
		"如意宫灯", {}, "res://TCP/灯/31206.tcp", 1, [], 0, "宫廷巧匠耗费月余精制而成的宫灯，象征着平安吉祥，如意称心。")
	EquipData.register_named("玲珑盏", EquipData.SlotType.WEAPON,
		"玲珑盏", {}, "res://TCP/灯/31207.tcp", 1, [], 0, "西域工匠以“费盎斯”工艺烧制的灯笼，其色流云漓彩，其质晶莹剔透，玲珑奇巧，引人注目。")
	EquipData.register_named("玉兔盏", EquipData.SlotType.WEAPON,
		"玉兔盏", {}, "res://TCP/灯/31208.tcp", 1, [], 0, "白璧无瑕琢成团绒玉兔，碧玉青翠雕作剔透环佩，光润莹然，美不胜收。")
	EquipData.register_named("冰心盏", EquipData.SlotType.WEAPON,
		"冰心盏", {}, "res://TCP/灯/31209.tcp", 1, [], 0, "北俱寒冰，澄澈剔透，经年不化。炽焰为刃，琢成玲珑灯盏，寒光为焰，凛风逼人。")
	EquipData.register_named("蟠龙", EquipData.SlotType.WEAPON,
		"蟠龙", {}, "res://TCP/灯/31250.tcp", 1, [], 0, "风从龙出，云有龙息，夜放光华，金碧辉煌。")
	EquipData.register_named("云鹤", EquipData.SlotType.WEAPON,
		"云鹤", {}, "res://TCP/灯/31251.tcp", 1, [], 0, "饥餐瑶草，渴饮琼泉。朝飞阆苑，暮宿云烟。白鹤雪羽为灯盏，光耀如雪，不惹尘埃。")
	EquipData.register_named("风荷", EquipData.SlotType.WEAPON,
		"风荷", {}, "res://TCP/灯/31252.tcp", 1, [], 0, "清莲出水，玉立亭亭。其灵性卓然者，化为灵仙，凡胎肉身，则凝为灯盏。含苞欲放，清芬十里。")
	EquipData.register_named("金风玉露", EquipData.SlotType.WEAPON,
		"金风玉露", {}, "res://TCP/灯/31260.tcp", 1, [], 0, "今日云軿渡鹊桥，应非脉脉与迢迢。灵鹊仙羽，织就金风，七夕月华，酿作玉露。皎皎华光，可照良人。")
	EquipData.register_named("凰火燎原", EquipData.SlotType.WEAPON,
		"凰火燎原", {}, "res://TCP/灯/31261.tcp", 1, [], 0, "凰与凤，生相伴，死同归。一方离世，则生者必引颈而鸣，唤涅槃之火，双双浴火重生。此火五百年不灭，奔腾炽烈，可焚八方。")
	EquipData.register_named("风露清愁", EquipData.SlotType.WEAPON,
		"风露清愁", {}, "res://TCP/灯/31262.tcp", 1, [], 0, "三界之西，有湖曰灵，湖水乃天女眼泪所化，夜色深浓时，有溶溶光华。水滴如泪，泪干为夜明灵珠，风流蕴藉，清光泠泠。")
	EquipData.register_named("夭桃秾李", EquipData.SlotType.WEAPON,
		"夭桃秾李", {}, "res://TCP/灯/31270.tcp", 1, [], 0, "桃之夭夭，灼灼其华。烂漫春光，转瞬即逝。九重天上仙娥取之以为灯盏，光华所至处，枯木吐芽，桃李争芳。")
	EquipData.register_named("荒尘", EquipData.SlotType.WEAPON,
		"荒尘", {}, "res://TCP/灯/31280.tcp", 1, [], 0, "星河浩瀚，繁星若尘，亿万星尘聚沙为塔，是以沧海桑田，人世幻变，其光华永恒也。")

	# ═══════════════════════════════════
	# 爪（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("铁爪", EquipData.SlotType.WEAPON,
		"铁爪", {}, "res://TCP/爪/1301.tcp", 1, [], 0, "镔铁制成的铁爪")
	EquipData.register_named("天狼爪", EquipData.SlotType.WEAPON,
		"天狼爪", {}, "res://TCP/爪/1302.tcp", 1, [], 0, "天山雪狼之爪，锐利无比")
	EquipData.register_named("幽冥鬼爪", EquipData.SlotType.WEAPON,
		"幽冥鬼爪", {}, "res://TCP/爪/1303.tcp", 1, [], 0, "精钢打造，饰以冥文，透出森森鬼气")
	EquipData.register_named("青龙牙", EquipData.SlotType.WEAPON,
		"青龙牙", {}, "res://TCP/爪/1304.tcp", 1, [], 0, "龙牙状的尖刺，可以透入坚固的衣甲")
	EquipData.register_named("勾魂爪", EquipData.SlotType.WEAPON,
		"勾魂爪", {}, "res://TCP/爪/1305.tcp", 1, [], 0, "状似银勾，夺命勾魂")
	EquipData.register_named("玄冰刺", EquipData.SlotType.WEAPON,
		"玄冰刺", {}, "res://TCP/爪/1306.tcp", 1, [], 0, "吸玄冰阴寒之气，可以直透骨骸")
	EquipData.register_named("青刚刺", EquipData.SlotType.WEAPON,
		"青刚刺", {}, "res://TCP/爪/1307.tcp", 1, [], 0, "寒刚玉所制，坚硬无比，可断金")
	EquipData.register_named("华光刺", EquipData.SlotType.WEAPON,
		"华光刺", {}, "res://TCP/爪/1308.tcp", 1, [], 0, "百炼纯钢打造，华光刺目")
	EquipData.register_named("龙鳞刺", EquipData.SlotType.WEAPON,
		"龙鳞刺", {}, "res://TCP/爪/1309.tcp", 1, [], 0, "金色似龙鳞的针刺")
	EquipData.register_named("撕天", EquipData.SlotType.WEAPON,
		"撕天", {}, "res://TCP/爪/1350.tcp", 1, [], 0, "天如幕，白光起，破九重天")
	EquipData.register_named("毒牙", EquipData.SlotType.WEAPON,
		"毒牙", {}, "res://TCP/爪/1351.tcp", 1, [], 0, "恐惧，只有经历无尽虚空中袭来的毒牙才知其真意")
	EquipData.register_named("胭脂", EquipData.SlotType.WEAPON,
		"胭脂", {}, "res://TCP/爪/1352.tcp", 1, [], 0, "血红的颜色，胭脂的香气，将缤纷的灵魂凝结为黑白")
	EquipData.register_named("九阴勾魂", EquipData.SlotType.WEAPON,
		"九阴勾魂", {}, "res://TCP/爪/1360.tcp", 1, [], 0, "爪有九刺，阴寒冷酷，破颅勾魂，使正道名门闻之色变。为地藏王所得，将要销毁，不知何人盗出，又重现江湖。")
	EquipData.register_named("雪蚕之刺", EquipData.SlotType.WEAPON,
		"雪蚕之刺", {}, "res://TCP/爪/1361.tcp", 1, [], 0, "昆仑山雪蚕之毒毛所化，坚硬非常，穿犀牛皮如针穿薄纱，瞬间透入；刺中后使人身中热毒，如在灼热地狱之中。")
	EquipData.register_named("贵霜之牙", EquipData.SlotType.WEAPON,
		"贵霜之牙", {}, "res://TCP/爪/1362.tcp", 1, [], 0, "传说是天竺国千年神象之牙雕刻而成，纯如傅霜，又有神象法力贯注其中，具有神秘的威力。")
	EquipData.register_named("忘川三途", EquipData.SlotType.WEAPON,
		"忘川三途", {}, "res://TCP/爪/1370.tcp", 1, [], 0, "忘川为生死界河，水分三途，缓急不同。此爪凝三途之水，可证罪业，望之似缓，暗流甚疾。伤者不可骤脱，如坠地狱、饿鬼、畜生道。")
	EquipData.register_named("离钩", EquipData.SlotType.WEAPON,
		"离钩", {}, "res://TCP/爪/1380.tcp", 1, [], 0, "鸿蒙初辟，混沌之气混焉；后清浊渐离，有神识之气胶而不舍，亦聚亦离，愁丝千丈，钩绊难舍，岁月风化遂成离钩。")

	# ═══════════════════════════════════
	# 锤（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("烈焰锤", EquipData.SlotType.WEAPON,
		"烈焰锤", {"dmg": 112}, "res://TCP/锤/1205.tcp", 10, [], 1350, "锤面上制造了不少火焰波浪一般的锋刃，可怕的武器")
	EquipData.register_named("松木锤", EquipData.SlotType.WEAPON,
		"松木锤", {}, "res://TCP/锤/1201.tcp", 1, [], 0, "松木质轻，制成的锤主要作练习用")
	EquipData.register_named("镔铁锤", EquipData.SlotType.WEAPON,
		"镔铁锤", {}, "res://TCP/锤/1202.tcp", 1, [], 0, "镔铁打造的锤是价廉而常被采用的兵器")
	EquipData.register_named("八棱金瓜", EquipData.SlotType.WEAPON,
		"八棱金瓜", {}, "res://TCP/锤/1203.tcp", 1, [], 0, "锤似金瓜，八棱突起，是实用的战锤")
	EquipData.register_named("狼牙锤", EquipData.SlotType.WEAPON,
		"狼牙锤", {}, "res://TCP/锤/1204.tcp", 1, [], 0, "锤面密布狼牙细齿，杀伤力不可小视")
	EquipData.register_named("破甲战锤", EquipData.SlotType.WEAPON,
		"破甲战锤", {}, "res://TCP/锤/1206.tcp", 1, [], 0, "精钢打造的巨型战锤，上部粗大的尖齿，可破甲裂碑")
	EquipData.register_named("震天锤", EquipData.SlotType.WEAPON,
		"震天锤", {}, "res://TCP/锤/1207.tcp", 1, [], 0, "寒钢制成的锤头巨大沉重，一击之下威势震天")
	EquipData.register_named("巨灵神锤", EquipData.SlotType.WEAPON,
		"巨灵神锤", {}, "res://TCP/锤/1208.tcp", 1, [], 0, "巨灵神所用神锤，锤似流星，非凡力可举，可挡十万天兵")
	EquipData.register_named("天崩地裂", EquipData.SlotType.WEAPON,
		"天崩地裂", {}, "res://TCP/锤/1209.tcp", 1, [], 0, "静似天柱巍巍，动则天崩地裂")
	EquipData.register_named("八卦", EquipData.SlotType.WEAPON,
		"八卦", {}, "res://TCP/锤/1250.tcp", 1, [], 0, "八卦其间，太极天成，天地造化，混沌无常")
	EquipData.register_named("鬼牙", EquipData.SlotType.WEAPON,
		"鬼牙", {}, "res://TCP/锤/1251.tcp", 1, [], 0, "以万炼钢，合猛鬼牙，噬三界")
	EquipData.register_named("雷神", EquipData.SlotType.WEAPON,
		"雷神", {}, "res://TCP/锤/1252.tcp", 1, [], 0, "一击天地轰鸣，再击电光四起，三击万物俱灰")
	EquipData.register_named("混元金锤", EquipData.SlotType.WEAPON,
		"混元金锤", {}, "res://TCP/锤/1260.tcp", 1, [], 0, "锤按六道之纹，柄接阴阳之气，持之者自有五行造化，诸天看护。")
	EquipData.register_named("九瓣莲花", EquipData.SlotType.WEAPON,
		"九瓣莲花", {}, "res://TCP/锤/1261.tcp", 1, [], 0, "此锤乃仙池中的一朵婷婷玉莲，花开九瓣，蕊露金蓬。不知被谁采来，炼为兵器。虽已过五百年，依然盛开如新发。")
	EquipData.register_named("鬼王蚀日", EquipData.SlotType.WEAPON,
		"鬼王蚀日", {}, "res://TCP/锤/1262.tcp", 1, [], 0, "斩魔王之头为锤，隐隐发出邪气，使日月无光。执此物则将与魔神契约，可拥魔王之力。")
	EquipData.register_named("狂澜碎岳", EquipData.SlotType.WEAPON,
		"狂澜碎岳", {}, "res://TCP/锤/1270.tcp", 1, [], 0, "水神共工至宝，内收九曲黄河，出则天地齐喑，奔涛如雷。共工怒触不周山，天柱折地维绝，水潦尘埃俱归东南，双锤亦泯然其中，为黄帝所得。")
	EquipData.register_named("碎寂", EquipData.SlotType.WEAPON,
		"碎寂", {}, "res://TCP/锤/1280.tcp", 1, [], 0, "盘古龙齿所化，固若金汤。嘘为风雨，吹为雷电，舞之铿锵如鸣金铁，乃天下至阳至刚之物，邪魔宵小望之丧魂。")

	# ═══════════════════════════════════
	# 鞭（EquipData.SlotType.WEAPON）
	# ═══════════════════════════════════
	EquipData.register_named("牛皮鞭", EquipData.SlotType.WEAPON,
		"牛皮鞭", {}, "res://TCP/鞭/1701.tcp", 1, [], 0, "用牛皮制的皮鞭，很容易得到的练习用品")
	EquipData.register_named("牛筋鞭", EquipData.SlotType.WEAPON,
		"牛筋鞭", {}, "res://TCP/鞭/1702.tcp", 1, [], 0, "以上等牛筋制成，弹性极佳，抽之有破空之声")
	EquipData.register_named("乌龙鞭", EquipData.SlotType.WEAPON,
		"乌龙鞭", {}, "res://TCP/鞭/1703.tcp", 1, [], 0, "以鲨鱼皮制成，表皮毛糙，极其坚韧")
	EquipData.register_named("钢结鞭", EquipData.SlotType.WEAPON,
		"钢结鞭", {}, "res://TCP/鞭/1704.tcp", 1, [], 0, "以细钢环联结起一个个钢条，柔中带刚")
	EquipData.register_named("蛇骨鞭", EquipData.SlotType.WEAPON,
		"蛇骨鞭", {}, "res://TCP/鞭/1705.tcp", 1, [], 0, "结似蛇骨，环环相联，抖动时骨节相撞，噼啪作响")
	EquipData.register_named("玉竹金铃", EquipData.SlotType.WEAPON,
		"玉竹金铃", {}, "res://TCP/鞭/1706.tcp", 1, [], 0, "由玉制的竹节联结而成,节间缚着金铃,铃随鞭动,声声悦耳")
	EquipData.register_named("青藤柳叶鞭", EquipData.SlotType.WEAPON,
		"青藤柳叶鞭", {}, "res://TCP/鞭/1707.tcp", 1, [], 0, "采深山古藤制成，上缚柳叶刀片，刀光闪动，杀气逼人")
	EquipData.register_named("雷鸣嗜血鞭", EquipData.SlotType.WEAPON,
		"雷鸣嗜血鞭", {}, "res://TCP/鞭/1708.tcp", 1, [], 0, "管节空洞，银钩闪闪，挥动时隐隐有风雷之音")
	EquipData.register_named("混元金钩", EquipData.SlotType.WEAPON,
		"混元金钩", {}, "res://TCP/鞭/1709.tcp", 1, [], 0, "混元钢索之上缚有金钩，追命勾魂")
	EquipData.register_named("龙筋", EquipData.SlotType.WEAPON,
		"龙筋", {}, "res://TCP/鞭/1750.tcp", 1, [], 0, "以恶龙之筋制成，挥舞若龙腾")
	EquipData.register_named("百花", EquipData.SlotType.WEAPON,
		"百花", {}, "res://TCP/鞭/1751.tcp", 1, [], 0, "龙藤塑其筋，百花缀其上，集仙灵之气，香飘四海。")
	EquipData.register_named("吹雪", EquipData.SlotType.WEAPON,
		"吹雪", {}, "res://TCP/鞭/1752.tcp", 1, [], 0, "鞭上石晶经千年生长，成雪花密布，映日月之光")
	EquipData.register_named("游龙惊鸿", EquipData.SlotType.WEAPON,
		"游龙惊鸿", {}, "res://TCP/鞭/1760.tcp", 1, [], 0, "此鞭舞之矫如游龙，翩若惊鸿，宛如活物。据传是因仙家点化，方有此功效。")
	EquipData.register_named("仙人指路", EquipData.SlotType.WEAPON,
		"仙人指路", {}, "res://TCP/鞭/1761.tcp", 1, [], 0, "此鞭之奇，在于打斗时会自寻敌之弱点，或攻或守，或点或缠，如仙人指路，变化万端；又如灵蛇狂舞，眼花缭乱。")
	EquipData.register_named("血之刺藤", EquipData.SlotType.WEAPON,
		"血之刺藤", {}, "res://TCP/鞭/1762.tcp", 1, [], 0, "此鞭遍体生有倒刺，散发黑色邪气。据传打斗之时会如巨蟒缠住敌人，倒刺嵌入敌人体内，吸食其血肉。")
	EquipData.register_named("牧云清歌", EquipData.SlotType.WEAPON,
		"牧云清歌", {}, "res://TCP/鞭/1770.tcp", 1, [], 0, "此鞭具大神通，持之则神虑清明，可驭使万物。苍穹为牧野，云霞为羔犊，驱鞭行九天，驭风乘云，竞雷逐电。")
	EquipData.register_named("霜陨", EquipData.SlotType.WEAPON,
		"霜陨", {}, "res://TCP/鞭/1780.tcp", 1, [], 0, "昆仑之巅有涧曰冰溪，灿然如银，凝霜聚雪。溪流九曲，矫然若蛟，后凝为软玉长鞭，姑射仙子倚为护身仙器。")
