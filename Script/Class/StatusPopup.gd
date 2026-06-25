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
			_potential_pool[mid] = s.level * 2 if s else 10
	_reset_temp()
	_refresh()

	_hp_btn.pressed.connect(func(): _add_temp("hp"))
	_magic_btn.pressed.connect(func(): _add_magic())
	_str_btn.pressed.connect(func(): _add_temp("atk"))
	_def_btn.pressed.connect(func(): _add_temp("def"))
	_spd_btn.pressed.connect(func(): _add_temp("spd"))
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


func _add_temp(stat: String) -> void:
	if _potential() <= 0: return
	match stat:
		"hp":  _tmp_hp += 1
		"mp":  _tmp_mp += 1
		"atk": _tmp_atk += 1
		"def": _tmp_def += 1
		"spd": _tmp_spd += 1
	_refresh()


func _add_magic() -> void:
	if _potential() <= 0: return
	_tmp_magic += 1; _tmp_matk += 1
	_refresh()


func _prev_char() -> void:
	if _members.is_empty(): return
	_reset_temp()
	_current_idx = (_current_idx - 1 + _members.size()) % _members.size()
	_refresh()


func _next_char() -> void:
	if _members.is_empty(): return
	_reset_temp()
	_current_idx = (_current_idx + 1) % _members.size()
	_refresh()


func _confirm() -> void:
	var s := _current_stats()
	if s == null or _members.is_empty(): return
	var mid = _members[_current_idx]
	var used := _tmp_hp + _tmp_mp + _tmp_atk + _tmp_def + _tmp_spd + _tmp_magic
	_potential_pool[mid] = maxi(0, _potential_pool.get(mid, 0) - used)
	s.max_hp        += _tmp_hp + _tmp_magic
	s.max_mp        += _tmp_mp + _tmp_magic
	s.attack        += _tmp_atk
	s.defense       += _tmp_def
	s.speed         += _tmp_spd
	s.magic_attack  += _tmp_matk
	_reset_temp()
	_refresh()


func close_popup() -> void:
	closed.emit()
	queue_free()


func _cancel() -> void:
	_reset_temp()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_popup()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var s := _current_stats()
	if s == null: return

	_set_attr("名称", s.character_name, Color(1, 0.85, 0.2))
	_set_attr("等级", "%d" % s.level, Color.WHITE)
	_set_attr("气血", "%d" % (s.max_hp + _tmp_hp + _tmp_magic), _green_if(_tmp_hp > 0 or _tmp_magic > 0))
	_set_attr("蓝量", "%d" % (s.max_mp + _tmp_mp + _tmp_magic), _green_if(_tmp_mp > 0 or _tmp_magic > 0))
	_set_attr("升级经验", "%d" % s.exp, Color.WHITE)
	_set_attr("所需经验", "%d" % s.exp_to_next, Color.WHITE)

	_set_attr("体质", "%d" % (s.max_hp + _tmp_hp + _tmp_magic), _green_if(_tmp_hp > 0 or _tmp_magic > 0))
	_set_attr("魔力", "%d" % (s.max_mp + _tmp_mp + _tmp_magic), _green_if(_tmp_mp > 0 or _tmp_magic > 0))
	_set_attr("力量", "%d" % (s.attack + _tmp_atk), _green_if(_tmp_atk > 0))
	_set_attr("耐力", "%d" % (s.defense + _tmp_def), _green_if(_tmp_def > 0))
	_set_attr("敏捷", "%d" % (s.speed + _tmp_spd), _green_if(_tmp_spd > 0))

	set_label("潜力", "%d" % _potential())

	var pot := _potential()
	_hp_btn.disabled = pot <= 0
	_magic_btn.disabled = pot <= 0
	_str_btn.disabled = pot <= 0
	_def_btn.disabled = pot <= 0
	_spd_btn.disabled = pot <= 0
	var gray := Color(0.4, 0.4, 0.4) if pot <= 0 else Color.WHITE
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
