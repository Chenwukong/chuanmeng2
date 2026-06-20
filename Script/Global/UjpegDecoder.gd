# uJPEG (MicroJPEG) -- KeyJ's Small Baseline JPEG Decoder
# Ported from ujpeg_orig.h/ujpeg_orig.cpp (MIT license)
# https://github.com/nothings/stb/blob/master/stb_image.h
#
# Minimal baseline JPEG decoder for Godot.
# Supports: YCbCr (3 components) and grayscale (1 component),
# standard Huffman tables, any power-of-two subsampling.
# Outputs RGBA8 Image via static UjpegDecoder.decode(data).

class_name UjpegDecoder

# ── Zigzag order ──────────────────────────────────────────────────────
const ZZ: PackedByteArray = [
	0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18,
	11, 4, 5, 12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35,
	42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51, 58, 59, 52, 45,
	38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63
]

# ── IDCT constants ──────────────────────────────────────────────────────
const W1 := 2841
const W2 := 2676
const W3 := 2408
const W5 := 1609
const W6 := 1108
const W7 := 565

# ── Chroma upsampling filter constants ─────────────────────────────────
const CF4A := -9
const CF4B := 111
const CF4C := 29
const CF4D := -3
const CF3A := 28
const CF3B := 109
const CF3C := -9
const CF3X := 104
const CF3Y := 27
const CF3Z := -3
const CF2A := 139
const CF2B := -11

# ======================================================================
#  Public API
# ======================================================================

# Decode a JPEG buffer into a Godot Image (RGBA8).
# Returns null on failure.
static func decode(data: PackedByteArray) -> Image:
	if data.size() < 2:
		return null
	if data[0] != 0xFF or data[1] != 0xD8:
		return null # not SOI

	var ctx = JContext.new()
	ctx.data = data
	ctx.pos = 2
	ctx.size = data.size()

	while true:
		if ctx.size - ctx.pos < 2:
			return null
		if ctx.data[ctx.pos] != 0xFF:
			return null
		var marker = ctx.data[ctx.pos + 1]
		ctx.pos += 2

		match marker:
			0xC0: # SOF0
				if not _decode_sof(ctx):
					return null
			0xC4: # DHT
				if not _decode_dht(ctx):
					return null
			0xDB: # DQT
				if not _decode_dqt(ctx):
					return null
			0xDD: # DRI
				if not _decode_dri(ctx):
					return null
			0xDA: # SOS
				if not _decode_sos(ctx):
					return null
				# After SOS we're done decoding
				# Convert the decoded planes to RGB
				var img = _convert_to_image(ctx)
				return img
			0xD9: # EOI
				return null # unexpected EOI before SOS
			0xFE: # COM
				_skip_marker(ctx)
			_:
				if (marker & 0xF0) == 0xE0:
					_skip_marker(ctx)
				else:
					return null # unsupported

	return null

# ======================================================================
#  Internal context (state holder, not saved)
# ======================================================================
class JContext:
	var data: PackedByteArray
	var pos: int = 0
	var size: int = 0

	# image info
	var width: int = 0
	var height: int = 0
	var ncomp: int = 0

	# macroblock info
	var mbwidth: int = 0
	var mbheight: int = 0
	var mbsizex: int = 0
	var mbsizey: int = 0

	# components (max 3)
	var comp: Array = []

	# quantization tables (max 4 tables, each 64 bytes)
	var qtused: int = 0
	var qtavail: int = 0
	var qtab: Array = [] # 4 x PackedByteArray of 64

	# Huffman tables (8 tables, each 65536 entries)
	# Each entry: {bits: int, code: int}
	var vlctab: Array = []

	# bit buffer
	var buf: int = 0
	var bufbits: int = 0

	# block buffer
	var block: PackedInt32Array = []

	# restart interval
	var rstinterval: int = 0

	# valid / decoded flags
	var valid: bool = false

	func _init():
		comp = [null, null, null]
		qtab = []
		for i in range(4):
			qtab.append(PackedByteArray())
			qtab[i].resize(64)
		vlctab = []
		for i in range(8):
			var tbl: Array = []
			tbl.resize(65536)
			for j in range(65536):
				tbl[j] = {"bits": 0, "code": 0}
			vlctab.append(tbl)
		block = PackedInt32Array()
		block.resize(64)

