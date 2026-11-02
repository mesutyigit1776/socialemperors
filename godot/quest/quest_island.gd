class_name QuestIsland
extends RefCounted
## The data of one quest island that the client keeps in the class of the
## quest, not in the configuration: the kind of quest, the gold key, the start
## tile of the army, the land and the units of the map that join the player.
##
## Only the islands in ISLANDS are in the port. The other islands of
## GameConfig.quest_order show in the island list with a "not in the port"
## sign and cannot start. To add an island, port its quest class and add it to
## ISLANDS.

## The kinds of quests in the port, by the quest class of the client. Each
## kind has its own subclass of QuestBattle, see QuestBattle.create().
## - TROLLS: all units and buildings are enemies. When the last enemy unit is
##   dead, the treasure opens; the player wins when they collect it.
## - CIVILISATION: the player wins when every town hall is destroyed.
## - YETI, GOLEM, WORM: the enemies stand in 4 groups. The last unit of a
##   group opens a key (an activator); when the player has collected all keys,
##   the boss comes, and the player wins when it is dead.
## - DRAGON, DRAGON_2: the dragon boss islands, see DragonQuest and Dragon2Quest.
## - HEROES: the enemy units stand behind walls in 7 areas; the door of an
##   area opens when its last unit is dead. The player wins when all enemy
##   units are dead.
## - HARD, GOD: the player wins when all enemy units are dead. Each enemy that
##   dies can drop an item of the Bahamut collections. The god islands give
##   more experience.
enum Family { TROLLS, CIVILISATION, YETI, GOLEM, WORM, DRAGON, DRAGON_2, HEROES, HARD, GOD }

## A land area of the island with this layout value is water: no item can be
## on it and units cannot walk on it. Other values are frames (from 1) of the
## land graphic: the land and its coasts.
const WATER := 5
## The land graphics of the islands are items of the configuration.
const GRASS := 1000
const DESERT := 1001
const ICE := 1002
const SEA := 1003
const MINERAL := 1004
const JUNGLE := 1005
const CLOUD := 1006

const HERO_VALKYRIE := 554
const HERO_WALLACE := 555
const HERO_THOR := 556
const KAMIKAZE := 575
const FIRE_CANNON := 568
const WIZARD := 550
const POWERFUL_KNIGHT := 541
const PRINCE_ARTHUR := 534

## The pictures of the start window: frame (from 0) of "images" and the file.
## The client takes the file from the list IMAGES_QUESTBEGIN by the frame.
const PICTURES := ["COLLECT_GEMS.jpg", "pop_up_nieve.jpg", "barco.jpg", "TESORO.jpg", "rockdriller_start.jpg", "barca.jpg", "zeppelin.jpg", "boss2_ini.jpg"]
const PICTURE_GEMS := 0
const PICTURE_SNOW := 1
const PICTURE_TREASURE := 3
const PICTURE_ROCKDRILLER := 4
const PICTURE_DRAGON_2 := 7

const _TROLLS_1_2_LAYOUT: Array[int] = [5, 5, 5, 5, 5, 5, 10, 6, 11, 5, 5, 12, 7, 13, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]
const _HUMANS_LAYOUT: Array[int] = [10, 6, 6, 11, 5, 8, 3, 3, 9, 5, 8, 3, 3, 9, 5, 8, 3, 3, 9, 5, 12, 7, 7, 13, 5]
const _SQUARE_LAYOUT: Array[int] = [10, 6, 6, 6, 11, 8, 3, 3, 3, 9, 8, 3, 3, 3, 9, 8, 3, 3, 3, 9, 12, 7, 7, 7, 13]
## The hard and god islands ask for frame 0 of the land graphic in all areas,
## which Flash shows as frame 1: land without coast.
const _ALL_LAND_LAYOUT: Array[int] = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]

