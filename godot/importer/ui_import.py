"""Imports the windows of the client that the port shows with the original graphics.

A window of the client is a symbol of the client SWF file. Its parts with an
instance name (buttons, stars, locks, text fields) change at run time, so the
port must place them itself. This module writes:

  <out>/ui/windows.swf          a copy of the SWF file in which the sprites of the windows do not
                                place their named parts and text fields; the port draws the
                                frames of the sprites, the named buttons and the fonts from it
  <out>/ui/layout.json          {"symbols": {name: sprite id}, "fonts": {font name: font id},
                                 "clips": {id: {"origin": [x, y] or null, "frames": [[part, ...] for each frame],
                                                "labels": {label: frame (0-based)}}},
                                 "buttons": {id: {}}}
                                "origin" is the corner of the bounds of the sprite without its
                                parts, or null when it draws nothing besides them.
  <out>/ui/images/<name>        pictures that the windows load from assets/images_new
  <out>/ui/thumbs/<img_name>.jpg  small pictures of the units, for the units lost in a quest
  <out>/ui/cast/...             the banner of a cast spell, from its own SWF file, in the same form

A part is {"name", "depth", "matrix": [a, b, c, d, x, y], and "clip": id (a
sprite), "button": id (a button) or "text": settings (see SwfFile.edit_text)},
with "alpha", "glow" or "mask" when the placement has them. Unnamed text
fields are parts too, so that the port draws their text with the font, and
unnamed buttons, which the drawing of a sprite leaves out.
"""

import json
import os
import shutil

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
	# The window in which the player chooses the team for an island with teams.
	"SelectionTeamWindowMC",
	# The alert of the team window (Alert of the client).
	"AlertTournamentMC",
	# Survival: the window of the maps, a map in it, the reward of a time, the
	# window before the start and the result window.
	"PopupSurvivalMC",
	"SurvivalMapMC",
	"SurvivalMinRewardMc",
	"PopupLoadingSurvivalMC",
	"PopupSurvivalResultsMC",
	# Tournament: the window before a match and the window of its result.
	"PopupLoadingTournamentMC",
	"PopupTournamentFinishedMC",
	# The village screen: the HUD with its menus, the store with its tabs,
	# item buttons and subcategories, the panels of a selected item
	# (RecuadroInfoNew), the goal box, the neighbour bar and the zoom slider.
	"GuiMC",
	"StoreMC",
	"TabMC",
	"MenuTabMC",
	"BuildButtonLargeMC",
	"PastillaSubcategoriaMC",
	"EP_House_MC",
	"EP_Farm_MC",
	"EP_NewBarracksMC",
	"EP_Market_MC",
	"EP_UnitMC",
	"popUpMissionsMC",
	"NewGoalMC",
	"MenuTabFriendsMC",
	"FriendButtonMC",
	"PopOverVisitMC",
	"ZoomSliderMC",
	# Windows of the village: the goal list, the tutorial, the confirm window,
	# the town window and the window of a quest in the town.
	"PopupGoalListMC",
	"GoalListLineMC",
	"TutorialPopupMC",
	"PopupConfirmMC",
	"PopupRaceSelectorMC",
	"PopupQuestInfo2MC",
	# The pause of the options panel: the dark curtain and the window over it.
	"GamePausedMC",
	"CortinaMC",
]
# The island window shows 7 pictures side by side; the start and end windows
# show a picture for the kind of quest and for the result. The spell windows
# show a book and a wizard; the pictures of the spells come with spell_images.
# The alert with a picture tells the player about the spell book. The
# neighbour bar shows the host of the tutorial with the picture of the king,
# and the town window a picture of each town.
IMAGES = [f"quests_manager_img_{n}.jpg" for n in range(1, 8)] + ["TESORO.jpg", "COLLECT_GEMS.jpg", "pop_up_nieve.jpg", "rockdriller_start.jpg", "boss2_ini.jpg", "ataque_ganado.jpg", "ataque_perdido.jpg", "pop_up5_sueno2.jpg", "llibre.png", "mago_altar.png", "alert_magic.jpg"] \
	+ ["SURVIVAL_DESIERTO.jpg", "SURVIVAL_MINERAL.jpg", "SURVIVAL_NUBES.jpg", "SURVIVAL_NIEVE.jpg", "SURVIVAL_SELVA.jpg", "aldeana-regalos.png"] \
	+ ["tournament_weekly_gold.jpg", "weekly_tournament_bot1.png", "weekly_tournament_bot2.png", "weekly_tournament_bot3.png"] \
	+ ["thumbrey.jpg", "townHuman.png", "townTroll.png"]
# The banner that shows the name of a cast spell.
CAST_SWF = os.path.join("assets", "buildingsprites", "magic_cast_marquee.swf")
CAST_SYMBOLS = ["magic_cast"]
# The copy of a SWF file with the windows, from which the port draws them.
WINDOWS_FILE = "windows.swf"


