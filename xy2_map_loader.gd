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
var mask_num: int = 0
var _mask_list: Array[Dictionary] = []
var _mask_images: Dictionary = {}
var _mapx_ids: Dictionary = {}
var _mapx_header := PackedByteArray()

func open(file_path: String) -> bool:
	_file_path = file_path
	mask_num = 0
	_mask_list.clear()
	_mask_images.clear()
	_mapx_ids.clear()
	_mapx_header.clear()
	_blocks.clear()
	_raw_data.clear()
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null or f.get_length() < 16:
		return false

	flag = f.get_32()
	if flag == 0x4D415058:  # 'MAPX' written as a C multi-character constant
		flag = MAP_FLAG_MAPX
	map_width = f.get_32()
	map_height = f.get_32()
	if flag != MAP_FLAG_M10 and flag != MAP_FLAG_MAPX:
		return false
	colnum = ceili(float(map_width) / BLOCK_W)
	rownum = ceili(float(map_height) / BLOCK_H)
	mapnum = colnum * rownum
	if mapnum <= 0 or mapnum > (f.get_length() - 16) / 4:
		return false
	_maplist = _read_u32s(f, mapnum)
	for offset in _maplist:
		if offset < 0 or offset > f.get_length() - 4:
			return false

	if flag == MAP_FLAG_M10:
		if not _index_m10_masks(f, f.get_32()):
			_mask_list.clear()
	else:
		if f.get_length() - f.get_position() < 12:
			return false
		f.get_32()  # file size
		f.get_32()  # shared JPEG header tag
		var header_size := f.get_32()
		if header_size > f.get_length() - f.get_position():
			return false
		_mapx_header = f.get_buffer(header_size)
		if not _index_mapx_masks(f):
			_mapx_ids.clear()
			_mask_list.clear()
	mask_num = _mask_list.size()
	return true

func _index_m10_masks(f: FileAccess, section: int) -> bool:
	if section < f.get_position() or section > f.get_length() - 4:
		return false
	f.seek(section)
	var count := f.get_32()
	if count > (f.get_length() - f.get_position()) / 4:
		return false
	var offsets := _read_u32s(f, count)
	for offset in offsets:
		if offset < 0 or offset > f.get_length() - 20:
			return false
		f.seek(offset)
		var rect := _read_rect(f)
		var size := f.get_32()
		if not _add_mask(f, offset, rect, size):
			return false
	return true

func _index_mapx_masks(f: FileAccess) -> bool:
	for id in range(mapnum):
		f.seek(_maplist[id])
		var count := f.get_32()
		var ids := PackedInt32Array()
		while ids.size() < count:
			if f.get_position() > f.get_length() - 8:
				return false
			var tag := f.get_32()
			var size := f.get_32()
			var payload := f.get_position()
			if size > f.get_length() - payload or tag == 0:
				return false
			if tag == 0x4D41534B:  # MASK
				if size < 16:
					return false
				var rect := _read_rect(f)
				rect.position += Vector2i(id % colnum * BLOCK_W, id / colnum * BLOCK_H)
				ids.append(_mask_list.size())
				if not _add_mask(f, payload - 4, rect, size - 16):
					return false
			f.seek(payload + size)
		_mapx_ids[id] = ids
	return true

func _read_rect(f: FileAccess) -> Rect2i:
	var data := f.get_buffer(16)
	return Rect2i(data.decode_s32(0), data.decode_s32(4), data.decode_s32(8), data.decode_s32(12))

func _add_mask(f: FileAccess, offset: int, rect: Rect2i, size: int) -> bool:
	# Bound allocations for malformed headers. Real masks may extend past a map edge.
	if not rect.has_area() or rect.size.x * rect.size.y > 16777216 or size <= 0 or size > f.get_length() - f.get_position():
		return false
	_mask_list.append({"id": _mask_list.size(), "offset": offset, "rect": rect, "data_size": size})
	return true

func get_info() -> Dictionary:
	return {
		"flag": "M1.0" if flag == MAP_FLAG_M10 else "MAPX",
		"width": map_width, "height": map_height,
		"colnum": colnum, "rownum": rownum,
		"mapnum": mapnum, "masknum": mask_num,
	}

func load_masks() -> void:
	for id in range(mask_num):
		get_mask_image(id)

func get_block_mask_ids(block_id: int) -> PackedInt32Array:
	if block_id < 0 or block_id >= mapnum:
		return PackedInt32Array()
	if flag == MAP_FLAG_MAPX:
		return _mapx_ids.get(block_id, PackedInt32Array())
	var f := FileAccess.open(_file_path, FileAccess.READ)
	if f == null:
		return PackedInt32Array()
	f.seek(_maplist[block_id])
	var count := f.get_32()
	if count > mask_num or count > (f.get_length() - f.get_position()) / 4:
		return PackedInt32Array()
	return _read_u32s(f, count)

func get_all_masks() -> Array:
	var result: Array = []
	for id in range(mask_num):
		var info := _mask_list[id].duplicate()
		info["image"] = get_mask_image(id)
		result.append(info)
	return result

func get_mask_rect(mask_id: int) -> Rect2i:
	if mask_id < 0 or mask_id >= mask_num:
		return Rect2i()
	return _mask_list[mask_id].rect

func release_mask_image(mask_id: int) -> void:
	_mask_images.erase(mask_id)


