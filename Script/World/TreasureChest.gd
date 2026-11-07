@tool
extends Node2D
## 实例化到地图，与 Player 放在同一层。奖励留空，等待策划配置。
const Loot = preload("res://Script/Data/Models/ChestLoot.gd")
const Assets = preload("res://Script/Assets/AssetLoader.gd")
const CHEST_TEXTURE_PATH := "res://TCP/世界道具/5218.tcp"
@export var chest_id: String = ""
@export var chest_name: String = "宝箱"
@export var loot: Array[Loot] = []
@export_range(8.0, 65.0, 1.0) var pickup_radius: float = 24.0
signal opened
signal opening_failed(reason: String)
var _opening := false
var _attempted_contact := false

func _ready() -> void:
	var sprite := $ChestSprite as Sprite2D
	sprite.texture = Assets.tcp_texture(CHEST_TEXTURE_PATH)
	if sprite.texture:
		var size := sprite.texture.get_size()
		sprite.offset = Vector2(-size.x * 0.5, -size.y)
		$State.position.y = -size.y - $State.size.y
	if Engine.is_editor_hint():
		set_process(false)
		return
	$State.text = chest_name
	if is_opened(): _remove_chest()

func _process(_delta: float) -> void:
	if is_opened():
		_remove_chest()
		return
	var map := get_parent()
	if not map.has_method("get_player_node"): return
	var player := map.get_player_node() as Node2D
	if not _touches_player(player):
		_attempted_contact = false
		return
	if _attempted_contact or _pickup_blocked(): return
	_attempted_contact = true
	try_pickup(player)

func save_key() -> String:
	if not chest_id.strip_edges().is_empty(): return "chest/" + chest_id.strip_edges()
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path.is_empty(): return ""
	return "chest/" + scene.scene_file_path + "/" + str(scene.get_path_to(self))

func is_opened() -> bool:
	var key := save_key()
	return not key.is_empty() and GameData.story_flag(key)

func _remove_chest() -> void:
	hide()
	set_process(false)
	queue_free()

func _touches_player(player: Node2D) -> bool:
	return is_instance_valid(player) and player.is_visible_in_tree() and player.global_position.distance_squared_to(global_position) <= pickup_radius * pickup_radius

func _pickup_blocked() -> bool:
	return GameData.in_battle or GameData.ui_blocked or GameData._npc_dialogue_playing or GameData.is_dialogue_active()

func _fail(reason: String) -> bool:
	opening_failed.emit(reason)
	_log(reason)
	return false

func try_pickup(player: Node2D) -> bool:
	if _opening or is_opened() or _pickup_blocked() or not _touches_player(player): return false
	var key := save_key()
	if key.is_empty(): return _fail("宝箱尚未配置独立标识。")
	var error := validate_loot()
	if not error.is_empty(): return _fail(error)
	_opening = true
	# 同步提交，不在发奖中途 await；防止道具信号回调导致重复领取。
	GameData.game_flags[key] = true
	var lines: PackedStringArray = []
	for entry in loot:
		match entry.kind:
			Loot.Kind.GOLD:
				GameData.player_gold += entry.amount
				GameData.gold += entry.amount
				lines.append("金币 ×%d" % entry.amount)
			Loot.Kind.ITEM:
				var item = GameData.item_db[entry.reward_id]
				GameData.player_inventory.add_item(item, entry.amount)
				lines.append("%s ×%d" % [item.item_name, entry.amount])
			Loot.Kind.EQUIPMENT:
				for i in entry.amount: GameData.add_equip_to_bag(EquipData.get_named(entry.reward_id).duplicate(true))
				lines.append("%s ×%d" % [entry.reward_id, entry.amount])
			Loot.Kind.MATERIAL:
				for i in entry.amount: GameData.material_bag.append(GameData.get_material(entry.reward_id))
				lines.append("%s ×%d" % [GameData.get_material(entry.reward_id).get("name", entry.reward_id), entry.amount])
			Loot.Kind.EXPERIENCE:
				GameData.gain_exp(entry.member_id, entry.amount)
				lines.append("%s 经验 +%d" % [GameData.get_party_member(entry.member_id).get_display_name(), entry.amount])
			Loot.Kind.TALENT_POINT:
				GameData.talent_points += entry.amount
				lines.append("天赋点 +%d" % entry.amount)
	_remove_chest()
	_log("打开%s，获得：%s" % [chest_name, "、".join(lines)])
	GameData.request_auto_save()
	_opening = false
	opened.emit()
	return true

func validate_loot() -> String:
	if loot.is_empty(): return "宝箱内容尚未配置。"
	var item_totals := {}
	for entry in loot:
		if entry == null or not entry is Loot or entry.amount <= 0: return "宝箱奖励配置无效。"
		match entry.kind:
			Loot.Kind.ITEM:
				if not GameData.item_db.has(entry.reward_id) or GameData.player_inventory == null: return "宝箱道具ID无效。"
				item_totals[entry.reward_id] = int(item_totals.get(entry.reward_id, 0)) + entry.amount
			Loot.Kind.EQUIPMENT:
				if EquipData.get_named(entry.reward_id).is_empty(): return "宝箱装备ID无效。"
			Loot.Kind.MATERIAL:
				if GameData.get_material(entry.reward_id).is_empty(): return "宝箱材料ID无效。"
			Loot.Kind.EXPERIENCE:
				if GameData.get_party_member(entry.member_id) == null: return "宝箱经验接收角色无效。"
			Loot.Kind.GOLD, Loot.Kind.TALENT_POINT: pass
			_: return "宝箱奖励类型无效。"
	for id in item_totals:
		if GameData.player_inventory.get_count(id) + item_totals[id] > GameData.item_db[id].max_stack:
			return "道具数量将超过背包堆叠上限，请整理背包后再开启。"
	return ""

func _log(message: String) -> void:
	var line := message + "\n"
	GameData.world_log_text += line
	if is_instance_valid(GameData.world_log): GameData.world_log.add_text(line)
