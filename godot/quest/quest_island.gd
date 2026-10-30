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

## The kinds of quests in the port, by their rules (see QuestBattle):
## - TROLLS: all units and buildings are enemies. When the last enemy unit is
##   dead, the treasure opens; the player wins when they collect it.
## - CIVILISATION: the player wins when every town hall is destroyed.
enum Family { TROLLS, CIVILISATION }

## A land area of the island with this layout value is water: no item can be
## on it and units cannot walk on it. Other values are frames (from 1) of the
## land graphic: the land and its coasts.
const WATER := 5
## The land graphics of the islands are items of the configuration.
const DESERT := 1001
const ICE := 1002
const SEA := 1003
const MINERAL := 1004
const JUNGLE := 1005

const HERO_VALKYRIE := 554
const HERO_WALLACE := 555
const HERO_THOR := 556
const KAMIKAZE := 575
const FIRE_CANNON := 568

const _TROLLS_1_2_LAYOUT: Array[int] = [5, 5, 5, 5, 5, 5, 10, 6, 11, 5, 5, 12, 7, 13, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]
const _HUMANS_LAYOUT: Array[int] = [10, 6, 6, 11, 5, 8, 3, 3, 9, 5, 8, 3, 3, 9, 5, 8, 3, 3, 9, 5, 12, 7, 7, 13, 5]