## Quest id -> the texts of its name in the battle and of its goal in the start
## window (GameConfig.text()), family, gold key (GameConfig.quest_gold), start tile, land
## graphic, layout of the 5 x 5 land areas (row by row), and the units of the
## map that join the player ("free"): unit id -> number. Optional:
## - "free_all": the Kamikaze island gives the player all its kamikazes and fire cannons.
## - "picture": the picture of the start window, see PICTURES. Default PICTURE_TREASURE.
## - "rewards": the items that a win gives, by the race of the player.
## - "team": the player takes a team of at most QuestBattle.TEAM_SIZE units, not the whole army.
## - "groups", "group_count": the team needs this number of units of these groups.
## - "title_item": the name in the battle is the name of this item of the configuration.
## The hard and god islands take their name from their island item, see NAME_ITEMS.
const ISLANDS := {
	"100000006": {"title": "QUEST_MISTERIOSA", "goal": "POPUP_QUEST_TROLLS", "family": Family.TROLLS, "gold": "QUEST_ISLA_TROLLS_1", "start": Vector2i(72, 40), "land": DESERT, "layout": _TROLLS_1_2_LAYOUT, "free": {}},
	"100000007": {"title": "QUEST_DESCONOCIDA", "goal": "POPUP_QUEST_TROLLS", "family": Family.TROLLS, "gold": "QUEST_ISLA_TROLLS_2", "start": Vector2i(71, 27), "land": ICE, "layout": _TROLLS_1_2_LAYOUT, "free": {HERO_WALLACE: 1}},
	"100000008": {"title": "QUEST_NO_DESCUBIERTA", "goal": "POPUP_QUEST_ESQUELETOS", "family": Family.TROLLS, "gold": "QUEST_ISLA_TROLLS_3", "start": Vector2i(33, 26), "land": MINERAL, "layout": [5, 5, 5, 5, 5, 5, 10, 14, 11, 5, 5, 8, 3, 9, 5, 5, 12, 7, 13, 5, 5, 5, 5, 5, 5], "free": {HERO_THOR: 1}},
	"100000002": {"title": "QUEST_ARTICO", "goal": "POPUP_QUEST_YETI", "family": Family.YETI, "gold": "QUEST_BOSS_YETI", "start": Vector2i(29, 10), "land": ICE, "layout": [14, 11, 5, 5, 5, 8, 9, 5, 5, 5, 8, 9, 5, 5, 5, 8, 3, 6, 6, 11, 12, 7, 7, 7, 13], "free": {WIZARD: 1, POWERFUL_KNIGHT: 4}, "picture": PICTURE_SNOW, "rewards": {"h": {541: 1}, "t": {596: 1}}},
	"100000012": {"title": "QUEST_EMERGENTE", "goal": "POPUP_QUEST_TROLLS", "family": Family.TROLLS, "gold": "QUEST_ISLA_TROLLS_4", "start": Vector2i(50, 27), "land": JUNGLE, "layout": [5, 5, 5, 5, 5, 5, 10, 14, 11, 5, 5, 12, 3, 9, 5, 5, 5, 12, 13, 5, 5, 5, 5, 5, 5], "free": {HERO_VALKYRIE: 1}},
	"100000021": {"title": "QUEST_NUBLADA", "goal": "POPUP_QUEST_VIKINGOS", "family": Family.CIVILISATION, "gold": "QUEST_ISLA_VIKINGO", "start": Vector2i(71, 91), "land": JUNGLE, "layout": _HUMANS_LAYOUT, "free": {767: 1}},
	"100000022": {"title": "QUEST_DUNAS", "goal": "POPUP_QUEST_EGIPCIOS", "family": Family.CIVILISATION, "gold": "QUEST_ISLA_EGYPT", "start": Vector2i(70, 10), "land": DESERT, "layout": [5, 10, 14, 11, 5, 10, 3, 3, 9, 5, 8, 3, 3, 9, 5, 12, 3, 3, 9, 5, 5, 12, 7, 13, 5], "free": {}},
	"100000003": {"title": "QUEST_DESIERTO", "goal": "", "family": Family.GOLEM, "gold": "QUEST_BOSS_GOLEM", "start": Vector2i(48, 28), "land": DESERT, "layout": [5, 5, 5, 5, 5, 10, 6, 14, 6, 11, 8, 3, 3, 3, 9, 8, 3, 3, 3, 9, 12, 7, 7, 7, 13], "free": {PRINCE_ARTHUR: 1}, "picture": PICTURE_GEMS, "rewards": {"h": {537: 1}, "t": {537: 1}}},
	"100000028": {"title": "QUEST_NIDO", "goal": "POPUP_QUEST_DRAGON", "family": Family.DRAGON, "gold": "QUEST_BOSS_DRAGON_1", "start": Vector2i(66, 54), "land": MINERAL, "layout": [5, 10, 6, 6, 11, 5, 8, 3, 3, 9, 5, 8, 3, 3, 9, 5, 12, 7, 7, 13, 5, 5, 5, 5, 5], "free": {}},
	"100000014": {"title": "QUEST_AZTECAS", "goal": "POPUP_QUEST_AZTECAS", "family": Family.CIVILISATION, "gold": "QUEST_ISLA_AZTECAS", "start": Vector2i(71, 91), "land": JUNGLE, "layout": [5, 5, 5, 5, 5, 5, 10, 6, 11, 5, 5, 8, 3, 9, 5, 5, 8, 3, 9, 5, 5, 12, 7, 13, 5], "free": {}},
	"100000013": {"title": "QUEST_CHINOS", "goal": "POPUP_QUEST_CHINOS", "family": Family.CIVILISATION, "gold": "QUEST_ISLA_CHINOS", "start": Vector2i(88, 88), "land": JUNGLE, "layout": [5, 5, 5, 5, 5, 5, 10, 6, 6, 11, 5, 8, 3, 3, 9, 5, 8, 3, 3, 9, 5, 12, 7, 7, 13], "free": {}},
	"100000020": {"title": "QUEST_HUMANOS", "goal": "POPUP_QUEST_KAMIKAZES", "family": Family.CIVILISATION, "gold": "QUEST_ISLA_KAMIKAZES", "start": Vector2i(28, 69), "land": JUNGLE, "layout": [5, 5, 5, 5, 5, 5, 10, 6, 11, 5, 5, 8, 3, 9, 5, 5, 12, 7, 13, 5, 5, 5, 5, 5, 5], "free": {}, "free_all": [KAMIKAZE, FIRE_CANNON]},
	"100000015": {"title": "QUEST_HUMANOS", "goal": "POPUP_QUEST_HUMANOS", "family": Family.CIVILISATION, "gold": "QUEST_ISLA_HUMANOS", "start": Vector2i(73, 95), "land": ICE, "layout": _HUMANS_LAYOUT, "free": {}},
	"100000019": {"title": "QUEST_HUMANOS", "goal": "POPUP_QUEST_HUMANOS", "family": Family.CIVILISATION, "gold": "QUEST_ISLA_HUMANOS_2", "start": Vector2i(94, 6), "land": JUNGLE, "layout": _SQUARE_LAYOUT, "free": {}},
	"100000018": {"title": "QUEST_HEROES", "goal": "POPUP_QUEST_HEROES", "family": Family.HEROES, "gold": "QUEST_ISLA_HEROES", "start": Vector2i(95, 86), "land": ICE, "layout": _SQUARE_LAYOUT, "free": {}},
	# Atlantis is all land; its walls and decorations are neutral.
	"100000023": {"title": "QUEST_MITICA", "goal": "POPUP_QUEST_ATLANTES", "family": Family.CIVILISATION, "gold": "QUEST_ISLA_ATLANTIS", "start": Vector2i(90, 90), "land": SEA, "layout": [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3], "free": {}, "neutral_subcats": [221, 411]},
	"100000011": {"title": "QUEST_GUSANO", "goal": "POPUP_QUEST_GUSANO", "family": Family.WORM, "gold": "QUEST_BOSS_WORM", "start": Vector2i(49, 5), "land": MINERAL, "layout": _SQUARE_LAYOUT, "free": {}, "picture": PICTURE_ROCKDRILLER, "rewards": {"h": {574: 3, 288: 1}, "t": {600: 3, 288: 1}}},
	"100000033": {"title": "QUEST_NIDO", "goal": "POPUP_QUEST_DRAGON_2", "family": Family.DRAGON_2, "gold": "QUEST_BOSS_DRAGON_2", "start": Vector2i(50, 90), "land": MINERAL, "layout": [5, 5, 1, 1, 1, 5, 1, 1, 1, 1, 5, 1, 5, 1, 1, 1, 1, 5, 5, 5, 1, 1, 1, 1, 5], "free": {}, "picture": PICTURE_DRAGON_2},
	"100000041": {"goal": "QUEST_HARDCORE1_DESCRIP", "family": Family.HARD, "gold": "QUEST_HARDCORE_1", "start": Vector2i(90, 90), "land": CLOUD, "layout": _ALL_LAND_LAYOUT, "free": {}},
	"100000042": {"goal": "QUEST_HARDCORE2_DESCRIP", "family": Family.HARD, "gold": "QUEST_HARDCORE_2", "start": Vector2i(90, 50), "land": GRASS, "layout": _ALL_LAND_LAYOUT, "free": {}},
	"100000043": {"goal": "QUEST_HARDCORE3_DESCRIP", "family": Family.HARD, "gold": "QUEST_HARDCORE_3", "start": Vector2i(90, 50), "land": MINERAL, "layout": _ALL_LAND_LAYOUT, "free": {}},
	"100000044": {"goal": "QUEST_HARDCORE4_DESCRIP", "family": Family.HARD, "gold": "QUEST_HARDCORE_4", "start": Vector2i(90, 50), "land": DESERT, "layout": _ALL_LAND_LAYOUT, "free": {}},
	"100000045": {"goal": "QUEST_HARDCORE5_DESCRIP", "family": Family.HARD, "gold": "QUEST_HARDCORE_5", "start": Vector2i(90, 50), "land": MINERAL, "layout": _ALL_LAND_LAYOUT, "free": {}},
	"100000046": {"goal": "QUEST_HARDCORE6_DESCRIP", "family": Family.HARD, "gold": "QUEST_HARDCORE_6", "start": Vector2i(5, 90), "land": DESERT, "layout": _ALL_LAND_LAYOUT, "free": {}, "team": true},
	"100000047": {"goal": "QUEST_HARDCORE7_DESCRIP", "family": Family.HARD, "gold": "QUEST_HARDCORE_7", "start": Vector2i(90, 5), "land": GRASS, "layout": _ALL_LAND_LAYOUT, "free": {}, "team": true},
	"100000090": {"goal": "QUEST_GOD1_DESCRIP", "family": Family.GOD, "gold": "QUEST_GODS_1", "start": Vector2i(5, 90), "land": MINERAL, "layout": _ALL_LAND_LAYOUT, "free": {}, "team": true, "groups": ["god", "colossus"], "group_count": 1},
	"100000091": {"goal": "QUEST_GOD2_DESCRIP", "family": Family.GOD, "gold": "QUEST_GODS_2", "start": Vector2i(5, 5), "land": MINERAL, "layout": _ALL_LAND_LAYOUT, "free": {}, "team": true, "groups": ["god", "colossus"], "group_count": 1},
	"100000092": {"goal": "QUEST_GOD3_DESCRIP", "family": Family.GOD, "gold": "QUEST_GODS_3", "start": Vector2i(60, 95), "land": MINERAL, "layout": _ALL_LAND_LAYOUT, "free": {}, "team": true, "groups": ["god", "colossus"], "group_count": 5},
}

