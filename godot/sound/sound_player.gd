class_name SoundPlayer
extends Node
## Plays the music and the sound effects of the client (SoundManager), from
## the files that importer/sound_import.py wrote to <data>/sound.
##
## The project has one SoundPlayer as the autoload "Sounds", as the client has
## one SoundManager (Base.Sound) for all screens: the map, the windows and the
## battles play through it, and the settings of the player apply to all of
## them. The other scripts use the static functions, not the name of the
## autoload: Godot knows that name only after it makes the autoload, and the
## checks and the screenshots compile the scripts before that (--script).
## Until main.gd calls load_from(), it plays nothing, so that the checks run
## without sounds.

enum Music { MAP, BATTLE, SHIP, ASSAULT, QUEST, TROLL, SURVIVAL }

## The files of SoundManager.MUSIC. The client of 1.4.07 never plays SURVIVAL:
## survival plays QUEST, see main.gd.
const MUSIC_FILES := {
	Music.MAP: "Spirit of Eternity.mp3", Music.BATTLE: "BATALLA.mp3", Music.SHIP: "BARCO.mp3",
	Music.ASSAULT: "ASSAULTS.mp3", Music.QUEST: "QUESTS.mp3", Music.TROLL: "trollcamp_v2.mp3",
	Music.SURVIVAL: "SURVIVAL.mp3",
}
## MUSIC_VOLUME and SFX_VOLUME of the client.
const MUSIC_VOLUME := 0.25
const EFFECT_VOLUME := 0.25
## A new music fades in while the old one fades out, in 20 steps of 50 ms.
const CROSS_FADE_SECONDS := 1.0
## The client starts an effect after a random wait of 50 to 150 ms, so that
## the effects of many units do not start together.
const MIN_DELAY_MS := 50
const MAX_DELAY_MS := 150
## The client plays at most 20 effects at the same time (MAX_TIMER_POOL_SIZE).
const MAX_EFFECTS := 20
## The settings of the player: the client keeps them in its local
## SharedObject; both are on for a new player.
const SETTINGS_FILE := "user://settings.cfg"

static var _player: SoundPlayer

var _music_on := true
var _effects_on := true
var _dir := ""
var _music_streams: Dictionary = {}  # Music -> AudioStreamMP3, or null for a missing file.
var _effect_streams: Dictionary = {}  # File name -> AudioStreamMP3, or null.
var _wanted := -1  # The music of the current screen, or -1.
var _music_player: AudioStreamPlayer  # The music that plays, or null.
var _fade: Tween
var _playing: Dictionary = {}  # Effect -> copies that wait or play, see SoundEffect.limit().
var _effects_now := 0
var _rng := RandomNumberGenerator.new()


func _enter_tree() -> void:
	_player = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_FILE) == OK:
		_music_on = bool(settings.get_value("sound", "music", true))
		_effects_on = bool(settings.get_value("sound", "effects", true))


func _exit_tree() -> void:
	if _player == self:
		_player = null


## Plays from <data_dir>/sound from now on. Returns false, and plays nothing,
## when the import has no sounds.
static func load_from(data_dir: String) -> bool:
	var dir := data_dir.path_join("sound")
	if _player == null or not FileAccess.file_exists(dir.path_join("import.json")):
		push_warning("The import has no sounds in '%s'. Import the game files again to hear the music and the sounds." % dir)
		return false
	_player._dir = dir
	return true


static func is_music_on() -> bool:
	return _player != null and _player._music_on


static func are_effects_on() -> bool:
	return _player != null and _player._effects_on


## The music of a town of this race (SoundManager.startMusic): the troll
## town has its own music.
static func town_music(race: String) -> Music:
	return Music.TROLL if race == "t" else Music.MAP


## Plays the music of a screen, with a cross fade from the music before it.
## The same music goes on without a new start.
static func play_music(music: Music) -> void:
	if _player == null:
		return
	_player._wanted = music
	if _player._music_on:
		_player._start_music(music)


static func set_music_on(on: bool) -> void:
	if _player == null:
		return
	_player._music_on = on
	if on and _player._wanted >= 0:
		_player._start_music(_player._wanted)
	elif not on:
		_player._stop_music()
	_player._save_settings()


