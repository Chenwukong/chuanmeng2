# MainScene.gd
# 主场景逻辑 — 管理悬赏弹窗等全局 UI，相机跟随玩家，时辰/坐标/地图名
extends Node2D
const UIFeedback = preload("res://Script/UI/UISoundFeedback.gd")

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

@onready var _keyboard_nav: Node = $UI/UIKeyboardNavigator
var _world_info_visibility: Dictionary = {}
var _achievement_popup = null
var _achievement_btn: Button
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
var _desktop_menu_layout: Dictionary = {}
var _desktop_menu_transform := Transform2D.IDENTITY
var _desktop_message_offsets: Dictionary = {}

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
@onready var _time_phase_label: Label = $UI/坐标图/TimePhase

## 默认使用玩家子节点 Camera2D；特殊镜头时启用场景相机。
@export var use_scene_camera: bool = false:
	set(value):
		use_scene_camera = value
		if is_node_ready():
			_configure_world_camera()
@export var camera_follow_player: bool = true
var play_childhood_on_start := false

var _tex_cache: Dictionary = {}

func prepare_new_game() -> void:
	play_childhood_on_start = true
	# 标题页实例化后、入树前移除默认地图，避免触发它的镜头、遇怪与音乐。
	var foothills := get_node_or_null("方寸山")
	if foothills:
		foothills.free()


func _ready() -> void:
	if not GameData.difficulty_locked:
		var selection = preload("res://scenes/UI/DifficultySelection.tscn").instantiate()
		add_child(selection)
		await selection.confirmed
	_configure_world_camera()

	_play_time_accum = float(GameData.play_time_sec)
	_shichen_idx = GameData.shichen_idx
	_shichen_accum = GameData.shichen_accum
	bounty_btn.pressed.connect(_on_bounty_pressed)
	_setup_ui_buttons()
	_setup_achievement_button()
	GameData.set_language("zh")
	_world_log = $UI/BattleLog
	_world_log.bbcode_enabled = true
	GameData.world_log = _world_log
	if map_btn:
		map_btn.visible = true
		# 锁定状态由 _refresh_btn_visuals 处理
	# 给所有按钮加名字标签
	_add_btn_labels()
	add_child(load("res://Script/UI/CursorController.gd").new())
	_setup_platform_controls()
	_keyboard_nav.host = self
	GameData.add_party_by_name("游霄云")
	#GameData.add_party_by_name("英女侠")
	#GameData.add_party_by_name("桃夭夭")
	#GameData.add_party_by_name("影精灵")
	GameData.add_party_by_name("凌若昭")

	#ameData.add_party_by_name("大将军")
	_update_time_volume()
	if GameData.story_flag("childhood_prologue_seen"):
		enter_opening_outskirts()
	elif play_childhood_on_start:
		var prologue := load("res://scenes/World/ChildhoodPrologue.tscn") as PackedScene
		add_child(prologue.instantiate())


func enter_opening_outskirts() -> void:
	if has_node("郊外"): return
	var foothills := get_node_or_null("方寸山")
	var outskirts := (load("res://scenes/郊外.tscn") as PackedScene).instantiate()
	if foothills:
		remove_child(foothills)
		foothills.queue_free()
	$BGM.stop()
	add_child(outskirts)
	_configure_world_camera()
	_find_player()
	refresh_map_tint()

func _setup_platform_controls() -> void:
	var base = $UI/按钮底图
	_desktop_menu_transform = base.transform
	for child in base.get_children():
		if child is AnimatedSprite2D: _desktop_menu_layout[child.name] = child.transform
	for name in ["信息框", "BattleLog"]:
		var control = $UI.get_node(name)
		_desktop_message_offsets[name] = Vector2(control.offset_top, control.offset_bottom)
	PlatformControls.mode_changed.connect(_apply_platform_layout)
	get_viewport().size_changed.connect(_apply_platform_layout)
	_apply_platform_layout()

