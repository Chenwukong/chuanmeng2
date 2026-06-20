extends RefCounted
class_name WASReader

var group_count: int = 0
var frame_count: int = 0
var canvas_width: int = 0
var canvas_height: int = 0
var key_x: int = 0
var key_y: int = 0

var _data: PackedByteArray = PackedByteArray()
var _palette: PackedInt32Array = PackedInt32Array()
var _frame_offsets: PackedInt64Array = PackedInt64Array()
var _compatible_flag: bool = false
var _header_len: int = 0
var _last_error: String = ""
var _frame_cache: Dictionary = {}


func get_last_error() -> String:
	return _last_error


func load_from_file(path: String) -> bool:
	_reset()
	if not FileAccess.file_exists(path):
		_last_error = "WAS file not found: %s" % path
		return false

	_data = FileAccess.get_file_as_bytes(path)
	if _data.size() < 16:
		_last_error = "Invalid WAS file: header too short"
		return false

	var flag: int = _read_u16(0)
	var h_len: int = _read_u16(2)
	group_count = _read_u16(4)
	frame_count = _read_u16(6)
	canvas_width = _read_u16(8)
	canvas_height = _read_u16(10)
	key_x = _read_i16(12)
	key_y = _read_i16(14)

	if group_count <= 0 or frame_count <= 0:
		_last_error = "Invalid WAS header: group/frame must be > 0"
		return false

	_compatible_flag = (flag == 0x3344)
	var total_frames: int = group_count * frame_count

	if _compatible_flag:
		_header_len = 16
		_build_palette_8888(_header_len, h_len)
		var list_start: int = _header_len + h_len
		if not _build_frame_offsets(list_start, total_frames, false):
			return false
	else:
		_header_len = h_len + 4
		if _header_len + 512 > _data.size():
			_last_error = "Invalid WAS file: palette section overflow"
			return false
		_build_palette_565(_header_len)
		var list_start_565: int = _header_len + 512
		if not _build_frame_offsets(list_start_565, total_frames, true):
			return false

	return true


func get_total_frames() -> int:
	return group_count * frame_count


func decode_frame(direction: int, frame: int) -> Dictionary:
	if direction < 0 or direction >= group_count:
		return {}
	if frame < 0 or frame >= frame_count:
		return {}

	var frame_id: int = direction * frame_count + frame
	if frame_id >= _frame_offsets.size():
		return {}
	if _frame_cache.has(frame_id):
		return _frame_cache[frame_id]

	var frame_offset: int = int(_frame_offsets[frame_id])
	if frame_offset <= 0 or frame_offset + 16 > _data.size():
		return {}

	var frame_key_x: int = _read_i32(frame_offset)
	var frame_key_y: int = _read_i32(frame_offset + 4)
	var width: int = _read_u32(frame_offset + 8)
	var height: int = _read_u32(frame_offset + 12)
	if width <= 0 or height <= 0:
		return {}
	if frame_offset + 16 + height * 4 > _data.size():
		return {}

	var pixels := PackedByteArray()
	pixels.resize(width * height * 4)
	var visible_pixels: int = 0

	for y in height:
		var line_offset: int = _read_u32(frame_offset + 16 + y * 4)
		var rp: int = frame_offset + line_offset
		var row_start_pixel: int = y * width
		var pos: int = row_start_pixel
		var row_end: int = row_start_pixel + width

		while rp < _data.size() and _read_u8(rp) > 0:
			var tag: int = _read_u8(rp)
			var style: int = tag >> 6
			if style == 0:
				if (tag & 0x20) == 0x20:
					var level: int = tag & 0x1F
					rp += 1
					if rp >= _data.size():
						break
					var color_idx: int = _read_u8(rp)
					var alpha_single: int = ((level << 3) | (level >> 2)) & 0xFF
					if pos < row_end:
						visible_pixels += _write_pixel(pixels, pos, _palette[color_idx], alpha_single)
						pos += 1
					rp += 1
				else:
					var repeat0: int = tag & 0x1F
					rp += 1
					if rp + 1 >= _data.size():
						break
					var level0: int = _read_u8(rp)
					rp += 1
					var color_idx0: int = _read_u8(rp)
					var alpha0: int = ((level0 << 3) | (level0 >> 2)) & 0xFF
					var i0: int = 0
					while i0 < repeat0 and pos < row_end:
						visible_pixels += _write_pixel(pixels, pos, _palette[color_idx0], alpha0)
						pos += 1
						i0 += 1
					rp += 1
			elif style == 1:
				var repeat1: int = tag & 0x3F
				rp += 1
				var i1: int = 0
				while i1 < repeat1 and rp < _data.size():
					if pos < row_end:
						var c1: int = _palette[_read_u8(rp)]
						visible_pixels += _write_pixel(pixels, pos, c1, 255)
						pos += 1
					rp += 1
					i1 += 1
			elif style == 2:
				var repeat2: int = tag & 0x3F
				rp += 1
				if rp >= _data.size():
					break
				var c2: int = _palette[_read_u8(rp)]
				var i2: int = 0
				while i2 < repeat2 and pos < row_end:
					visible_pixels += _write_pixel(pixels, pos, c2, 255)
					pos += 1
					i2 += 1
				rp += 1
			else:
				var repeat3: int = tag & 0x3F
				if repeat3 == 0:
					# GGElua compatibility branch for edge anti-aliased pixels.
					if pos - 1 >= 0 and rp + 2 < _data.size():
						var a_tag: int = _read_u8(rp + 1)
						if (a_tag & 0x20) == 0x20:
							var level3: int = a_tag & 0x1F
							var alpha3: int = ((level3 << 3) | (level3 >> 2)) & 0xFF
							var prev_alpha: int = pixels[(pos - 1) * 4 + 3]
							if alpha3 > prev_alpha:
								visible_pixels += _write_pixel(pixels, pos - 1, _palette[_read_u8(rp + 2)], alpha3)
					if rp + 3 < _data.size():
						rp += 2
				else:
					pos = mini(pos + repeat3, row_end)
				rp += 1

		# If one row is empty but previous row has data, copy previous row.
		if y > 0 and rp < _data.size() and _read_u8(rp) == 0 and pos == row_start_pixel:
			var prev_line_offset: int = _read_u32(frame_offset + 16 + (y - 1) * 4)
			if frame_offset + prev_line_offset < _data.size() and _read_u8(frame_offset + prev_line_offset) != 0:
				_copy_row(pixels, y, width)

	var image := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, pixels)
	var texture := ImageTexture.create_from_image(image)

	var out := {
		"texture": texture,
		"key_x": frame_key_x,
		"key_y": frame_key_y,
		"width": width,
		"height": height,
		"visible_pixels": visible_pixels,
		"direction": direction,
		"frame": frame
	}
	_frame_cache[frame_id] = out
	return out


