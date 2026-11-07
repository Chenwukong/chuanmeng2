# tcp_reader.gd — 读取《梦幻西游》TCP/TCA 精灵动画文件（SP/RP 格式）
class_name TcpReader
extends RefCounted

## SP 格式 'PS' (0x5053) — 压缩像素 + RGB565 调色板
## RP 格式 'PR' (0x5052) — 内嵌 PNG/JPG 图片

const FLAG_SP: int = 0x5053  # 'PS'
const FLAG_RP: int = 0x5052  # 'PR'

# ── 公有属性 ──
var flag: int = 0
var format_name: String = ""
var group_count: int = 0
var frame_count: int = 0
var canvas_width: int = 0
var canvas_height: int = 0
var key_x: int = 0
var key_y: int = 0
var total_frames: int = 0

var _data: PackedByteArray = PackedByteArray()
var _palette: PackedInt32Array = PackedInt32Array()
var _frame_offsets: PackedInt32Array = PackedInt32Array()
var _last_error: String = ""

# RP 格式专用
var _rp_info: Array = []
var _rp_list: Array = []

var _frame_cache: Dictionary = {}


func get_last_error() -> String:
	return _last_error


func load_from_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		_last_error = "TCP file not found: %s" % path
		return false
	var bytes := FileAccess.get_file_as_bytes(path)
	return load_from_bytes(bytes)


func load_from_bytes(bytes: PackedByteArray) -> bool:
	_reset()
	if bytes.size() < 16:
		_last_error = "Invalid TCP: too short"
		return false

	_data = bytes
	flag = _read_u16(0)

	match flag:
		FLAG_SP:
			return _parse_sp()
		FLAG_RP:
			return _parse_rp()
		_:
			_last_error = "Unknown TCP flag: 0x%04X" % flag
			return false


# ── SP 格式解析 ──
func _parse_sp() -> bool:
	var h_len: int = _read_u16(2)
	if h_len < 12:
		_last_error = "Invalid SP: header length too small"
		return false

	group_count = _read_u16(4)
	frame_count = _read_u16(6)
	canvas_width = _read_u16(8)
	canvas_height = _read_u16(10)
	key_x = _read_i16(12)
	key_y = _read_i16(14)
	total_frames = group_count * frame_count
	format_name = "SP"

	# 调色板：256 色 RGB565
	var pal_offset := h_len + 4
	_build_palette_565(pal_offset)

	# 帧偏移表：total_frames 个 Uint32
	var list_offset := pal_offset + 512
	_frame_offsets.resize(total_frames)
	for i in range(total_frames):
		var off := _read_u32(list_offset + i * 4)
		if off > 0:
			_frame_offsets[i] = off + h_len + 4
		else:
			_frame_offsets[i] = 0

	return true


# ── RP 格式解析 ──
func _parse_rp() -> bool:
	group_count = _read_u16(2)
	frame_count = _read_u16(4)
	canvas_width = _read_u16(6)
	canvas_height = _read_u16(8)
	key_x = _read_i16(10)
	key_y = _read_i16(12)
	total_frames = _read_u16(14)
	format_name = "RP"

	# RP_INFO: 7 个 Uint16 = 14 字节
	var info_offset := 16
	_rp_info.clear()
	for i in range(total_frames):
		var rp = {
			"id":    _read_u16(info_offset),
			"u1":    _read_i16(info_offset + 2),
			"u2":    _read_i16(info_offset + 4),
			"width": _read_u16(info_offset + 6),
			"height": _read_u16(info_offset + 8),
			"x":     _read_i16(info_offset + 10),
			"y":     _read_i16(info_offset + 12),
		}
		_rp_info.append(rp)
		info_offset += 14

	# RP_LIST: offset(u32=4) + len(u32=4) = 8 字节
	var list_offset := 16 + total_frames * 14 + 4
	_rp_list.clear()
	for i in range(total_frames):
		var rl = {
			"offset": _read_u32(list_offset),
			"len":    _read_u32(list_offset + 4),
		}
		_rp_list.append(rl)
		list_offset += 8

	return true


