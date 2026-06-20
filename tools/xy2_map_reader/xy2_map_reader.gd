class_name XY2MapReader
extends RefCounted

const UjpegDecoderScript := preload("res://Script/Global/UjpegDecoder.gd")

const MAP_FLAG_M10 := 0x4D312E30
const MAP_FLAG_MAPX := 0x5850414D

const BLOCK_W := 320
const BLOCK_H := 240
const CELL_COLS := 16
const CELL_ROWS := 12
const CELL_PER_BLOCK := 192

const BLOCK_JPG2 := 0x4A504732
const BLOCK_PNG1 := 0x504E4731
const BLOCK_WEBP := 0x57454250
const BLOCK_0PNG := 0x00504E47
const BLOCK_JPEG := 0x4A504547
const BLOCK_CELL := 0x43454C4C
const BLOCK_MASK := 0x4D41534B

var path := ""
var flag := 0
var width := 0
var height := 0
var colnum := 0
var rownum := 0
var mapnum := 0
var masknum := 0

var _map_offsets := PackedInt32Array()
var _mask_offsets := PackedInt32Array()
var _mapx_jpeg_header := PackedByteArray()
var _image_cache := {}
var _cell_cache := PackedByteArray()


func open_map(file_path: String) -> bool:
	clear()
	path = file_path

	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		push_error("XY2MapReader: cannot open map: %s" % file_path)
		return false

	f.big_endian = false
	flag = f.get_32()
	width = f.get_32()
	height = f.get_32()

	if flag != MAP_FLAG_M10 and flag != MAP_FLAG_MAPX:
		push_error("XY2MapReader: unsupported map flag %s" % _tag_name(flag))
		f.close()
		return false

	colnum = ceili(float(width) / float(BLOCK_W))
	rownum = ceili(float(height) / float(BLOCK_H))
	mapnum = colnum * rownum
	_map_offsets = _read_u32_array(f, mapnum)

	if flag == MAP_FLAG_M10:
		var mask_offset := f.get_32()
		var saved_pos := f.get_position()
		f.seek(mask_offset)
		masknum = f.get_32()
		if masknum > 0:
			_mask_offsets = _read_u32_array(f, masknum)
		f.seek(saved_pos)
	else:
		f.seek(f.get_position() + 4)
		var header_tag := f.get_32()
		var header_size := f.get_32()
		if header_size > 0:
			_mapx_jpeg_header = f.get_buffer(header_size)
		print("MAPX shared JPEG header: %s, %d bytes" % [_tag_name(header_tag), header_size])

	f.close()
	return true


func get_info() -> Dictionary:
	return {
		"flag": _tag_name(flag),
		"width": width,
		"height": height,
		"colnum": colnum,
		"rownum": rownum,
		"mapnum": mapnum,
		"masknum": masknum,
	}


func get_block_image(block_id: int, use_cache: bool = true) -> Image:
	if use_cache and _image_cache.has(block_id):
		return _image_cache[block_id]
	if block_id < 0 or block_id >= mapnum:
		return null

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	f.big_endian = false

	var image: Image = _read_block_image(f, block_id)
	f.close()
	if use_cache and image != null:
		_image_cache[block_id] = image
	return image


func build_chunk_image(start_col: int, start_row: int, cols: int, rows: int, max_blocks: int = -1) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	f.big_endian = false

	var chunk_img := Image.create(cols * BLOCK_W, rows * BLOCK_H, false, Image.FORMAT_RGBA8)
	chunk_img.fill(Color.TRANSPARENT)
	var blocks_drawn := 0
	var block_limit := mapnum if max_blocks < 0 else mini(max_blocks, mapnum)

	for row in range(rows):
		for col in range(cols):
			var block_col := start_col + col
			var block_row := start_row + row
			var block_id := block_row * colnum + block_col
			if block_col < 0 or block_col >= colnum or block_row < 0 or block_row >= rownum:
				continue
			if block_id < 0 or block_id >= block_limit:
				continue

			var block_img: Image = _read_block_image(f, block_id)
			if block_img == null:
				continue
			if block_img.get_format() != Image.FORMAT_RGBA8:
				block_img.convert(Image.FORMAT_RGBA8)
			chunk_img.blit_rect(block_img, Rect2i(Vector2i.ZERO, block_img.get_size()), Vector2i(col * BLOCK_W, row * BLOCK_H))
			blocks_drawn += 1

	f.close()
	return {
		"image": chunk_img,
		"blocks": blocks_drawn,
	}


