# MainScene.gd
# 主场景逻辑 — 管理悬赏弹窗等全局 UI，相机跟随玩家，时辰/坐标/地图名
extends Node2D

const SHICHEN_NAMES: Array[String] = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
const SECONDS_PER_SHICHEN: float = 120.0
const DAY_START_IDX: int = 3
const NIGHT_START_IDX: int = 9

const SHICHEN_IMG: Array[String] = [
	"res://Graphic/UI/子时.png", "res://Graphic/UI/丑时.png", "res://Graphic/UI/寅时.png",
	"res://Graphic/UI/卯时.png",
	"res://Graphic/UI/辰时.png", "res://Graphic/UI/巳时.PNG", "res://Graphic/UI/午时.png",
	"res://Graphic/UI/未时.png", "res://Graphic/UI/申时.png", "res://Graphic/UI/酉时.png",
	"res://Graphic/UI/戌时.png", "res://Graphic/UI/亥时.png",
]

var _bounty_popup = null
var _bounty_open = false
var _hint_popup = null
var _disabled_buttons: Array = []
var _map_popup = null
var _pet_popup = null
var _save_popup = null
var _talent_tree = null
var _equip_page = null
var _team_popup = null
var _status_popup = null
var _build_popup = null
var _setting_popup = null
var _shop_popup = null
var _shichen_accum: float = 0.0
var _shichen_idx: int = 10
var _last_period: int = -1
var _cached_map = null
var _was_in_battle: bool = false
var _play_time_accum: float = 0.0

const PERIOD_TINTS: Array = [
	Color(0.28, 0.32, 0.5),
	Color.WHITE,
	Color(1.0, 0.72, 0.5),
]

@onready var _camera: Camera2D = $Camera2D
@onready var bounty_btn = $UI/BountyBtn
@onready var map_btn = $UI/按钮底图/地图 as AnimatedSprite2D
@onready var _xy_label: Label = $UI/坐标图/xy
@onready var _map_name_label: Label = $UI/坐标图/mapName
@onready var _day_night_icon: TextureRect = $UI/坐标图/dayNightIcon
@onready var _shichen_icon: TextureRect = $UI/坐标图/shichenIcon
@onready var _shichen_fallback: Label = $UI/坐标图/shichenFallback

@export var camera_follow_player: bool = true

var _tex_cache: Dictionary = {}



func _ready() -> void:
	
	_play_time_accum = float(GameData.play_time_sec)
	bounty_btn.pressed.connect(_on_bounty_pressed)
	_setup_ui_buttons()
	GameData.set_language("zh")
	_world_log = $UI/BattleLog
	_world_log.bbcode_enabled = true
	GameData.world_log = _world_log
	if map_btn:
		map_btn.visible = true
		# 锁定状态由 _refresh_btn_visuals 处理
	# 给所有按钮加名字标签
	_add_btn_labels()
	add_child(load("res://Script/Class/CursorController.gd").new())
	GameData.add_party_by_name("游霄云")
	GameData.add_party_by_name("千面")
	GameData.add_party_by_name("堕十一")
	GameData.add_party_by_name("叮咚")
	GameData.add_party_by_name("凌风")
	#ameData.add_party_by_name("大将军")
	
# ════════════════════════════
# UI 按钮系统
# ════════════════════════════

## 按钮定义：{ node_name: { "action": 动作, "locked": bool } }
## 动作可以是字符串 ("pet"/"save"/"bounty"/"")，或者 Callable
func _setup_ui_buttons() -> void:
	var btn_base = $UI/按钮底图
	if btn_base == null: return

	for node_name in ["宠物", "天赋", "道具", "打造", "队伍", "系统", "存档", "悬赏", "剧情", "地图"]:
		var sprite = btn_base.get_node_or_null(node_name) as AnimatedSprite2D
		if sprite == null: continue
		_play_sprite_anim(sprite, "default")

	_refresh_btn_visuals()
	# 从存档恢复按钮禁用状态
	if GameData.disabled_buttons.size() > 0:
		_disabled_buttons = GameData.disabled_buttons.duplicate()
		_refresh_btn_visuals()
	initUIBtn()

