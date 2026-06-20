# BattleScene.gd
extends CanvasLayer

var party_ids: Array = [ "yuling", "chiyanshou", "dingdong"]
var enemy_ids: Array = ["超级赤焰兽",]

@onready var battle_manager = $BattleManager
@onready var battle_ui      = $BattleUI
@onready var party_group    = $PartyGroup
@onready var enemy_group    = $EnemyGroup

const HERO_SCENE  = preload("res://Component/fightScenePlayer.tscn")
const ENEMY_SCENE = preload("res://Component/fightScenePlayer.tscn")
const ENEMY_SCRIPT = preload("res://Script/Class/EnemyNode.gd")

## 我方阵型站位 — 从场景的 Marker2D 读取（battleField.tscn 中编辑）
const FRONT_SLOT_NAMES: Array[String] = [
	"AllieSlot1", "AllieSlot2", "AllieSlot3", "AllieSlot4", "AllieSlot5"
]
const PET_SLOT_NAMES: Array[String] = ["PetSlot1", "PetSlot2"]
const MAIN_SLOT_NAME: String = "main"

const BGM_LIST: Array[String] = [
	"res://Audio/BGM/战斗-森林.mp3",
	"res://Audio/BGM/《大侠立志传》游戏音乐BGM纯享版——战斗一 - 1.《大侠立志传》游戏音乐BGM纯享版——战斗一(Av995118947,P1).mp3",
	"res://Audio/BGM/《大侠立志传》游戏音乐BGM纯享版——战斗三 - 1.《大侠立志传》游戏音乐BGM纯享版——战斗三(Av312602269,P1).mp3",
	"res://Audio/BGM/《大侠立志传》游戏音乐BGM纯享版——战斗二 - 1.《大侠立志传》游戏音乐BGM纯享版——战斗二(Av740045895,P1).mp3",
	"res://Audio/BGM/【战斗】传说开始的地方.mp3",
	"res://Audio/BGM/金庸-战斗.mp3",
	"res://Audio/BGM/轩辕-战斗2.mp3",
	"res://Audio/BGM/轩辕-战斗.mp3",
	"res://Audio/BGM/战斗0.ogg",
	"res://Audio/BGM/战斗1.ogg",
	"res://Audio/BGM/战斗2.ogg",
	"res://Audio/BGM/战斗5.ogg",
	"res://Audio/BGM/战斗10.mp3",
	"res://Audio/BGM/战斗-九龙.mp3",
	"res://Audio/BGM/战斗-仙剑.mp3",
	"res://Audio/BGM/战斗-任务.mp3",
	"res://Audio/BGM/战斗-城市.mp3",
	"res://Audio/BGM/战斗-急凑.mp3",
	"res://Audio/BGM/战斗-梦想1.ogg",
	#"res://Audio/BGM/战斗-梦想3.ogg",悲壮
	"res://Audio/BGM/战斗-步天阶.ogg",
	"res://Audio/BGM/战斗-水浒.mp3",
	"res://Audio/BGM/战斗-生肖2.ogg",
	"res://Audio/BGM/战斗-生肖.ogg",
	"res://Audio/BGM/战斗-雪.mp3",
	"res://Audio/BGM/战斗Y.mp3",
	"res://Audio/BGM/战斗草原.mp3",
	"res://Audio/BGM/大话三国 (1).ogg"
	
	
	
	
			
	
	
	
	
	
	
	
	
	
	
]

var _bgm_player: AudioStreamPlayer

## 保存站位信息，供战斗中召唤宠物使用
var _front_slots: Array[Vector2] = []
var _pet_slots: Array[Vector2] = []
var _main_slot: Vector2 = Vector2.ZERO

