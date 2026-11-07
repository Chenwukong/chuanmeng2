extends Control

const PAGE_COLS := 5
const PAGE_ROWS := 6
const PAGE_SIZE := PAGE_COLS * PAGE_ROWS
const BASE_ICON_SIZE := 96.0

@onready var browser_page: Control = $Root/BrowserPage
@onready var preview_page: Control = $Root/PreviewPage
@onready var folder_edit: LineEdit = $Root/BrowserPage/BrowserVBox/TopRow/FolderEdit
@onready var page_label: Label = $Root/BrowserPage/BrowserVBox/PageRow/PageLabel
@onready var total_label: Label = $Root/BrowserPage/BrowserVBox/PageRow/TotalLabel
@onready var grid_zoom_slider: HSlider = $Root/BrowserPage/BrowserVBox/PageRow/GridZoomSlider
@onready var grid_zoom_label: Label = $Root/BrowserPage/BrowserVBox/PageRow/GridZoomLabel
@onready var item_list: ItemList = $Root/BrowserPage/BrowserVBox/FileList

@onready var selected_file_label: Label = $Root/PreviewPage/PreviewVBox/TopRow/SelectedFileLabel
@onready var direction_slider: HSlider = $Root/PreviewPage/PreviewVBox/DirectionRow/DirectionSlider
@onready var frame_slider: HSlider = $Root/PreviewPage/PreviewVBox/FrameRow/FrameSlider
@onready var direction_label: Label = $Root/PreviewPage/PreviewVBox/DirectionRow/DirectionLabel
@onready var frame_label: Label = $Root/PreviewPage/PreviewVBox/FrameRow/FrameLabel
@onready var info_label: Label = $Root/PreviewPage/PreviewVBox/InfoLabel
@onready var preview_canvas: Control = $Root/PreviewPage/PreviewVBox/PreviewPanel/PreviewCanvas
@onready var preview_sprite: Sprite2D = $Root/PreviewPage/PreviewVBox/PreviewPanel/PreviewCanvas/PreviewSprite
@onready var zoom_slider: HSlider = $Root/PreviewPage/PreviewVBox/TransformRow/ZoomSlider
@onready var zoom_label: Label = $Root/PreviewPage/PreviewVBox/TransformRow/ZoomLabel
@onready var offset_x_spin: SpinBox = $Root/PreviewPage/PreviewVBox/TransformRow/OffsetXSpin
@onready var offset_y_spin: SpinBox = $Root/PreviewPage/PreviewVBox/TransformRow/OffsetYSpin
@onready var play_timer: Timer = $PlayTimer
@onready var dir_dialog: FileDialog = $DirDialog

var _all_paths: PackedStringArray = PackedStringArray()
var _thumb_cache: Dictionary = {}
var _current_page: int = 0
var _selected_index: int = -1
var _page_indices: PackedInt32Array = PackedInt32Array()
var _grid_zoom: float = 1.0

var _reader: WASReader = WASReader.new()
var _current_direction: int = 0
var _current_frame: int = 0
var _is_loaded: bool = false
var _preview_zoom: float = 1.0
var _ui_ready: bool = false


func _ready() -> void:
	dir_dialog.access = FileDialog.ACCESS_FILESYSTEM
	dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dir_dialog.current_dir = "D:/下载/GGElua/梦幻西游源码/天元/android/XYQCS/assets"

	item_list.max_columns = PAGE_COLS
	item_list.icon_mode = ItemList.ICON_MODE_TOP
	item_list.allow_rmb_select = false
	item_list.same_column_width = true
	item_list.fixed_column_width = 120
	item_list.fixed_icon_size = Vector2i(96, 96)

	preview_sprite.centered = true

	_refresh_player_disabled_state(true)
	_set_page(true)
	_update_info("请选择素材目录并加载（会自动扫描子目录中的 .was）")
	_ui_ready = true
	call_deferred("_fit_grid_icons_to_window")


func _on_browse_folder_button_pressed() -> void:
	dir_dialog.popup_centered_ratio(0.75)


func _on_load_folder_button_pressed() -> void:
	_load_folder(folder_edit.text.strip_edges())


func _on_dir_dialog_dir_selected(dir: String) -> void:
	folder_edit.text = dir
	_load_folder(dir)


func _load_folder(folder_path: String) -> void:
	if folder_path.is_empty():
		_update_info("目录路径为空")
		return
	if DirAccess.open(folder_path) == null:
		_update_info("目录不可访问: %s" % folder_path)
		return

	_all_paths = _scan_was_files(folder_path)
	_thumb_cache.clear()
	_current_page = 0
	_selected_index = -1
	_is_loaded = false
	preview_sprite.texture = null
	_refresh_player_disabled_state(true)

	_render_page()
	if _all_paths.is_empty():
		_update_info("目录内没有找到 .was 文件")
	else:
		_update_info("已找到 %d 个 WAS 文件，左键单击列表项进行预览与播放" % _all_paths.size())
	_set_page(true)