static func set_effects_on(on: bool) -> void:
	if _player == null:
		return
	_player._effects_on = on
	_player._save_settings()


## Plays an effect of SoundEffect after delay_ms, or after a random wait of
## MIN_DELAY_MS to MAX_DELAY_MS when delay_ms is negative. The effect does not
## play when the sounds are off or when its limit of copies plays already.
static func play(effect: int, delay_ms := -1) -> void:
	if _player != null:
		_player._play(effect, delay_ms)


func _play(effect: int, delay_ms: int) -> void:
	if _dir.is_empty() or not _effects_on or _effects_now >= MAX_EFFECTS or _playing.get(effect, 0) >= SoundEffect.limit(effect):
		return
	var names: Array = SoundEffect.FILES[effect]
	var stream := _effect_stream(names[_rng.randi_range(0, names.size() - 1)])
	if stream == null:
		return
	_playing[effect] = _playing.get(effect, 0) + 1
	_effects_now += 1
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(EFFECT_VOLUME)
	add_child(player)
	var plays_left := [1 + SoundEffect.REPEATS.get(effect, 0)]
	player.finished.connect(func() -> void:
		plays_left[0] -= 1
		if plays_left[0] > 0:
			player.play()
			return
		_playing[effect] -= 1
		_effects_now -= 1
		player.queue_free())
	var wait := delay_ms if delay_ms >= 0 else _rng.randi_range(MIN_DELAY_MS, MAX_DELAY_MS)
	get_tree().create_timer(wait / 1000.0, true, false, true).timeout.connect(player.play)


func _start_music(music: Music) -> void:
	if _music_player != null and _music_player.get_meta("music") == music:
		return
	var stream := _music_stream(music)
	if stream == null:
		return
	var old := _music_player
	_music_player = AudioStreamPlayer.new()
	_music_player.set_meta("music", music)
	_music_player.stream = stream
	add_child(_music_player)
	if _fade != null:
		_fade.kill()
	if old == null:
		_music_player.volume_db = linear_to_db(MUSIC_VOLUME)
		_music_player.play()
		return
	_music_player.volume_db = linear_to_db(0.0)
	_music_player.play()
	_fade = create_tween().set_parallel()
	_fade.tween_method(func(volume: float) -> void: _music_player.volume_db = linear_to_db(volume), 0.0, MUSIC_VOLUME, CROSS_FADE_SECONDS)
	_fade.tween_method(func(volume: float) -> void: old.volume_db = linear_to_db(volume), db_to_linear(old.volume_db), 0.0, CROSS_FADE_SECONDS)
	_fade.chain().tween_callback(old.queue_free)


func _stop_music() -> void:
	if _fade != null:
		_fade.kill()
		_fade = null
	for child in get_children():
		if child.has_meta("music"):
			child.queue_free()
	_music_player = null


func _music_stream(music: Music) -> AudioStreamMP3:
	if _dir.is_empty():
		return null
	if not _music_streams.has(music):
		var stream := _load_mp3(_dir.path_join("music").path_join(MUSIC_FILES[music]))
		if stream != null:
			stream.loop = true
		_music_streams[music] = stream
	return _music_streams[music]


func _effect_stream(file_name: String) -> AudioStreamMP3:
	if not _effect_streams.has(file_name):
		_effect_streams[file_name] = _load_mp3(_dir.path_join("sfx").path_join(file_name + ".mp3"))
	return _effect_streams[file_name]


func _load_mp3(path: String) -> AudioStreamMP3:
	var stream := AudioStreamMP3.load_from_file(path)
	if stream == null:
		push_error("Cannot read the sound '%s'. Import the game files again." % path)
	return stream


func _save_settings() -> void:
	var settings := ConfigFile.new()
	settings.load(SETTINGS_FILE)
	settings.set_value("sound", "music", _music_on)
	settings.set_value("sound", "effects", _effects_on)
	if settings.save(SETTINGS_FILE) != OK:
		push_error("Cannot save the settings to '%s'." % SETTINGS_FILE)
