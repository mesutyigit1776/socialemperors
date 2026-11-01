"""Reads the parts of SWF files that the importer needs: the exported symbols,
the placements, bounds and text fields of the client windows (ui_import.py),
and the frame labels of the spell graphics. The port reads the art and the
data of the frames itself, with the extension flash_art.
"""

import struct
import zlib

SHAPE_TAGS = {2, 22, 32, 83}          # DefineShape, DefineShape2, 3, 4
MORPH_TAGS = {46, 84}                 # DefineMorphShape, DefineMorphShape2
TEXT_TAGS = {11, 33}                  # DefineText, DefineText2
EDIT_TEXT_TAG = 37
FONT_TAGS = {48, 75}                  # DefineFont2, DefineFont3
SPRITE_TAG = 39
BUTTON2_TAG = 34                       # DefineButton2
PLACE_TAGS = {26, 70}                 # PlaceObject2, PlaceObject3
SYMBOL_CLASS_TAG = 76
SHOW_FRAME_TAG = 1
FRAME_LABEL_TAG = 43
REMOVE_OBJECT2_TAG = 28


class SwfError(Exception):
	pass


class _Bits:
	def __init__(self, data, pos):
		self.data = data
		self.pos = pos * 8

	def read(self, n):
		value = 0
		for _ in range(n):
			byte = self.data[self.pos >> 3]
			value = (value << 1) | ((byte >> (7 - (self.pos & 7))) & 1)
			self.pos += 1
		return value

	def read_signed(self, n):
		value = self.read(n)
		if n and value & (1 << (n - 1)):
			value -= 1 << n
		return value

	def byte_pos(self):
		return (self.pos + 7) >> 3


def _read_rect(data, pos):
	bits = _Bits(data, pos)
	n = bits.read(5)
	xmin, xmax, ymin, ymax = (bits.read_signed(n) for _ in range(4))
	return (xmin, ymin, xmax, ymax), bits.byte_pos()


def _read_matrix(data, pos):
	"Returns (a, b, c, d, tx, ty) in twips and the position after the matrix."
	bits = _Bits(data, pos)
	a = d = 1.0
	b = c = 0.0
	if bits.read(1):
		n = bits.read(5)
		a = bits.read_signed(n) / 65536
		d = bits.read_signed(n) / 65536
	if bits.read(1):
		n = bits.read(5)
		b = bits.read_signed(n) / 65536
		c = bits.read_signed(n) / 65536
	n = bits.read(5)
	tx = bits.read_signed(n)
	ty = bits.read_signed(n)
	return (a, b, c, d, tx, ty), bits.byte_pos()


def _read_color_transform_alpha(data, pos):
	"Returns the alpha multiplier (0 to 1, or None) of a CXFORMWITHALPHA record and the position after it."
	bits = _Bits(data, pos)
	has_add = bits.read(1)
	has_mult = bits.read(1)
	n = bits.read(4)
	alpha = None
	if has_mult:
		bits.read_signed(n)
		bits.read_signed(n)
		bits.read_signed(n)
		alpha = bits.read_signed(n) / 256
	if has_add:
		bits.read(n * 4)
	return alpha, bits.byte_pos()


def _first_glow(data, pos):
	"Returns [color, blur, strength] of the first glow filter of a FILTERLIST, or None."
	count = data[pos]
	p = pos + 1
	for _ in range(count):
		kind = data[p]
		p += 1
		if kind == 2:  # GlowFilter: RGBA, blur x and y (16.16), strength (8.8), flags
			color = "#%02x%02x%02x%02x" % tuple(data[p:p + 4])
			blur = struct.unpack_from('<I', data, p + 4)[0] / 65536
			strength = struct.unpack_from('<H', data, p + 12)[0] / 256
			return [color, blur, strength]
		# Only the filters before the first glow filter need a size: drop shadow (0), blur (1), bevel (3).
		sizes = {0: 23, 1: 9, 3: 27, 6: 80}
		if kind not in sizes:
			return None
		p += sizes[kind]
	return None