def import_ui(source, out_dir, unit_thumbs, more_images):
	"""unit_thumbs: the file names of the pictures in buildingthumbs that the
	windows and the portrait buttons can show. more_images: other pictures of
	assets/images_new, for example of the spells ("<img_name>.jpg" and
	"prev_<img_name>.jpg") and of the goals. Returns the number of imported
	sprites."""
	ui_dir = os.path.join(out_dir, "ui")
	count = _import_windows(os.path.join(source, CLIENT_SWF), SYMBOLS, ui_dir)
	count += _import_windows(os.path.join(source, CAST_SWF), CAST_SYMBOLS, os.path.join(ui_dir, "cast"))
	os.makedirs(os.path.join(ui_dir, "images"), exist_ok=True)
	for image in IMAGES + more_images:
		shutil.copyfile(os.path.join(source, "assets", "images_new", image), os.path.join(ui_dir, "images", image))
	os.makedirs(os.path.join(ui_dir, "thumbs"), exist_ok=True)
	for thumb in unit_thumbs:
		path = os.path.join(source, "assets", "buildingthumbs", thumb)
		if os.path.exists(path):
			shutil.copyfile(path, os.path.join(ui_dir, "thumbs", thumb))
	return count


def _import_windows(swf_path, symbol_names, ui_dir):
	"Writes windows.swf and layout.json of the symbols of one SWF file to ui_dir."
	swf = SwfFile(swf_path)
	symbols = {name: _resolve(swf, name) for name in symbol_names}
	clips = {}
	drops = {}
	buttons = {}
	layers = {}
	next_id = [swf.max_character_id() + 1]
	for sprite_id in symbols.values():
		_collect(swf, sprite_id, clips, drops, buttons, layers, next_id)
	os.makedirs(ui_dir, exist_ok=True)
	windows_path = os.path.join(ui_dir, WINDOWS_FILE)
	new_sprites = {layer_id: swf.first_frame_placements(sprite_id, depths) for layer_id, (sprite_id, depths) in layers.items()}
	with open(windows_path, 'wb') as f:
		f.write(swf.without_placements(drops, new_sprites))
	for layer_id in layers:
		clips[layer_id] = {"origin": None, "frames": [[]]}
	bases = SwfFile(windows_path)
	for sprite_id, clip in clips.items():
		bounds = bases.character_bounds(sprite_id)
		clip["origin"] = None if bounds is None else [bounds[0] / 20, bounds[1] / 20]
	with open(os.path.join(ui_dir, "layout.json"), 'w', encoding='utf-8') as f:
		json.dump({"symbols": symbols, "fonts": {name: font_id for font_id, name in swf.fonts.items()}, "clips": {str(k): v for k, v in clips.items()}, "buttons": {str(k): v for k, v in buttons.items()}}, f, indent='\t')
	return len(clips) + len(buttons)


def _resolve(swf, name):
	"Returns the sprite id of a symbol, or of a child named by a path such as GuiMC/bgBar/btnExit."
	parts = name.split("/")
	sprite_id = swf.symbols[parts[0]]
	for child in parts[1:]:
		sprite_id = swf.named_child(sprite_id, child)
	return sprite_id


def _collect(swf, sprite_id, clips, drops, buttons, layers, next_id):
	"""Adds the sprite and its named sprites to clips, and its named buttons to
	buttons. drops gets the depths that the base images leave out: named parts
	and text fields. A named mask, for example of a bar that the client
	scales, gets the shapes under it in the first frame as a sprite of their
	own: layers gets {new sprite id: (sprite id, depths)}, the part gets
	"masked": the new sprite id, and the base image leaves the shapes out."""
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
			elif char_id in swf.buttons:
				# The drawing of a sprite leaves out its buttons, so unnamed
				# buttons are parts too, for example the icons of the HUD menus.
				part["button"] = char_id
				buttons[char_id] = {}
			else:
				continue
			dropped.add(depth)
			parts.append(part)
		clip["frames"].append(parts)
	if places:
		named = {part["depth"] for part in clip["frames"][0]}
		for part in clip["frames"][0]:
			clip_depth = details.get(part["depth"], {}).get("clip_depth")
			if not part.get("mask") or part["name"] is None or clip_depth is None:
				continue
			masked = {depth for depth in places[0] if part["depth"] < depth <= clip_depth and depth not in named}
			if masked:
				layer_id = next_id[0]
				next_id[0] += 1
				layers[layer_id] = (sprite_id, masked)
				dropped |= masked
				for frame_parts in clip["frames"]:
					for other in frame_parts:
						if other["name"] == part["name"] and other.get("mask"):
							other["masked"] = layer_id
	if dropped:
		drops[sprite_id] = dropped
	for child_id in nested:
		_collect(swf, child_id, clips, drops, buttons, layers, next_id)
