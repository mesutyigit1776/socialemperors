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
SPRITE_TAG = 39
PLACE_TAGS = {26, 70}                 # PlaceObject2, PlaceObject3
SYMBOL_CLASS_TAG = 76
SHOW_FRAME_TAG = 1
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
		_, pos = _read_rect(body, 0)
		pos += 4  # frame rate and frame count
		self.bounds = {}      # character id -> rect in twips
		self.sprites = {}     # sprite id -> (start, end) of its tag list
		self.symbols = {}     # class name -> character id
		self._read_definitions(pos, len(body))
		self._sprite_bounds = {}
		self._sprite_first_frame_bounds = {}

	def _read_definitions(self, pos, end):
		data = self.data
		for code, start, length in _tags(data, pos, end):
			if code in SHAPE_TAGS or code in TEXT_TAGS or code == EDIT_TEXT_TAG:
				char_id = struct.unpack_from('<H', data, start)[0]
				self.bounds[char_id], _ = _read_rect(data, start + 2)
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
			for char_id, matrix in places.values():
				rect = _union(rect, _transform_or_none(nested_bounds(char_id), matrix))
			frames.append(rect)
		return frames

	def _frame_places(self, pos, end):
		"Returns for each frame of a sprite {depth: (character id, matrix)} of the placed characters."
		data = self.data
		depth_char = {}
		depth_matrix = {}
		frames = []
		for code, start, length in _tags(data, pos, end):
			if code == SHOW_FRAME_TAG:
				frames.append({depth: (char_id, depth_matrix[depth]) for depth, char_id in depth_char.items()})
				continue
			if code == REMOVE_OBJECT2_TAG:
				depth = struct.unpack_from('<H', data, start)[0]
				depth_char.pop(depth, None)
				continue
			if code not in PLACE_TAGS:
				continue
			flags = data[start]
			p = start + 1
			if code == 70:
				flags3 = data[p]
				p += 1
			depth = struct.unpack_from('<H', data, p)[0]
			p += 2
			if code == 70 and (flags3 & 0x08 or (flags3 & 0x10 and flags & 0x02)):
				p = data.index(b'\0', p) + 1  # PlaceObject3 class name
			if flags & 0x02:
				depth_char[depth] = struct.unpack_from('<H', data, p)[0]
				p += 2
				depth_matrix[depth] = (1.0, 0.0, 0.0, 1.0, 0, 0)
			if flags & 0x04:
				depth_matrix[depth], p = _read_matrix(data, p)
		return frames

	def _first_frame_bounds(self, char_id):
		if char_id not in self.sprites:
			return self.bounds.get(char_id)
		if char_id not in self._sprite_first_frame_bounds:
			self._sprite_first_frame_bounds[char_id] = None  # stops recursion on bad files
			frames = self._frame_bounds(*self.sprites[char_id], self._first_frame_bounds)
			self._sprite_first_frame_bounds[char_id] = frames[0] if frames else None
		return self._sprite_first_frame_bounds[char_id]

	def symbol_frame_sizes(self, class_name):
		"""Returns (width, height) in pixels of each frame of the symbol, as Flash reports them.

		The client stops nested sprites on their first frame, so they count with that frame.
		"""
		if class_name not in self.symbols:
			raise SwfError(f"symbol '{class_name}' is not exported")
		char_id = self.symbols[class_name]
		if char_id not in self.sprites:
			raise SwfError(f"symbol '{class_name}' is not a sprite")
		sizes = []
		for rect in self._frame_bounds(*self.sprites[char_id], self._first_frame_bounds):
			sizes.append((0.0, 0.0) if rect is None else ((rect[2] - rect[0]) / 20, (rect[3] - rect[1]) / 20))
		return sizes

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
				result.append(clips[0])
			else:
				result.append(None)
		return result

	def sprite_offset(self, char_id):
		"Returns the top-left corner of a sprite's bounds in pixels, relative to its registration point."
		rect = self.character_bounds(char_id)
		if rect is None:
			raise SwfError(f"sprite {char_id} has no visible content")
		return rect[0] / 20, rect[1] / 20