## 创建脚下彩色圆圈指示器
func _create_slot_indicator(pos: Vector2, color: Color) -> void:
	var node = Node2D.new()
	node.position = pos
	node.z_index = -1  # 在角色下方
	party_group.add_child(node)
	node.set_meta(&"slot_color", color)
	node.draw.connect(func():
		var c: Color = node.get_meta(&"slot_color")
		c.a = 0.4
		node.draw_circle(Vector2.ZERO, 36, c)
		# 外圈边框
		c.a = 0.7
		node.draw_arc(Vector2.ZERO, 36, 0, TAU, 24, c, 2.5)
	)
	node.queue_redraw()

func _ready() -> void:
	var enterFightSound = AudioStreamPlayer.new()
	enterFightSound.stream = load("res://Audio/SE/SWD 战斗开始.mp3")
	enterFightSound.autoplay = true
	add_child(enterFightSound)

	# 优先使用暗雷传入的敌人/队伍配置（通过 GameData meta）
	if GameData.has_meta("pending_enemies"):
		enemy_ids = GameData.get_meta("pending_enemies")
	if GameData.has_meta("pending_party"):
		party_ids = GameData.get_meta("pending_party")

	# ── 构建队伍数据 ──
	var party_stats: Array[CharacterStats] = []
	for pid in party_ids:
		var s = GameData.get_party_member(pid)
		if s:
			# 合并技能库
			var merged = s.duplicate_for_battle()
			var full_skills = GameData.get_all_skills(pid)
			merged.skill_ids = full_skills
			party_stats.append(merged)

	var enemy_stats: Array[CharacterStats] = []
	for eid in enemy_ids:
		var s = GameData.create_enemy(eid)
		if s: enemy_stats.append(s)

	# ── 读取场景上的 Marker2D 获取站位（相对 PartyGroup 本地坐标） ──
	_front_slots.clear()
	_pet_slots.clear()

	for name in FRONT_SLOT_NAMES:
		var m = get_node_or_null(name) as Marker2D
		if m:
			_front_slots.append(m.position - party_group.position)
	for name in PET_SLOT_NAMES:
		var m = get_node_or_null(name) as Marker2D
		if m:
			_pet_slots.append(m.position - party_group.position)
	var m_main = get_node_or_null(MAIN_SLOT_NAME) as Marker2D
	if m_main:
		_main_slot = m_main.position - party_group.position

	# ── 创建脚下彩色圆圈指示器 ──
	for pos in _front_slots:
		_create_slot_indicator(pos, Color(0.3, 0.5, 1.0))  # 蓝色：队友
	for pos in _pet_slots:
		_create_slot_indicator(pos, Color(0.3, 1.0, 0.3))  # 绿色：宠物
	if m_main:
		_create_slot_indicator(_main_slot, Color(1.0, 0.8, 0.2))  # 金色：主角

	# ── 按定位分配阵型 ──
	var all_chars:  Array[BattleCharacter] = []
	var all_stats:  Array[CharacterStats]  = []
	var all_ids:    Array[String] = []
	var pet_queue:  Array[PetData] = _collect_battle_pets()

	# ① 找出定位为「主」的角色 → 右下角主角位
	var main_stat: CharacterStats = null
	var main_id: String = ""
	var team_stats: Array[CharacterStats] = []  # 其他队友
	var team_ids: Array[String] = []
	for i in party_stats.size():
		var st = party_stats[i]
		var pid = party_ids[i]
		if st.role == CharacterStats.Role.MAIN:
			main_stat = st
			main_id = pid
		else:
			team_stats.append(st)
			team_ids.append(pid)

	# ② 右下主角位
	if main_stat:
		var node = _spawn_hero("Main")
		party_group.add_child(node)
		node.position = _main_slot
		all_chars.append(node.get_node("BattleCharacter"))
		all_stats.append(main_stat)
		all_ids.append(main_id)

	# ③ 左下 + 右上：宠物专用位（优先）
	for i in _pet_slots.size():
		if pet_queue.is_empty():
			break
		var pet = pet_queue.pop_front()
		var node = _spawn_pet_node(pet, "PetSlot_%d" % i)
		party_group.add_child(node)
		node.position = _pet_slots[i]
		all_chars.append(node.get_node("BattleCharacter"))
		all_stats.append(pet.to_character_stats())
		all_ids.append("")

	# ④ 前排中间5个：其他队友 → 剩余宠物补位
	for i in _front_slots.size():
		var slot_pos = _front_slots[i]
		if i < team_stats.size():
			var node = _spawn_hero("Front_%d" % i)
			party_group.add_child(node)
			node.position = slot_pos
			all_chars.append(node.get_node("BattleCharacter"))
			all_stats.append(team_stats[i])
			all_ids.append(team_ids[i])
		elif not pet_queue.is_empty():
			var pet = pet_queue.pop_front()
			var node = _spawn_pet_node(pet, "FrontPet_%d" % i)
			party_group.add_child(node)
			node.position = slot_pos
			all_chars.append(node.get_node("BattleCharacter"))
			all_stats.append(pet.to_character_stats())
			all_ids.append("")

	# ── 生成敌人（不变） ──
	var enemy_chars = _spawn_enemies(enemy_stats.size())

	battle_manager.setup(all_chars, all_stats, all_ids, enemy_chars, enemy_stats, GameData.player_inventory)
	battle_manager.start_battle()
	_sort_party_z_index()
	# BGM 立刻启动，不等延迟（延迟可能在战斗结束时还未触发）
	_start_bgm()


