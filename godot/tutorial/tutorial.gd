class_name Tutorial
extends RefCounted
## The tutorial of the client (TutorialMain) for a new empire: the player does
## what each step asks, and the step goes on. The save keeps the last step in
## playerInfo "completed_tutorial" (Village.set_tutorial_step()), as the
## command "complete_tutorial" of the client does at each step; the tutorial
## runs only while it is 0, on the first map.
##
## Steps 0 to 13 show a box with a title and a lesson. When the troll dies at
## step 13, the client goes on to step 15: step 14, the congratulations, does
## not show. Steps 15 to 31 show only the arrow of the client, which leads
## through the first goals: build a farm, train a villager, send it to the
## farm, collect the food, and cut three trees. The port shows its own short
## text for these steps. After the third tree, the tutorial ends and the
## client gives a dragon nest.
##
## While the tutorial runs, the client lets the player do only what the step
## asks: see the allows_*() functions.

signal step_changed(step: int)
signal finished

enum Action {
	BOX_BUTTON,  ## The button of a box that has one (steps 0 and 14).
	SELECTED,  ## item: the player selected an item of the map.
	TRAINING_STARTED,  ## item: the unit.
	UNIT_ORDERED,  ## item: the target of the walk, or null.
	ATTACK_ORDERED,
	HARVEST_DONE,
	BUILD_ITEM_CHOSEN,  ## item
	PLACED,  ## item
	ENEMY_KILLED,
	GOAL_BOX,  ## The player clicked the goal box.
	GOAL_WINDOW_CLOSED,
	FARM_READY,
	COLLECTED,  ## item
	TREE_HARVESTED,
}

const LAST_STEP := 31
const SUBCAT_TOWN_HALL := 135
const SUBCAT_PEASANT := 71
const SUBCAT_TREE := 125
const SUBCAT_FARM := 122
const HOUSE := 1
const FARM_LAND := 10
const KNIGHT := 512
## The client places the house and the farm of the tutorial only on these tiles.
const PLACE_TILES := {10: Vector2i(55, 55), 19: Vector2i(52, 44)}
## The trees that step 31 marks; the tutorial ends after TREES_TO_CUT trees.
const MARKED_TREES: Array[Vector2i] = [Vector2i(43, 54), Vector2i(44, 54), Vector2i(45, 54)]
const TREES_TO_CUT := 3
## In step 26 the farm produces this much faster.
const FARM_SPEED := 11
## The goals whose window the goal box opens at steps 15, 20 and 28.
const STEP_GOALS := {15: 1, 20: 2, 28: 5}
## Steps with a box: [title text, lesson text, has a button].
const BOXES := {
	0: ["TUTORIAL_INTRO_TITULO", "TUTORIAL_INTRO_LECCION", true],
	1: ["TUTORIAL_AYTO_TITULO", "TUTORIAL_AYTO_LECCION", false],
	2: ["TUTORIAL_ALDEANO_TITULO", "TUTORIAL_ALDEANO_LECCION", false],
	3: ["TUTORIAL_SELECCIONAR_ALDEANO_TITULO", "TUTORIAL_SELECCIONAR_ALDEANO_LECCION", false],
	4: ["TUTORIAL_MOVER_ALDEANO_TITULO", "TUTORIAL_MOVER_ALDEANO_LECCION", false],
	5: ["TUTORIAL_ARBOL_TITULO", "TUTORIAL_ARBOL_LECCION", false],
	6: ["TUTORIAL_ESPERA_TITULO", "TUTORIAL_ESPERA_LECCION", false],
	7: ["TUTORIAL_RECOLECCION_TITULO", "TUTORIAL_RECOLECCION_LECCION", false],
	8: ["TUTORIAL_CONSTRUIR_TITULO", "TUTORIAL_CONSTRUIR_LECCION", false],
	9: ["TUTORIAL_CASA_TITULO", "TUTORIAL_CASA_LECCION", false],
	10: ["TUTORIAL_COLOCAR_TITULO", "TUTORIAL_COLOCAR_LECCION", false],
	11: ["TUTORIAL_CABALLERO_TITULO", "TUTORIAL_CABALLERO_LECCION", false],
	12: ["TUTORIAL_ATACAR_TITULO", "TUTORIAL_ATACAR_LECCION", false],
	13: ["TUTORIAL_BATALLA_TITULO", "TUTORIAL_BATALLA_LECCION", false],
	14: ["TUTORIAL_ENHORABUENA_TITULO", "TUTORIAL_ENHORABUENA_LECCION", true],
}
## The port's text for the steps that show only the arrow in the client.
const ARROW_TEXTS := {
	15: "Click the first goal in the goal box.",
	17: "Build a Farm Land: choose it in the build menu.",
	18: "Build a Farm Land: choose it in the build menu.",
	19: "Place the farm on the marked place.",
	20: "Click the goal box again.",
	21: "Close the goal window.",
	22: "Select your Town Hall.",
	23: "Train a villager.",
	24: "Select the new villager.",
	25: "Click the farm to send the villager into it.",
	26: "Wait until the farm is ready.",
	27: "Click the farm to collect the food.",
	28: "Click the goal box again.",
	29: "Close the goal window.",
	30: "Select a villager.",
	31: "Send villagers to cut the three marked trees.",
}