func _add_btn_labels() -> void:
	var btn_base = $UI/按钮底图
	if btn_base == null: return
	# 从已有的 "打造/Label" 读取样式
	var template_node = btn_base.get_node_or_null("打造/Label") as Label
	var template_color = Color(1, 1, 0)
	var template_size = 10
	if template_node:
		var c = template_node.get("theme_override_colors/font_color")
		if c != null: template_color = c
		var s = template_node.get("theme_override_font_sizes/font_size")
		if s != null: template_size = s
	for node_name in ["宠物", "天赋", "道具", "打造", "队伍", "系统", "存档", "悬赏", "剧情", "人物", "地图"]:
		var sprite = btn_base.get_node_or_null(node_name) as Node2D
		if sprite == null: continue
		if sprite.has_node("Label"): continue
		var lbl = Label.new()
		lbl.name = "Label"
		lbl.text = node_name
		lbl.add_theme_color_override("font_color", template_color)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
		lbl.add_theme_font_size_override("font_size", template_size)
		lbl.size = Vector2(40, 24)
		lbl.position = Vector2(-20, -13)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.add_child(lbl)


func _get_menu_sprite_at(pos: Vector2) -> AnimatedSprite2D:
	var btn_base = $UI/按钮底图
	if btn_base == null: return null
	var buttons = ["宠物", "天赋", "道具", "打造", "队伍", "系统", "存档", "悬赏", "剧情", "人物", "地图"]
	for node_name in buttons:
		var sprite = btn_base.get_node_or_null(node_name) as AnimatedSprite2D
		if sprite == null: continue
		if not sprite.visible: continue
		# 获取精灵在屏幕上的矩形
		var tex_size = Vector2(25, 33)
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("default"):
			var tex = sprite.sprite_frames.get_frame_texture("default", 0)
			if tex: tex_size = tex.get_size()
		var global_pos = sprite.global_position
		var rect = Rect2(global_pos - tex_size * 0.5, tex_size)
		if rect.has_point(pos):
			return sprite
	return null

var _hovered_sprite: AnimatedSprite2D = null

func _refresh_btn_visuals() -> void:
	var btn_base = $UI/按钮底图
	if btn_base == null: return
	var btn_list = ["宠物", "天赋", "道具", "队伍", "系统", "存档", "悬赏", "剧情", "人物", "打造", "地图"]
	for bn in btn_list:
		var sprite = btn_base.get_node_or_null(bn) as AnimatedSprite2D
		if sprite == null: continue
		if bn in _disabled_buttons:
			sprite.modulate = Color(0.3, 0.3, 0.3, 0.4)
			var lbl = sprite.get_node_or_null("Label") as Label
			if lbl: lbl.visible = false
			continue
		# 地图特殊：未解锁天赋则禁用
		if bn == "地图" and not GameData.has_talent("main_map"):
			sprite.modulate = Color(0.3, 0.3, 0.3, 0.4)
			var lbl = sprite.get_node_or_null("Label") as Label
			if lbl: lbl.visible = false
			continue
		# 不在禁用列表 → 正常显示
		sprite.modulate = Color.WHITE
		var lbl = sprite.get_node_or_null("Label") as Label
		if lbl: lbl.visible = true


func disable_btn(name: String) -> void:
	if name not in _disabled_buttons:
		_disabled_buttons.append(name)
		GameData.disabled_buttons = _disabled_buttons.duplicate()
	_refresh_btn_visuals()

func enable_btn(name: String) -> void:
	_disabled_buttons.erase(name)
	GameData.disabled_buttons = _disabled_buttons.duplicate()
	_refresh_btn_visuals()

func set_btn_enabled(name: String, enabled: bool) -> void:
	if enabled: enable_btn(name)
	else: disable_btn(name)