## 按 Y 坐标排序绘制层级（Y 越大越靠前）
func _sort_party_z_index() -> void:
	_sort_group_z_index(party_group)
	_sort_group_z_index(enemy_group)


func _sort_group_z_index(group: Node2D) -> void:
	var chars: Array[Node2D] = []
	for child in group.get_children():
		if child is Node2D and child.get_node_or_null("BattleCharacter") != null:
			chars.append(child as Node2D)
	chars.sort_custom(func(a, b): return a.position.y < b.position.y)
	for i in chars.size():
		chars[i].z_index = i


## 收集战斗中出战的宠物（最多4只）
func _collect_battle_pets() -> Array[PetData]:
	var result: Array[PetData] = []
	for pid in GameData.pet_team:
		var pet = GameData.pet_db.get(pid)
		if pet:
			result.append(pet)
			if result.size() >= 4:
				break
	return result


## 生成一个我方英雄/角色节点
func _spawn_hero(name_suffix: String) -> Node2D:
	var node = HERO_SCENE.instantiate()
	node.name = "Hero_%s" % name_suffix
	return node


## 生成一个宠物节点（使用 HeroNode 表现层）
func _spawn_pet_node(pet: PetData, name_suffix: String) -> Node2D:
	var node = HERO_SCENE.instantiate()
	node.name = "Pet_%s" % name_suffix
	# 宠物的 BattleCharacter 会在 setup 时通过 stats 里的 was_base_path 加载动画
	return node

## 战斗中召唤宠物上场，找到空闲站位并注册到战斗管理器
## prefer_pos: 如果指定，优先使用这个位置
func summon_pet(pet: PetData, prefer_pos: Vector2 = Vector2.INF) -> Node2D:
	var all_slots: Array[Vector2] = []
	all_slots.append_array(_pet_slots)
	all_slots.append_array(_front_slots)

	var pos: Vector2 = all_slots[0]
	# 指定位置优先（替换时用）
	if prefer_pos != Vector2.INF:
		pos = prefer_pos
	else:
		for slot in all_slots:
			var occupied = false
			for child in party_group.get_children():
				if child is Node2D and child.get_node_or_null("BattleCharacter") != null:
					if (child as Node2D).position.distance_squared_to(slot) < 100:
						occupied = true
						break
			if not occupied:
				pos = slot
				break

	var node = _spawn_pet_node(pet, "Summoned")
	party_group.add_child(node)
	node.position = pos + Vector2(200, 0)  # 从右侧滑入
	node.modulate.a = 0.3
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "position", pos, 0.35)
	tween.parallel().tween_property(node, "modulate:a", 1.0, 0.25)
	await tween.finished  # 等滑入动画跑完再继续

	var bc = node.get_node("BattleCharacter") as BattleCharacter
	var stats = pet.to_character_stats()
	battle_manager.add_summoned_character(bc, stats, pet.pet_id)
	_sort_party_z_index()
	return node