func _apply_platform_layout() -> void:
	var base = $UI/按钮底图
	var message_shift: float = $UI/MobileControls/MessageArea.offset_top - _desktop_message_offsets["信息框"].x if PlatformControls.android_mode else 0.0
	for name in _desktop_message_offsets:
		var control = $UI.get_node(NodePath(name))
		control.offset_top = _desktop_message_offsets[name].x + message_shift
		control.offset_bottom = _desktop_message_offsets[name].y + message_shift
	if PlatformControls.android_mode:
		base.transform = Transform2D.IDENTITY
		base.self_modulate.a = 0.0
		for name in _desktop_menu_layout:
			var sprite = base.get_node(NodePath(name))
			var marker = $UI/MobileControls/MenuPositions.get_node(NodePath(name))
			sprite.position = marker.get_global_transform_with_canvas().origin
			sprite.scale = Vector2(2.0, 2.0)
		if is_instance_valid(_achievement_btn):
			var point: Vector2 = $UI/MobileControls/MenuPositions/成就.get_global_transform_with_canvas().origin
			_achievement_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			_achievement_btn.position = point - Vector2(37, 30)
			_achievement_btn.size = Vector2(74, 60)
	else:
		base.transform = _desktop_menu_transform
		base.self_modulate.a = 1.0
		for name in _desktop_menu_layout: base.get_node(NodePath(name)).transform = _desktop_menu_layout[name]
		if is_instance_valid(_achievement_btn):
			_achievement_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			_achievement_btn.offset_left = -194
			_achievement_btn.offset_right = -104
			_achievement_btn.offset_top = 14
			_achievement_btn.offset_bottom = 44
	
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
	#initUIBtn()

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
		var local_point: Vector2 = sprite.get_global_transform_with_canvas().affine_inverse() * pos
		var rect = Rect2(-tex_size * 0.5, tex_size)
		if rect.has_point(local_point):
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
				UIFeedback.play_ui(&"select")
				_play_sprite_anim(_hovered_sprite, "hover")

	# 鼠标点击按钮
	var pointer_pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed and not event.canceled)
	if pointer_pressed:
		var point: Vector2 = event.position if event is InputEventScreenTouch else event.global_position
		var sprite = _get_menu_sprite_at(point)
		if sprite:
			var btn_name = sprite.name
			if btn_name in _disabled_buttons:
				return
			if btn_name == "地图" and not GameData.has_talent("main_map"):
				return
			_activate_menu(str(btn_name))
			_play_sprite_anim(sprite, "pressed")
			get_viewport().set_input_as_handled()
			await get_tree().create_timer(0.15).timeout
			if _hovered_sprite == sprite:
				_play_sprite_anim(sprite, "hover")
			else:
				_play_sprite_anim(sprite, "default")

	# ESC 由 _unhandled_input 处理
	


func _activate_menu(button: String) -> void:
	match button:
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
		"成就": _open_achievement_popup()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if get_tree().root.get_node_or_null("BattleScene"):
			return  # 战斗中不允许 ESC 打开存档
		_esc_close_or_save()
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_F2:
			get_viewport().set_input_as_handled()
			open_shop("", 10)  # 调试：打开 10 级装备商店
		if event.keycode == KEY_F1:
			var bs = get_tree().root.get_node_or_null("BattleScene")
			if bs and bs.has_method("_toggle_double_speed"):
				get_viewport().set_input_as_handled()
				bs._toggle_double_speed()


## 关闭任意一个已打开的弹窗（返回是否真的关掉了一个）
func _close_top_popup() -> bool:
	if $HelpUI.is_open():
		$HelpUI.close()
		return true
	if is_instance_valid(_achievement_popup):
		_achievement_popup.close()
		return true
	if _team_popup and is_instance_valid(_team_popup):
		_team_popup.close()
		return true
	if _build_popup and is_instance_valid(_build_popup):
		_build_popup.close()
		_build_popup = null
		_unregister_popup()
		return true
	if _status_popup and is_instance_valid(_status_popup):
		_status_popup.close_popup()
		_status_popup = null
		_unregister_popup()
		return true
	if _equip_page and is_instance_valid(_equip_page):
		_close_popup(_equip_page)
		return true
	if _pet_popup and is_instance_valid(_pet_popup):
		_close_popup(_pet_popup)
		return true
	if _talent_tree and is_instance_valid(_talent_tree):
		_close_popup(_talent_tree)
		return true
	if _map_popup and is_instance_valid(_map_popup):
		_close_popup(_map_popup)
		return true
	if _setting_popup and is_instance_valid(_setting_popup):
		_setting_popup.close()
		_setting_popup = null
		_unregister_popup()
		return true
	if _hint_popup and is_instance_valid(_hint_popup):
		_hint_popup._close()
		_hint_popup = null
		return true
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
		return true
	if _save_popup and is_instance_valid(_save_popup):
		_close_popup(_save_popup)
		return true
	if _shop_popup and is_instance_valid(_shop_popup):
		_shop_popup._close()
		return true
	return false


