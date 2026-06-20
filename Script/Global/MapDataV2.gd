# map_data_v2.gd — 基于 C++ libmap 逻辑的完整 .map 解析器
# 同时支持 M1.0 和 MAPX 格式，包含遮罩解码和障碍物解析
class_name MapDataV2
extends RefCounted

const BLOCK_W: int = 320
const BLOCK_H: int = 240
const CELL_COLS: int = 16   # 每个图块横向格子数
const CELL_ROWS: int = 12   # 每个图块纵向格子数 (来自 cMapReader::c16 / c12)
const CELL_PX: int = 20     # 每个格子像素大小

const FLAG_M10: int  = 0x4D312E30   # "M1.0"
const FLAG_MAPX: int = 0x5850414D   # "MAPX"

const TAG_JPG2: int = 0x4A504732
const TAG_PNG1: int = 0x504E4731
const TAG_WEBP: int = 0x57454250
const TAG_0PNG: int = 0x00504E47
const TAG_JPEG: int = 0x4A504547
const TAG_CELL: int = 0x43454C4C   # "CELL"
const TAG_MASK: int = 0x4D41534B   # "MASK" (KSAM in little-endian = 0x4D41534B)

# ── 地图元数据 ──
var flag: int = 0
var map_width: int = 0
var map_height: int = 0
var colnum: int = 0     # 横向图块数
var rownum: int = 0     # 纵向图块数
var mapnum: int = 0     # 图块总数

var _file_path: String = ""
var _block_offsets: PackedInt32Array = []   # 每个图块的偏移
var _mask_section_offset: int = 0

# ── 遮罩 ──
var mask_count: int = 0
var _mask_offsets: PackedInt32Array = []   # public for direct read by viewer
var _mask_cache: Dictionary = {}
var _mask_loaded: bool = false

# ── 障碍物 ──
var _obstacle_grid: PackedByteArray = PackedByteArray()  # 1D 数组，0=通行, 非0=阻挡
var _obstacle_loaded: bool = false
var _obstacle_width: int = 0    # = colnum * CELL_COLS
var _obstacle_height: int = 0   # = rownum * CELL_ROWS

# ── 图块图像缓存 ──
var _block_images: Dictionary = {}  # block_id -> Image

# ── MAPX 共享 JPEG 头 ──
var _mapx_jpeg_header: PackedByteArray = PackedByteArray()


# ═══════════════════════════════════════
# 打开文件
# ═══════════════════════════════════════
func open(file_path: String) -> bool:
	clear()
	_file_path = file_path
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		push_error("MapDataV2: 无法打开 " + file_path)
		return false

	flag = f.get_32()
	map_width = f.get_32()
	map_height = f.get_32()

	if flag != FLAG_M10 and flag != FLAG_MAPX:
		push_error("MapDataV2: 未知格式 0x%X" % flag)
		f.close()
		return false

	colnum = ceili(float(map_width) / BLOCK_W)
	rownum = ceili(float(map_height) / BLOCK_H)
	mapnum = colnum * rownum

	_block_offsets = _read_u32_array(f, mapnum)

	if flag == FLAG_M10:
		_mask_section_offset = f.get_32()
		var saved := f.get_position()
		f.seek(_mask_section_offset)
		mask_count = f.get_32()
		if mask_count > 0:
			_mask_offsets = _read_u32_array(f, mask_count)
		f.seek(saved)
	else:
		# MAPX: 跳过 shared header
		var _fsize := f.get_32()
		var htag := f.get_32()
		var hsize := f.get_32()
		if hsize > 0 and htag == TAG_JPEG:
			_mapx_jpeg_header = f.get_buffer(hsize)

	f.close()
	return true


# ═══════════════════════════════════════
# 图块图像加载
# ═══════════════════════════════════════

## 加载全部图块到内存
func load_all_blocks() -> void:
	if _block_images.size() == mapnum:
		return
	var f := FileAccess.open(_file_path, FileAccess.READ)
	if f == null:
		return
	for id in range(mapnum):
		if _block_images.has(id):
			continue
		var img := _read_block_image(f, id)
		if img != null:
			_block_images[id] = img
	f.close()

## 获取单个图块
func get_block_image(block_id: int) -> Image:
	if _block_images.has(block_id):
		return _block_images[block_id]
	if block_id < 0 or block_id >= mapnum:
		return null
	var f := FileAccess.open(_file_path, FileAccess.READ)
	if f == null:
		return null
	var img := _read_block_image(f, block_id)
	f.close()
	if img != null:
		_block_images[block_id] = img
	return img