func _input(event: InputEvent):
	if GameData.in_battle or GameData.ui_blocked or GameData.is_dialogue_active(): return

	# 鼠标移动 — hover 切换
	if event is InputEventMouseMotion:
		var sprite = _get_menu_sprite_at(event.global_position)
		if sprite != _hovered_sprite:
			if _hovered_sprite:
				_play_sprite_anim(_hovered_sprite, "default")
			_hovered_sprite = sprite
			if _hovered_sprite:
				_play_sprite_anim(_hovered_sprite, "hover")

	# 鼠标点击按钮
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var sprite = _get_menu_sprite_at(event.global_position)
		if sprite:
			var btn_name = sprite.name
			if btn_name in _disabled_buttons:
				return
			if btn_name == "地图" and not GameData.has_talent("main_map"):
				return
			match btn_name:
				"宠物": _open_pet_popup()
				"天赋": _open_talent_tree()
				"道具": _open_equip_page()
				"存档": _open_save_popup()
				"悬赏": _open_bounty_popup()
				"队伍": _open_team_popup()
				"人物": _open_status_popup()
				"地图": _open_map_popup()
				"系统": _open_setting_popup()
				"打造": _open_build_popup()
				"剧情": _open_hint_popup()
			_play_sprite_anim(sprite, "pressed")
			get_viewport().set_input_as_handled()
			await get_tree().create_timer(0.15).timeout
			if _hovered_sprite == sprite:
				_play_sprite_anim(sprite, "hover")
			else:
				_play_sprite_anim(sprite, "default")

	# ESC 由 _unhandled_input 处理
	


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_esc_close_or_save()
	# 测试：F2 打开商店
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_F2:
			get_viewport().set_input_as_handled()
			open_shop()


## ESC 依次关闭已打开的面板（队伍/道具/宠物/天赋/悬赏/存档），全关掉后开存档
func _esc_close_or_save() -> void:
	if _team_popup and is_instance_valid(_team_popup):
		_team_popup.close()
		return
	if _status_popup and is_instance_valid(_status_popup):
		_status_popup.close_popup()
		_status_popup = null
		_unregister_popup()
		return
	if _equip_page and is_instance_valid(_equip_page):
		_close_popup(_equip_page)
		return
	if _pet_popup and is_instance_valid(_pet_popup):
		_close_popup(_pet_popup)
		return
	if _talent_tree and is_instance_valid(_talent_tree):
		_close_popup(_talent_tree)
		return
	if _map_popup and is_instance_valid(_map_popup):
		_close_popup(_map_popup)
		return
	if _setting_popup and is_instance_valid(_setting_popup):
		_setting_popup.close()
		_setting_popup = null
		return
	if _hint_popup and is_instance_valid(_hint_popup):
		_hint_popup.closed.emit()
		_hint_popup = null
		return
	if _bounty_popup and is_instance_valid(_bounty_popup) and _bounty_open:
		var snd = AudioStreamPlayer.new()
		snd.stream = load("res://Audio/SE/003-System03.ogg")
		snd.bus = "SFX"
		get_tree().root.add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)
		_bounty_popup.hide()
		_bounty_open = false
		_unregister_popup()
		return
	if _save_popup and is_instance_valid(_save_popup):
		_close_popup(_save_popup)
		return
	_open_save_popup()


func _play_sprite_anim(sprite: AnimatedSprite2D, anim: String):
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


func _open_talent_tree():
	if _talent_tree and is_instance_valid(_talent_tree):
		_close_popup(_talent_tree)
		return
	_talent_tree = preload("res://Component/TalentTree.tscn").instantiate()
	add_child(_talent_tree)
	_talent_tree.closed.connect(func():
		_talent_tree = null
		_unregister_popup()
	)
	_register_popup(_talent_tree)


func _open_status_popup():
	if _status_popup and is_instance_valid(_status_popup):
		_status_popup.close_popup()
		_status_popup = null
		return
	_status_popup = StatusPopup.open()
	_status_popup.closed.connect(func():
		_status_popup = null
		_unregister_popup()
	)
	_register_popup(_status_popup)


func _open_equip_page():
	if _equip_page and is_instance_valid(_equip_page):
		_close_popup(_equip_page)
		return
	_equip_page = preload("res://scenes/EquipPage.tscn").instantiate()
	$UI.add_child(_equip_page)
	# 使用第一个队伍角色
	var first_mid := ""
	for mid in GameData.party_order:
		if GameData.party_db.has(mid):
			first_mid = mid
			break
	if first_mid.is_empty():
		for mid in GameData.party_db:
			first_mid = mid
			break
	_equip_page.set_member_id(first_mid)
	_equip_page.set_equip_bag(GameData.equip_bag)
	_equip_page.set_inventory(GameData.player_inventory._slots)
	_equip_page.full_refresh()
	_equip_page.closed.connect(func(): _close_popup(_equip_page))
	_register_popup(_equip_page)


func _on_equip_page_equip(slot_key: String, bag_index: int) -> void:
	GameData.equip_item_by_index(_equip_page._member_id, slot_key, bag_index)
	_equip_page.equipment = GameData.player_equipment.get(_equip_page._member_id, {})
	_equip_page.set_equip_bag(GameData.equip_bag)
	_equip_page.full_refresh()