# ── 解码单帧 ──
func decode_frame(index: int) -> Dictionary:
	if index < 0 or index >= total_frames:
		_last_error = "Frame index out of range: %d" % index
		return {}
	if _frame_cache.has(index):
		return _frame_cache[index]

	var result: Dictionary
	match flag:
		FLAG_SP:
			result = _decode_sp_frame(index)
		FLAG_RP:
			result = _decode_rp_frame(index)

	if not result.is_empty():
		_frame_cache[index] = result
	return result


# ── SP 帧解码 ──
func _decode_sp_frame(index: int) -> Dictionary:
	var frame_offset := _frame_offsets[index]
	if frame_offset <= 0 or frame_offset + 16 > _data.size():
		return {}

	var fx := _read_i32(frame_offset)
	var fy := _read_i32(frame_offset + 4)
	var fw := _read_u32(frame_offset + 8)
	var fh := _read_u32(frame_offset + 12)

	if fw <= 0 or fh <= 0:
		return {}
	if frame_offset + 16 + fh * 4 > _data.size():
		return {}

	var pixels := PackedByteArray()
	pixels.resize(fw * fh * 4)

	for y in range(fh):
		var line_offset := _read_u32(frame_offset + 16 + y * 4)
		if line_offset == 0:
			# 空行：如果上一行有数据，复制上一行
			if y > 0:
				var prev_off := _read_u32(frame_offset + 16 + (y - 1) * 4)
				if prev_off != 0:
					var dst_start := y * fw * 4
					var src_start := (y - 1) * fw * 4
					for i in range(fw * 4):
						pixels[dst_start + i] = pixels[src_start + i]
			continue

		var rp := frame_offset + line_offset
		var pos := y * fw
		var row_end := pos + fw

		while rp < _data.size() and _read_u8(rp) != 0:
			var tag := _read_u8(rp)
			var style := (tag >> 6) & 3
			match style:
				0:
					if (tag & 0x20) != 0:
						# {001*****} 带 Alpha 单像素
						var alpha := ((tag & 0x1F) << 3) & 0xFF
						rp += 1
						if rp >= _data.size(): break
						var idx := _read_u8(rp)
						rp += 1
						if pos < row_end:
							_write_pixel(pixels, pos, _palette[idx] & 0xFFFFFF, alpha)
							pos += 1
					else:
						# {000*****} 重复 n 次带 Alpha 像素
						var n := tag & 0x1F
						rp += 1
						if rp >= _data.size(): break
						var alpha := (_read_u8(rp) << 3) & 0xFF
						rp += 1
						if rp >= _data.size(): break
						var idx := _read_u8(rp)
						rp += 1
						var col := _palette[idx] & 0xFFFFFF
						for _j in range(n):
							if pos >= row_end: break
							_write_pixel(pixels, pos, col, alpha)
							pos += 1
				1:
					# {01******} 不重复 n 个像素
					var n := tag & 0x3F
					rp += 1
					for _j in range(n):
						if rp >= _data.size() or pos >= row_end: break
						var c := _palette[_read_u8(rp)]
						_write_pixel(pixels, pos, c & 0xFFFFFF, (c >> 24) & 0xFF)
						pos += 1
						rp += 1
				2:
					# {10******} 重复 n 次像素
					var n := tag & 0x3F
					rp += 1
					if rp >= _data.size(): break
					var c := _palette[_read_u8(rp)]
					rp += 1
					for _j in range(n):
						if pos >= row_end: break
						_write_pixel(pixels, pos, c & 0xFFFFFF, (c >> 24) & 0xFF)
						pos += 1
				3:
					# {11******} 跳过 n 个像素
					var skip := tag & 0x3F
					if skip == 0:
						if pos > 0 and y > 0:
							var prev := (pos - 1) * 4
							if pixels[prev] == 0 and pixels[prev + 1] == 0 and pixels[prev + 2] == 0:
								# 黑点复制上方
								var above := (pos - 1 - fw) * 4
								if above >= 0:
									for k in range(4):
										pixels[prev + k] = pixels[above + k]
							else:
								pixels[prev + 3] = 255
						rp += 2
					else:
						pos = mini(pos + skip, row_end)
					rp += 1

	var image := Image.create_from_data(fw, fh, false, Image.FORMAT_RGBA8, pixels)
	var texture := ImageTexture.create_from_image(image)

	return {
		"texture": texture,
		"key_x": fx, "key_y": fy,
		"width": fw, "height": fh,
	}