def _raw_tags(data, pos, end):
	"Yields (code, start of the header, start of the content, end) of each tag."
	while pos < end:
		header = pos
		code, length = struct.unpack_from('<H', data, pos)[0] >> 6, struct.unpack_from('<H', data, pos)[0] & 0x3F
		pos += 2
		if length == 0x3F:
			length = struct.unpack_from('<I', data, pos)[0]
			pos += 4
		yield code, header, pos, pos + length
		pos += length
		if code == 0:
			return


def _tags(data, pos, end):
	while pos < end:
		header = struct.unpack_from('<H', data, pos)[0]
		pos += 2
		code, length = header >> 6, header & 0x3F
		if length == 0x3F:
			length = struct.unpack_from('<I', data, pos)[0]
			pos += 4
		yield code, pos, length
		pos += length
		if code == 0:
			return


def _transform(rect, m):
	a, b, c, d, tx, ty = m
	xs, ys = [], []
	for x, y in ((rect[0], rect[1]), (rect[2], rect[1]), (rect[0], rect[3]), (rect[2], rect[3])):
		xs.append(a * x + c * y + tx)
		ys.append(b * x + d * y + ty)
	return (min(xs), min(ys), max(xs), max(ys))


def _transform_or_none(rect, m):
	return None if rect is None else _transform(rect, m)


def _union(r1, r2):
	if r1 is None:
		return r2
	if r2 is None:
		return r1
	return (min(r1[0], r2[0]), min(r1[1], r2[1]), max(r1[2], r2[2]), max(r1[3], r2[3]))