var step := 0
var _active := false
var _village: Village
var _config: GameConfig
var _trees_cut := 0


func _init(village: Village, config: GameConfig) -> void:
	_village = village
	_config = config
	_active = village.tutorial_step() == 0 and village.is_first_map()


func is_active() -> bool:
	return _active


## [title, lesson, page, has a button] of the box of the step, or [] when the step has no box.
func box() -> Array:
	if not BOXES.has(step):
		return []
	var entry: Array = BOXES[step]
	var host := _config.text("TUTORIAL_HOST_NAME_MALE")
	var page := _config.text("POPUP_TUTORIAL_PAGINA").replace("#0#", str((step + 1) / 2)).replace("#1#", "7")
	return [_config.text(entry[0]), _config.text(entry[1]).replace("#0#", host), page, entry[2]]


func arrow_text() -> String:
	return ARROW_TEXTS.get(step, "")


## The tile that the step marks on the map, or Village.ANY_TILE.
func marked_tile() -> Vector2i:
	return PLACE_TILES.get(step, Village.ANY_TILE)


## The items that the arrow of the client points at in this step.
func marked_items() -> Array[Village.PlacedItem]:
	var result: Array[Village.PlacedItem] = []
	for placed in _village.items:
		var item := _config.get_item(placed.item_id)
		if item == null:
			continue
		var subcat := item.subcat_functional
		var marked := false
		match step:
			1, 22:
				marked = subcat == SUBCAT_TOWN_HALL
			3, 24, 30:
				marked = subcat == SUBCAT_PEASANT and _village.is_own_unit(placed)
			5:
				marked = subcat == SUBCAT_TREE and placed.tile in MARKED_TREES
			11:
				marked = item.id == KNIGHT
			12:
				marked = _village.is_enemy_unit(placed)
			25, 26, 27:
				marked = subcat == SUBCAT_FARM
			31:
				marked = placed.tile in MARKED_TREES and subcat == SUBCAT_TREE
		if marked:
			result.append(placed)
	return result


## The goal whose window opens when the player clicks the goal box now, or 0.
func goal_for_box() -> int:
	return STEP_GOALS.get(step, 0)


