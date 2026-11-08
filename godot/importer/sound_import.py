"""Copies the music and extracts the sound effects of the client.

  <out>/sound/music/<file>.mp3   the music of the client (SoundManager.MUSIC), as it is
  <out>/sound/sfx/<class>.mp3    each sound of the library 120608_dynamic.swf, with
                                 the name of its class (for example ButtonClickSound)

The client loads the sounds of SoundManager from that library by the name of
their class (ExternalClass). The library stores them as MP3 frames, which an
MP3 file can hold as they are.
"""

import glob
import os
import shutil

from swf_bounds import SwfFile

MUSIC_DIR = os.path.join("assets", "music")
SOUND_LIBRARY = os.path.join("assets", "swf", "120608_dynamic.swf")


def sound_sources(source):
	"The files from which import_sounds() reads, for the record of the import."
	return sorted(glob.glob(os.path.join(source, MUSIC_DIR, "*.mp3"))) + [os.path.join(source, SOUND_LIBRARY)]


def import_sounds(source, out_dir):
	"Returns the number of music files and of sound effects."
	music_dir = os.path.join(out_dir, "sound", "music")
	sfx_dir = os.path.join(out_dir, "sound", "sfx")
	os.makedirs(music_dir, exist_ok=True)
	os.makedirs(sfx_dir, exist_ok=True)
	music = glob.glob(os.path.join(source, MUSIC_DIR, "*.mp3"))
	for path in music:
		shutil.copyfile(path, os.path.join(music_dir, os.path.basename(path)))
	swf = SwfFile(os.path.join(source, SOUND_LIBRARY))
	effects = {name: char_id for name, char_id in swf.symbols.items() if char_id in swf.sounds}
	for name, char_id in effects.items():
		with open(os.path.join(sfx_dir, f"{name}.mp3"), 'wb') as f:
			f.write(swf.mp3_sound(char_id))
	return len(music), len(effects)