func _on_equip_page_unequip(slot_key: String) -> void:
	GameData.unequip_item(_equip_page._member_id, slot_key)
	_equip_page.equipment = GameData.player_equipment.get(_equip_page._member_id, {})
	_equip_page.set_equip_bag(GameData.equip_bag)
	_equip_page.full_refresh()


func _load_hero_portrait() -> Texture2D:
	for mid in GameData.party_db:
		var s = GameData.party_db[mid]
		if s.was_base_path.is_empty(): continue
		var p = s.was_base_path + "/头像/头像.was"
		if not FileAccess.file_exists(p): continue
		var r := WASReader.new()
		if not r.load_from_file(p): continue
		var d := r.decode_frame(0, 0)
		if d.is_empty(): continue
		return d.get("texture", null)
	return null


func _open_pet_popup():
	if _pet_popup and is_instance_valid(_pet_popup):
		_close_popup(_pet_popup)
		return
	_pet_popup = preload("res://Component/PetPopup.tscn").instantiate()
	add_child(_pet_popup)
	_pet_popup.closed.connect(func(): _pet_popup = null; _unregister_popup())
	_register_popup()


## 队伍列表弹窗 — 点击「队伍」按钮打开（弹窗会阻止走路/怪物追击，ESC 或点击任意处关闭）
func _open_team_popup():
	if _team_popup and is_instance_valid(_team_popup):
		_team_popup.close()
		return
	_team_popup = preload("res://Component/TeamPopup.tscn").instantiate()
	$UI.add_child(_team_popup)
	_team_popup.closed.connect(func():
		if is_instance_valid(_team_popup):
			_team_popup.queue_free()
		_team_popup = null
		_unregister_popup()
	)
	_team_popup.open()
	_register_popup(_team_popup)


func _open_save_popup():
	if _save_popup and is_instance_valid(_save_popup):
		_close_popup(_save_popup)
		return
	_save_popup = preload("res://Component/SavePopup.tscn").instantiate()
	add_child(_save_popup)
	_save_popup.closed.connect(func(): _save_popup = null; _unregister_popup())
	_register_popup()


func _open_map_popup() -> void:
	if _map_popup and is_instance_valid(_map_popup):
		_close_popup(_map_popup)
		return
	if not GameData.has_talent("main_map"): return
	_map_popup = preload("res://Component/map.tscn").instantiate()
	add_child(_map_popup)
	# 按钮
	var close_btn = _map_popup.get_node_or_null("CloseButton") as TextureButton
	if close_btn:
		close_btn.pressed.connect(_close_map)
	var world_btn = _map_popup.get_node_or_null("世界地图") as Button
	var current_btn = _map_popup.get_node_or_null("当前地图") as Button
	var map_container = _map_popup.get_node_or_null("MapContainer")
	if world_btn and map_container:
		world_btn.pressed.connect(func(): map_container.switch_to_world())
	if current_btn and map_container:
		current_btn.pressed.connect(func(): map_container.switch_to_current())
	# 填充地图传送数据
	var map_root = get_node_or_null("MapRoot")
	var map_id = map_root.map_id if map_root and not map_root.map_id.is_empty() else ""
	var tp_data = GameData.get_teleports(map_id)
	if not tp_data.is_empty():
		var content = _map_popup.get_node("MapContainer/MapViewport/MapContent")
		if content:
			content.teleport_data = tp_data
	_register_popup()

func _close_map() -> void:
	if _map_popup and is_instance_valid(_map_popup):
		_close_popup(_map_popup)


func _open_build_popup() -> void:
	var popup = preload("res://Component/build_popup.tscn").instantiate()
	add_child(popup)
	popup.closed.connect(func(): popup.queue_free(); _unregister_popup())
	# 传装备 + 材料
	popup.set_materials(GameData.equip_bag.duplicate() + GameData.material_bag.duplicate() + _get_equipped_items())
	_register_popup()


func _get_equipped_items() -> Array:
	var items: Array = []
	for mid in GameData.party_order:
		var eq = GameData.player_equipment.get(mid, {})
		for slot_key in eq.values():
			if slot_key is Dictionary:
				var copy = slot_key.duplicate()
				copy["_worn"] = true
				items.append(copy)
	return items


