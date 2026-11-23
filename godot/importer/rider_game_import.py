"""Imports the mini-game of the Dragon Riding and the Rider Academy.

The client plays a separate SWF file (swf/minigames/SagaOTDC.swf) in its
window WindowMiniGameDragonRiderMC. This module writes:

  <out>/rider_game/game.swf          a copy of the SWF file; the port draws the
                                     hero, the enemies and the levels from it
  <out>/rider_game/sounds/<class>.mp3  each sound of the file, with the name of its class
  <out>/rider_game/ui/...            the skill bar, the health bar and the result
                                     screens, in the form of ui_import.py
"""

import os
import shutil

from swf_bounds import SwfFile
from ui_import import import_windows

GAME_SWF = os.path.join("assets", "swf", "minigames", "SagaOTDC.swf")
GAME_FILE = "game.swf"
# The parts of the screen that have buttons and text fields.
UI_SYMBOLS = ["main.control_board", "main.heroHealthBar", "main.game_won", "main.game_over", "main.game_complete"]


def import_rider_game(source, out_dir):
	"Returns the number of sounds."
	game_dir = os.path.join(out_dir, "rider_game")
	sound_dir = os.path.join(game_dir, "sounds")
	os.makedirs(sound_dir, exist_ok=True)
	swf_path = os.path.join(source, GAME_SWF)
	shutil.copyfile(swf_path, os.path.join(game_dir, GAME_FILE))
	swf = SwfFile(swf_path)
	sounds = {name: char_id for name, char_id in swf.symbols.items() if char_id in swf.sounds}
	for name, char_id in sounds.items():
		with open(os.path.join(sound_dir, f"{name}.mp3"), 'wb') as f:
			f.write(swf.mp3_sound(char_id))
	import_windows(swf_path, UI_SYMBOLS, os.path.join(game_dir, "ui"))
	return len(sounds)