func _read_block_image(f: FileAccess, block_id: int) -> Image:
	f.seek(_map_offsets[block_id])
	var nearby_mask_count := f.get_32()
	if flag == MAP_FLAG_M10 and nearby_mask_count > 0:
		f.seek(f.get_position() + nearby_mask_count * 4)

	var image: Image = null
	while f.get_position() < f.get_length():
		var block_tag := f.get_32()
		var block_size := f.get_32()

		if block_tag == 0:
			if block_size > 0:
				f.seek(f.get_position() + block_size)
			break

		match block_tag:
			BLOCK_JPG2, BLOCK_PNG1, BLOCK_WEBP, BLOCK_0PNG:
				image = _decode_image(f.get_buffer(block_size))
			BLOCK_JPEG:
				var raw := f.get_buffer(block_size)
				if flag == MAP_FLAG_M10:
					if raw.size() >= 4 and raw[2] == 0xFF and raw[3] == 0xA0:
						raw = _fix_cloud_jpeg(raw)
					image = _decode_jpeg(raw)
				else:
					var full_jpeg := _mapx_jpeg_header.duplicate()
					full_jpeg.append_array(raw)
					image = _decode_jpeg(full_jpeg)
			_:
				if block_size > 0:
					f.seek(f.get_position() + block_size)

		if image != null:
			break

	return image


func clear_image_cache() -> void:
	_image_cache.clear()


func get_block_mask_ids(block_id: int) -> PackedInt32Array:
	if flag != MAP_FLAG_M10 or block_id < 0 or block_id >= mapnum:
		return PackedInt32Array()

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedInt32Array()
	f.big_endian = false

	f.seek(_map_offsets[block_id])
	var count := f.get_32()
	var ids := _read_u32_array(f, count)
	f.close()
	return ids


func get_mask_info(mask_id: int) -> Dictionary:
	if flag != MAP_FLAG_M10 or mask_id < 0 or mask_id >= _mask_offsets.size():
		return {}

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	f.big_endian = false

	var offset := _mask_offsets[mask_id]
	f.seek(offset)
	var rect := Rect2i(f.get_32(), f.get_32(), f.get_32(), f.get_32())
	var size := f.get_32()
	f.close()
	return {
		"id": mask_id,
		"offset": offset,
		"rect": rect,
		"size": size,
	}


func get_cells() -> PackedByteArray:
	if not _cell_cache.is_empty():
		return _cell_cache
	if mapnum <= 0:
		return PackedByteArray()

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	f.big_endian = false

	var cells := PackedByteArray()
	cells.resize(rownum * colnum * CELL_PER_BLOCK)
	var global_row_stride := colnum * CELL_COLS
	var block_row_stride := colnum * CELL_PER_BLOCK

	for block_id in range(mapnum):
		var block_row := block_id / colnum
		var block_col := block_id % colnum

		f.seek(_map_offsets[block_id])
		var nearby_mask_count := f.get_32()
		if flag == MAP_FLAG_M10 and nearby_mask_count > 0:
			f.seek(f.get_position() + nearby_mask_count * 4)

		while f.get_position() < f.get_length():
			var block_tag := f.get_32()
			var block_size := f.get_32()

			if block_tag == BLOCK_CELL:
				var raw := f.get_buffer(block_size)
				if raw.size() == CELL_PER_BLOCK:
					var src := 0
					var dst_base := block_row * block_row_stride + block_col * CELL_COLS
					for y in range(CELL_ROWS):
						var dst := dst_base + y * global_row_stride
						for x in range(CELL_COLS):
							var value := raw[src]
							cells[dst + x] = 0 if value == 2 else value
							src += 1
				break
			elif block_tag == 0:
				if block_size > 0:
					f.seek(f.get_position() + block_size)
				break
			else:
				if block_size > 0:
					f.seek(f.get_position() + block_size)

	f.close()
	_cell_cache = cells
	return _cell_cache