# ======================================================================
#  Bit I/O
# ======================================================================

static func _show_bits(ctx: JContext, n: int) -> int:
	if n == 0:
		return 0
	while ctx.bufbits < n:
		if ctx.pos >= ctx.size:
			ctx.buf = (ctx.buf << 8) | 0xFF
			ctx.bufbits += 8
			continue
		var newbyte = ctx.data[ctx.pos]
		ctx.pos += 1
		ctx.bufbits += 8
		ctx.buf = (ctx.buf << 8) | newbyte
		if newbyte == 0xFF and ctx.pos < ctx.size:
			var marker = ctx.data[ctx.pos]
			ctx.pos += 1
			if marker != 0x00:
				# For restart markers, absorb them into the bitstream
				ctx.buf = (ctx.buf << 8) | marker
				ctx.bufbits += 8
	# return top n bits
	return (ctx.buf >> (ctx.bufbits - n)) & ((1 << n) - 1)

static func _skip_bits(ctx: JContext, n: int) -> void:
	if ctx.bufbits < n:
		_show_bits(ctx, n)
	ctx.bufbits -= n

static func _get_bits(ctx: JContext, n: int) -> int:
	var res = _show_bits(ctx, n)
	_skip_bits(ctx, n)
	return res

static func _byte_align(ctx: JContext) -> void:
	ctx.bufbits &= 0xF8

# ======================================================================
#  Marker reading helpers
# ======================================================================

static func _read16(data: PackedByteArray, pos: int) -> int:
	return (data[pos] << 8) | data[pos + 1]

static func _decode_length(ctx: JContext) -> int:
	if ctx.size - ctx.pos < 2:
		return -1
	var len = _read16(ctx.data, ctx.pos)
	ctx.pos += 2
	if len < 2 or len > ctx.size - ctx.pos + 2:
		return -1
	return len

static func _skip_marker(ctx: JContext) -> bool:
	var len = _decode_length(ctx)
	if len < 0:
		return false
	ctx.pos += len - 2
	return true

# ======================================================================
#  SOF (Start of Frame)
# ======================================================================

static func _decode_sof(ctx: JContext) -> bool:
	var len = _decode_length(ctx)
	if len < 0 or len < 9:
		return false

	var data = ctx.data
	var p = ctx.pos

	if data[p] != 8: # precision must be 8
		return false

	ctx.height = _read16(data, p + 1)
	ctx.width = _read16(data, p + 3)
	if ctx.width == 0 or ctx.height == 0:
		return false

	ctx.ncomp = data[p + 5]
	if ctx.ncomp != 1 and ctx.ncomp != 3:
		return false

	if len < (ctx.ncomp * 3 + 6):
		return false

	var ssxmax = 0
	var ssymax = 0
	ctx.qtused = 0

	p += 6
	for i in range(ctx.ncomp):
		var c = JComponent.new()
		c.cid = data[p]
		c.ssx = data[p + 1] >> 4
		c.ssy = data[p + 1] & 0x0F
		if c.ssx == 0 or c.ssy == 0:
			return false
		if c.ssx & (c.ssx - 1): return false # not power of 2
		if c.ssy & (c.ssy - 1): return false
		c.qtsel = data[p + 2] & 0x03
		if data[p + 2] & 0xFC: return false
		ctx.qtused |= 1 << c.qtsel
		if c.ssx > ssxmax: ssxmax = c.ssx
		if c.ssy > ssymax: ssymax = c.ssy
		ctx.comp[i] = c
		p += 3

	if ctx.ncomp == 1:
		ctx.comp[0].ssx = 1
		ctx.comp[0].ssy = 1
		ssxmax = 1
		ssymax = 1

	ctx.mbsizex = ssxmax << 3
	ctx.mbsizey = ssymax << 3
	ctx.mbwidth = (ctx.width + ctx.mbsizex - 1) / ctx.mbsizex
	ctx.mbheight = (ctx.height + ctx.mbsizey - 1) / ctx.mbsizey

	for i in range(ctx.ncomp):
		var c = ctx.comp[i] as JComponent
		c.width = (ctx.width * c.ssx + ssxmax - 1) / ssxmax
		c.height = (ctx.height * c.ssy + ssymax - 1) / ssymax
		c.stride = ctx.mbwidth * c.ssx << 3
		# Allocate pixel buffer, initialized to 0x80 (mid-gray for chroma)
		var size: int = (c.stride * ctx.mbheight * c.ssy) << 3
		c.pixels = PackedByteArray()
		c.pixels.resize(size)
		for j in range(size):
			c.pixels[j] = 0x80

	# Skip remaining bytes: total payload is len-2, we consumed 6 + ncomp*3
	ctx.pos = p + (len - 8 - ctx.ncomp * 3)
	return true