func _open_setting_popup() -> void:
	if _setting_popup and is_instance_valid(_setting_popup):
		_setting_popup.close()
		_setting_popup = null
		return
	var popup = preload("res://Component/SettingPopup.tscn").instantiate()
	_setting_popup = popup
	add_child(popup)
	popup.closed.connect(func(): _setting_popup = null; _unregister_popup())
	_register_popup()


func _open_hint_popup() -> void:
	if _hint_popup and is_instance_valid(_hint_popup):
		return
	_hint_popup = preload("res://Component/hintPopup.tscn").instantiate()
	add_child(_hint_popup)
	_hint_popup.closed.connect(func(): _hint_popup = null; _unregister_popup())
	_register_popup()


func _open_bounty_popup():
	if _bounty_popup == null or not is_instance_valid(_bounty_popup):
		_bounty_popup = preload("res://Component/BountyPopup.tscn").instantiate()
		add_child(_bounty_popup)
		_bounty_popup.closed.connect(func(): _bounty_open = false; _unregister_popup())
		_bounty_popup.open()
		_bounty_open = true
		_register_popup()
		return

	if _bounty_open:
		_bounty_popup.hide()
		_bounty_open = false
		_unregister_popup()
	else:
		_bounty_popup.open()
		_bounty_open = true
		_register_popup()


func _has_any_popup_open() -> bool:
	if _bounty_open: return true
	if _map_popup and is_instance_valid(_map_popup): return true
	if _pet_popup and is_instance_valid(_pet_popup): return true
	if _save_popup and is_instance_valid(_save_popup): return true
	if _talent_tree and is_instance_valid(_talent_tree): return true
	if _equip_page and is_instance_valid(_equip_page): return true
	if _status_popup and is_instance_valid(_status_popup): return true
	return false


func _register_popup(_node: Node = null):
	GameData.ui_blocked = true
	_refresh_btn_visuals()
	$UI/坐标图.visible = false
	$UI/按钮底图.visible = false
	if bounty_btn: bounty_btn.visible = false

func _unregister_popup(_node: Node = null):
	if not _has_any_popup_open():
		GameData.ui_blocked = false
		_refresh_btn_visuals()
		if map_btn:
			map_btn.visible = true
			# 锁定状态由 _refresh_btn_visuals 处理
		$UI/坐标图.visible = true
		$UI/按钮底图.visible = true
		if bounty_btn: bounty_btn.visible = true

func _close_popup(node: Node):
	if node == null or not is_instance_valid(node):
		return
	if node == _talent_tree and node.has_method("close"):
		node.close()
		_talent_tree = null
		_unregister_popup()
		return
	# 关闭音效
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://Audio/SE/003-System03.ogg")
	snd.bus = "SFX"
	get_tree().root.add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)
	if node.has_method("hide"): node.hide()
	if node is CanvasLayer or node is Panel: node.queue_free()
	# queue_free 是延迟的，必须先清引用再 _unregister_popup
	if node == _save_popup:   _save_popup = null
	if node == _pet_popup:    _pet_popup = null
	if node == _talent_tree:  _talent_tree = null
	if node == _equip_page:   _equip_page = null
	if node == _map_popup:    _map_popup = null
	_unregister_popup()


func _process(delta: float) -> void:
	if GameData.in_battle:
		if not _was_in_battle:
			_was_in_battle = true
		$UI/坐标图.visible = false
		$UI/按钮底图.visible = false
		if bounty_btn: bounty_btn.visible = false
		if has_node("UI/信息框"): $UI/信息框.visible = false
		if has_node("UI/提示"): $UI/提示.visible = false
		return

	if _was_in_battle:
		_was_in_battle = false
		$UI/坐标图.visible = true
		$UI/按钮底图.visible = true
		if bounty_btn: bounty_btn.visible = true
		if has_node("UI/信息框"): $UI/信息框.visible = true
		if has_node("UI/提示"): $UI/提示.visible = true
		if _world_log:
			_world_log.scroll_to_line(_world_log.get_line_count())

	# 外部 BattleLog 由 battleUI 通过 GameData.world_log_text 更新，MainScene 只读不写

	_shichen_accum += delta
	if _shichen_accum >= SECONDS_PER_SHICHEN:
		_shichen_accum -= SECONDS_PER_SHICHEN
		_shichen_idx = (_shichen_idx + 1) % 12
	if not GameData.ui_blocked:
		GameData.play_time_sec = int(Time.get_ticks_msec() / 1000.0)
	_update_time_ui()

	var period := _get_period()
	if period != _last_period:
		_last_period = period
		GameData.current_period = period
		_apply_day_tint()

	if not camera_follow_player or _camera == null:
		return
	var player := _find_player()
	if not player:
		return
	_camera.global_position = player.global_position
	_xy_label.text = "x:%d  y:%d" % [int(player.global_position.x) / 10, int(player.global_position.y) / 10]