func _scan_was_files(root: String) -> PackedStringArray:
	var out := PackedStringArray()
	var pending := [root]
	while not pending.is_empty():
		var current: String = String(pending.pop_back())
		var dir := DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		while true:
			var name := dir.get_next()
			if name == "":
				break
			if name == "." or name == "..":
				continue
			var full := current.path_join(name)
			if dir.current_is_dir():
				pending.push_back(full)
			else:
				if name.get_extension().to_lower() == "was":
					out.append(full)
		dir.list_dir_end()
	out.sort()
	return out


func _render_page() -> void:
	item_list.clear()
	_page_indices = PackedInt32Array()

	var total_pages: int = maxi(1, int(ceil(float(_all_paths.size()) / float(PAGE_SIZE))))
	_current_page = clampi(_current_page, 0, total_pages - 1)

	var start_idx: int = _current_page * PAGE_SIZE
	var end_idx: int = mini(start_idx + PAGE_SIZE, _all_paths.size())

	for i in range(start_idx, end_idx):
		var path: String = _all_paths[i]
		var icon: Texture2D = _get_thumb(path)
		var idx := item_list.add_item(path.get_file(), icon, true)
		item_list.set_item_tooltip(idx, path)
		_page_indices.append(i)

	for _i in range(end_idx, start_idx + PAGE_SIZE):
		var empty_idx := item_list.add_item("", null, false)
		item_list.set_item_disabled(empty_idx, true)
		_page_indices.append(-1)

	page_label.text = "页码: %d / %d" % [_current_page + 1, total_pages]
	total_label.text = "总数: %d" % _all_paths.size()
	_fit_grid_icons_to_window()


