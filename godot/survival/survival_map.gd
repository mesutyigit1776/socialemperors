class_name SurvivalMap
extends RefCounted
## The data of the survival maps that the client keeps in its classes
## (QuestSurvivalMap1 to 5 and PopupSurvival): the land, the waves of enemies
## and the reward units by the time that the player survives.
##
## The client shows all five maps, but only the first two can be played; the
## others say "coming soon". The server of this project also has only the
## maps of the first two.

## A stage of waves: the enemy units, the seconds until the next wave, the
## number of units in a wave, and the number of waves. A boss stage spawns
## each of its units once; while the bosses live, extra waves of the stage
## before come after "boss_wait" seconds.
class Stage:
	var units: Array[int] = []
	var seconds := 0
	var boss_wait := 0
	var count := 0
	var boss := false
	var waves := 0

const IDS: Array[String] = ["100000035", "100000036", "100000037", "100000038", "100000039"]
const PLAYABLE := 2
const NAMES: Array[String] = ["SURVIVAL_MAP1", "SURVIVAL_MAP2", "SURVIVAL_MAP3", "SURVIVAL_MAP4", "SURVIVAL_MAP5"]
const PICTURES: Array[String] = ["SURVIVAL_DESIERTO.jpg", "SURVIVAL_MINERAL.jpg", "SURVIVAL_NUBES.jpg", "SURVIVAL_NIEVE.jpg", "SURVIVAL_SELVA.jpg"]
const LANDS: Array[int] = [QuestIsland.DESERT, QuestIsland.MINERAL, QuestIsland.CLOUD, QuestIsland.ICE, QuestIsland.JUNGLE]
## The land of all areas, with the coast at the border of the map.
const LAYOUT: Array[int] = [10, 6, 6, 6, 11, 8, 3, 3, 3, 9, 8, 3, 3, 3, 9, 8, 3, 3, 3, 9, 12, 7, 7, 7, 13]
const START_TILE := Vector2i(50, 50)
## The units of each map: [units, seconds, boss wait, count, boss, waves]. The
## last stage of each map has the kamikazes, which come until the end.
const STAGES := [
	[[[593], 20, 0, 8, false, 4], [[669], 5, 20, 1, true, 1], [[613, 594], 18, 0, 8, false, 4], [[538], 5, 20, 1, true, 1], [[614, 595], 15, 0, 8, false, 4], [[665], 5, 20, 1, true, 1], [[613, 596], 10, 0, 8, false, 4], [[671], 5, 20, 1, true, 1], [[612, 614, 597], 8, 0, 8, false, 4], [[753], 5, 20, 6, true, 1], [[743], 3, 0, 5, false, 1000]],
	[[[558], 20, 0, 8, false, 4], [[667], 5, 20, 4, true, 1], [[729, 643], 18, 0, 8, false, 4], [[742], 5, 20, 1, true, 1], [[730, 715], 15, 0, 8, false, 4], [[745], 5, 20, 1, true, 1], [[619, 687, 620], 10, 0, 8, false, 4], [[754], 5, 20, 2, true, 1], [[712, 621, 624], 8, 0, 8, false, 4], [[723], 5, 20, 2, true, 1], [[743], 3, 0, 5, false, 1000]],
	[[[645], 20, 0, 8, false, 4], [[654], 5, 20, 4, true, 1], [[644], 15, 0, 8, false, 4], [[649], 5, 20, 1, true, 1], [[648], 10, 0, 8, false, 4], [[650], 5, 20, 2, true, 1], [[725, 647], 6, 0, 8, false, 4], [[758], 5, 20, 2, true, 1], [[646], 4, 0, 8, false, 4], [[755], 5, 20, 3, true, 1], [[743], 3, 0, 5, false, 1000]],
	[[[578, 605], 20, 0, 8, false, 4], [[637], 5, 20, 4, true, 1], [[606, 607], 15, 0, 8, false, 4], [[641], 5, 20, 1, true, 1], [[603, 601], 10, 0, 8, false, 4], [[545, 653], 5, 20, 2, true, 1], [[706, 727, 704], 6, 0, 8, false, 4], [[709, 716], 5, 20, 2, true, 1], [[694, 683, 735], 4, 0, 8, false, 4], [[722, 745], 5, 20, 2, true, 1], [[743], 3, 0, 5, false, 1000]],
	[[[621, 622, 624, 625], 20, 0, 8, false, 4], [[623], 5, 20, 1, true, 1], [[632, 633, 662, 626, 627, 628, 629], 15, 0, 8, false, 4], [[635], 5, 20, 1, true, 1], [[655, 662, 660, 661], 10, 0, 8, false, 4], [[684], 5, 20, 1, true, 1], [[699, 700, 701, 702, 704, 705, 703], 6, 0, 8, false, 4], [[711, 724, 736], 5, 20, 3, true, 1], [[748, 749, 750, 751, 752, 753], 4, 0, 8, false, 4], [[744, 755, 765], 5, 20, 3, true, 1], [[743], 3, 0, 5, false, 1000]],
]
## The reward of each map: [unit, minutes]. The player gets the unit of the
## last time that they survived.
const REWARDS := [
	[[619, 5], [577, 8], [662, 12], [629, 15]],
	[[607, 5], [655, 8], [687, 12], [652, 15]],
	[[730, 12], [654, 15], [644, 20], [758, 25]],
	[[730, 12], [654, 15], [644, 20], [758, 25]],
	[[730, 12], [654, 15], [644, 20], [758, 25]],
]

var index := 0
var id := ""
var stages: Array[Stage] = []


static func find(map_id: String) -> SurvivalMap:
	var at := IDS.find(map_id)
	if at < 0:
		return null
	var map := SurvivalMap.new()
	map.index = at
	map.id = map_id
	for entry: Array in STAGES[at]:
		var stage := Stage.new()
		stage.units.assign(entry[0])
		stage.seconds = entry[1]
		stage.boss_wait = entry[2]
		stage.count = entry[3]
		stage.boss = entry[4]
		stage.waves = entry[5]
		map.stages.append(stage)
	return map


func land_frames() -> Array[int]:
	var frames: Array[int] = []
	for value in LAYOUT:
		frames.append(value - 1)
	return frames


## The unit that the player gets after seconds of survival, or 0 for none.
func reward(seconds: int) -> int:
	var unit := 0
	if seconds <= int(REWARDS[index][0][1]) * 60:
		return 0
	for entry: Array in REWARDS[index]:
		if seconds < int(entry[1]) * 60:
			break
		unit = entry[0]
	return unit