## 强制关闭所有菜单弹窗（进入战斗等场景前调用，确保 HUD 干净）
func _close_all_popups() -> void:
	var guard: int = 0
	while guard < 30:
		guard += 1
		if not _close_top_popup():
			break
	# 兜底：悬赏弹窗若状态不一致，也强制关掉
	if _bounty_popup and is_instance_valid(_bounty_popup):
		_bounty_popup.hide()
		_bounty_popup.queue_free()
		_bounty_popup = null
	_bounty_open = false
	# 兜底：清掉弹窗阻塞状态并恢复 HUD
	GameData.ui_blocked = false
	_unregister_popup()


## ESC 依次关闭已打开的面板（队伍/道具/宠物/天赋/悬赏/存档等），全关掉后开存档
func _esc_close_or_save() -> void:
	if not _close_top_popup():
		_open_save_popup()


func _play_sprite_anim(sprite: AnimatedSprite2D, anim: String):
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


func begin_talent_tutorial() -> void:
	if GameData.in_battle or GameData.ui_blocked or GameData.is_dialogue_active(): return
	_open_talent_tree()
	# 教学暂停游戏前完成页面切换，避免淡入 Tween 停在全透明状态。
	_talent_tree.show_page("Page_Main")
	var tutorial = preload("res://scenes/UI/TalentTutorial.tscn").instantiate()
	add_child(tutorial)

func _open_talent_tree():
	if _talent_tree and is_instance_valid(_talent_tree):
		_close_popup(_talent_tree)
		return
	_talent_tree = preload("res://scenes/UI/TalentTree.tscn").instantiate()
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
	_equip_page.set_materials(GameData.material_bag)
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
		var root_texture = preload("res://Script/Assets/AssetLoader.gd").root_portrait(s.was_base_path, s.portrait_path, s.character_name)
		if root_texture != null: return root_texture
		if s.was_base_path.is_empty(): continue
		var p = s.was_base_path + "/头像/头像.was"
		if not FileAccess.file_exists(p): continue
		var r_frame: Dictionary = preload("res://Script/Assets/AssetLoader.gd").was_frame(p)
		if r_frame.is_empty(): continue
		var d := r_frame
		if d.is_empty(): continue
		return d.get("texture", null)
	return null


func _open_pet_popup():
	if _pet_popup and is_instance_valid(_pet_popup):
		_close_popup(_pet_popup)
		return
	_pet_popup = preload("res://scenes/UI/Pets/PetPopup.tscn").instantiate()
	add_child(_pet_popup)
	_pet_popup.closed.connect(func():
		if is_instance_valid(_pet_popup): _pet_popup.queue_free()
		_pet_popup = null
		_unregister_popup()
	)
	_register_popup(_pet_popup)


## 队伍列表弹窗 — 点击「队伍」按钮打开（弹窗会阻止走路/怪物追击，ESC 或点击任意处关闭）
func _open_team_popup():
	if _team_popup and is_instance_valid(_team_popup):
		_team_popup.close()
		return
	_team_popup = preload("res://scenes/UI/TeamPopup.tscn").instantiate()
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
	_save_popup = preload("res://scenes/UI/Save/SavePopup.tscn").instantiate()
	add_child(_save_popup)
	_save_popup.closed.connect(func(): _save_popup = null; _unregister_popup())
	_register_popup(_save_popup)


