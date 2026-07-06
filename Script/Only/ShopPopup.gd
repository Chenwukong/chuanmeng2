extends CanvasLayer

signal closed

const SLOT_COUNT = 25

var _items: Array[Dictionary] = []
var _quantities: Dictionary = {}
var _selected_idx: int = -1
var _player_gold: int = 0

@onready var slots: Array[Panel] = []
@onready var qty_labels: Array[Label] = []

@onready var price_label: Label = $商城/单价
@onready var qty_total_label: Label = $商城/数量
@onready var amount_label: Label = $商城/总额
@onready var cash_label: Label = $商城/现金
@onready var close_btn: TextureButton = $CloseBtn
@onready var buy_btn: TextureButton = $商城/BuyBtn
@onready var cancel_btn: TextureButton = $商城/CancelBtn
@onready var info_panel: Panel = $商城/InfoPanel
@onready var info_name: Label = $商城/InfoPanel/Name
@onready var info_stats: Label = $商城/InfoPanel/Stats
@onready var info_price: Label = $商城/InfoPanel/PriceLabel


func _ready() -> void:
	for i in SLOT_COUNT:
		var name_str = "ItemSlot_%02d" % i
		var slot = $商城/Items.get_node(name_str) as Panel
		if slot == null:
			slots.append(null)
			qty_labels.append(null)
			continue
		slots.append(slot)

		var qty = Label.new()
		qty.name = "Qty"
		qty.text = ""
		qty.add_theme_color_override("font_color", Color(1, 1, 0))
		qty.add_theme_font_size_override("font_size", 16)
		qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		qty.size = Vector2(80, 22)
		qty.position = Vector2(slot.size.x - 90, slot.size.y - 24)
		qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(qty)
		qty_labels.append(qty)

		var idx = i
		slot.gui_input.connect(func(ev: InputEvent): _on_slot_input(idx, ev))

	_player_gold = GameData.player_gold

	close_btn.pressed.connect(_close)
	if buy_btn: buy_btn.pressed.connect(_buy)
	if cancel_btn: cancel_btn.pressed.connect(_on_cancel)

	if info_panel:
		info_panel.visible = false

	# 初始化左侧 EquipPage
	var ep = $EquipPage
	if ep:
		ep.shop_mode = true
		ep.request_sell.connect(_on_sell_item)
		var first_mid = ""
		for mid in GameData.party_order:
			if GameData.party_db.has(mid):
				first_mid = mid
				break
		if first_mid.is_empty():
			for mid in GameData.party_db:
				first_mid = mid
				break
		if not first_mid.is_empty():
			ep.set_member_id(first_mid)
			ep.set_equip_bag(GameData.equip_bag)
			ep.set_inventory(GameData.player_inventory._slots)
			ep.full_refresh()

	_setup_default_items()
	_refresh_ui()


func set_item_list(list: Array[Dictionary]) -> void:
	_items = list.duplicate()
	_reset_all()


func _setup_default_items() -> void:
	var belt_ids = [
		"equip_2902", "equip_2903", "equip_2906", "equip_2908",
		"equip_2910", "equip_2912", "equip_2950",
		"equip_2952", "equip_2953", "equip_2954",
		"equip_2955", "equip_2956", "equip_2957", "equip_2958",
	]
	_items.clear()
	for eid in belt_ids:
		var eq = EquipData.get_named(eid)
		if eq.is_empty(): continue
		var price = eq.get("price", 0)
		_items.append({
			"name": eq.get("display_name", eq.get("name", "装备")),
			"price": price,
			"tcp_path": eq.get("tcp_path", ""),
			"equip_data": eq,
			"rarity": eq.get("rarity", 0),
		})




