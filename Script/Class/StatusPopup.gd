# StatusPopup.gd
# 角色属性加点面板 — 5 属性 + 魔力按钮，Prev/Next 切角色，Confirm 确认写入
class_name StatusPopup
extends CanvasLayer

signal closed()

@onready var _hp_btn: TextureButton = %HpAddButton
@onready var _magic_btn: TextureButton = %MagicAddButton
@onready var _str_btn: TextureButton = %StrengthAddButton
@onready var _def_btn: TextureButton = %DefenseAddButton
@onready var _spd_btn: TextureButton = %SpeedAddButton
@onready var _prev_btn: TextureButton = %PrevButton
@onready var _next_btn: TextureButton = %NextButton
@onready var _confirm_btn: TextureButton = %ConfirmButton
@onready var _cancel_btn: TextureButton = %CancelButton
@onready var _portrait: TextureRect = %Portrait

var _members: Array = []
var _current_idx: int = 0

var _tmp_hp: int = 0
var _tmp_mp: int = 0
var _tmp_atk: int = 0
var _tmp_def: int = 0
var _tmp_spd: int = 0
var _tmp_magic: int = 0
var _tmp_matk: int = 0
var _potential_pool: Dictionary = {}
var _animating: bool = false
var _step5_mode: bool = false      # 每次 +5 模式（toggle）
@onready var _step_btn: TextureButton = %StepButton  # 场景中的加点步长切换按钮


static func open() -> StatusPopup:
	var inst: StatusPopup = load("res://Component/StatusPopup.tscn").instantiate()
	Engine.get_main_loop().current_scene.add_child(inst)
	inst._setup()
	return inst


func _setup() -> void:
	_members = GameData.party_db.keys().duplicate()
	_current_idx = 0
	for mid in _members:
		if not _potential_pool.has(mid):
			var s = GameData.party_db[mid]
			_potential_pool[mid] = s.potential_left if s else 0
	_reset_temp()
	_add_xisuidan_button()
	_step_btn.toggled.connect(_on_step_toggled)
	_update_step_btn()
	_refresh()

	_hp_btn.pressed.connect(func(): _add_step("hp"))
	_magic_btn.pressed.connect(func(): _add_magic_step())
	_str_btn.pressed.connect(func(): _add_step("atk"))
	_def_btn.pressed.connect(func(): _add_step("def"))
	_spd_btn.pressed.connect(func(): _add_step("spd"))
	_prev_btn.pressed.connect(_prev_char)
	_next_btn.pressed.connect(_next_char)
	_confirm_btn.pressed.connect(_confirm)
	_cancel_btn.pressed.connect(_cancel)


func _reset_temp() -> void:
	_tmp_hp = 0; _tmp_mp = 0; _tmp_atk = 0
	_tmp_def = 0; _tmp_spd = 0; _tmp_magic = 0; _tmp_matk = 0


func _current_stats() -> CharacterStats:
	return GameData.party_db.get(_members[_current_idx], null) if _current_idx < _members.size() else null


func _potential() -> int:
	if _members.is_empty(): return 0
	var mid = _members[_current_idx]
	var pool: int = _potential_pool.get(mid, 0)
	var used := _tmp_hp + _tmp_mp + _tmp_atk + _tmp_def + _tmp_spd + _tmp_magic
	return maxi(0, pool - used)


## 本次加点步长：+5 模式开启 或 按住 Shift 点击 → 5，否则 1
func _current_step() -> int:
	if _step5_mode or Input.is_key_pressed(KEY_SHIFT):
		return 5
	return 1


## 当前模式下的最少可用潜力（按钮禁用阈值）
func _min_step() -> int:
	return 5 if _step5_mode else 1


func _add_step(stat: String) -> void:
	var step := _current_step()
	if _potential() < step:
		_play_sfx("res://Audio/SE/002-System02.ogg")
		if step > 1:
			_show_toast("潜力不足 %d 点" % step)
		return
	match stat:
		"hp":  _tmp_hp += step
		"mp":  _tmp_mp += step
		"atk": _tmp_atk += step
		"def": _tmp_def += step
		"spd": _tmp_spd += step
	_play_sfx("res://Audio/SE/001-System01.ogg")
	_refresh()


func _add_magic_step() -> void:
	var step := _current_step()
	if _potential() < step:
		_play_sfx("res://Audio/SE/002-System02.ogg")
		if step > 1:
			_show_toast("潜力不足 %d 点" % step)
		return
	_tmp_magic += step; _tmp_matk += step
	_play_sfx("res://Audio/SE/001-System01.ogg")
	_refresh()


## 步长切换（场景中的 StepButton 节点，toggle）
func _on_step_toggled(on: bool) -> void:
	_step5_mode = on
	_update_step_btn()
	_play_sfx("res://Audio/SE/001-System01.ogg")
	_refresh()


