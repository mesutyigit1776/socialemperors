class_name VillageEvent
## The things that the player does in the village and that the goals of the
## client count, see GoalBook. The village model sends most of them with
## VillageMap.happened; the screens send the others (windows, zoom,
## selection, battles) to GoalBook.record().
##
## The data of an event has the values that a goal compares:
## "item", "building", "unit": item ids; "amount"; "code": a resource code;
## "quest": a quest id; "stars": the stars of a won quest; "window": the name
## of the client's window, for example "popups.popupCollections".

enum Kind {
	BUILT,  ## item: a building came on the map (bought, placed from the store, or there when the map loads).
	TRAINED,  ## building, unit: a building trained a unit, or the stables mounted one.
	PUSHED,  ## building, unit: a unit went into a building.
	PULLED,  ## building, unit: a unit came out of a building.
	COLLECTED,  ## item: the player collected from a building or harvested a resource.
	TIME_SELECTED,  ## building, amount: the work time of a mill or mine in minutes.
	CAPTURED,  ## unit: a wild animal.
	KILLED,  ## unit: an enemy unit died in the village.
	QUEST_WON,  ## quest, stars
	STORED,  ## item: the player put an item of the map in the item store.
	LAND_BOUGHT,  ## amount: the number of land areas that the map has now.
	MARKET_TRADED,  ## code, amount: the resource that the market gave (> 0) or took (< 0).
	RESOURCE_CHANGED,  ## code, amount
	WINDOW_OPENED,  ## window
	ZOOMED,  ## One step of the mouse wheel.
	NEST_FED,  ## One care step of the dragon nest.
	DOUBLE_CLICKED,  ## A double click selected the units of a kind.
	RENAMED,  ## The player named the empire.
	MOVED,  ## item: the player moved a building.
	PACK_BOUGHT,  ## amount: the unit packs that the player bought until now.
	SOULS_MIXED,  ## The Soul Mixer started a new unit.
	SELECTION_TOOL_USED,
	FIRE_PUT_OUT,  ## A unit put out the fire of a building.
	TOWER_KILLED_BY_SCORPION,
	SACRIFICED,  ## unit
	CONVERTED,  ## A monk converted an enemy unit.
	HEALED,  ## A healing spring healed a unit.
	SOCIAL_BUILDING_OPENED,  ## item: a building with workers opened, or an allies market gave its resources.
	WORKERS_HIRED,  ## item, amount: the building has this number of hired workers.
	FRIEND_VISITED,  ## pid: the player visited the neighbour.
	FRIEND_ASSISTED,  ## The player helped a building of a neighbour.
	ASSAULT_STARTED,  ## level: the player attacked another player of this level.
	ASSAULT_WON,  ## amount: the attacks that the player won until now.
	UNIT_ARRIVED,  ## unit: a unit of the player came on the map (bought, placed from the store, trained, out of a building or from a special building). The goals do not count it; the unit list does.
}