## The island list of the client names each island after an island item of
## the configuration: quest id -> item id.
const NAME_ITEMS := {
	"100000006": 148, "100000007": 149, "100000008": 182, "100000012": 183, "100000002": 145,
	"100000021": 431, "100000022": 432, "100000003": 144, "100000027": 436, "100000028": 436,
	"100000014": 294, "100000013": 293, "100000020": 296, "100000015": 297, "100000023": 433,
	"100000019": 295, "100000018": 298, "100000011": 284, "100000033": 435,
	"100000041": 1384, "100000042": 1385, "100000043": 1386, "100000044": 1387, "100000045": 1388,
	"100000046": 1489, "100000047": 1490, "100000090": 1506, "100000091": 1507, "100000092": 1511,
}

var id: String
var title_text: String
var description_text: String
var family: Family
var gold_key: String
var start_tile: Vector2i
var land_item: int
var layout: Array[int] = []
var free_units: Dictionary = {}
var free_all_units: Array[int] = []
var neutral_subcats: Array[int] = []
var picture := PICTURE_TREASURE
var rewards: Dictionary = {}  ## Race -> {item id: number}.
var team := false
var groups: Array[String] = []
var group_count := 0


## The island of the quest, or null when the port does not have the quest.
static func find(quest_id: String) -> QuestIsland:
	if not ISLANDS.has(quest_id):
		return null
	var data: Dictionary = ISLANDS[quest_id]
	var island := QuestIsland.new()
	island.id = quest_id
	island.title_text = data.get("title", "")
	island.description_text = data["goal"]
	island.family = data["family"]
	island.gold_key = data["gold"]
	island.start_tile = data["start"]
	island.land_item = data["land"]
	island.layout.assign(data["layout"])
	island.free_units = data["free"]
	island.free_all_units.assign(data.get("free_all", []))
	island.neutral_subcats.assign(data.get("neutral_subcats", []))
	island.picture = data.get("picture", PICTURE_TREASURE)
	island.rewards = data.get("rewards", {})
	island.team = data.get("team", false)
	island.groups.assign(data.get("groups", []))
	island.group_count = data.get("group_count", 0)
	return island


static func is_in_port(quest_id: String) -> bool:
	return ISLANDS.has(quest_id)


## The name of the island in the battle bar: a text of the client, or for the
## hard and god islands the name of the island item, as the client does.
func title(config: GameConfig) -> String:
	return config.text(title_text) if title_text != "" else name_of(id, config)


## The name of the island, as the island list of the client shows it.
static func name_of(quest_id: String, config: GameConfig) -> String:
	var item := config.get_item(NAME_ITEMS.get(quest_id, 0))
	return item.name if item != null else quest_id


## The frame (from 0) of the land graphic in each land area, row by row, for
## VillageView.place_land(). The water frame shows nothing, so the sea of the
## screen shows.
func land_frames() -> Array[int]:
	var frames: Array[int] = []
	for value in layout:
		frames.append(value - 1)
	return frames


## The layout value of the land area that contains tile.
func layout_at(tile: Vector2i) -> int:
	var area := tile / IsoGrid.LAND_TILES
	return layout[area.y * IsoGrid.LAND_AREAS + area.x]


func is_water(tile: Vector2i) -> bool:
	return layout_at(tile) == WATER