func get_current_map_root() -> Node2D:
	for child in get_children():
		if child is Node2D and child.has_method("get_player_node") and not child.is_queued_for_deletion():
			return child
	return null


func _open_map_popup() -> void:
	if _map_popup and is_instance_valid(_map_popup):
		_close_popup(_map_popup)
		return
	if not GameData.has_talent("main_map"): return
	_map_popup = preload("res://scenes/UI/map.tscn").instantiate()
	add_child(_map_popup)
	# 按钮
	var close_btn = _map_popup.get_node_or_null("CloseButton") as BaseButton
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
	var map_root = get_current_map_root()
	var map_id = map_root.map_id if map_root and not map_root.map_id.is_empty() else ""
	var tp_data = GameData.get_teleports(map_id)
	if not tp_data.is_empty():
		var content = _map_popup.get_node("MapContainer/MapViewport/MapContent")
		if content:
			content.teleport_data = tp_data
	_register_popup(_map_popup)
	if map_container:
		map_container.navigation_requested.connect(_on_minimap_navigation_requested)
		map_container.switch_to_current()


func _on_minimap_navigation_requested(world_position: Vector2) -> void:
	if GameData.in_battle or GameData.is_dialogue_active(): return
	var map_root = get_current_map_root()
	if map_root == null: return
	var player = map_root.get_player_node()
	if player and player.has_method("navigate_to") and player.navigate_to(world_position):
		return
	elif _map_popup and is_instance_valid(_map_popup):
		var container = _map_popup.get_node("MapContainer")
		container._minimap_overlay.show_navigation_error()

func _close_map() -> void:
	if _map_popup and is_instance_valid(_map_popup):
		_close_popup(_map_popup)


func _open_build_popup() -> void:
	if _build_popup and is_instance_valid(_build_popup):
		_close_popup(_build_popup)
		return
	open_crafting()

func open_crafting() -> CanvasLayer:
	if is_instance_valid(_build_popup): return _build_popup
	var popup = preload("res://scenes/UI/build_popup.tscn").instantiate()
	add_child(popup)
	_build_popup = popup
	popup.closed.connect(func(): _build_popup = null; _unregister_popup(), CONNECT_ONE_SHOT)
	# 传装备 + 材料
	popup.set_materials(GameData.equip_bag.duplicate() + GameData.material_bag.duplicate() + _get_equipped_items())
	_register_popup(_build_popup)
	return popup


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
	var popup = preload("res://scenes/UI/SettingPopup.tscn").instantiate()
	_setting_popup = popup
	add_child(popup)
	popup.closed.connect(func(): _setting_popup = null; _unregister_popup())
	popup.volume_changed.connect(_update_time_volume)
	_register_popup(_setting_popup)


func _open_hint_popup() -> void:
	if _hint_popup and is_instance_valid(_hint_popup):
		return
	_hint_popup = preload("res://scenes/UI/hintPopup.tscn").instantiate()
	add_child(_hint_popup)
	_hint_popup.closed.connect(func(): _hint_popup = null; _unregister_popup())
	_register_popup(_hint_popup)


func _open_bounty_popup():
	if _bounty_popup == null or not is_instance_valid(_bounty_popup):
		_bounty_popup = preload("res://scenes/UI/BountyPopup.tscn").instantiate()
		add_child(_bounty_popup)
		_bounty_popup.closed.connect(func(): _bounty_open = false; _unregister_popup())
		_bounty_popup.open()
		_bounty_open = true
		_register_popup(_bounty_popup)
		return

	if _bounty_open:
		_bounty_popup.hide()
		_bounty_open = false
		_unregister_popup()
	else:
		_bounty_popup.open()
		_bounty_open = true
		_register_popup(_bounty_popup)


func can_navigate_with_minimap_open() -> bool:
	return is_instance_valid(_map_popup) and not _has_any_popup_open(false)