## 召唤铁甲兽
func summon_mech_pet(stats: CharacterStats, prefer_pos: Vector2 = Vector2.INF) -> Node2D:
	var all_slots: Array[Vector2] = []
	all_slots.append_array(_pet_slots)
	all_slots.append_array(_front_slots)
	var pos: Vector2 = all_slots[0]
	if prefer_pos != Vector2.INF:
		pos = prefer_pos
	else:
		for slot in all_slots:
			var occupied = false
			for child in party_group.get_children():
				if child is Node2D and child.get_node_or_null("BattleCharacter") != null:
					if (child as Node2D).position.distance_squared_to(slot) < 100:
						occupied = true
						break
			if not occupied:
				pos = slot
				break
	var node = _spawn_hero("MechSummoned")
	party_group.add_child(node)
	node.position = pos + Vector2(200, 0)
	node.modulate.a = 0.3
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "position", pos, 0.35)
	tween.parallel().tween_property(node, "modulate:a", 1.0, 0.25)
	await tween.finished
	var bc = node.get_node("BattleCharacter") as BattleCharacter
	battle_manager.add_summoned_character(bc, stats, "")
	_sort_party_z_index()
	return node


## 检查是否有空闲宠物位
func has_free_pet_slot() -> bool:
	for slot in _pet_slots + _front_slots:
		var occupied = false
		for child in party_group.get_children():
			if child is Node2D and child.get_node_or_null("BattleCharacter") != null:
				var nd = child as Node2D
				if nd.position.distance_squared_to(slot) < 100:
					occupied = true
					break
		if not occupied:
			return true
	return false


## 随机播放一首战斗 BGM
## 根据视口大小重新定位队伍和敌人组
func _start_bgm() -> void:
	if BGM_LIST.is_empty():
		return
	# 随机挑一首存在的
	var shuffled := BGM_LIST.duplicate()
	shuffled.shuffle()
	for path in shuffled:
		if ResourceLoader.exists(path):
			_bgm_player = AudioStreamPlayer.new()
			_bgm_player.stream = load(path)
			_bgm_player.autoplay = true
			_bgm_player.finished.connect(func(): _bgm_player.play())
			add_child(_bgm_player)
			return



func _exit_tree() -> void:
	if _bgm_player:
		_bgm_player.stop()


## 生成敌人（斜向站位）
func _spawn_enemies(count: int) -> Array[BattleCharacter]:
	var chars: Array[BattleCharacter] = []
	var all_units: Array[Vector2] = []
	var slant = 30
	var front_count = mini(count, 4)

	for j in count:
		if j < front_count:
			var fx = (j - (front_count - 1) * 0.5) * -80 + 50
			var fy = (j - (front_count - 1) * 0.5) * slant - 130
			all_units.append(Vector2(fx, fy))
		else:
			var k = j - front_count
			var back_count = count - front_count
			var bx = (k - (back_count - 1) * 0.5) * -80 - 25
			var by = (k - (back_count - 1) * 0.5) * slant - 200
			all_units.append(Vector2(bx, by))

	for i in count:
		var node = ENEMY_SCENE.instantiate()
		node.set_script(ENEMY_SCRIPT)
		node.name = "Enemy_%d" % i
		enemy_group.add_child(node)
		node.position = all_units[i]
		# 敌人不显示头顶血蓝条和行动条
		var wui = node.get_node_or_null("WorldUI")
		if wui: wui.visible = false
		chars.append(node.get_node("BattleCharacter"))

	return chars