func _read_block_image(f: FileAccess, block_id: int) -> Image:
	f.seek(_block_offsets[block_id])
	# M1.0: 跳过附近遮罩 ID 列表
	var nearby_mask_cnt := f.get_32()
	if flag == FLAG_M10 and nearby_mask_cnt > 0:
		f.seek(f.get_position() + nearby_mask_cnt * 4)

	var image: Image = null
	while f.get_position() < f.get_length():
		var btag := f.get_32()
		var bsize := f.get_32()

		if btag == 0:
			if bsize > 0: f.seek(f.get_position() + bsize)
			break

		match btag:
			TAG_JPG2, TAG_PNG1, TAG_WEBP, TAG_0PNG:
				image = _decode_standard(f.get_buffer(bsize))
			TAG_JPEG:
				var raw := f.get_buffer(bsize)
				if flag == FLAG_M10:
					if raw.size() >= 4 and raw[2] == 0xFF and raw[3] == 0xA0:
						raw = _fix_cloud_jpeg(raw)
					image = _decode_jpeg(raw)
				else:
					var full := _mapx_jpeg_header.duplicate()
					full.append_array(raw)
					image = _decode_jpeg(full)
			_:
				if bsize > 0: f.seek(f.get_position() + bsize)

		if image != null:
			break
	return image


# ═══════════════════════════════════════
# 遮罩系统（基于 C++ libmap: sMapDecode::decode）
# ═══════════════════════════════════════

## 获取某个图块关联的遮罩 ID 列表
func get_block_mask_ids(block_id: int) -> PackedInt32Array:
	if flag != FLAG_M10 or block_id < 0 or block_id >= mapnum:
		return PackedInt32Array()
	var f := FileAccess.open(_file_path, FileAccess.READ)
	if f == null:
		return PackedInt32Array()
	f.seek(_block_offsets[block_id])
	var cnt := f.get_32()
	var ids := _read_u32_array(f, cnt) if cnt > 0 else PackedInt32Array()
	f.close()
	return ids

## 加载所有遮罩数据（C++ libmap: LZSS 压缩的 2-bit alpha mask）
## 遮罩加载由 MapViewerV2 的 _render_masks() 直接处理
func load_all_masks() -> void:
	if _mask_loaded: return
	_mask_loaded = true


## 获取遮罩图像
func get_mask_image(mask_id: int) -> Image:
	if not _mask_loaded:
		load_all_masks()
	var info: Dictionary = _mask_cache.get(mask_id, {})
	var img = info.get("image")
	if img == null or not (img is Image):
		return null
	return img

## 获取遮罩矩形
func get_mask_rect(mask_id: int) -> Rect2i:
	if not _mask_loaded:
		load_all_masks()
	var info = _mask_cache.get(mask_id)
	if info == null:
		return Rect2i()
	return info.get("rect", Rect2i())

## 获取所有遮罩信息
func get_all_mask_info() -> Array:
	if not _mask_loaded:
		load_all_masks()
	var result: Array = []
	for mid in range(mask_count):
		var info: Dictionary = _mask_cache.get(mid, {})
		if not info.is_empty():
			result.append({
				"id": mid,
				"rect": info.get("rect", Rect2i()),
				"image": info.get("image"),
			})
	return result


# ═══════════════════════════════════════
# 障碍物系统

## 加载所有障碍物数据（CELL 块）
func load_obstacles() -> void:
	if _obstacle_loaded:
		return
	_obstacle_loaded = true
	if mapnum <= 0:
		return

	_obstacle_width = colnum * CELL_COLS
	_obstacle_height = rownum * CELL_ROWS
	_obstacle_grid.resize(_obstacle_width * _obstacle_height)
	# 默认全部通行（和 XY2MapReader 一致），只标记 CELL 中找到的阻挡格
	for i in range(_obstacle_grid.size()):
		_obstacle_grid[i] = 0

	var f := FileAccess.open(_file_path, FileAccess.READ)
	if f == null:
		return

	var global_row_stride := colnum * CELL_COLS

	for block_id in range(mapnum):
		f.seek(_block_offsets[block_id])
		var nearby_mask_cnt := f.get_32()
		if flag == FLAG_M10 and nearby_mask_cnt > 0:
			f.seek(f.get_position() + nearby_mask_cnt * 4)

		# 扫描块内的所有 tag
		while f.get_position() < f.get_length():
			var btag := f.get_32()
			var bsize := f.get_32()

			if btag == TAG_CELL:
				# CELL 数据：192 字节（16×12），0=通行, 非0=阻挡
				var raw := f.get_buffer(bsize)
				var block_row := block_id / colnum
				var block_col := block_id % colnum
				var dst_base := block_row * CELL_ROWS * global_row_stride + block_col * CELL_COLS

				for cy in range(mini(CELL_ROWS, bsize / CELL_COLS)):
					for cx in range(mini(CELL_COLS, CELL_COLS)):
						var src_idx := cy * CELL_COLS + cx
						if src_idx >= raw.size(): break
						# XY2MapReader 逻辑：value 0 和 2 都表示通行，其他阻挡
						var grid_idx := dst_base + cy * global_row_stride + cx
						if grid_idx < _obstacle_grid.size():
							var v := raw[src_idx]
							_obstacle_grid[grid_idx] = 1 if (v != 0 and v != 2) else 0
				break  # CELL 块之后不需要继续读这个 block

			elif btag == 0:
				if bsize > 0: f.seek(f.get_position() + bsize)
				break
			else:
				if bsize > 0: f.seek(f.get_position() + bsize)

	f.close()