func get_mask_image(mask_id: int) -> Image:
	if mask_id < 0 or mask_id >= mask_num:
		return null
	if _mask_images.has(mask_id):
		return _mask_images[mask_id]
	var info := _mask_list[mask_id]
	var rect: Rect2i = info.rect
	var f := FileAccess.open(_file_path, FileAccess.READ)
	if f == null:
		return null
	f.seek(info.offset + 20)
	var stride := (rect.size.x + 3) >> 2
	var packed := _unpack_lzo(f.get_buffer(info.data_size), stride * rect.size.y)
	if packed.is_empty():
		return null

	# Gather the map pixels beneath the mask; one mask can straddle several tiles.
	if _blocks.is_empty():
		load_all()
	var img := Image.create_empty(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	var visible := rect.intersection(Rect2i(0, 0, map_width, map_height))
	if visible.has_area():
		for row in range(visible.position.y / BLOCK_H, (visible.end.y - 1) / BLOCK_H + 1):
			for col in range(visible.position.x / BLOCK_W, (visible.end.x - 1) / BLOCK_W + 1):
				var block := decode_raw(row * colnum + col)
				if block == null:
					return null
				var origin := Vector2i(col * BLOCK_W, row * BLOCK_H)
				var part := visible.intersection(Rect2i(origin, block.get_size()))
				if block.get_format() != Image.FORMAT_RGBA8:
					block.convert(Image.FORMAT_RGBA8)
				img.blit_rect(block, Rect2i(part.position - origin, part.size), part.position - rect.position)

		var rgba := img.get_data()
		var local_rect := Rect2i(visible.position - rect.position, visible.size)
		for y in range(local_rect.position.y, local_rect.end.y):
			var src := y * stride
			var dst := (y * rect.size.x + local_rect.position.x) * 4 + 3
			for x in range(local_rect.position.x, local_rect.end.x):
				var level := (packed[src + (x >> 2)] >> ((x & 3) * 2)) & 3
				rgba[dst] = 136 if level == 3 else 0  # 与现有场景遮罩 PNG 的透明度一致
				dst += 4
		img.set_data(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8, rgba)
	_mask_images[mask_id] = img
	return img

# LZO1X stream used by map.c. The previous literal length determines what a
# token below 16 means (a literal run, a two-byte match, or a far three-byte match).
static func _unpack_lzo(data: PackedByteArray, expected: int) -> PackedByteArray:
	var empty := PackedByteArray()
	if data.size() < 3 or expected <= 0:
		return empty
	var out := PackedByteArray()
	out.resize(expected)
	var ip := 0
	var op := 0
	var literals := 0
	if data[0] > 17:
		literals = data[0] - 17
		ip = 1
	while ip < data.size():
		if ip + literals >= data.size() or op + literals > expected:
			return empty
		for i in range(literals):
			out[op + i] = data[ip + i]
		ip += literals
		op += literals
		var token := int(data[ip])
		ip += 1
		var length := 0
		var distance := 0
		if token < 16 and literals == 0:
			literals = token
			if token == 0:
				while ip < data.size() and data[ip] == 0:
					literals += 255
					ip += 1
				if ip >= data.size():
					return empty
				literals += 15 + data[ip]
				ip += 1
			literals += 3
			continue
		if token < 16 or token >= 64:
			if ip >= data.size():
				return empty
			if token >= 64:
				length = (token >> 5) + 1
				distance = 1 + ((token >> 2) & 7) + (data[ip] << 3)
			else:
				length = 3 if literals >= 4 else 2
				distance = (2049 if literals >= 4 else 1) + (token >> 2) + (data[ip] << 2)
			ip += 1
			literals = token & 3
		else:
			var length_mask := 31 if token >= 32 else 7
			length = token & length_mask
			if length == 0:
				while ip < data.size() and data[ip] == 0:
					length += 255
					ip += 1
				if ip >= data.size():
					return empty
				length += length_mask + data[ip]
				ip += 1
			length += 2
			if ip + 2 > data.size():
				return empty
			distance = data.decode_u16(ip) >> 2
			literals = data[ip] & 3
			ip += 2
			if token >= 32:
				distance += 1
			else:
				distance += (token & 8) << 11
				if distance == 0:
					return out if op == expected else empty
				distance += 16384
		if distance > op or op + length > expected:
			return empty
		for i in range(length):  # LZO allows the source and destination to overlap.
			out[op] = out[op - distance]
			op += 1
	return empty

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
		while f.get_position() <= f.get_length() - 8:
			var iflag := f.get_32(); var isize := f.get_32()
			if iflag == 0 or isize > f.get_length() - f.get_position():
				break
			match iflag:
				_JPG2, _PNG1, _WEBP, _0PNG:
					_img = _decode(f.get_buffer(isize))
				_JPEG:
					var raw := f.get_buffer(isize)
					if flag == MAP_FLAG_MAPX:
						raw = _mapx_header + raw
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
	return { "block_id": block_id, "image": img, "masknum": get_block_mask_ids(block_id).size() }

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
		while f.get_position() <= f.get_length() - 8:
			var iflag := f.get_32(); var isize := f.get_32()
			if iflag == 0 or isize > f.get_length() - f.get_position():
				break
			var raw := f.get_buffer(isize)
			match iflag:
				_JPG2, _PNG1, _WEBP, _0PNG, _JPEG:
					_raw_data[id] = _mapx_header + raw if iflag == _JPEG and flag == MAP_FLAG_MAPX else raw
					break
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
	if raw.size() < 4:
		return null
	var img := Image.new()
	if raw[0] == 0xFF and raw[1] == 0xD8:
		if raw[2] == 0xFF and raw[3] == 0xA0:
			return _decode_raw_jpeg(_fix_jpeg(raw))
		return img if img.load_jpg_from_buffer(raw) == OK else null
	match raw.decode_u32(0):
		0x474E5089:  # PNG
			return img if img.load_png_from_buffer(raw) == OK else null
		0x46464952:  # RIFF / WebP
			return img if img.load_webp_from_buffer(raw) == OK else null
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
				out[op] = 0xFF; out[op + 1] = 0xD9; op += 2; ip = data.size()
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