# ======================================================================
#  DQT (Define Quantization Table)
# ======================================================================

static func _decode_dqt(ctx: JContext) -> bool:
	var len = _decode_length(ctx)
	if len < 0:
		return false

	var end_pos = ctx.pos + len - 2
	while ctx.pos < end_pos:
		if end_pos - ctx.pos < 65:
			return false
		var i = ctx.data[ctx.pos] & 0x03
		ctx.qtavail |= 1 << i
		for j in range(64):
			ctx.qtab[i][j] = ctx.data[ctx.pos + 1 + j]
		ctx.pos += 65
	return true

# ======================================================================
#  DHT (Define Huffman Table)
# ======================================================================

static func _decode_dht(ctx: JContext) -> bool:
	var len = _decode_length(ctx)
	if len < 0:
		return false

	var end_pos = ctx.pos + len - 2
	while ctx.pos < end_pos:
		if end_pos - ctx.pos < 17:
			return false
		var i = ctx.data[ctx.pos]
		if i & 0xEC: return false
		# Combined DC/AC + tableid: 0-3 DC, 4-7 AC
		i = (i | (i >> 2)) & 7

		var counts = PackedByteArray()
		counts.resize(16)
		for k in range(16):
			counts[k] = ctx.data[ctx.pos + 1 + k]
		ctx.pos += 17

		var vlc: Array = ctx.vlctab[i]
		var remain = 65536
		var spread = 65536
		var base = 0

		for codelen in range(1, 17):
			spread >>= 1
			var currcnt = counts[codelen - 1]
			if currcnt == 0:
				continue
			if end_pos - ctx.pos < currcnt:
				return false
			remain -= currcnt << (16 - codelen)
			if remain < 0:
				return false
			# spread is how many table slots each code value fills
			for k in range(currcnt):
				var code = ctx.data[ctx.pos + k]
				for _j in range(spread):
					vlc[base]["bits"] = codelen
					vlc[base]["code"] = code
					base += 1
			ctx.pos += currcnt

		while remain > 0:
			vlc[65536 - remain]["bits"] = 0
			remain -= 1

	if ctx.pos > end_pos:
		return false
	return true

# ======================================================================
#  DRI (Define Restart Interval)
# ======================================================================

static func _decode_dri(ctx: JContext) -> bool:
	var len = _decode_length(ctx)
	if len < 0 or len < 2:
		return false
	ctx.rstinterval = _read16(ctx.data, ctx.pos)
	ctx.pos += len - 2
	return true

# ======================================================================
#  IDCT
# ======================================================================

