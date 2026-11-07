class_name WpalDye
extends RefCounted
## GGE WPAL：分段索引边界 + 每段的 3×3 定点 RGB 变换矩阵。
## 只变换调色板，像素索引、逐像素透明度和动画锚点保持原样。

var boundaries: Array[int] = []
var schemes: Array = []
var last_error: String = ""

func load_file(path: String) -> bool:
	return load_bytes(FileAccess.get_file_as_bytes(path))

func load_bytes(data: PackedByteArray) -> bool:
	boundaries.clear()
	schemes.clear()
	last_error = ""
	if data.size() < 16 or data.slice(0, 4).get_string_from_ascii() != "wpal":
		return _fail("无效的 WPAL 文件头")
	var count := data.decode_u32(4)
	if count < 1 or count > 256 or 8 + (count + 1) * 4 > data.size():
		return _fail("无效的 WPAL 分段数量")
	var pos := 8
	for i in range(count + 1):
		var boundary := data.decode_u32(pos)
		if boundary > 256 or (i > 0 and boundary < boundaries[i - 1]):
			return _fail("无效的 WPAL 索引边界")
		boundaries.append(boundary)
		pos += 4
	for segment in range(count):
		if pos + 4 > data.size(): return _fail("WPAL 方案数量缺失")
		var size := data.decode_u32(pos)
		pos += 4
		if size < 1 or size > 4096 or pos + size * 36 > data.size():
			return _fail("WPAL 矩阵数据不完整")
		var options: Array = []
		for option in range(size):
			var matrix := PackedInt32Array()
			for cell in range(9):
				matrix.append(data.decode_s32(pos))
				pos += 4
			options.append(matrix)
		schemes.append(options)
	if pos != data.size(): return _fail("WPAL 包含未识别的附加数据")
	return true

func _fail(message: String) -> bool:
	last_error = message
	boundaries.clear()
	schemes.clear()
	return false

## 输入/输出均为 WASReader 使用的 RGBA8888；方案从 0 开始。
## 每次从原始调色板计算，不叠加上一次染色。
func apply(source: PackedInt32Array, choices: PackedInt32Array) -> PackedInt32Array:
	last_error = ""
	if schemes.is_empty() or source.size() != 256 or choices.size() > schemes.size():
		last_error = "染色调色板或分段参数无效"
		return PackedInt32Array()
	var result := source.duplicate()
	for segment in range(schemes.size()):
		var choice := choices[segment] if segment < choices.size() else 0
		if choice < 0 or choice >= schemes[segment].size():
			last_error = "第 %d 段不存在方案 %d" % [segment + 1, choice]
			return PackedInt32Array()
		var matrix: PackedInt32Array = schemes[segment][choice]
		for index in range(boundaries[segment], boundaries[segment + 1]):
			var color := source[index]
			var r := (color >> 24) & 255
			var g := (color >> 16) & 255
			var b := (color >> 8) & 255
			var rr := clampi((r * matrix[0] + g * matrix[1] + b * matrix[2]) >> 8, 0, 255)
			var gg := clampi((r * matrix[3] + g * matrix[4] + b * matrix[5]) >> 8, 0, 255)
			var bb := clampi((r * matrix[6] + g * matrix[7] + b * matrix[8]) >> 8, 0, 255)
			result[index] = (rr << 24) | (gg << 16) | (bb << 8) | (color & 255)
	return result