func _reset() -> void:
	group_count = 0
	frame_count = 0
	canvas_width = 0
	canvas_height = 0
	key_x = 0
	key_y = 0
	_data = PackedByteArray()
	_palette = PackedInt32Array()
	_frame_offsets = PackedInt64Array()
	_compatible_flag = false
	_header_len = 0
	_last_error = ""
	_frame_cache.clear()


func _build_frame_offsets(start_offset: int, total_frames: int, add_header_len: bool) -> bool:
	if start_offset + total_frames * 4 > _data.size():
		_last_error = "Invalid WAS file: frame list overflow"
		return false
	_frame_offsets.resize(total_frames)
	for i in total_frames:
		var v: int = _read_u32(start_offset + i * 4)
		if v > 0 and add_header_len:
			v += _header_len
		_frame_offsets[i] = v
	return true


func _build_palette_565(palette_offset: int) -> void:
	_palette.resize(256)
	for i in 256:
		var c565: int = _read_u16(palette_offset + i * 2)
		var r5: int = (c565 >> 11) & 0x1F
		var g6: int = (c565 >> 5) & 0x3F
		var b5: int = c565 & 0x1F
		var r: int = ((r5 << 3) | (r5 >> 2)) & 0xFF
		var g: int = ((g6 << 2) | (g6 >> 4)) & 0xFF
		var b: int = ((b5 << 3) | (b5 >> 2)) & 0xFF
		_palette[i] = (r << 24) | (g << 16) | (b << 8) | 255


func _build_palette_8888(palette_offset: int, byte_len: int) -> void:
	_palette.resize(256)
	for i in 256:
		if byte_len <= 0 or palette_offset + i * 4 + 3 >= _data.size():
			_palette[i] = 0x000000FF
			continue
		var raw: int = _read_u32(palette_offset + i * 4)
		var r: int = (raw >> 16) & 0xFF
		var g: int = (raw >> 8) & 0xFF
		var b: int = raw & 0xFF
		_palette[i] = (r << 24) | (g << 16) | (b << 8) | 255


func _copy_row(pixels: PackedByteArray, row: int, width: int) -> void:
	var src_start: int = (row - 1) * width * 4
	var dst_start: int = row * width * 4
	for i in width * 4:
		pixels[dst_start + i] = pixels[src_start + i]


func _write_pixel(pixels: PackedByteArray, pixel_index: int, rgb_packed: int, alpha: int) -> int:
	var o: int = pixel_index * 4
	pixels[o] = (rgb_packed >> 24) & 0xFF
	pixels[o + 1] = (rgb_packed >> 16) & 0xFF
	pixels[o + 2] = (rgb_packed >> 8) & 0xFF
	pixels[o + 3] = alpha & 0xFF
	return 1 if (alpha & 0xFF) > 0 else 0


func _read_u8(offset: int) -> int:
	if offset < 0 or offset >= _data.size():
		return 0
	return _data[offset]


func _read_u16(offset: int) -> int:
	if offset + 1 >= _data.size():
		return 0
	return _data[offset] | (_data[offset + 1] << 8)


func _read_i16(offset: int) -> int:
	var v: int = _read_u16(offset)
	return v - 0x10000 if v >= 0x8000 else v


func _read_u32(offset: int) -> int:
	if offset + 3 >= _data.size():
		return 0
	return _data[offset] | (_data[offset + 1] << 8) | (_data[offset + 2] << 16) | (_data[offset + 3] << 24)


func _read_i32(offset: int) -> int:
	var v: int = _read_u32(offset)
	return v - 0x100000000 if v >= 0x80000000 else v
