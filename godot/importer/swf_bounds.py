"""Reads the bounds of exported symbols in a SWF file.

An exported PNG of a symbol loses the symbol's registration point. The game
places the registration point on the map, so the importer needs the offset
from the registration point to the top-left corner of the image. This module
computes that offset from the shape bounds and placement matrices in the SWF.
"""

import struct
import zlib

SHAPE_TAGS = {2, 22, 32, 83}          # DefineShape, DefineShape2, 3, 4
MORPH_TAGS = {46, 84}                 # DefineMorphShape, DefineMorphShape2
TEXT_TAGS = {11, 33}                  # DefineText, DefineText2
EDIT_TEXT_TAG = 37
FONT_TAGS = {48, 75}                  # DefineFont2, DefineFont3
SPRITE_TAG = 39
PLACE_TAGS = {26, 70}                 # PlaceObject2, PlaceObject3
SYMBOL_CLASS_TAG = 76
SHOW_FRAME_TAG = 1
REMOVE_OBJECT2_TAG = 28
# Names of the point in a graphic where the shots of the client start. The
# client looks for the first name; for some shots it also accepts the second.
SHOT_POINT_NAMES = ('proyectilePoint', 'projectilePoint')


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


def _skip_color_transform(data, pos):
	"Returns the position after a CXFORMWITHALPHA record."
	bits = _Bits(data, pos)
	has_add = bits.read(1)
	has_mult = bits.read(1)
	n = bits.read(4)
	bits.read(n * 4 * (has_add + has_mult))
	return bits.byte_pos()


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
		self._read_definitions(pos, len(body))
		self._sprite_bounds = {}
		self._sprite_first_frame_bounds = {}

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

	def _frame_places(self, pos, end, details=None):
		"""Returns for each frame of a sprite {depth: (character id, matrix, instance name or None)} of the placed characters.

		details, a dict, receives for each depth of the last frame the other
		settings of the placement: "alpha" (0 to 1), "clip_depth" (a mask covers
		the depths up to it) and "glow" ([color "#rrggbbaa", blur, strength] of
		the first glow filter)."""
		data = self.data
		depth_char = {}
		depth_matrix = {}
		depth_name = {}
		frames = []
		for code, start, length in _tags(data, pos, end):
			if code == SHOW_FRAME_TAG:
				frames.append({depth: (char_id, depth_matrix[depth], depth_name.get(depth)) for depth, char_id in depth_char.items()})
				continue
			if code == REMOVE_OBJECT2_TAG:
				depth = struct.unpack_from('<H', data, start)[0]
				depth_char.pop(depth, None)
				depth_name.pop(depth, None)
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
			if flags & 0x04:
				depth_matrix[depth], p = _read_matrix(data, p)
			alpha = None
			if flags & 0x08:
				alpha, p = _read_color_transform_alpha(data, p)
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

	def _first_frame_bounds(self, char_id):
		if char_id not in self.sprites:
			return self.bounds.get(char_id)
		if char_id not in self._sprite_first_frame_bounds:
			self._sprite_first_frame_bounds[char_id] = None  # stops recursion on bad files
			frames = self._frame_bounds(*self.sprites[char_id], self._first_frame_bounds)
			self._sprite_first_frame_bounds[char_id] = frames[0] if frames else None
		return self._sprite_first_frame_bounds[char_id]

	def _symbol_sprite(self, class_name):
		if class_name not in self.symbols:
			raise SwfError(f"symbol '{class_name}' is not exported")
		char_id = self.symbols[class_name]
		if char_id not in self.sprites:
			raise SwfError(f"symbol '{class_name}' is not a sprite")
		return char_id

	def symbol_frame_rects(self, class_name):
		"""Returns (x, y, width, height) in pixels of each frame of the symbol, as Flash reports them:
		the bounds relative to the registration point.

		The client stops nested sprites on their first frame, so they count with that frame.
		"""
		rects = []
		for rect in self._frame_bounds(*self.sprites[self._symbol_sprite(class_name)], self._first_frame_bounds):
			rects.append((0.0, 0.0, 0.0, 0.0) if rect is None else (rect[0] / 20, rect[1] / 20, (rect[2] - rect[0]) / 20, (rect[3] - rect[1]) / 20))
		return rects

	def symbol_shot_points(self, class_name):
		"""Returns for each frame of the symbol the point (x, y) in pixels where its shots start, or None.

		The client looks for the point in the first child of the frame, a sprite.
		The point can be in any frame of that sprite; this takes the first frame
		that has it.
		"""
		points = []
		for places in self._frame_places(*self.sprites[self._symbol_sprite(class_name)]):
			point = None
			if places:
				char_id, matrix, _ = places[min(places)]
				if char_id in self.sprites:
					point = self._named_point(char_id, matrix)
			points.append(point)
		return points

	def _named_point(self, sprite_id, matrix):
		found = {}
		for places in self._frame_places(*self.sprites[sprite_id]):
			for _, point_matrix, name in places.values():
				if name in SHOT_POINT_NAMES and name not in found:
					found[name] = point_matrix
		for name in SHOT_POINT_NAMES:
			if name in found:
				a, b, c, d, tx, ty = matrix
				x, y = found[name][4], found[name][5]
				return ((a * x + c * y + tx) / 20, (b * x + d * y + ty) / 20)
		return None

	def symbol_offset(self, class_name):
		"Returns the top-left corner of the symbol's bounds in pixels, relative to its registration point."
		if class_name not in self.symbols:
			raise SwfError(f"symbol '{class_name}' is not exported")
		rect = self.character_bounds(self.symbols[class_name])
		if rect is None:
			raise SwfError(f"symbol '{class_name}' has no visible content")
		return rect[0] / 20, rect[1] / 20, (rect[2] - rect[0]) / 20, (rect[3] - rect[1]) / 20

	def symbol_frame_clips(self, class_name):
		"""Returns for each frame of the symbol (character id, matrix) of its clip, or None.

		A clip is a nested sprite with more than one frame. A frame of a unit graphic shows one nested sprite, the clip, which plays
		its own frames: for example the walk in one direction. The client shows
		only the first frame of nested sprites in buildings, but units play them.
		"""
		char_id = self.symbols[class_name]
		result = []
		for places in self._frame_places(*self.sprites[char_id]):
			clips = list(places.values())
			if len(clips) == 1 and clips[0][0] in self.sprites and len(self._frame_places(*self.sprites[clips[0][0]])) > 1:
				result.append(clips[0][:2])
			else:
				result.append(None)
		return result

	def sprite_offset(self, char_id):
		"Returns the top-left corner of a sprite's bounds in pixels, relative to its registration point."
		rect = self.character_bounds(char_id)
		if rect is None:
			raise SwfError(f"sprite {char_id} has no visible content")
		return rect[0] / 20, rect[1] / 20