func _has_any_popup_open(include_map: bool = true) -> bool:
	if $HelpUI.is_open(): return true
	if is_instance_valid(_achievement_popup): return true
	if _bounty_open: return true
	if include_map and is_instance_valid(_map_popup): return true
	if is_instance_valid(_team_popup): return true
	if is_instance_valid(_build_popup): return true
	if is_instance_valid(_setting_popup): return true
	if is_instance_valid(_shop_popup): return true
	if is_instance_valid(_hint_popup): return true
	if _pet_popup and is_instance_valid(_pet_popup): return true
	if _save_popup and is_instance_valid(_save_popup): return true
	if _talent_tree and is_instance_valid(_talent_tree): return true
	if _equip_page and is_instance_valid(_equip_page): return true
	if _status_popup and is_instance_valid(_status_popup): return true
	return false


func _register_popup(_node: Node = null):
	if is_instance_valid(_node): _node.set_meta("keyboard_cancel", _close_keyboard_panel.bind(_node))
	if is_instance_valid(_keyboard_nav): _keyboard_nav.push(_node)
	GameData.ui_blocked = true
	for info_name in ["信息框", "提示", "BattleLog"]:
		var info := get_node_or_null("UI/" + info_name) as CanvasItem
		if info:
			if not _world_info_visibility.has(info_name):
				_world_info_visibility[info_name] = info.visible
			info.hide()
	_refresh_btn_visuals()
	$UI/坐标图.visible = false
	$UI/按钮底图.visible = false
	if _achievement_btn: _achievement_btn.visible = false
	if bounty_btn: bounty_btn.visible = false

func _close_keyboard_panel(panel: Node) -> void:
	if not is_instance_valid(panel): return
	if panel == _bounty_popup:
		panel._on_close()
		panel.hide()
	elif panel.has_method("close_popup"):
		panel.close_popup()
	elif panel.has_method("close"):
		panel.close()
	elif panel.has_method("_close"):
		panel._close()
	else:
		_close_popup(panel)

func _unregister_popup(_node: Node = null):
	if not _has_any_popup_open():
		for info_name in _world_info_visibility:
			var info := get_node_or_null("UI/" + str(info_name)) as CanvasItem
			if info: info.visible = _world_info_visibility[info_name]
		_world_info_visibility.clear()
		GameData.ui_blocked = false
		_refresh_btn_visuals()
		if map_btn:
			map_btn.visible = true
			# 锁定状态由 _refresh_btn_visuals 处理
		$UI/坐标图.visible = true
		$UI/按钮底图.visible = true
		if _achievement_btn: _achievement_btn.visible = true
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
			# 进入战斗：强制关掉所有菜单弹窗（防止过渡中打开的 UI 留在战斗界面上）
			_close_all_popups()
		$UI/坐标图.visible = false
		$UI/按钮底图.visible = false
		if _achievement_btn: _achievement_btn.visible = false
		if bounty_btn: bounty_btn.visible = false
		if has_node("UI/信息框"): $UI/信息框.visible = false
		if has_node("UI/提示"): $UI/提示.visible = false
		return

	if _was_in_battle:
		_was_in_battle = false
		$UI/坐标图.visible = true
		$UI/按钮底图.visible = true
		if _achievement_btn: _achievement_btn.visible = true
		if bounty_btn: bounty_btn.visible = true
		if has_node("UI/信息框"): $UI/信息框.visible = true
		if has_node("UI/提示"): $UI/提示.visible = true
		if _world_log:
			_world_log.scroll_to_line(_world_log.get_line_count())

	# 没有消息时收起日志背景，避免空面板遮住地图。
	if not GameData.ui_blocked and is_instance_valid(_world_log):
		var has_messages := not _world_log.get_parsed_text().strip_edges().is_empty()
		$UI/信息框.visible = has_messages
		_world_log.visible = has_messages

	# 外部 BattleLog 由 battleUI 通过 GameData.world_log_text 更新，MainScene 只读不写

	if not GameData.ui_blocked:
		_shichen_accum += delta
		if _shichen_accum >= SECONDS_PER_SHICHEN:
			_shichen_accum -= SECONDS_PER_SHICHEN
			_shichen_idx = (_shichen_idx + 1) % 12
			_update_time_volume()
		GameData.play_time_sec = int(Time.get_ticks_msec() / 1000.0)
		GameData.shichen_idx = _shichen_idx
		GameData.shichen_accum = _shichen_accum
	_update_time_ui()

	var period := _get_period()
	if period != _last_period or not is_instance_valid(_cached_map):
		_last_period = period
		GameData.current_period = period
		_apply_day_tint()

	var player := _find_player()
	if not player:
		return
	if use_scene_camera and camera_follow_player and _camera:
		_camera.global_position = player.global_position
	_xy_label.text = "x:%d  y:%d" % [int(player.global_position.x) / 10, int(player.global_position.y) / 10]