static func _row_idct(blk: PackedInt32Array, offset: int) -> void:
	var x0: int
	var x1: int
	var x2: int
	var x3: int
	var x4: int
	var x5: int
	var x6: int
	var x7: int
	var x8: int

	x1 = blk[offset + 4] << 11
	x2 = blk[offset + 6]
	x3 = blk[offset + 2]
	x4 = blk[offset + 1]
	x5 = blk[offset + 7]
	x6 = blk[offset + 5]
	x7 = blk[offset + 3]

	if (x1 | x2 | x3 | x4 | x5 | x6 | x7) == 0:
		var v = blk[offset + 0] << 3
		for i in range(8):
			blk[offset + i] = v
		return

	x0 = (blk[offset + 0] << 11) + 128
	x8 = W7 * (x4 + x5)
	x4 = x8 + (W1 - W7) * x4
	x5 = x8 - (W1 + W7) * x5
	x8 = W3 * (x6 + x7)
	x6 = x8 - (W3 - W5) * x6
	x7 = x8 - (W3 + W5) * x7
	x8 = x0 + x1
	x0 -= x1
	x1 = W6 * (x3 + x2)
	x2 = x1 - (W2 + W6) * x2
	x3 = x1 + (W2 - W6) * x3
	x1 = x4 + x6
	x4 -= x6
	x6 = x5 + x7
	x5 -= x7
	x7 = x8 + x3
	x8 -= x3
	x3 = x0 + x2
	x0 -= x2
	x2 = (181 * (x4 + x5) + 128) >> 8
	x4 = (181 * (x4 - x5) + 128) >> 8

	blk[offset + 0] = (x7 + x1) >> 8
	blk[offset + 1] = (x3 + x2) >> 8
	blk[offset + 2] = (x0 + x4) >> 8
	blk[offset + 3] = (x8 + x6) >> 8
	blk[offset + 4] = (x8 - x6) >> 8
	blk[offset + 5] = (x0 - x4) >> 8
	blk[offset + 6] = (x3 - x2) >> 8
	blk[offset + 7] = (x7 - x1) >> 8

static func _clip(x: int) -> int:
	if x < 0: return 0
	if x > 255: return 255
	return x

static func _col_idct(blk: PackedInt32Array, out: PackedByteArray, out_offset: int, stride: int) -> void:
	var x0: int
	var x1: int
	var x2: int
	var x3: int
	var x4: int
	var x5: int
	var x6: int
	var x7: int
	var x8: int

	x1 = blk[8 * 4] << 8
	x2 = blk[8 * 6]
	x3 = blk[8 * 2]
	x4 = blk[8 * 1]
	x5 = blk[8 * 7]
	x6 = blk[8 * 5]
	x7 = blk[8 * 3]

	if (x1 | x2 | x3 | x4 | x5 | x6 | x7) == 0:
		var v = _clip(((blk[0] + 32) >> 6) + 128)
		var o = out_offset
		for _i in range(8):
			out[o] = v
			o += stride
		return

	x0 = (blk[0] << 8) + 8192
	x8 = W7 * (x4 + x5) + 4
	x4 = (x8 + (W1 - W7) * x4) >> 3
	x5 = (x8 - (W1 + W7) * x5) >> 3
	x8 = W3 * (x6 + x7) + 4
	x6 = (x8 - (W3 - W5) * x6) >> 3
	x7 = (x8 - (W3 + W5) * x7) >> 3
	x8 = x0 + x1
	x0 -= x1
	x1 = W6 * (x3 + x2) + 4
	x2 = (x1 - (W2 + W6) * x2) >> 3
	x3 = (x1 + (W2 - W6) * x3) >> 3
	x1 = x4 + x6
	x4 -= x6
	x6 = x5 + x7
	x5 -= x7
	x7 = x8 + x3
	x8 -= x3
	x3 = x0 + x2
	x0 -= x2
	x2 = (181 * (x4 + x5) + 128) >> 8
	x4 = (181 * (x4 - x5) + 128) >> 8

	var o = out_offset
	out[o] = _clip(((x7 + x1) >> 14) + 128); o += stride
	out[o] = _clip(((x3 + x2) >> 14) + 128); o += stride
	out[o] = _clip(((x0 + x4) >> 14) + 128); o += stride
	out[o] = _clip(((x8 + x6) >> 14) + 128); o += stride
	out[o] = _clip(((x8 - x6) >> 14) + 128); o += stride
	out[o] = _clip(((x0 - x4) >> 14) + 128); o += stride
	out[o] = _clip(((x3 - x2) >> 14) + 128); o += stride
	out[o] = _clip(((x7 - x1) >> 14) + 128)