func _update_time_ui() -> void:
	var is_night := _shichen_idx >= 0 and _shichen_idx <= 2
	var dn_path := "res://Graphic/UI/夜.PNG" if is_night else "res://Graphic/UI/昼.PNG"
	_day_night_icon.texture = _load_tex(dn_path)

	var img_path := SHICHEN_IMG[_shichen_idx]
	if not img_path.is_empty():
		_shichen_fallback.visible = false
		_shichen_icon.visible = true
		_shichen_icon.texture = _load_tex(img_path)
	else:
		_shichen_icon.visible = false
		_shichen_fallback.visible = true
		_shichen_fallback.text = SHICHEN_NAMES[_shichen_idx] + "时"


func _load_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex := load(path) as Texture2D
	if tex:
		_tex_cache[path] = tex
	return tex


func _get_period() -> int:
	if _shichen_idx >= 3 and _shichen_idx <= 8:
		return 1
	elif _shichen_idx == 9 or _shichen_idx == 10:
		return 2
	return 0


func _apply_day_tint() -> void:
	if not _cached_map or not _cached_map.has_method("set_day_tint"):
		_cached_map = null
		for child in get_children():
			if child is Node2D and child.has_method("set_day_tint"):
				_cached_map = child
				break
	if _cached_map:
		_cached_map.set_day_tint(PERIOD_TINTS[_last_period])


func _find_player() -> Node2D:
	for child in get_children():
		if child is Node2D and child.has_method("get_player_node"):
			_cached_map = child
			var p = child.get_player_node()
			if p:
				if "map_id" in child and child.map_id != "":
					_map_name_label.text = child.map_id
				return p
	var g := get_tree().get_nodes_in_group("player")
	if not g.is_empty():
		return g[0] as Node2D
	return null


func get_camera() -> Camera2D:
	return _camera


## 场景中是否有对话气球正在显示
static func is_dialogue_active() -> bool:
	return GameData.is_dialogue_active()


## 支持的语言列表
const SUPPORTED_LOCALES: Array[String] = ["zh", "en"]


## 安全检测：当前场景是否有对话气球阻塞 UI（避免非 MainScene 时崩溃）
func _is_ui_blocked_by_dialogue() -> bool:
	var s := get_tree().current_scene
	if s == self or not s.has_method("is_dialogue_active"):
		return false
	return s.is_dialogue_active()


## 切换语言
static func switch_language(locale: String) -> void:
	GameData.set_language(locale)


## 当前语言
static func current_language() -> String:
	return TranslationServer.get_locale()


## 显示普通对话气泡（商店等无限对话 NPC）
func show_normal_chat(dialogue_file: String, title: String, flag: String = "") -> void:
	_show_dialogue_balloon("res://addons/dialogue_manager/example_balloon/normalChat.tscn", dialogue_file, title, flag)


## 打开商店弹窗（由 NPC 对话调用）
func open_shop(npc_name: String = "") -> void:
	var shop = preload("res://Component/ShopPopup.tscn").instantiate()
	add_child(shop)
	shop.closed.connect(func(): shop.queue_free(); _unregister_popup())
	var items = GameData.get_shop_items(npc_name)
	if not items.is_empty():
		shop.set_item_list(items)
	_register_popup()


## 显示剧情对话气泡
func show_story_chat(dialogue_file: String, title: String, flag: String = "") -> void:
	_show_dialogue_balloon("res://addons/dialogue_manager/example_balloon/storyChat.tscn", dialogue_file, title, flag)