func _update_time_ui() -> void:
	var is_night := _shichen_idx >= 0 and _shichen_idx <= 2
	var dn_path := "res://Graphic/UI/夜.PNG" if is_night else "res://Graphic/UI/昼.PNG"
	_day_night_icon.texture = _load_tex(dn_path)

	# 时辰用清晰文字显示，避免像素字贴图与信息卡字号不协调。
	_shichen_icon.visible = false
	_shichen_fallback.visible = true
	_shichen_fallback.text = SHICHEN_NAMES[_shichen_idx] + "时"
	_time_phase_label.text = "夜间" if is_night else "白昼"


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


func _apply_day_tint(immediate: bool = false) -> void:
	if not is_instance_valid(_cached_map) or not _cached_map.has_method("set_day_tint") or _cached_map.is_queued_for_deletion():
		_cached_map = null
		for child in get_children():
			if child is Node2D and child.has_method("set_day_tint") and not child.is_queued_for_deletion():
				_cached_map = child
	if is_instance_valid(_cached_map):
		_cached_map.set_day_tint(PERIOD_TINTS[_last_period], immediate)


func refresh_map_tint() -> void:
	_cached_map = null
	_apply_day_tint(true)


func _get_volume_multiplier() -> float:
	# 子丑寅(0-2)=晚上60%, 卯辰巳(3-5)=早上100%, 午未申(6-8)=下午80%, 酉戌亥(9-11)=晚上60%
	if _shichen_idx <= 2: return 0.6
	elif _shichen_idx <= 5: return 1.0
	elif _shichen_idx <= 8: return 0.8
	else: return 0.6

func _update_time_volume() -> void:
	var mult = _get_volume_multiplier()
	for bus_name in ["Master", "BGM", "SFX"]:
		var bus = AudioServer.get_bus_index(bus_name)
		if bus < 0: continue
		var base = {
			"Master": GameData.base_vol_master,
			"BGM": GameData.base_vol_bgm,
			"SFX": GameData.base_vol_sfx
		}[bus_name]
		var actual = base * mult
		AudioServer.set_bus_volume_db(bus, linear_to_db(actual) if actual > 0 else -80)


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


func _configure_world_camera() -> void:
	var selected := get_camera()
	var scene_camera := get_node_or_null("Camera2D") as Camera2D
	if scene_camera:
		scene_camera.enabled = scene_camera == selected
	for child in get_children():
		if child.has_method("get_player_node"):
			var player = child.get_player_node()
			var player_camera: Camera2D = player.get_node_or_null("Camera2D") if player else null
			if player_camera:
				player_camera.enabled = player_camera == selected
			if child.has_method("_set_camera_limits"):
				child._set_camera_limits()
	if selected:
		selected.enabled = true
		selected.make_current()
		selected.reset_smoothing()
		selected.force_update_scroll()


func get_camera() -> Camera2D:
	# 子地图 ready 时也会调用，不能依赖主场景的 onready 字段。
	if not use_scene_camera:
		for child in get_children():
			if child.has_method("get_player_node"):
				var player = child.get_player_node()
				if player:
					var camera := player.get_node_or_null("Camera2D") as Camera2D
					if camera:
						return camera
	return get_node_or_null("Camera2D") as Camera2D


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
func show_normal_chat(dialogue_file: String, title: String, flag: String = "") -> bool:
	return await _show_dialogue_balloon("res://addons/dialogue_manager/example_balloon/normalChat.tscn", dialogue_file, title, flag)