func _get_thumb(path: String) -> Texture2D:
	if _thumb_cache.has(path):
		return _thumb_cache[path]

	var reader := WASReader.new()
	if not reader.load_from_file(path):
		var fallback := _make_fallback_thumb(Color(0.35, 0.15, 0.15, 1.0))
		_thumb_cache[path] = fallback
		return fallback

	var frame := reader.decode_frame(0, 0)
	if frame.is_empty():
		var fallback_empty := _make_fallback_thumb(Color(0.2, 0.2, 0.2, 1.0))
		_thumb_cache[path] = fallback_empty
		return fallback_empty

	var src: Texture2D = frame["texture"]
	var img: Image = src.get_image()
	img.resize(128, 128, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_thumb_cache[path] = tex
	return tex


func _make_fallback_thumb(color: Color) -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _on_prev_page_button_pressed() -> void:
	if _all_paths.is_empty():
		return
	_current_page = maxi(0, _current_page - 1)
	_render_page()


func _on_next_page_button_pressed() -> void:
	if _all_paths.is_empty():
		return
	var total_pages: int = maxi(1, int(ceil(float(_all_paths.size()) / float(PAGE_SIZE))))
	_current_page = mini(total_pages - 1, _current_page + 1)
	_render_page()


func _on_file_list_item_selected(index: int) -> void:
	if index < 0 or index >= _page_indices.size():
		return
	var global_idx: int = _page_indices[index]
	if global_idx < 0 or global_idx >= _all_paths.size():
		return
	_selected_index = global_idx
	_open_selected()


func _open_selected() -> void:
	if _selected_index < 0 or _selected_index >= _all_paths.size():
		return
	var path := _all_paths[_selected_index]
	if not _reader.load_from_file(path):
		_is_loaded = false
		preview_sprite.texture = null
		_refresh_player_disabled_state(true)
		_update_info("加载失败: %s" % _reader.get_last_error())
		return

	_is_loaded = true
	_current_direction = 0
	_current_frame = 0

	direction_slider.max_value = maxi(0, _reader.group_count - 1)
	frame_slider.max_value = maxi(0, _reader.frame_count - 1)
	direction_slider.value = 0
	frame_slider.value = 0

	offset_x_spin.value = 0
	offset_y_spin.value = 0
	zoom_slider.value = 1.0
	_preview_zoom = 1.0
	selected_file_label.text = path

	_refresh_player_disabled_state(false)
	_set_page(false)
	_draw_current_frame()


func _draw_current_frame() -> void:
	if not _is_loaded:
		return
	var decoded := _reader.decode_frame(_current_direction, _current_frame)
	if decoded.is_empty():
		preview_sprite.texture = null
		_update_info("帧解码失败")
		return

	preview_sprite.texture = decoded["texture"]
	_update_preview_transform()
	direction_label.text = "方向: %d / %d" % [_current_direction + 1, _reader.group_count]
	frame_label.text = "帧: %d / %d" % [_current_frame + 1, _reader.frame_count]
	_update_info(
		"%s | 帧: %dx%d | Key: (%d,%d) | 可见像素: %d" % [
			_all_paths[_selected_index].get_file(),
			decoded["width"],
			decoded["height"],
			decoded["key_x"],
			decoded["key_y"],
			decoded.get("visible_pixels", -1)
		]
	)


func _refresh_player_disabled_state(disabled: bool) -> void:
	direction_slider.editable = not disabled
	frame_slider.editable = not disabled
	$Root/PreviewPage/PreviewVBox/BottomRow/PrevFrameButton.disabled = disabled
	$Root/PreviewPage/PreviewVBox/BottomRow/NextFrameButton.disabled = disabled
	$Root/PreviewPage/PreviewVBox/BottomRow/PlayButton.disabled = disabled
	$Root/PreviewPage/PreviewVBox/TopRow/PrevResourceButton.disabled = disabled
	$Root/PreviewPage/PreviewVBox/TopRow/NextResourceButton.disabled = disabled
	if disabled:
		play_timer.stop()
		$Root/PreviewPage/PreviewVBox/BottomRow/PlayButton.button_pressed = false
		$Root/PreviewPage/PreviewVBox/BottomRow/PlayButton.text = "播放"


func _update_info(text: String) -> void:
	info_label.text = text


func _on_direction_slider_value_changed(value: float) -> void:
	_current_direction = int(value)
	_draw_current_frame()


func _on_frame_slider_value_changed(value: float) -> void:
	_current_frame = int(value)
	_draw_current_frame()


func _on_prev_frame_button_pressed() -> void:
	if not _is_loaded:
		return
	_current_frame = posmod(_current_frame - 1, _reader.frame_count)
	frame_slider.value = _current_frame
	_draw_current_frame()


func _on_next_frame_button_pressed() -> void:
	if not _is_loaded:
		return
	_current_frame = (_current_frame + 1) % _reader.frame_count
	frame_slider.value = _current_frame
	_draw_current_frame()


func _on_play_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		play_timer.start()
		$Root/PreviewPage/PreviewVBox/BottomRow/PlayButton.text = "暂停"
	else:
		play_timer.stop()
		$Root/PreviewPage/PreviewVBox/BottomRow/PlayButton.text = "播放"


func _on_play_timer_timeout() -> void:
	if not _is_loaded:
		return
	_on_next_frame_button_pressed()


func _on_back_to_browser_button_pressed() -> void:
	play_timer.stop()
	$Root/PreviewPage/PreviewVBox/BottomRow/PlayButton.button_pressed = false
	$Root/PreviewPage/PreviewVBox/BottomRow/PlayButton.text = "播放"
	_set_page(true)


func _on_prev_resource_button_pressed() -> void:
	if _all_paths.is_empty():
		return
	_selected_index = posmod(_selected_index - 1, _all_paths.size())
	_open_selected()


func _on_next_resource_button_pressed() -> void:
	if _all_paths.is_empty():
		return
	_selected_index = (_selected_index + 1) % _all_paths.size()
	_open_selected()


func _on_grid_zoom_slider_value_changed(value: float) -> void:
	_grid_zoom = value
	grid_zoom_label.text = "网格缩放: %.2fx" % _grid_zoom
	_fit_grid_icons_to_window()


func _fit_grid_icons_to_window() -> void:
	if not _ui_ready or item_list == null:
		return
	var usable_width: float = item_list.size.x
	if usable_width <= 10.0:
		return
	var base_cell_width: float = (usable_width - 24.0) / float(PAGE_COLS)
	var cell_width: int = maxi(70, int(base_cell_width * _grid_zoom))
	item_list.fixed_column_width = cell_width
	var icon_side: int = maxi(40, int(minf(float(cell_width - 24), BASE_ICON_SIZE * _grid_zoom)))
	item_list.fixed_icon_size = Vector2i(icon_side, icon_side)


func _on_zoom_slider_value_changed(value: float) -> void:
	_preview_zoom = value
	zoom_label.text = "缩放: %.2fx" % _preview_zoom
	_update_preview_transform()


func _on_offset_x_spin_value_changed(value: float) -> void:
	_update_preview_transform()


func _on_offset_y_spin_value_changed(value: float) -> void:
	_update_preview_transform()


func _update_preview_transform() -> void:
	if not _ui_ready or preview_sprite == null or preview_canvas == null:
		return
	if preview_sprite.texture == null:
		return
	preview_sprite.scale = Vector2(_preview_zoom, _preview_zoom)
	preview_sprite.position = preview_canvas.size * 0.5 + Vector2(offset_x_spin.value, offset_y_spin.value)
	preview_sprite.region_enabled = false
	preview_sprite.offset = Vector2.ZERO


func _set_page(is_browser: bool) -> void:
	browser_page.visible = is_browser
	preview_page.visible = not is_browser


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_grid_icons_to_window()
		_update_preview_transform()
