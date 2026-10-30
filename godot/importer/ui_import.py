"""Imports the windows of the client that the port shows with the original graphics.

A window of the client is a symbol of the client SWF file. Its parts with an
instance name (buttons, stars, locks, text fields) change at run time, so the
port must place them itself. For each sprite of a window this module writes:

  <out>/ui/clips/<id>/<n>.png   frame n of the sprite without its named parts and text fields
  <out>/ui/layout.json          {"symbols": {name: sprite id},
                                 "clips": {id: {"origin": [x, y] or null, "frames": [[part, ...] for each frame]}}}
  <out>/ui/fonts/<font id>.ttf  the fonts of the text fields
  <out>/ui/images/<name>        pictures that the windows load from assets/images_new
  <out>/ui/thumbs/<img_name>.jpg  small pictures of the units, for the units lost in a quest

A part is {"name", "depth", "matrix": [a, b, c, d, x, y], and "clip": id (a
sprite) or "text": settings (see SwfFile.edit_text)}, with "alpha", "glow" or
"mask" when the placement has them. Unnamed text fields are parts too, so
that the port draws their text with the font.
"""

import json
import os
import shutil
import subprocess
import tempfile

from jpexs import copy_frames, exported_frames, run_jpexs
from swf_bounds import SwfFile

CLIENT_SWF = os.path.join("assets", "flash", "SocialEmpires1.4.07sec_fixed.swf")
# Windows of the quests, and parts of the screen of the client ("GuiMC/..."
# names a child of a symbol by its instance names).
SYMBOLS = [
	"PopupQuestsManagerMC",
	"NewQuestIslandButtonMC",
	"PopupLoadingQuestMC",
	"PopupQuestFinishedMC",
	"GuiMC/barraAttackArriba",
	"GuiMC/bgBar/btnExit",
	"PopupAlertMC",
	"PortraitAssaultMC",
]
# The island window shows 7 pictures side by side; the start and end windows
# show a picture for the kind of quest and for the result.
IMAGES = [f"quests_manager_img_{n}.jpg" for n in range(1, 8)] + ["TESORO.jpg", "ataque_ganado.jpg", "ataque_perdido.jpg", "pop_up5_sueno2.jpg"]


def import_ui(jpexs, source, out_dir, unit_thumbs):
	"""unit_thumbs: the file names "<img_name>.jpg" of the units whose
	pictures the windows can show. Returns the number of imported sprites."""
	swf_path = os.path.join(source, CLIENT_SWF)
	swf = SwfFile(swf_path)
	ui_dir = os.path.join(out_dir, "ui")
	symbols = {name: _resolve(swf, name) for name in SYMBOLS}
	clips = {}
	drops = {}
	for sprite_id in symbols.values():
		_collect(swf, sprite_id, clips, drops)

	with tempfile.TemporaryDirectory() as work_dir:
		base_path = os.path.join(work_dir, "bases.swf")
		with open(base_path, 'wb') as f:
			f.write(swf.without_placements(drops))
		bases = SwfFile(base_path)
		drawn = sorted(sprite_id for sprite_id in clips if bases.character_bounds(sprite_id) is not None)
		run_jpexs(jpexs, base_path, ["-selectid", ",".join(map(str, drawn))], work_dir)
		for sprite_id in drawn:
			name = f"DefineSprite_{sprite_id}"
			frames = exported_frames(work_dir, lambda d: d == name or d.startswith(name + "_"), f"sprite {sprite_id} of {swf_path}")
			copy_frames(frames, os.path.join(ui_dir, "clips", str(sprite_id)))
			clips[sprite_id]["origin"] = list(bases.sprite_offset(sprite_id))

	font_ids = sorted({part["text"]["font_id"] for clip in clips.values() for frame in clip["frames"] for part in frame if "text" in part and part["text"]["font_id"] is not None})
	_export_fonts(jpexs, swf_path, font_ids, os.path.join(ui_dir, "fonts"))

	os.makedirs(os.path.join(ui_dir, "images"), exist_ok=True)
	for image in IMAGES:
		shutil.copyfile(os.path.join(source, "assets", "images_new", image), os.path.join(ui_dir, "images", image))
	os.makedirs(os.path.join(ui_dir, "thumbs"), exist_ok=True)
	for thumb in unit_thumbs:
		path = os.path.join(source, "assets", "buildingthumbs", thumb)
		if os.path.exists(path):
			shutil.copyfile(path, os.path.join(ui_dir, "thumbs", thumb))
	with open(os.path.join(ui_dir, "layout.json"), 'w', encoding='utf-8') as f:
		json.dump({"symbols": symbols, "clips": {str(k): v for k, v in clips.items()}}, f, indent='\t')
	return len(clips)


def _resolve(swf, name):
	"Returns the sprite id of a symbol, or of a child named by a path such as GuiMC/bgBar/btnExit."
	parts = name.split("/")
	sprite_id = swf.symbols[parts[0]]
	for child in parts[1:]:
		sprite_id = swf.named_child(sprite_id, child)
	return sprite_id


def _collect(swf, sprite_id, clips, drops):
	"""Adds the sprite and its named sprites to clips. drops gets the depths
	that the base images leave out: named parts and text fields."""
	if sprite_id in clips:
		return
	details = {}
	places = swf._frame_places(*swf.sprites[sprite_id], details=details)
	clip = {"origin": None, "frames": []}
	clips[sprite_id] = clip
	dropped = set()
	nested = []
	for frame in places:
		parts = []
		for depth in sorted(frame):
			char_id, matrix, name = frame[depth]
			part = {"name": name, "depth": depth, "matrix": [*matrix[:4], matrix[4] / 20, matrix[5] / 20]}
			extra = details.get(depth, {})
			if "alpha" in extra:
				part["alpha"] = extra["alpha"]
			if "glow" in extra:
				part["glow"] = extra["glow"]
			if "clip_depth" in extra:
				part["mask"] = True
			if char_id in swf.edit_texts:
				part["text"] = swf.edit_text(char_id)
			elif name is not None and char_id in swf.sprites:
				part["clip"] = char_id
				nested.append(char_id)
			else:
				continue
			dropped.add(depth)
			parts.append(part)
		clip["frames"].append(parts)
	if dropped:
		drops[sprite_id] = dropped
	for child_id in nested:
		_collect(swf, child_id, clips, drops)


def _export_fonts(jpexs, swf_path, font_ids, fonts_dir):
	if not font_ids:
		return
	os.makedirs(fonts_dir, exist_ok=True)
	with tempfile.TemporaryDirectory() as work_dir:
		command = ["java", "-jar", jpexs] if jpexs.endswith(".jar") else [jpexs]
		command += ["-selectid", ",".join(map(str, font_ids)), "-format", "font:ttf", "-export", "font", work_dir, swf_path]
		result = subprocess.run(command, capture_output=True, text=True)
		if result.returncode != 0:
			raise RuntimeError(f"JPEXS failed to export the fonts of {swf_path}: {result.stdout[-500:]}{result.stderr[-500:]}")
		for file_name in os.listdir(work_dir):
			font_id = file_name.split("_", 1)[0]
			if file_name.endswith(".ttf") and font_id.isdigit():
				shutil.copyfile(os.path.join(work_dir, file_name), os.path.join(fonts_dir, f"{font_id}.ttf"))