## Quest id -> the texts of its name in the battle and of its goal in the start
## window (GameConfig.text()), family, gold key (GameConfig.quest_gold), start tile, land
## graphic, layout of the 5 x 5 land areas (row by row), and the units of the
## map that join the player ("free"): unit id -> number. The Kamikaze island
## gives the player all its kamikazes and fire cannons ("free_all").
const ISLANDS := {
	"100000006": {"title": "QUEST_MISTERIOSA", "goal": "POPUP_QUEST_TROLLS", "family": Family.TROLLS, "gold": "QUEST_ISLA_TROLLS_1", "start": Vector2i(72, 40), "land": DESERT, "layout": _TROLLS_1_2_LAYOUT, "free": {}},
	"100000007": {"title": "QUEST_DESCONOCIDA", "goal": "POPUP_QUEST_TROLLS", "family": Family.TROLLS, "gold": "QUEST_ISLA_TROLLS_2", "start": Vector2i(71, 27), "land": ICE, "layout": _TROLLS_1_2_LAYOUT, "free": {HERO_WALLACE: 1}},
	"100000008": {"title": "QUEST_NO_DESCUBIERTA", "goal": "POPUP_QUEST_ESQUELETOS", "family": Family.TROLLS, "gold": "QUEST_ISLA_TROLLS_3", "start": Vector2i(33, 26), "land": MINERAL, "layout": [5, 5, 5, 5, 5, 5, 10, 14, 11, 5, 5, 8, 3, 9, 5, 5, 12, 7, 13, 5, 5, 5, 5, 5, 5], "free": {HERO_THOR: 1}},
	"100000012": {"title": "QUEST_EMERGENTE", "goal": "POPUP_QUEST_TROLLS", "family": Family.TROLLS, "gold": "QUEST_ISLA_TROLLS_4", "start": Vector2i(50, 27), "land": JUNGLE, "layout": [5, 5, 5, 5, 5, 5, 10, 14, 11, 5, 5, 12, 3, 9, 5, 5, 5, 12, 13, 5, 5, 5, 5, 5, 5], "free": {HERO_VALKYRIE: 1}},
	"100000021": {"title": "QUEST_NUBLADA", "goal": "POPUP_QUEST_VIKINGOS", "family": Family.CIVILISATION, "gold": "QUEST_ISLA_VIKINGO", "start": Vector2i(71, 91), "land": JUNGLE, "layout": _HUMANS_LAYOUT, "free": {767: 1}},
	"100000022": {"title": "QUEST_DUNAS", "goal": "POPUP_QUEST_EGIPCIOS", "family": Family.CIVILISATION, "gold": "QUEST_ISLA_EGYPT", "start": Vector2i(70, 10), "land": DESERT, "layout": [5, 10, 14, 11, 5, 10, 3, 3, 9, 5, 8, 3, 3, 9, 5, 12, 3, 3, 9, 5, 5, 12, 7, 13, 5], "free": {}},
	"100000014": {"title": "QUEST_AZTECAS", "goal": "POPUP_QUEST_AZTECAS", "family": Family.CIVILISATION, "gold": "QUEST_ISLA_AZTECAS", "start": Vector2i(71, 91), "land": JUNGLE, "layout": [5, 5, 5, 5, 5, 5, 10, 6, 11, 5, 5, 8, 3, 9, 5, 5, 8, 3, 9, 5, 5, 12, 7, 13, 5], "free": {}},
	"100000013": {"title": "QUEST_CHINOS", "goal": "POPUP_QUEST_CHINOS", "family": Family.CIVILISATION, "gold": "QUEST_ISLA_CHINOS", "start": Vector2i(88, 88), "land": JUNGLE, "layout": [5, 5, 5, 5, 5, 5, 10, 6, 6, 11, 5, 8, 3, 3, 9, 5, 8, 3, 3, 9, 5, 12, 7, 7, 13], "free": {}},
	"100000020": {"title": "QUEST_HUMANOS", "goal": "POPUP_QUEST_KAMIKAZES", "family": Family.CIVILISATION, "gold": "QUEST_ISLA_KAMIKAZES", "start": Vector2i(28, 69), "land": JUNGLE, "layout": [5, 5, 5, 5, 5, 5, 10, 6, 11, 5, 5, 8, 3, 9, 5, 5, 12, 7, 13, 5, 5, 5, 5, 5, 5], "free": {}, "free_all": [KAMIKAZE, FIRE_CANNON]},
	"100000015": {"title": "QUEST_HUMANOS", "goal": "POPUP_QUEST_HUMANOS", "family": Family.CIVILISATION, "gold": "QUEST_ISLA_HUMANOS", "start": Vector2i(73, 95), "land": ICE, "layout": _HUMANS_LAYOUT, "free": {}},
	"100000019": {"title": "QUEST_HUMANOS", "goal": "POPUP_QUEST_HUMANOS", "family": Family.CIVILISATION, "gold": "QUEST_ISLA_HUMANOS_2", "start": Vector2i(94, 6), "land": JUNGLE, "layout": [10, 6, 6, 6, 11, 8, 3, 3, 3, 9, 8, 3, 3, 3, 9, 8, 3, 3, 3, 9, 12, 7, 7, 7, 13], "free": {}},
	# Atlantis is all land; its walls and decorations are neutral.
	"100000023": {"title": "QUEST_MITICA", "goal": "POPUP_QUEST_ATLANTES", "family": Family.CIVILISATION, "gold": "QUEST_ISLA_ATLANTIS", "start": Vector2i(90, 90), "land": SEA, "layout": [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3], "free": {}, "neutral_subcats": [221, 411]},
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


## The island of the quest, or null when the port does not have the quest.
static func find(quest_id: String) -> QuestIsland:
	if not ISLANDS.has(quest_id):
		return null
	var data: Dictionary = ISLANDS[quest_id]
	var island := QuestIsland.new()
	island.id = quest_id
	island.title_text = data["title"]
	island.description_text = data["goal"]
	island.family = data["family"]
	island.gold_key = data["gold"]
	island.start_tile = data["start"]
	island.land_item = data["land"]
	island.layout.assign(data["layout"])
	island.free_units = data["free"]
	island.free_all_units.assign(data.get("free_all", []))
	island.neutral_subcats.assign(data.get("neutral_subcats", []))
	return island


static func is_in_port(quest_id: String) -> bool:
	return ISLANDS.has(quest_id)


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
