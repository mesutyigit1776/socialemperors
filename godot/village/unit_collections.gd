class_name UnitCollections
extends RefCounted
## The units that the unit list counts for the unit collections
## (GameConfig.unit_collections), as the client's UnitCollectionsManager
## counts them: when the town loads, the units of "boughtUnits" and the units
## of the player on the map; after that, each unit of the player that comes on
## the map (VillageEvent.Kind.UNIT_ARRIVED). A unit that goes into the item
## store counts only after the next load or when it comes on the map.
##
## Five units are in two collections. The client counts them once in the units
## that the player has and twice in the total, so the list cannot show all
## units as obtained; the port shows the same numbers.

var _village: Village
var _config: GameConfig
var _counted: Dictionary = {}  # unit id -> true, only for units of the collections
var _in_collections: Dictionary = {}  # unit id -> true
var _total := 0


func _init(config: GameConfig, village: Village) -> void:
	_config = config
	_village = village
	for collection in config.unit_collections:
		_total += collection["units"].size()
		for id: int in collection["units"]:
			_in_collections[id] = true
	for id in village.bought_units():
		_count(id)
	for placed in village.items:
		if village.is_own_unit(placed):
			_count(placed.item_id)


## The number of units in all collections.
func total() -> int:
	return _total


## The number of different units of the collections that the player has.
func owned_count() -> int:
	return _counted.size()


func is_owned(unit_id: int) -> bool:
	return _counted.has(unit_id)


func owned_in(collection: Dictionary) -> int:
	return collection["units"].filter(func(id: int) -> bool: return _counted.has(id)).size()


func is_complete(collection: Dictionary) -> bool:
	return owned_in(collection) == collection["units"].size()


func is_claimed(collection: Dictionary) -> bool:
	return collection["id"] in _village.unit_collections_claimed()


## Takes the reward of a complete collection; NOT_ALLOWED when the collection
## is not complete or the player took the reward before.
func claim(collection: Dictionary) -> Village.Placement:
	if not is_complete(collection):
		return Village.Placement.NOT_ALLOWED
	return _village.claim_unit_collection(collection["id"])


## Counts a unit of the player that came on the map. Returns true when the unit
## was not counted before and completes the first collection that has it, and
## the player did not take the reward of that collection: the client then
## tells the player to take the reward.
func add_unit(unit_id: int) -> bool:
	if _counted.has(unit_id) or not _in_collections.has(unit_id):
		return false
	_count(unit_id)
	for collection in _config.unit_collections:
		if unit_id in collection["units"]:
			return is_complete(collection) and not is_claimed(collection)
	return false


func _count(unit_id: int) -> void:
	if _in_collections.has(unit_id):
		_counted[unit_id] = true