## The player did something; the step goes on when it is what the step asks.
func handle(action: Action, item: GameConfig.ItemDef = null) -> void:
	if not _active:
		return
	var subcat := item.subcat_functional if item != null else -1
	match [step, action]:
		[0, Action.BOX_BUTTON], [14, Action.BOX_BUTTON]:
			_next()
		[1, Action.SELECTED], [22, Action.SELECTED]:
			if subcat == SUBCAT_TOWN_HALL:
				_next()
		[3, Action.SELECTED], [24, Action.SELECTED], [30, Action.SELECTED]:
			if subcat == SUBCAT_PEASANT:
				_next()
		[2, Action.TRAINING_STARTED], [23, Action.TRAINING_STARTED]:
			if subcat == SUBCAT_PEASANT:
				_next()
		[4, Action.UNIT_ORDERED]:
			_next()
		[5, Action.UNIT_ORDERED]:
			if subcat == SUBCAT_TREE:
				_next()
		[25, Action.UNIT_ORDERED]:
			if subcat == SUBCAT_FARM:
				_next()
		[6, Action.HARVEST_DONE]:
			# The client goes on when the player picks up the wood; the port
			# gives the wood with the harvest.
			_next()
			_next()
		[8, Action.BUILD_ITEM_CHOSEN], [9, Action.BUILD_ITEM_CHOSEN]:
			if item.id == HOUSE:
				while step < 10:
					_next()
		[17, Action.BUILD_ITEM_CHOSEN], [18, Action.BUILD_ITEM_CHOSEN]:
			if item.id == FARM_LAND:
				while step < 19:
					_next()
		[10, Action.PLACED], [19, Action.PLACED]:
			_next()
		[11, Action.SELECTED]:
			if item.id == KNIGHT:
				_next()
		[12, Action.ATTACK_ORDERED]:
			_next()
		[13, Action.ENEMY_KILLED]:
			step += 1
			_next()
		[15, Action.GOAL_BOX]:
			# The click opens the window of the first goal, which is step 16.
			_next()
			_next()
		[20, Action.GOAL_BOX], [28, Action.GOAL_BOX], [21, Action.GOAL_WINDOW_CLOSED], [29, Action.GOAL_WINDOW_CLOSED], [26, Action.FARM_READY]:
			_next()
		[27, Action.COLLECTED]:
			if subcat == SUBCAT_FARM:
				_next()
		[31, Action.TREE_HARVESTED]:
			_trees_cut += 1
			if _trees_cut >= TREES_TO_CUT:
				_active = false
				finished.emit()


## The player can select this item now. At most steps, the client lets the
## player select only the item that the step asks for.
func allows_select(item: GameConfig.ItemDef, enemy: bool) -> bool:
	if not _active or item == null:
		return true
	match step:
		1, 22:
			return item.subcat_functional == SUBCAT_TOWN_HALL
		3, 24, 30:
			return item.subcat_functional == SUBCAT_PEASANT
		5:
			# The port deselects a unit after an order; the client keeps it selected.
			return item.subcat_functional in [SUBCAT_TREE, SUBCAT_PEASANT]
		6, 7:
			return item.subcat_functional == SUBCAT_TREE
		11:
			return item.id == KNIGHT
		12:
			return enemy
		25, 27:
			return item.subcat_functional == SUBCAT_FARM
		31:
			return item.subcat_functional in [SUBCAT_TREE, SUBCAT_PEASANT]
	return false


## The client trains only villagers, and only at steps 2 and 23.
func allows_training(unit: GameConfig.ItemDef) -> bool:
	return not _active or (step in [2, 23] and unit.subcat_functional == SUBCAT_PEASANT)


## Units walk only at the steps that ask for it.
func allows_orders() -> bool:
	return not _active or step in [2, 4, 5, 12, 25, 26, 31]


## The build menu works only at the steps that build, and only for their item.
func allows_build(item: GameConfig.ItemDef) -> bool:
	if not _active:
		return true
	match step:
		8, 9, 10:
			return item.id == HOUSE
		17, 18, 19:
			return item.id == FARM_LAND
	return false


func allows_place(tile: Vector2i) -> bool:
	return not _active or not PLACE_TILES.has(step) or tile == PLACE_TILES[step]


## The other windows and buttons of the village wait until the tutorial ends.
func allows_other() -> bool:
	return not _active


func _next() -> void:
	step += 1
	_village.set_tutorial_step(step)
	step_changed.emit(step)