func _update_step_btn() -> void:
	if _step_btn == null: return
	_step_btn.button_pressed = _step5_mode
	var lbl := _step_btn.get_node_or_null("Label") as Label
	if lbl:
		lbl.text = "+5" if _step5_mode else "+1"
	_step_btn.modulate = Color(1, 0.85, 0.2) if _step5_mode else Color.WHITE




func _prev_char() -> void:
	if _members.is_empty() or _animating: return
	_animating = true
	_play_sfx("res://Audio/SE/001-System01.ogg")
	_reset_temp()
	var orig := offset.x
	await _shift_x(orig + 30)
	_current_idx = (_current_idx - 1 + _members.size()) % _members.size()
	_refresh()
	await _unshift_x(orig)
	_animating = false


func _next_char() -> void:
	if _members.is_empty() or _animating: return
	_animating = true
	_play_sfx("res://Audio/SE/001-System01.ogg")
	_reset_temp()
	var orig := offset.x
	await _shift_x(orig - 30)
	_current_idx = (_current_idx + 1) % _members.size()
	_refresh()
	await _unshift_x(orig)
	_animating = false


func _shift_x(to: float) -> void:
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "offset:x", to, 0.08)
	await tw.finished


func _unshift_x(orig: float) -> void:
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "offset:x", orig, 0.15)


func _confirm() -> void:
	var s := _current_stats()
	if s == null or _members.is_empty(): return
	var mid = _members[_current_idx]
	var used := _tmp_hp + _tmp_mp + _tmp_atk + _tmp_def + _tmp_spd + _tmp_magic
	_play_sfx("res://Audio/SE/001-System01.ogg" if used > 0 else "res://Audio/SE/002-System02.ogg")
	_potential_pool[mid] = maxi(0, _potential_pool.get(mid, 0) - used)
	# 记录已分配的能力点（洗髓丹返还用）
	s.alloc_hp    += _tmp_hp
	s.alloc_mp    += _tmp_mp
	s.alloc_atk   += _tmp_atk
	s.alloc_def   += _tmp_def
	s.alloc_spd   += _tmp_spd
	s.alloc_magic += _tmp_magic
	s.potential_left = _potential_pool[mid]
	s.max_hp        += _tmp_hp + _tmp_magic
	s.max_mp        += _tmp_mp + _tmp_magic
	s.attack        += _tmp_atk
	s.defense       += _tmp_def
	s.speed         += _tmp_spd
	s.magic_attack  += _tmp_matk
	_reset_temp()
	_refresh()


func close_popup() -> void:
	_play_sfx("res://Audio/SE/003-System03.ogg")
	closed.emit()
	queue_free()


func _cancel() -> void:
	_play_sfx("res://Audio/SE/003-System03.ogg")
	_reset_temp()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_popup()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var s := _current_stats()
	if s == null: return

	# 套用装备属性（只取当前查看角色的装备）
	var eq_hp := 0; var eq_mp := 0; var eq_atk := 0
	var eq_def := 0; var eq_spd := 0; var eq_matk := 0
	if _current_idx < _members.size():
		var mid = _members[_current_idx]
		var char_equip = GameData.player_equipment.get(mid, {})
		if char_equip is Dictionary:
			for eq in char_equip.values():
				if eq is Dictionary:
					var b = eq.get("base", {})
					eq_hp += b.get("hp", 0); eq_mp += b.get("mp", 0)
					eq_atk += b.get("atk", 0); eq_def += b.get("def", 0)
					eq_spd += b.get("spd", 0); eq_matk += b.get("matk", 0)

	var hp := s.max_hp + eq_hp + _tmp_hp + _tmp_magic
	var mp := s.max_mp + eq_mp + _tmp_mp + _tmp_magic
	var atk := s.attack + eq_atk + _tmp_atk
	var df := s.defense + eq_def + _tmp_def
	var spd := s.speed + eq_spd + _tmp_spd
	var matk := s.magic_attack + eq_matk + _tmp_matk

	_set_attr("名称", s.get_display_name(), Color(1, 0.85, 0.2))
	_set_attr("等级", "%d" % s.level, Color.WHITE)
	_set_attr("气血", "%d/%d" % [s.saved_hp if s.saved_hp > 0 else hp, hp], _green_if(_tmp_hp > 0 or _tmp_magic > 0))
	_set_attr("蓝量", "%d/%d" % [s.saved_mp if s.saved_mp > 0 else mp, mp], _green_if(_tmp_mp > 0 or _tmp_magic > 0))
	_set_attr("升级经验", "%d" % s.exp, Color.WHITE)
	_set_attr("所需经验", "%d" % s.exp_to_next, Color.WHITE)

	_set_attr("体质", "%d" % hp, _green_if(_tmp_hp > 0 or _tmp_magic > 0))
	_set_attr("魔力", "%d" % matk, _green_if(_tmp_matk > 0))
	_set_attr("力量", "%d" % atk, _green_if(_tmp_atk > 0))
	_set_attr("耐力", "%d" % df, _green_if(_tmp_def > 0))
	_set_attr("敏捷", "%d" % spd, _green_if(_tmp_spd > 0))

	set_label("潜力", "%d" % _potential())

	var pot := _potential()
	var min_step := _min_step()
	_hp_btn.disabled = pot < min_step
	_magic_btn.disabled = pot < min_step
	_str_btn.disabled = pot < min_step
	_def_btn.disabled = pot < min_step
	_spd_btn.disabled = pot < min_step
	var gray := Color(0.4, 0.4, 0.4) if pot < min_step else Color.WHITE
	_hp_btn.modulate = gray
	_magic_btn.modulate = gray
	_str_btn.modulate = gray
	_def_btn.modulate = gray
	_spd_btn.modulate = gray

	_load_portrait(s)