func show_team_chat(dialogue_file: String, title: String, flag: String = "") -> void:
	# 读对话文件 → 逐行生成独立气泡
	var res := load(dialogue_file) as DialogueResource
	if res == null: return
	var next_id := title
	var y := 200.0
	var last_speaker := ""
	var on_left := false  # false = 右边, true = 左边
	while true:
		var dl := await res.get_next_dialogue_line(next_id, [])
		if dl == null: break
		next_id = dl.next_id
		if dl.character.is_empty() and dl.text.is_empty(): continue
		if dl.next_id.is_empty(): break

		# 换人说话 → 换边
		if dl.character != last_speaker:
			on_left = not on_left
			last_speaker = dl.character

		var x := 50 if on_left else 350

		# 每行一个新气泡
		var bubble: CanvasLayer = load("res://addons/dialogue_manager/example_balloon/teamChat.tscn").instantiate()
		bubble.layer = 60
		bubble.remove_from_group(&"ballon")
		bubble.will_block_other_input = false
		y += 90
		$UI.add_child(bubble)

		var dlabel := bubble.get_node_or_null("%DialogueLabel") as RichTextLabel
		var clabel := bubble.get_node_or_null("%CharacterLabel") as RichTextLabel
		var balloon := bubble.get_node_or_null("%Balloon") as Control

		if balloon:
			balloon.offset_left = x; balloon.offset_top = int(y)
			balloon.offset_right = x + 400; balloon.offset_bottom = int(y) + 110
			balloon.show()
			balloon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if dlabel:
			dlabel.bbcode_enabled = true
			dlabel.text = dl.text
			dlabel.visible = true
			dlabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if clabel:
			clabel.text = dl.character
			clabel.visible = true
			clabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var panel := bubble.get_node_or_null("%Panel") as Panel
		if panel:
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# 同步到战斗外日志
		var log_line := "[color=lightgreen]%s: %s[/color]\n" % [dl.character, dl.text]
		GameData.world_log_text += log_line
		if _world_log:
			_world_log.append_text(log_line)
			_world_log.scroll_to_line(_world_log.get_line_count())

		# 头像
		var pt := bubble.get_node_or_null("%portrait") as TextureRect
		if pt:
			var was_path := ""
			for mid in GameData.CHARACTER_DB:
				if GameData.CHARACTER_DB[mid].name == dl.character:
					was_path = GameData.CHARACTER_DB[mid].get("was_base_path", "")
					break
			if was_path.is_empty(): was_path = "res://WAS/" + dl.character
			var pp := was_path.path_join("头像/头像.was")
			if FileAccess.file_exists(pp):
				var r := WASReader.new()
				if r.load_from_file(pp):
					var d := r.decode_frame(0, 0)
					if not d.is_empty(): pt.texture = d.get("texture", null)

		# 隐藏不需要的
		for hide_name in ["ResponsesMenu", "Control"]:
			var h := bubble.get_node_or_null("Balloon/" + hide_name)
			if h is CanvasItem: h.visible = false
		var h := bubble.get_node_or_null("AudioStreamPlayer")
		if h is CanvasItem: h.visible = false

		# 自动淡出
		var tw := balloon.create_tween() if balloon else null
		if tw:
			tw.tween_interval(5.0)
			tw.tween_property(balloon, "modulate:a", 0.0, 0.5)
			tw.tween_callback(bubble.queue_free)

		var delay := maxf(1.5, dl.text.length() * 0.08)
		await get_tree().create_timer(delay).timeout

func _show_dialogue_balloon(balloon_scene: String, dialogue_file: String, title: String, flag: String) -> void:
	var res := load(dialogue_file) as DialogueResource
	if res == null:
		return
	var balloon := load(balloon_scene).instantiate() as CanvasLayer
	balloon.add_to_group(&"ballon")
	balloon.dialogue_resource = res
	balloon.start_from_title = title
	balloon.auto_start = false
	balloon.will_block_other_input = true
	add_child(balloon)
	balloon.start(res, title)
	# 等 DialogueManager 发出对话结束信号
	await Engine.get_singleton("DialogueManager").dialogue_ended
	balloon.remove_from_group(&"ballon")
	_unregister_popup()
	if is_instance_valid(balloon):
		balloon.queue_free()
	if not flag.is_empty():
		GameData.game_flags[flag] = true


func _on_bounty_pressed() -> void:
	_open_bounty_popup()


## 战斗外 BattleLog
var _world_log: RichTextLabel = null

func initUIBtn():
	disable_btn("打造")
	disable_btn("天赋")
	disable_btn("悬赏")
	disable_btn("宠物")
	disable_btn("打造")
	disable_btn("人物")
	