func _on_slot_input(idx: int, event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if idx >= _items.size(): return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if _selected_idx == idx:
			# 已选中 → +1
			_quantities[idx] = _quantities.get(idx, 0) + 1
		else:
			# 切到新物品，清之前选中
			_reset_all()
			_selected_idx = idx
			_quantities[idx] = 1
		_refresh_ui()
		_show_item_info(idx)
		_play_sound("res://Audio/SE/001-System01.ogg")

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		var cur = _quantities.get(idx, 0)
		if cur > 0:
			if cur <= 1:
				_quantities.erase(idx)
				_selected_idx = -1
				_hide_item_info()
			else:
				_quantities[idx] = cur - 1
			_refresh_ui()
			_play_sound("res://Audio/SE/003-System03.ogg")


func _show_item_info(idx: int) -> void:
	if info_panel == null: return
	if idx < 0 or idx >= _items.size():
		_hide_item_info()
		return
	var item = _items[idx]
	var eq: Dictionary = item.get("equip_data", {})
	if info_name:
		var rarity_colors = {
			EquipData.Rarity.COMMON: Color(0.75, 0.75, 0.75),
			EquipData.Rarity.UNCOMMON: Color(0.3, 1.0, 0.3),
			EquipData.Rarity.RARE: Color(0.3, 0.5, 1.0),
			EquipData.Rarity.EPIC: Color(0.85, 0.3, 1.0),
			EquipData.Rarity.LEGENDARY: Color(1.0, 0.55, 0.05),
		}
		info_name.text = item.get("name", "")
		info_name.add_theme_color_override("font_color", rarity_colors.get(item.get("rarity", 0), Color.WHITE))
	if info_stats:
		var stats_text = ""
		var base: Dictionary = eq.get("base", {})
		for key in base:
			stats_text += "%s +%d  " % [{"hp":"气血","atk":"攻击","def":"防御","spd":"速度","matk":"法攻","mdef":"法防"}.get(key, key), base[key]]
		info_stats.text = stats_text if stats_text else "无属性"
	if info_price:
		info_price.text = "单价: %d" % item.price
	info_panel.visible = true


func _hide_item_info() -> void:
	if info_panel:
		info_panel.visible = false


func _buy() -> void:
	if _selected_idx < 0 or _selected_idx >= _items.size():
		return
	var qty = _quantities.get(_selected_idx, 0)
	if qty <= 0: return
	var item = _items[_selected_idx]
	var cost = item.price * qty

	if _player_gold < cost:
		_push_msg("金币不足！需要 %d，当前 %d" % [cost, _player_gold])
		_play_sound("res://Audio/SE/057-Wrong01.ogg")
		return

	_player_gold -= cost
	GameData.player_gold = _player_gold
	var eq = item.get("equip_data", {}).duplicate(true)
	for _i in qty:
		if not eq.is_empty():
			GameData.add_equip_to_bag(eq.duplicate(true))
	_push_msg("购买成功！%s ×%d，花费 %d 金币" % [item.get("name", ""), qty, cost])
	_play_sound("res://Audio/SE/005-System05.ogg")
	# 刷新左侧装备页面
	var ep = $EquipPage
	if ep and ep.has_method("full_refresh"):
		ep.set_equip_bag(GameData.equip_bag)
		ep.full_refresh()
	_reset_all()
	_refresh_ui()


func _on_sell_item(bag_idx: int) -> void:
	if _sell_panel != null: return
	_sell_panel = Panel.new()
	_sell_panel.size = Vector2(300, 150)
	_sell_panel.position = get_viewport().get_visible_rect().size * 0.5 - Vector2(150, 75)
	_sell_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sell_panel)

	var lbl = Label.new()
	lbl.text = "确认出售这个装备吗？"
	lbl.position = Vector2(50, 30)
	lbl.size = Vector2(200, 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sell_panel.add_child(lbl)

	var btn_sell = Button.new()
	btn_sell.text = "出售"
	btn_sell.position = Vector2(50, 80)
	btn_sell.size = Vector2(80, 35)
	_sell_panel.add_child(btn_sell)
	btn_sell.pressed.connect(func():
		_do_sell(bag_idx)
		_remove_sell_panel()
	)

	var btn_cancel = Button.new()
	btn_cancel.text = "取消"
	btn_cancel.position = Vector2(170, 80)
	btn_cancel.size = Vector2(80, 35)
	_sell_panel.add_child(btn_cancel)
	btn_cancel.pressed.connect(_remove_sell_panel)


var _sell_panel: Panel = null

func _remove_sell_panel() -> void:
	if _sell_panel:
		_sell_panel.queue_free()
		_sell_panel = null


func _do_sell(bag_idx: int) -> void:
	var ep = $EquipPage
	if ep == null: return
	if bag_idx < 0 or bag_idx >= GameData.equip_bag.size(): return
	var eq = GameData.equip_bag[bag_idx]
	var price = eq.get("price", int(eq.get("rarity", 0)) * 100 + 50)
	var sell_price = maxi(1, int(price * 0.5))
	_push_msg("出售 %s，获得 %d 金币" % [eq.get("display_name", ""), sell_price])
	GameData.equip_bag.remove_at(bag_idx)
	_player_gold += sell_price
	GameData.player_gold = _player_gold
	if ep.has_method("set_equip_bag"):
		ep.set_equip_bag(GameData.equip_bag)
		ep.full_refresh()
	_refresh_ui()
	_play_sound("res://Audio/SE/006-System06.ogg")


func _play_sound(path: String) -> void:
	var snd = AudioStreamPlayer.new()
	snd.stream = load(path)
	snd.bus = "SFX"
	add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)