## 检查某个格子是否为障碍物（格子坐标，20×20 像素/格）
func is_obstacle(cell_x: int, cell_y: int) -> bool:
	if not _obstacle_loaded:
		load_obstacles()
	if cell_x < 0 or cell_y < 0 or cell_x >= _obstacle_width or cell_y >= _obstacle_height:
		return true  # 边界外 = 阻挡
	return _obstacle_grid[cell_y * _obstacle_width + cell_x] != 0

## 检查某个像素位置是否可通行（自动转格子坐标）
func is_passable_at(pixel_x: int, pixel_y: int) -> bool:
	return not is_obstacle(pixel_x / CELL_PX, pixel_y / CELL_PX)

## 获取完整障碍物网格
func get_obstacle_grid() -> PackedByteArray:
	if not _obstacle_loaded:
		load_obstacles()
	return _obstacle_grid

## 获取障碍物网格尺寸
func get_obstacle_size() -> Vector2i:
	if not _obstacle_loaded:
		load_obstacles()
	return Vector2i(_obstacle_width, _obstacle_height)


# ═══════════════════════════════════════
# 信息输出
# ═══════════════════════════════════════
func get_info() -> Dictionary:
	return {
		"flag": "M1.0" if flag == FLAG_M10 else "MAPX",
		"width": map_width,
		"height": map_height,
		"colnum": colnum,
		"rownum": rownum,
		"mapnum": mapnum,
		"mask_count": mask_count,
		"obstacle_grid": "%dx%d" % [_obstacle_width, _obstacle_height] if _obstacle_loaded else "未加载",
	}


# ═══════════════════════════════════════
# 内部工具
# ═══════════════════════════════════════

func clear() -> void:
	_file_path = ""
	flag = 0; map_width = 0; map_height = 0
	colnum = 0; rownum = 0; mapnum = 0
	_block_offsets = PackedInt32Array()
	_mask_section_offset = 0
	mask_count = 0
	_mask_offsets = PackedInt32Array()
	_mask_cache.clear(); _mask_loaded = false
	_obstacle_grid = PackedByteArray(); _obstacle_loaded = false
	_obstacle_width = 0; _obstacle_height = 0
	_block_images.clear()
	_mapx_jpeg_header = PackedByteArray()

func _read_u32_array(f: FileAccess, count: int) -> PackedInt32Array:
	var arr := PackedInt32Array()
	arr.resize(count)
	for i in range(count):
		arr[i] = f.get_32()
	return arr

func _decode_standard(raw: PackedByteArray) -> Image:
	var img := Image.new()
	if img.load_png_from_buffer(raw) == OK: return img
	if img.load_jpg_from_buffer(raw) == OK: return img
	if img.load_webp_from_buffer(raw) == OK: return img
	return null

func _decode_jpeg(raw: PackedByteArray) -> Image:
	var img := Image.new()
	if img.load_jpg_from_buffer(raw) == OK:
		return img
	# 回退到 UjpegDecoder
	if UjpegDecoder != null:
		img = UjpegDecoder.decode(raw)
		if img != null: return img
	return null

## JPEG 修复（与 C++ libmap JpgHandler 完全对齐）
func _fix_cloud_jpeg(data: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(data.size() * 2)
	var ip := 0; var op := 0

	while ip < data.size() and data[ip] == 0xFF:
		out[op] = 0xFF; op += 1; ip += 1
		if ip >= data.size(): break
		match data[ip]:
			0xD8: out[op] = 0xD8; op += 1; ip += 1
			0xA0: ip += 1; op -= 1
			0xC0, 0xC4, 0xDB:
				out[op] = data[ip]; op += 1; ip += 1
				if ip + 1 >= data.size(): break
				var sl := (data[ip] << 8) | data[ip + 1]
				out[op] = data[ip]; out[op + 1] = data[ip + 1]; op += 2; ip += 2
				for _i in range(sl - 2):
					if ip >= data.size(): break
					out[op] = data[ip]; op += 1; ip += 1
			0xDA:
				out[op] = 0xDA; out[op + 1] = 0x00; out[op + 2] = 0x0C; op += 3; ip += 1
				if ip + 1 >= data.size(): break
				var sl2 := (data[ip] << 8) | data[ip + 1]; ip += 2
				for _i in range(2, sl2):
					if ip >= data.size(): break
					out[op] = data[ip]; op += 1; ip += 1
				out[op] = 0x00; out[op + 1] = 0x3F; out[op + 2] = 0x00; op += 3
				while ip < data.size() - 2:
					if data[ip] == 0xFF:
						out[op] = 0xFF; out[op + 1] = 0x00; op += 2; ip += 1
					else:
						out[op] = data[ip]; op += 1; ip += 1
				out[op] = 0xD9; op += 1; ip = data.size()
			0xD9: out[op] = 0xD9; op += 1; ip += 1
			_: ip += 1
	out.resize(op)
	return out