## 打开商店弹窗（由 NPC 对话调用）
## 传 shop_level>0 直接卖 ≤该等级的装备（等级档表）；否则按 npc_name 查 SHOP_NPC_DB
func open_shop(npc_name: String = "", shop_level: int = 0) -> CanvasLayer:
	var shop = preload("res://scenes/UI/ShopPopup.tscn").instantiate()
	add_child(shop)
	_shop_popup = shop
	shop.closed.connect(func(): _shop_popup = null; shop.queue_free(); _unregister_popup())
	var items: Array[Dictionary] = []
	if shop_level > 0:
		items = GameData.get_equip_shop_items(shop_level)
	elif not npc_name.is_empty():
		items = GameData.get_shop_items(npc_name)
	if not items.is_empty():
		shop.set_item_list(items)
	_register_popup(_shop_popup)
	return shop


## 显示剧情对话气泡
func show_story_chat(dialogue_file: String, title: String, flag: String = "") -> bool:
	return await _show_dialogue_balloon("res://addons/dialogue_manager/example_balloon/storyChat.tscn", dialogue_file, title, flag)

var _team_chat_feed: CanvasLayer

func show_team_chat(dialogue_file: String, title: String, flag: String = "") -> bool:
	var resource := load(dialogue_file) as DialogueResource
	if resource == null: return false
	if is_instance_valid(_team_chat_feed): _team_chat_feed.cancel()
	var feed = preload("res://addons/dialogue_manager/example_balloon/teamChat.tscn").instantiate()
	_team_chat_feed = feed
	$UI.add_child(feed)
	feed.line_shown.connect(_on_team_chat_line)
	var completed: bool = await feed.play(resource, title)
	if _team_chat_feed == feed: _team_chat_feed = null
	feed.queue_free()
	if completed and not flag.is_empty(): GameData.game_flags[flag] = true
	return completed

func _on_team_chat_line(speaker: String, message: String) -> void:
	var line := "[color=#bcd9ef]%s：%s[/color]\n" % [speaker, message]
	GameData.world_log_text += line
	if _world_log:
		_world_log.append_text(line)
		_world_log.scroll_to_line(_world_log.get_line_count())

func _show_dialogue_balloon(balloon_scene: String, dialogue_file: String, title: String, flag: String) -> bool:
	var res := load(dialogue_file) as DialogueResource
	if res == null:
		return false
	var balloon := load(balloon_scene).instantiate() as CanvasLayer
	balloon.add_to_group(&"ballon")
	balloon.dialogue_resource = res
	balloon.start_from_title = title
	balloon.auto_start = false
	balloon.will_block_other_input = true
	add_child(balloon)
	balloon.start(res, title)
	# 只等待当前资源结束，避免其他对话或队友气泡的结束信号误关闭本段剧情。
	while true:
		var ended_resource = await Engine.get_singleton("DialogueManager").dialogue_ended
		if ended_resource == res: break
	balloon.remove_from_group(&"ballon")
	_unregister_popup()
	if is_instance_valid(balloon):
		balloon.queue_free()
	if not flag.is_empty():
		GameData.game_flags[flag] = true

	return true

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
	

func _setup_achievement_button() -> void:
	_achievement_btn = $UI/AchievementButton
	_achievement_btn.pressed.connect(_open_achievement_popup)
	GameData.achievements_changed.connect(_refresh_achievement_badge)
	GameData.ensure_achievement_notifications()
	_refresh_achievement_badge()

func _refresh_achievement_badge() -> void:
	if not is_instance_valid(_achievement_btn): return
	var count := GameData.get_claimable_achievement_count()
	_achievement_btn.text = "成就 %d" % count if count > 0 else "成就"
	_achievement_btn.add_theme_color_override("font_color", Color("ffe475") if count > 0 else Color("fff0ac"))
	_achievement_btn.tooltip_text = "%d 份成就奖励待领取" % count if count > 0 else "查看成就进度"

func _open_achievement_popup() -> void:
	if GameData.in_battle or GameData.ui_blocked: return
	_achievement_popup = preload("res://scenes/UI/AchievementPopup.tscn").instantiate()
	add_child(_achievement_popup)
	_achievement_popup.closed.connect(func():
		_achievement_popup = null
		_unregister_popup()
	)
	_register_popup(_achievement_popup)