func _on_cancel() -> void:
	_play_sound("res://Audio/SE/003-System03.ogg")
	_reset_all()


func _reset_all() -> void:
	_quantities.clear()
	_selected_idx = -1
	_hide_item_info()
	_refresh_ui()


func _close() -> void:
	closed.emit()
	queue_free()


func _push_msg(text: String) -> void:
	var log = get_tree().current_scene.get_node_or_null("UI/BattleLog") as RichTextLabel
	if log:
		log.append_text("[color=yellow]🛒 %s[/color]\n" % text)


func _refresh_ui() -> void:
	for i in SLOT_COUNT:
		var slot = slots[i] if i < slots.size() else null
		if slot == null: continue
		var icon = slot.get_node_or_null("Icon") as TextureRect
		var qty_lbl = qty_labels[i] if i < qty_labels.size() else null

		if i < _items.size():
			var item = _items[i]
			var tcp = item.get("tcp_path", "")
			if icon:
				if not tcp.is_empty():
					icon.texture = _load_tcp_icon(tcp)
				else:
					icon.texture = null
			# 高亮当前选中
			if i == _selected_idx:
				slot.modulate = Color(1, 1, 1, 1)
				slot.self_modulate = Color(1, 1, 0.7, 1)
			else:
				slot.modulate = Color(0.5, 0.5, 0.5, 0.5)
				slot.self_modulate = Color.WHITE
			if qty_lbl:
				var qty = _quantities.get(i, 0)
				qty_lbl.text = str(qty) if qty > 0 else ""
		else:
			if icon: icon.texture = null
			slot.modulate = Color(0.3, 0.3, 0.3, 0.2)
			slot.self_modulate = Color.WHITE
			if qty_lbl: qty_lbl.text = ""

	# 统计
	var total_qty = 0
	var total_amount = 0
	if _selected_idx >= 0 and _selected_idx < _items.size():
		total_qty = _quantities.get(_selected_idx, 0)
		total_amount = _items[_selected_idx].price * total_qty

	if price_label:
		if _selected_idx >= 0 and _selected_idx < _items.size():
			price_label.text = "%d" % _items[_selected_idx].price
		else:
			price_label.text = "—"
	if qty_total_label:
		qty_total_label.text = "%d" % total_qty
	if amount_label:
		amount_label.text = "%d" % total_amount
	if cash_label:
		cash_label.text = "%d" % _player_gold


var _icon_cache: Dictionary = {}

func _load_tcp_icon(tcp_path: String) -> Texture2D:
	if _icon_cache.has(tcp_path):
		return _icon_cache[tcp_path]
	var reader = WASReader.new()
	if reader.load_from_file(tcp_path):
		var frame = reader.decode_frame(0, 0)
		if frame != null and not frame.is_empty():
			var tex = frame.get("texture") as Texture2D
			if tex:
				_icon_cache[tcp_path] = tex
				return tex
	return null