class SwfFile:
	def __init__(self, path):
		raw = open(path, 'rb').read()
		signature = raw[:3]
		if signature == b'FWS':
			body = raw[8:]
		elif signature == b'CWS':
			body = zlib.decompress(raw[8:])
		else:
			# The game files use zlib compression only (CWS); LZMA (ZWS) is not supported.
			raise SwfError(f"{path}: not an uncompressed or zlib-compressed SWF file")
		self.data = body
		self.version = raw[3]
		_, pos = _read_rect(body, 0)
		pos += 4  # frame rate and frame count
		self._first_tag = pos
		self.bounds = {}      # character id -> rect in twips
		self.sprites = {}     # sprite id -> (start, end) of its tag list
		self.symbols = {}     # class name -> character id
		self.edit_texts = {}  # character id -> position of its DefineEditText tag
		self.fonts = {}       # font id -> font name
		self.buttons = {}     # button id -> (start, end) of its DefineButton2 tag
		self._read_definitions(pos, len(body))
		self._sprite_bounds = {}

	def _read_definitions(self, pos, end):
		data = self.data
		for code, start, length in _tags(data, pos, end):
			if code in SHAPE_TAGS or code in TEXT_TAGS or code == EDIT_TEXT_TAG:
				char_id = struct.unpack_from('<H', data, start)[0]
				self.bounds[char_id], _ = _read_rect(data, start + 2)
				if code == EDIT_TEXT_TAG:
					self.edit_texts[char_id] = start
			elif code in FONT_TAGS:
				font_id = struct.unpack_from('<H', data, start)[0]
				name_length = data[start + 4]
				self.fonts[font_id] = data[start + 5:start + 5 + name_length].rstrip(b'\0').decode('utf-8', 'replace')
			elif code in MORPH_TAGS:
				char_id = struct.unpack_from('<H', data, start)[0]
				start_rect, p = _read_rect(data, start + 2)
				end_rect, _ = _read_rect(data, p)
				self.bounds[char_id] = _union(start_rect, end_rect)
			elif code == SPRITE_TAG:
				char_id = struct.unpack_from('<H', data, start)[0]
				self.sprites[char_id] = (start + 4, start + length)
			elif code == BUTTON2_TAG:
				self.buttons[struct.unpack_from('<H', data, start)[0]] = (start, start + length)
			elif code == SYMBOL_CLASS_TAG:
				count = struct.unpack_from('<H', data, start)[0]
				p = start + 2
				for _ in range(count):
					char_id = struct.unpack_from('<H', data, p)[0]
					name_end = data.index(b'\0', p + 2)
					self.symbols[data[p + 2:name_end].decode('utf-8')] = char_id
					p = name_end + 1

	def without_placements(self, drops):
		"""Returns an uncompressed copy of the SWF file in which the sprites
		{sprite id: set of depths} no longer place anything at these depths."""
		data = self.data
		parts = []
		copied = self._first_tag
		for code, header, start, end in _raw_tags(data, self._first_tag, len(data)):
			if code != SPRITE_TAG:
				continue
			sprite_id = struct.unpack_from('<H', data, start)[0]
			if sprite_id not in drops:
				continue
			content = bytearray(data[start:start + 4])
			for inner_code, inner_header, inner_start, inner_end in _raw_tags(data, start + 4, end):
				if inner_code in PLACE_TAGS:
					depth_pos = inner_start + (2 if inner_code == 70 else 1)
					if struct.unpack_from('<H', data, depth_pos)[0] in drops[sprite_id]:
						continue
				content += data[inner_header:inner_end]
			parts.append(data[copied:header])
			parts.append(struct.pack('<HI', (SPRITE_TAG << 6) | 0x3F, len(content)) + bytes(content))
			copied = end
		body = data[:self._first_tag] + b''.join(parts) + data[copied:]
		return b'FWS' + bytes([self.version]) + struct.pack('<I', len(body) + 8) + body

	def named_child(self, sprite_id, name):
		"Returns the character id that the sprite places with the instance name in its first frame."
		for char_id, _, child_name in self._frame_places(*self.sprites[sprite_id])[0].values():
			if child_name == name:
				return char_id
		raise SwfError(f"sprite {sprite_id} has no child '{name}'")

	def edit_text(self, char_id):
		"""Returns the settings of a text field (DefineEditText): its rectangle
		[x, y, width, height] in pixels, font id and name, size in pixels, color
		"#rrggbbaa", alignment ("left", "right", "center" or "justify"), whether it
		has more lines, wraps words or reads HTML, and its initial text."""
		data = self.data
		start = self.edit_texts[char_id]
		rect, p = _read_rect(data, start + 2)
		flags1, flags2 = data[p], data[p + 1]
		p += 2
		result = {
			"rect": [rect[0] / 20, rect[1] / 20, (rect[2] - rect[0]) / 20, (rect[3] - rect[1]) / 20],
			"font_id": None, "font": None, "size": 12.0, "color": "#000000ff", "align": "left",
			"multiline": bool(flags1 & 0x20), "word_wrap": bool(flags1 & 0x40), "html": bool(flags2 & 0x02), "text": "",
		}
		if flags1 & 0x01:
			result["font_id"] = struct.unpack_from('<H', data, p)[0]
			result["font"] = self.fonts.get(result["font_id"])
			p += 2
		if flags2 & 0x80:
			p = data.index(b'\0', p) + 1
		if flags1 & 0x01:
			result["size"] = struct.unpack_from('<H', data, p)[0] / 20
			p += 2
		if flags1 & 0x04:
			result["color"] = "#%02x%02x%02x%02x" % tuple(data[p:p + 4])
			p += 4
		if flags1 & 0x02:
			p += 2
		if flags2 & 0x20:
			result["align"] = ("left", "right", "center", "justify")[min(data[p], 3)]
			p += 9
		p = data.index(b'\0', p) + 1  # variable name
		if flags1 & 0x80:
			end = data.index(b'\0', p)
			result["text"] = data[p:end].decode('utf-8', 'replace')
		return result

	def character_bounds(self, char_id):
		"Returns the bounds of a character in twips, over all frames, or None."
		if char_id in self.bounds:
			return self.bounds[char_id]
		if char_id not in self.sprites:
			return None
		if char_id not in self._sprite_bounds:
			self._sprite_bounds[char_id] = None  # stops recursion on bad files
			self._sprite_bounds[char_id] = self._compute_sprite_bounds(*self.sprites[char_id])
		return self._sprite_bounds[char_id]

	def _compute_sprite_bounds(self, pos, end):
		# The exported images cover nested sprites in all their frames.
		result = None
		for rect in self._frame_bounds(pos, end, self.character_bounds):
			result = _union(result, rect)
		return result

	def _frame_bounds(self, pos, end, nested_bounds):
		"Returns the bounds of each frame of a sprite. nested_bounds gives the bounds of a placed character."
		frames = []
		for places in self._frame_places(pos, end):
			rect = None
			for char_id, matrix, _ in places.values():
				rect = _union(rect, _transform_or_none(nested_bounds(char_id), matrix))
			frames.append(rect)
		return frames

	def _frame_places(self, pos, end, details=None, frame_alphas=None):
		"""Returns for each frame of a sprite {depth: (character id, matrix, instance name or None)} of the placed characters.

		details, a dict, receives for each depth of the last frame the other
		settings of the placement: "alpha" (0 to 1), "clip_depth" (a mask covers
		the depths up to it) and "glow" ([color "#rrggbbaa", blur, strength] of
		the first glow filter). frame_alphas, a list, receives for each frame
		{depth: alpha} of the placements with an alpha."""
		data = self.data
		depth_char = {}
		depth_matrix = {}
		depth_name = {}
		depth_alpha = {}
		frames = []
		for code, start, length in _tags(data, pos, end):
			if code == SHOW_FRAME_TAG:
				frames.append({depth: (char_id, depth_matrix[depth], depth_name.get(depth)) for depth, char_id in depth_char.items()})
				if frame_alphas is not None:
					frame_alphas.append({depth: alpha for depth, alpha in depth_alpha.items() if depth in depth_char})
				continue
			if code == REMOVE_OBJECT2_TAG:
				depth = struct.unpack_from('<H', data, start)[0]
				depth_char.pop(depth, None)
				depth_name.pop(depth, None)
				depth_alpha.pop(depth, None)
				continue
			if code not in PLACE_TAGS:
				continue
			flags = data[start]
			flags3 = 0
			p = start + 1
			if code == 70:
				flags3 = data[p]
				p += 1
			depth = struct.unpack_from('<H', data, p)[0]
			p += 2
			# The SWF specification also names (HasImage and HasCharacter) as a
			# condition for the class name; the Flash tools write HasImage
			# without a class name, so only HasClassName counts.
			if code == 70 and flags3 & 0x08:
				p = data.index(b'\0', p) + 1
			if flags & 0x02:
				depth_char[depth] = struct.unpack_from('<H', data, p)[0]
				p += 2
				depth_matrix[depth] = (1.0, 0.0, 0.0, 1.0, 0, 0)
				depth_name.pop(depth, None)
				if not flags & 0x01:  # a new character, not a move
					depth_alpha.pop(depth, None)
			if flags & 0x04:
				depth_matrix[depth], p = _read_matrix(data, p)
			alpha = None
			if flags & 0x08:
				alpha, p = _read_color_transform_alpha(data, p)
				if alpha is not None:
					depth_alpha[depth] = alpha
			if flags & 0x10:
				p += 2  # ratio
			if flags & 0x20:
				name_end = data.index(b'\0', p)
				depth_name[depth] = data[p:name_end].decode('utf-8', 'replace')
				p = name_end + 1
			clip_depth = None
			if flags & 0x40:
				clip_depth = struct.unpack_from('<H', data, p)[0]
				p += 2
			if details is not None:
				entry = details.setdefault(depth, {})
				if alpha is not None:
					entry["alpha"] = alpha
				if clip_depth is not None:
					entry["clip_depth"] = clip_depth
				if flags3 & 0x01:
					glow = _first_glow(data, p)
					if glow is not None:
						entry["glow"] = glow
		return frames

	def _symbol_sprite(self, class_name):
		if class_name not in self.symbols:
			raise SwfError(f"symbol '{class_name}' is not exported")
		char_id = self.symbols[class_name]
		if char_id not in self.sprites:
			raise SwfError(f"symbol '{class_name}' is not a sprite")
		return char_id

	def symbol_frame_labels(self, class_name):
		"Returns the frame labels of the symbol: label -> frame number (1-based)."
		return self.sprite_frame_labels(self._symbol_sprite(class_name))

	def sprite_frame_labels(self, sprite_id):
		"Returns the frame labels of a sprite: label -> frame number (1-based)."
		labels = {}
		frame = 1
		for code, start, _ in _tags(self.data, *self.sprites[sprite_id]):
			if code == FRAME_LABEL_TAG:
				labels[self.data[start:self.data.index(b'\0', start)].decode('utf-8')] = frame
			elif code == SHOW_FRAME_TAG:
				frame += 1
		return labels
