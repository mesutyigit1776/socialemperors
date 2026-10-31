"""Packs the frames of a graphic into sprite sheets: lossless WebP pictures
with the frames side by side, as modern 2D games keep their art.

Each frame is cropped to the pixels that are not fully transparent, with
a border of one transparent pixel. Frames
with the same pixels are kept one time. The pixels do not change.

For each frame, the importer writes an entry
[sheet, x, y, width, height, left, top, frame width, frame height]:
the frame is the rectangle (x, y, width, height) on sheet number "sheet",
and this rectangle was at (left, top) in the full frame of the given size.
"""

import hashlib
import os

from PIL import Image

# Most graphics cards accept textures of 8192 pixels on each side.
MAX_SHEET_SIDE = 8192
# Space between the frames, so that the graphics card does not mix the pixels of two frames.
PADDING = 1
# WebP lossless: 0 is the fastest, 6 the smallest. On the frames of a large
# unit, 0 was 4 times faster than 4 and gave the same size.
WEBP_METHOD = 0


def pack_frames(frame_paths, out_dir):
	"""Writes the sheets <out_dir>/<n>.webp (from 0) for the PNG frames in
	frame_paths and returns one entry for each frame, see the module text."""
	crops = []
	entries = []
	known = {}
	for path in frame_paths:
		with Image.open(path) as image:
			image = image.convert("RGBA")
		full_width, full_height = image.size
		box = _crop_box(image)
		crop = image.crop(box)
		key = hashlib.sha256(crop.tobytes() + repr(crop.size).encode()).digest()
		if key not in known:
			known[key] = len(crops)
			crops.append(crop)
		entries.append([known[key], box[0], box[1], full_width, full_height])
	places = _place(crops)
	os.makedirs(out_dir, exist_ok=True)
	for sheet_index in range(max(place[0] for place in places) + 1):
		members = [i for i, place in enumerate(places) if place[0] == sheet_index]
		width = max(places[i][1] + crops[i].width for i in members)
		height = max(places[i][2] + crops[i].height for i in members)
		sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
		for i in members:
			sheet.paste(crops[i], places[i][1:])
		sheet.save(os.path.join(out_dir, f"{sheet_index}.webp"), "WEBP", lossless=True, method=WEBP_METHOD, exact=True)
	result = []
	for crop_index, left, top, full_width, full_height in entries:
		sheet_index, x, y = places[crop_index]
		crop = crops[crop_index]
		result.append([sheet_index, x, y, crop.width, crop.height, left, top, full_width, full_height])
	return result


def _crop_box(image):
	"""The pixels that are not fully transparent, and one transparent pixel
	around them where the frame has it. A frame between two screen pixels mixes
	its edge with this border, as the full frame does. An empty frame keeps
	one transparent pixel."""
	box = image.getbbox()
	if box is None:
		return (0, 0, 1, 1)
	return (max(box[0] - 1, 0), max(box[1] - 1, 0), min(box[2] + 1, image.width), min(box[3] + 1, image.height))


def _place(crops):
	"""Returns (sheet, x, y) for each crop. Shelf packing: the crops go from the
	highest to the lowest into rows, and a row that is full starts the next one."""
	order = sorted(range(len(crops)), key=lambda i: (-crops[i].height, -crops[i].width))
	area = sum((crop.width + PADDING) * (crop.height + PADDING) for crop in crops)
	widest = max(crop.width for crop in crops) + PADDING
	row_width = min(MAX_SHEET_SIDE, max(widest, int(area ** 0.5 * 1.1)))
	places = [None] * len(crops)
	sheet = x = y = row_height = 0
	for i in order:
		crop = crops[i]
		if crop.width + PADDING > MAX_SHEET_SIDE or crop.height + PADDING > MAX_SHEET_SIDE:
			raise RuntimeError(f"a frame of {crop.width} x {crop.height} pixels is larger than a sheet")
		if x + crop.width + PADDING > row_width:
			x, y, row_height = 0, y + row_height, 0
		if y + crop.height + PADDING > MAX_SHEET_SIDE:
			sheet, x, y, row_height = sheet + 1, 0, 0, 0
		places[i] = (sheet, x, y)
		x += crop.width + PADDING
		row_height = max(row_height, crop.height + PADDING)
	return places