func _green_if(cond: bool) -> Color:
	return Color(0.3, 1, 0.4) if cond else Color.WHITE


func _set_attr(node_name: String, text: String, col: Color) -> void:
	var nd := get_node_or_null(node_name) as Label
	if nd == null: return
	nd.text = text
	nd.add_theme_color_override("font_color", col)


func set_label(node_name: String, text: String) -> void:
	var nd := get_node_or_null(node_name) as Label
	if nd: nd.text = text


func _load_portrait(s: CharacterStats) -> void:
	if _portrait == null: return
	var was_path := s.was_base_path
	if was_path.is_empty(): was_path = "res://WAS/" + s.character_name
	var p := was_path.path_join("头像/头像.was")
	if not FileAccess.file_exists(p):
		_portrait.texture = null
		return
	var r := WASReader.new()
	if not r.load_from_file(p): _portrait.texture = null; return
	var d := r.decode_frame(0, 0)
	_portrait.texture = d.get("texture", null) if not d.is_empty() else null


## 洗髓丹按钮（右下角，动态创建避免改场景）
var _xisuidan_btn: Button = null

func _add_xisuidan_button() -> void:
	if _xisuidan_btn: return
	var btn := Button.new()
	var item: ItemData = GameData.item_db.get("item_xisuidan")
	if item and not item.icon_path.is_empty():
		var reader := TcpReader.new()
		if reader.load_from_file(item.icon_path):
			var d := reader.decode_frame(0)
			if not d.is_empty():
				var tex: Texture2D = d.get("texture", null)
				if tex:
					btn.icon = tex
					btn.expand_icon = true
	btn.pressed.connect(_use_xisuidan)
	btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn.position = Vector2(-300, -70)
	btn.custom_minimum_size = Vector2(280, 44)
	add_child(btn)
	_xisuidan_btn = btn
	_refresh_xisuidan_text()


## 刷新按钮上的洗髓丹剩余数量（x1/x2…）
func _refresh_xisuidan_text() -> void:
	if _xisuidan_btn == null: return
	var cnt := GameData.player_inventory.get_count("item_xisuidan")
	_xisuidan_btn.text = "使用洗髓丹（返还能力点）x%d" % cnt


## 使用洗髓丹：返还当前角色全部已分配的能力点
func _use_xisuidan() -> void:
	if _members.is_empty(): return
	if not GameData.player_inventory.has_item("item_xisuidan"):
		_play_sfx("res://Audio/SE/002-System02.ogg")
		_show_toast("背包中没有洗髓丹！")
		return
	var mid = _members[_current_idx]
	var refunded := GameData.refund_ability_points(mid)
	if refunded <= 0:
		_play_sfx("res://Audio/SE/002-System02.ogg")
		_show_toast("该角色没有已分配的能力点")
		return
	GameData.player_inventory.remove_item("item_xisuidan", 1)
	var s: CharacterStats = GameData.party_db.get(mid)
	if s:
		_potential_pool[mid] = s.potential_left
	_reset_temp()
	_refresh()
	_refresh_xisuidan_text()
	_play_sfx("res://Audio/SE/001-System01.ogg")
	_show_toast("使用洗髓丹，返还 %d 点能力点！" % refunded)


## 播放 UI 音效（与其它界面同套规则：001 点击/成功、002 失败、003 取消/关闭）
func _play_sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var snd := AudioStreamPlayer.new()
	snd.stream = load(path)
	snd.bus = "SFX"
	get_tree().root.add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)


## 右下角提示文字
func _show_toast(msg: String) -> void:
	var label := Label.new()
	label.text = msg
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.position = Vector2(-400, -120)
	label.custom_minimum_size = Vector2(800, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(label.queue_free)


func _on_close_button_pressed() -> void:
	closed.emit()
	queue_free()
