"""Imports the windows of the client that the port shows with the original graphics.

A window of the client is a symbol of the client SWF file. Its parts with an
instance name (buttons, stars, locks, text fields) change at run time, so the
port must place them itself. For each sprite of a window this module writes:

  <out>/ui/clips/<id>/<n>.png   frame n of the sprite without its named parts and text fields
  <out>/ui/buttons/<id>/<state>.png  the states up, over and down of a named button
  <out>/ui/layout.json          {"symbols": {name: sprite id},
                                 "clips": {id: {"origin": [x, y] or null, "frames": [[part, ...] for each frame],
                                                "labels": {label: frame (0-based)}}},
                                 "buttons": {id: {"origin": [x, y]}}}
  <out>/ui/fonts/<font id>.ttf  the fonts of the text fields
  <out>/ui/images/<name>        pictures that the windows load from assets/images_new
  <out>/ui/thumbs/<img_name>.jpg  small pictures of the units, for the units lost in a quest
  <out>/ui/cast/...             the banner of a cast spell, from its own SWF file, in the same form

A part is {"name", "depth", "matrix": [a, b, c, d, x, y], and "clip": id (a
sprite), "button": id (a button) or "text": settings (see SwfFile.edit_text)},
with "alpha", "glow" or "mask" when the placement has them. Unnamed text
fields are parts too, so that the port draws their text with the font.
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
	"PopUpAlertaMC",
	"PortraitAssaultMC",
	# The spell book, its window, the window that sells mana, and the marker of the area of a spell.
	"PopupMagicMC",
	"SpellButtonMC",
	"InfoPopupManaMc",
	"PopupWizardryMC",
	"MagicentryMC",
	"SelectedMagicMC",
	"PopupBuyManaMC",
	"AOEMC",
]
# The island window shows 7 pictures side by side; the start and end windows
# show a picture for the kind of quest and for the result. The spell windows
# show a book and a wizard; the pictures of the spells come with spell_images.
# The alert with a picture tells the player about the spell book.
IMAGES = [f"quests_manager_img_{n}.jpg" for n in range(1, 8)] + ["TESORO.jpg", "ataque_ganado.jpg", "ataque_perdido.jpg", "pop_up5_sueno2.jpg", "llibre.png", "mago_altar.png", "alert_magic.jpg"]
# The banner that shows the name of a cast spell.
CAST_SWF = os.path.join("assets", "buildingsprites", "magic_cast_marquee.swf")
CAST_SYMBOLS = ["magic_cast"]


def import_ui(jpexs, source, out_dir, unit_thumbs, spell_images):
	"""unit_thumbs: the file names "<img_name>.jpg" of the units whose
	pictures the windows can show. spell_images: the pictures of the spells
	("<img_name>.jpg" and "prev_<img_name>.jpg"). Returns the number of
	imported sprites."""
	ui_dir = os.path.join(out_dir, "ui")
	count = _import_windows(jpexs, os.path.join(source, CLIENT_SWF), SYMBOLS, ui_dir)
	count += _import_windows(jpexs, os.path.join(source, CAST_SWF), CAST_SYMBOLS, os.path.join(ui_dir, "cast"))
	os.makedirs(os.path.join(ui_dir, "images"), exist_ok=True)
	for image in IMAGES + spell_images:
		shutil.copyfile(os.path.join(source, "assets", "images_new", image), os.path.join(ui_dir, "images", image))
	os.makedirs(os.path.join(ui_dir, "thumbs"), exist_ok=True)
	for thumb in unit_thumbs:
		path = os.path.join(source, "assets", "buildingthumbs", thumb)
		if os.path.exists(path):
			shutil.copyfile(path, os.path.join(ui_dir, "thumbs", thumb))
	return count


def _import_windows(jpexs, swf_path, symbol_names, ui_dir):
	"Writes the clips, buttons, fonts and layout.json of the symbols of one SWF file to ui_dir."
	swf = SwfFile(swf_path)
	symbols = {name: _resolve(swf, name) for name in symbol_names}
	clips = {}
	drops = {}
	buttons = {}
	for sprite_id in symbols.values():
		_collect(swf, sprite_id, clips, drops, buttons)

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

	if buttons:
		_export_buttons(jpexs, swf_path, sorted(buttons), os.path.join(ui_dir, "buttons"))
		for button_id in buttons:
			buttons[button_id]["origin"] = list(swf.button_offset(button_id))

	font_ids = sorted({part["text"]["font_id"] for clip in clips.values() for frame in clip["frames"] for part in frame if "text" in part and part["text"]["font_id"] is not None})
	_export_fonts(jpexs, swf_path, font_ids, os.path.join(ui_dir, "fonts"))
	with open(os.path.join(ui_dir, "layout.json"), 'w', encoding='utf-8') as f:
		json.dump({"symbols": symbols, "clips": {str(k): v for k, v in clips.items()}, "buttons": {str(k): v for k, v in buttons.items()}}, f, indent='\t')
	return len(clips) + len(buttons)


def _resolve(swf, name):
	"Returns the sprite id of a symbol, or of a child named by a path such as GuiMC/bgBar/btnExit."
	parts = name.split("/")
	sprite_id = swf.symbols[parts[0]]
	for child in parts[1:]:
		sprite_id = swf.named_child(sprite_id, child)
	return sprite_id


def _collect(swf, sprite_id, clips, drops, buttons):
	"""Adds the sprite and its named sprites to clips, and its named buttons to
	buttons. drops gets the depths that the base images leave out: named parts
	and text fields."""
	if sprite_id in clips:
		return
	details = {}
	alphas = []
	places = swf._frame_places(*swf.sprites[sprite_id], details=details, frame_alphas=alphas)
	clip = {"origin": None, "frames": []}
	# Labels are 1-based frame numbers in the SWF file; the layout counts from 0.
	labels = {label: frame - 1 for label, frame in swf.sprite_frame_labels(sprite_id).items()}
	if labels:
		clip["labels"] = labels
	clips[sprite_id] = clip
	dropped = set()
	nested = []
	for frame, frame_alpha in zip(places, alphas):
		parts = []
		for depth in sorted(frame):
			char_id, matrix, name = frame[depth]
			part = {"name": name, "depth": depth, "matrix": [*matrix[:4], matrix[4] / 20, matrix[5] / 20]}
			extra = details.get(depth, {})
			if depth in frame_alpha:
				part["alpha"] = frame_alpha[depth]
			if "glow" in extra:
				part["glow"] = extra["glow"]
			if "clip_depth" in extra:
				part["mask"] = True
			if char_id in swf.edit_texts:
				part["text"] = swf.edit_text(char_id)
			elif name is not None and char_id in swf.sprites:
				part["clip"] = char_id
				nested.append(char_id)
			elif name is not None and char_id in swf.buttons:
				part["button"] = char_id
				buttons[char_id] = {"origin": None}
			else:
				continue
			dropped.add(depth)
			parts.append(part)
		clip["frames"].append(parts)
	if dropped:
		drops[sprite_id] = dropped
	for child_id in nested:
		_collect(swf, child_id, clips, drops, buttons)


def _export_buttons(jpexs, swf_path, button_ids, buttons_dir):
	"JPEXS writes the states of a button to DefineButton2_<id>_.../<n>_<state>.png."
	with tempfile.TemporaryDirectory() as work_dir:
		command = ["java", "-jar", jpexs] if jpexs.endswith(".jar") else [jpexs]
		command += ["-selectid", ",".join(map(str, button_ids)), "-format", "button:png", "-export", "button", work_dir, swf_path]
		result = subprocess.run(command, capture_output=True, text=True)
		if result.returncode != 0:
			raise RuntimeError(f"JPEXS failed to export the buttons of {swf_path}: {result.stdout[-500:]}{result.stderr[-500:]}")
		for button_id in button_ids:
			folders = [name for name in os.listdir(work_dir) if name == f"DefineButton2_{button_id}" or name.startswith(f"DefineButton2_{button_id}_")]
			if not folders:
				raise RuntimeError(f"JPEXS did not export button {button_id} of {swf_path}")
			target = os.path.join(buttons_dir, str(button_id))
			os.makedirs(target, exist_ok=True)
			for number, state in ((1, "up"), (2, "over"), (3, "down")):
				shutil.copyfile(os.path.join(work_dir, folders[0], f"{number}_{state}.png"), os.path.join(target, f"{state}.png"))


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