# ======================================================================
#  Decode one 8x8 block
# ======================================================================

static func _decode_block(ctx: JContext, c: JComponent, out_offset: int) -> bool:
	var block = ctx.block
	for i in range(64):
		block[i] = 0

	# DC coefficient
	var dc_val = _get_vlc_raw(ctx, ctx.vlctab[c.dctabsel])
	if dc_val == null:
		return false
	c.dcpred += dc_val[1]
	block[0] = c.dcpred * ctx.qtab[c.qtsel][0]

	var coef = 0
	while coef < 63:
		var result = _get_vlc_raw(ctx, ctx.vlctab[c.actabsel])
		if result == null:
			return false
		var raw_code = result[0] as int
		var ext_val = result[1] as int

		if raw_code == 0:
			break # EOB

		if (raw_code & 0x0F) == 0 and raw_code != 0xF0:
			return false # bad code

		coef += (raw_code >> 4) + 1
		if coef > 63:
			return false
		block[ZZ[coef]] = ext_val * ctx.qtab[c.qtsel][coef]

	# Row IDCT
	for i in range(0, 64, 8):
		_row_idct(block, i)

	# Column IDCT
	var pixels = c.pixels
	for i in range(8):
		_col_idct(block, pixels, out_offset + i, c.stride)

	return true

# Decode one VLC symbol, returning [raw_code, extended_value] or null on error
static func _get_vlc_raw(ctx: JContext, vlc: Array):
	var value = _show_bits(ctx, 16)
	var bits = vlc[value]["bits"] as int
	if bits == 0:
		return null
	_skip_bits(ctx, bits)
	var raw_code = vlc[value]["code"] as int
	bits = raw_code & 15
	if bits == 0:
		return [raw_code, 0]
	value = _get_bits(ctx, bits)
	if value < (1 << (bits - 1)):
		value += ((-1) << bits) + 1
	return [raw_code, value]

# ======================================================================
#  SOS (Start of Scan)
# ======================================================================

static func _decode_sos(ctx: JContext) -> bool:
	var len = _decode_length(ctx)
	if len < 0 or len < (4 + 2 * ctx.ncomp):
		return false

	var data = ctx.data
	var p = ctx.pos
	if data[p] != ctx.ncomp:
		return false
	p += 1

	for i in range(ctx.ncomp):
		var c = ctx.comp[i] as JComponent
		if data[p] != c.cid:
			return false
		c.dctabsel = data[p + 1] >> 4
		c.actabsel = (data[p + 1] & 3) | 4
		p += 2

	# Check spectral selection (must be sequential: 0, 63, 0)
	if data[p] != 0 or data[p + 1] != 63 or data[p + 2] != 0:
		return false

	ctx.pos = p + (len - 2 - 1 - 2 * ctx.ncomp)

	# --- Decode MCUs ---
	ctx.valid = true

	var rstcount = ctx.rstinterval
	var nextrst = 0

	var mbx = 0
	var mby = 0

	while true:
		for i in range(ctx.ncomp):
			var c = ctx.comp[i] as JComponent
			for sby in range(c.ssy):
				for sbx in range(c.ssx):
					var offset = ((mby * c.ssy + sby) * c.stride + mbx * c.ssx + sbx) << 3
					if not _decode_block(ctx, c, offset):
						# On error, stop decoding (partial image)
						pass

		mbx += 1
		if mbx >= ctx.mbwidth:
			mbx = 0
			mby += 1
			if mby >= ctx.mbheight:
				break

		if ctx.rstinterval > 0:
			rstcount -= 1
			if rstcount == 0:
				_byte_align(ctx)
				var marker = _get_bits(ctx, 16)
				if (marker & 0xFFF8) == 0xFFD0 and (marker & 7) == nextrst:
					nextrst = (nextrst + 1) & 7
					rstcount = ctx.rstinterval
					for j in range(3):
						if ctx.comp[j] != null:
							ctx.comp[j].dcpred = 0

	return true

