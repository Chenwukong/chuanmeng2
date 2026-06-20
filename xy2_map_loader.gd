# xy2_map_loader.gd — 加载《梦幻西游》地图文件（含遮罩支持）
class_name MapLoader
extends RefCounted

const MAP_FLAG_M10: int  = 0x4D312E30
const MAP_FLAG_MAPX: int = 0x5850414D
const BLOCK_W: int = 320
const BLOCK_H: int = 240

const _JPG2: int = 0x4A504732
const _PNG1: int = 0x504E4731
const _WEBP: int = 0x57454250
const _0PNG: int = 0x00504E47
const _JPEG: int = 0x4A504547

var flag: int = 0
var map_width: int = 0
var map_height: int = 0
var colnum: int = 0
var rownum: int = 0
var mapnum: int = 0

var _maplist: PackedInt32Array = []
var _file_path: String = ""
var _blocks: Dictionary = {}

# ── 遮罩数据 ──
var mask_num: int = 0               # M1.0 全局遮罩数量
var _mask_offsets: PackedInt32Array = []  # M1.0 遮罩偏移列表
var _mask_list: Dictionary = {}     # mask_id -> { offset, rect, size, image }
var _mask_data_loaded: bool = false

# ── 打开文件 ──
func open(file_path: String) -> bool:
	_file_path = file_path
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		push_error("MapLoader: 无法打开 " + file_path)
		return false

	flag = f.get_32()
	map_width = f.get_32()
	map_height = f.get_32()

	if flag != MAP_FLAG_M10 and flag != MAP_FLAG_MAPX:
		f.close(); return false

	colnum = ceili(float(map_width) / BLOCK_W)
	rownum = ceili(float(map_height) / BLOCK_H)
	mapnum = colnum * rownum

	_maplist = _read_u32s(f, mapnum)

	if flag == MAP_FLAG_M10:
		var mask_off := f.get_32()
		# 记录遮罩段位置，等需要时再读
		_mask_section_offset = mask_off
		# 提前读 mask 头部（数量）
		var saved := f.get_position()
		f.seek(mask_off)
		mask_num = f.get_32()
		if mask_num > 0:
			_mask_offsets = _read_u32s(f, mask_num)
		f.seek(saved)
	else:
		# MAPX 遮罩在子块里，不在这里处理
		var _fsize := f.get_32()
		var bflag := f.get_32()
		var bsize := f.get_32()

	f.close()
	return true

var _mask_section_offset: int = 0

func get_info() -> Dictionary:
	return {
		"flag": "M1.0" if flag == MAP_FLAG_M10 else "MAPX",
		"width": map_width, "height": map_height,
		"colnum": colnum, "rownum": rownum,
		"mapnum": mapnum, "masknum": mask_num,
	}

# ── 批量加载遮罩图像 ──
func load_masks() -> void:
	if _mask_data_loaded:
		return
	if flag != MAP_FLAG_M10 or mask_num <= 0:
		return

	var f := FileAccess.open(_file_path, FileAccess.READ)
	if f == null:
		return

	for i in range(mask_num):
		var off := _mask_offsets[i]
		f.seek(off)

		var rx := f.get_32(); var ry := f.get_32()
		var rw := f.get_32(); var rh := f.get_32()
		var data_size := f.get_32()

		var img: Image = null
		if data_size > 0:
			var raw := f.get_buffer(data_size)
			# 尝试解码为图像
			img = Image.new()
			if img.load_jpg_from_buffer(raw) == OK:
				pass
			elif raw.size() == 320 * 240 * 2:
				img = Image.create_from_data(320, 240, false, Image.FORMAT_RGB565, raw)
			elif raw.size() == 320 * 240:
				img.set_data(320, 240, false, Image.FORMAT_L8, raw)
			else:
				img = null

		_mask_list[i] = {
			"id": i, "offset": off,
			"rect": Rect2i(rx, ry, rw, rh),
			"data_size": data_size, "image": img,
		}

	f.close()
	_mask_data_loaded = true

# ── 获取块的遮罩 ID 列表（M1.0 每个块关联的遮罩） ──
func get_block_mask_ids(block_id: int) -> PackedInt32Array:
	if block_id < 0 or block_id >= mapnum or flag != MAP_FLAG_M10:
		return PackedInt32Array()
	var f := FileAccess.open(_file_path, FileAccess.READ)
	if f == null:
		return PackedInt32Array()
	f.seek(_maplist[block_id])
	var cnt := f.get_32()
	if cnt <= 0:
		f.close(); return PackedInt32Array()
	var ids := _read_u32s(f, cnt)
	f.close()
	return ids