# ── RP 帧解码 ──
func _decode_rp_frame(index: int) -> Dictionary:
	var rl := _rp_list[index] as Dictionary
	if rl.offset <= 0 or rl.len <= 0:
		return {}

	var raw := _data.slice(rl.offset, rl.offset + rl.len)
	var image := Image.new()

	if image.load_png_from_buffer(raw) == OK:
		pass
	elif image.load_jpg_from_buffer(raw) == OK:
		pass
	else:
		return {}

	var rp := _rp_info[index] as Dictionary
	var texture := ImageTexture.create_from_image(image)

	return {
		"texture": texture,
		"key_x": rp.x, "key_y": rp.y,
		"width": rp.width, "height": rp.height,
	}


# ── 调色板 ──
func get_palette() -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(1024)
	for i in range(256):
		if i < _palette.size():
			var c := _palette[i]
			buf[i * 4]     = (c >> 24) & 0xFF
			buf[i * 4 + 1] = (c >> 16) & 0xFF
			buf[i * 4 + 2] = (c >> 8) & 0xFF
			buf[i * 4 + 3] = c & 0xFF
	return buf


func set_palette(pal: PackedByteArray) -> void:
	if pal.size() != 1024:
		return
	_palette.resize(256)
	for i in range(256):
		_palette[i] = (pal[i * 4] << 24) | (pal[i * 4 + 1] << 16) | (pal[i * 4 + 2] << 8) | pal[i * 4 + 3]
	_frame_cache.clear()


# ── 内部 ──
func _build_palette_565(offset: int) -> void:
	_palette.resize(256)
	for i in range(256):
		var c565 := _read_u16(offset + i * 2)
		var r5 := (c565 >> 11) & 0x1F
		var g6 := (c565 >> 5) & 0x3F
		var b5 := c565 & 0x1F
		var r := ((r5 << 3) | (r5 >> 2)) & 0xFF
		var g := ((g6 << 2) | (g6 >> 4)) & 0xFF
		var b := ((b5 << 3) | (b5 >> 2)) & 0xFF
		_palette[i] = (255 << 24) | (r << 16) | (g << 8) | b


func _write_pixel(pixels: PackedByteArray, idx: int, rgb: int, alpha: int) -> void:
	var o := idx * 4
	pixels[o]     = (rgb >> 16) & 0xFF
	pixels[o + 1] = (rgb >> 8) & 0xFF
	pixels[o + 2] = rgb & 0xFF
	pixels[o + 3] = alpha & 0xFF


func _reset() -> void:
	flag = 0
	format_name = ""
	group_count = 0
	frame_count = 0
	canvas_width = 0
	canvas_height = 0
	key_x = 0
	key_y = 0
	total_frames = 0
	_data = PackedByteArray()
	_palette = PackedInt32Array()
	_frame_offsets = PackedInt32Array()
	_last_error = ""
	_rp_info.clear()
	_rp_list.clear()
	_frame_cache.clear()


func _read_u8(offset: int) -> int:
	if offset < 0 or offset >= _data.size(): return 0
	return _data[offset]


func _read_u16(offset: int) -> int:
	if offset + 1 >= _data.size(): return 0
	return _data[offset] | (_data[offset + 1] << 8)


func _read_i16(offset: int) -> int:
	var v := _read_u16(offset)
	return v - 0x10000 if v >= 0x8000 else v


func _read_u32(offset: int) -> int:
	if offset + 3 >= _data.size(): return 0
	return _data[offset] | (_data[offset + 1] << 8) | (_data[offset + 2] << 16) | (_data[offset + 3] << 24)


func _read_i32(offset: int) -> int:
	var v := _read_u32(offset)
	return v - 0x100000000 if v >= 0x80000000 else v
