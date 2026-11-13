class_name Host
extends RefCounted
## The host of the game: Arthur, or Guinevere for a female player. The client
## takes the gender of the player from the page ("sex", "f" for female; any
## other value or none gives the male host). The host shows in the tutorial
## (GameShowHostMC or GameShowFemaleHostMC), in the goal box
## (GameShowHostMissionMC or GameShowFemaleMissionMC), in the neighbour bar
## (thumbrey.jpg or thumbprincess.jpg), and its name replaces "#0#" in the
## texts of the tutorial and the goals.
##
## The server page always sends "m". The port reads the choice from the
## setting SETTING_KEY of the settings file ("female" or "male"), or from the
## command line option --host for one run.

const SETTING_SECTION := "game"
const SETTING_KEY := "host"
const FEMALE := "female"

## The frames (from 0) where the animations start, from the frame labels of
## the symbols: "apparait", "attend1" and "bien1". The tutorial and the goal
## symbols of each host have the same frames.
const MALE_STARTS := {"appear": 327, "wait": 0, "well_done": 363}
const FEMALE_STARTS := {"appear": 51, "wait": 0, "well_done": 87}
## The frame scripts of the symbols: at the frame, the graphic goes to the
## frame of the value and plays on (true) or stops there (false). The male
## host waits in a loop after it appears, and talks ("parle") in a loop after
## "bien1". The female host stops at the end of each part, and after "bien1"
## on the first frame of "parle".
const MALE_SCRIPTS := {268: [0, true], 326: [269, true], 344: [0, true], 393: [269, true]}
const FEMALE_SCRIPTS := {37: [37, false], 50: [50, false], 68: [68, false], 86: [86, false], 103: [38, false]}

var female: bool


func _init(is_female := false) -> void:
	female = is_female


## option: the value of --host, or "" to use the settings file.
static func from_settings(option: String) -> Host:
	if not option.is_empty():
		return Host.new(option == FEMALE)
	var settings := ConfigFile.new()
	if settings.load(SoundPlayer.SETTINGS_FILE) != OK:
		return Host.new()
	return Host.new(str(settings.get_value(SETTING_SECTION, SETTING_KEY, "")) == FEMALE)


func name(config: GameConfig) -> String:
	return config.text("TUTORIAL_HOST_NAME_FEMALE" if female else "TUTORIAL_HOST_NAME_MALE")


## The text with the name of the host for "#0#".
func fill(text: String, config: GameConfig) -> String:
	return text.replace("#0#", name(config))


func goal_symbol() -> String:
	return "GameShowFemaleMissionMC" if female else "GameShowHostMissionMC"


func tutorial_symbol() -> String:
	return "GameShowFemaleHostMC" if female else "GameShowHostMC"


## The picture of the host in the neighbour bar (FriendButton).
func picture() -> String:
	return "thumbprincess.jpg" if female else "thumbrey.jpg"


## "appear", "wait" or "well_done": the first frame.
func start_frame(animation: String) -> int:
	return (FEMALE_STARTS if female else MALE_STARTS)[animation]


## Frame -> [next frame, plays on], see MALE_SCRIPTS.
func frame_scripts() -> Dictionary:
	return FEMALE_SCRIPTS if female else MALE_SCRIPTS