# ── 获取所有遮罩信息 ──
func get_all_masks() -> Array:
	if not _mask_data_loaded:
		load_masks()
	var result: Array = []
	for i in range(mask_num):
		if _mask_list.has(i):
			result.append(_mask_list[i])
	return result

# ── 获取遮罩图像 ──
func get_mask_image(mask_id: int) -> Image:
	if not _mask_data_loaded:
		load_masks()
	if _mask_list.has(mask_id):
		return _mask_list[mask_id].get("image")
	return null

# ── 一次性加载全部块 ──
func load_all() -> void:
	if _blocks.size() > 0:
		return
	var f := FileAccess.open(_file_path, FileAccess.READ)
	if f == null:
		return
	for id in range(mapnum):
		f.seek(_maplist[id])
		var maskcnt := f.get_32()
		if flag == MAP_FLAG_M10 and maskcnt > 0:
			f.seek(f.get_position() + maskcnt * 4)
		var _img: Image = null
		while true:
			var iflag := f.get_32(); var isize := f.get_32()
			if iflag == 0:
				if isize > 0: f.seek(f.get_position() + isize); break
			match iflag:
				_JPG2, _PNG1, _WEBP, _0PNG:
					_img = _decode(f.get_buffer(isize))
				_JPEG:
					var raw := f.get_buffer(isize)
					if raw.size() >= 4 and (raw[2] | (raw[3] << 8)) == 0xA0FF:
						_img = _decode_raw_jpeg(_fix_jpeg(raw))
					else:
						_img = _decode_raw_jpeg(raw)
				_:
					if isize > 0: f.seek(f.get_position() + isize)
			if _img != null: break
		if _img != null:
			_blocks[id] = _img
	f.close()

func get_block_image(block_id: int) -> Image:
	if _blocks.has(block_id):
		return _blocks[block_id]
	return null

func get_map(block_id: int) -> Dictionary:
	var img := get_block_image(block_id)
	return { "block_id": block_id, "image": img, "masknum": 0 }

# ── 原始数据分帧加载 ──
var _raw_data: Dictionary = {}

func preload_all_raw() -> void:
	if _raw_data.size() > 0: return
	var f := FileAccess.open(_file_path, FileAccess.READ)
	if f == null: return
	for id in range(mapnum):
		if _blocks.has(id): continue
		f.seek(_maplist[id])
		var maskcnt := f.get_32()
		if flag == MAP_FLAG_M10 and maskcnt > 0:
			f.seek(f.get_position() + maskcnt * 4)
		while true:
			var iflag := f.get_32(); var isize := f.get_32()
			if iflag == 0:
				if isize > 0: f.seek(f.get_position() + isize); break
			var raw := f.get_buffer(isize)
			match iflag:
				_JPG2, _PNG1, _WEBP, _0PNG, _JPEG:
					_raw_data[id] = raw; break
				_:
					pass
			if _raw_data.has(id): break
		if not _raw_data.has(id):
			_raw_data[id] = PackedByteArray()
	f.close()

func decode_raw(block_id: int) -> Image:
	if _blocks.has(block_id): return _blocks[block_id]
	if not _raw_data.has(block_id): return null
	var raw: PackedByteArray = _raw_data[block_id]
	if raw.is_empty(): return null
	var img := _decode(raw)
	if img == null:
		var t := 0
		if raw.size() >= 4: t = raw[2] | (raw[3] << 8)
		img = _decode_raw_jpeg(_fix_jpeg(raw) if t == 0xA0FF else raw)
	if img != null:
		_blocks[block_id] = img
	return img

# ── 解码 ──
func _decode(raw: PackedByteArray) -> Image:
	var img := Image.new()
	if img.load_jpg_from_buffer(raw) == OK: return img
	if img.load_png_from_buffer(raw) == OK: return img
	if img.load_webp_from_buffer(raw) == OK: return img
	return null

func _decode_raw_jpeg(raw: PackedByteArray) -> Image:
	var img := Image.new()
	if img.load_jpg_from_buffer(raw) == OK: return img
	img = UjpegDecoder.decode(raw)
	if img != null and img.get_size() == Vector2i(BLOCK_W, BLOCK_H): return img
	return null

func _fix_jpeg(data: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(data.size() * 2)
	var ip: int = 0; var op: int = 0
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

func _read_u32s(f: FileAccess, count: int) -> PackedInt32Array:
	var arr := PackedInt32Array()
	arr.resize(count)
	for i in range(count):
		arr[i] = f.get_32()
	return arr