func get_block_summary(block_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if block_id < 0 or block_id >= mapnum:
		return out

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	f.big_endian = false

	f.seek(_map_offsets[block_id])
	var nearby_mask_count := f.get_32()
	out.append({"tag": "MASK_IDS", "size": nearby_mask_count})
	if flag == MAP_FLAG_M10 and nearby_mask_count > 0:
		f.seek(f.get_position() + nearby_mask_count * 4)

	while f.get_position() < f.get_length():
		var block_tag := f.get_32()
		var block_size := f.get_32()
		out.append({"tag": _tag_name(block_tag), "size": block_size})
		if block_size > 0:
			f.seek(f.get_position() + block_size)
		if block_tag == 0:
			break

	f.close()
	return out


func clear() -> void:
	path = ""
	flag = 0
	width = 0
	height = 0
	colnum = 0
	rownum = 0
	mapnum = 0
	masknum = 0
	_map_offsets = PackedInt32Array()
	_mask_offsets = PackedInt32Array()
	_mapx_jpeg_header = PackedByteArray()
	_image_cache.clear()
	_cell_cache = PackedByteArray()


func _read_u32_array(f: FileAccess, count: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(count)
	for i in range(count):
		result[i] = f.get_32()
	return result


func _decode_image(raw: PackedByteArray) -> Image:
	var img := Image.new()
	if img.load_png_from_buffer(raw) == OK:
		return img
	if img.load_jpg_from_buffer(raw) == OK:
		return img
	if img.load_webp_from_buffer(raw) == OK:
		return img
	return null


func _decode_jpeg(raw: PackedByteArray) -> Image:
	var img: Image = UjpegDecoderScript.decode(raw)
	if img != null:
		return img
	img = Image.new()
	if img.load_jpg_from_buffer(raw) == OK:
		return img
	return null


func _fix_cloud_jpeg(data: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(max(data.size() * 2, data.size() + 16))
	var ip := 0
	var op := 0

	while ip < data.size() and data[ip] == 0xFF:
		out[op] = 0xFF
		op += 1
		ip += 1
		if ip >= data.size():
			break

		match data[ip]:
			0xD8:
				out[op] = 0xD8
				op += 1
				ip += 1
			0xA0:
				ip += 1
				op -= 1
			0xC0, 0xC4, 0xDB:
				out[op] = data[ip]
				op += 1
				ip += 1
				if ip + 1 >= data.size():
					break
				var seg_len := (data[ip] << 8) | data[ip + 1]
				for _i in range(seg_len):
					if ip >= data.size():
						break
					out[op] = data[ip]
					op += 1
					ip += 1
			0xDA:
				out[op] = 0xDA
				out[op + 1] = 0x00
				out[op + 2] = 0x0C
				op += 3
				ip += 1
				if ip + 1 >= data.size():
					break
				var scan_len := (data[ip] << 8) | data[ip + 1]
				ip += 2
				for _i in range(2, scan_len):
					if ip >= data.size():
						break
					out[op] = data[ip]
					op += 1
					ip += 1
				out[op] = 0x00
				out[op + 1] = 0x3F
				out[op + 2] = 0x00
				op += 3
				while ip < data.size() - 2:
					if data[ip] == 0xFF:
						out[op] = 0xFF
						out[op + 1] = 0x00
						op += 2
					else:
						out[op] = data[ip]
						op += 1
					ip += 1
				out[op] = 0xD9
				op += 1
				ip = data.size()
			0xD9:
				out[op] = 0xD9
				op += 1
				ip += 1
			_:
				ip += 1

	out.resize(op)
	return out


func _tag_name(value: int) -> String:
	if value == 0:
		return "END"
	var bytes := PackedByteArray([
		(value >> 24) & 0xFF,
		(value >> 16) & 0xFF,
		(value >> 8) & 0xFF,
		value & 0xFF,
	])
	var name := ""
	for byte_value in bytes:
		if byte_value == 0:
			name += "\\0"
		else:
			name += char(byte_value)
	return name