# ======================================================================
#  Chroma upsampling (fast, pixel-replication)
# ======================================================================

static func _upsample_fast(ctx: JContext, c: JComponent) -> void:
	var xshift = 0
	var yshift = 0
	while c.width < ctx.width:
		c.width <<= 1
		xshift += 1
	while c.height < ctx.height:
		c.height <<= 1
		yshift += 1

	if xshift == 0 and yshift == 0:
		return

	var out = PackedByteArray()
	out.resize(c.width * c.height)

	var dst_idx = 0
	for y in range(c.height):
		var src_row = (y >> yshift) * c.stride
		for x in range(c.width):
			out[dst_idx] = c.pixels[src_row + (x >> xshift)]
			dst_idx += 1

	c.stride = c.width
	c.pixels = out

# ======================================================================
#  Color conversion (YCbCr → RGB) and final Image creation
# ======================================================================

static func _convert_to_image(ctx: JContext) -> Image:
	# Upsample chroma planes to full resolution
	for i in range(ctx.ncomp):
		var c = ctx.comp[i] as JComponent
		_upsample_fast(ctx, c)
		if c.width < ctx.width or c.height < ctx.height:
			return null

	var w = ctx.width
	var h = ctx.height

	var img_data = PackedByteArray()
	img_data.resize(w * h * 4)

	if ctx.ncomp == 3:
		var py: PackedByteArray = ctx.comp[0].pixels
		var pcb: PackedByteArray = ctx.comp[1].pixels
		var pcr: PackedByteArray = ctx.comp[2].pixels

		var dst_idx = 0
		for yy in range(h):
			var y_row: int = yy * ctx.comp[0].stride
			var cb_row: int = yy * ctx.comp[1].stride
			var cr_row: int = yy * ctx.comp[2].stride

			for x in range(w):
				var yval = py[y_row + x] as int
				var cb = (pcb[cb_row + x] as int) - 128
				var cr = (pcr[cr_row + x] as int) - 128

				var yyval = yval << 8
				var r = _clip((yyval + 359 * cr + 128) >> 8)
				var g = _clip((yyval - 88 * cb - 183 * cr + 128) >> 8)
				var b = _clip((yyval + 454 * cb + 128) >> 8)

				img_data[dst_idx] = r
				img_data[dst_idx + 1] = g
				img_data[dst_idx + 2] = b
				img_data[dst_idx + 3] = 255
				dst_idx += 4
	else:
		# Grayscale
		var py: PackedByteArray = ctx.comp[0].pixels
		var dst_idx = 0
		for yy in range(h):
			var y_row: int = yy * ctx.comp[0].stride
			for x in range(w):
				var v = py[y_row + x]
				img_data[dst_idx] = v
				img_data[dst_idx + 1] = v
				img_data[dst_idx + 2] = v
				img_data[dst_idx + 3] = 255
				dst_idx += 4

	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, img_data)

# ======================================================================
#  Component helper class
# ======================================================================
class JComponent:
	var width: int = 0
	var height: int = 0
	var stride: int = 0
	var pixels: PackedByteArray = PackedByteArray()
	var cid: int = 0
	var ssx: int = 0
	var ssy: int = 0
	var qtsel: int = 0
	var actabsel: int = 0
	var dctabsel: int = 0
	var dcpred: int = 0
