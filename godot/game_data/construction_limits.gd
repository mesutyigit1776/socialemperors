class_name ConstructionLimits
extends RefCounted
## Construction limits that the client contains as fixed values, not in the game
## configuration. The house limit per town hall is in the configuration
## (GameConfig.townhall_house_limit). Village.check_limits applies these values.

const SUBCAT_HOUSE := 111
const SUBCAT_TOWNHALL := 135
const SUBCAT_TOWER := 211
const BATHS := 230  ## A house that does not count for the house limit.

## Towers: at most this number per owned land area in total, and the land area
## of a new tower must contain fewer tower tiles than this number.
const MAX_TOWERS_PER_LAND_AREA := 10

## Item id -> maximum number of that item on a map. Each level of a mine or a
## mill is a different item, so a map can have Gold Mine I and Gold Mine II.
const MAX_PER_ITEM := {
	# Mines and mills, human and troll.
	13: 1, 14: 1, 15: 1, 203: 1, 315: 1, 316: 1, 317: 1,  # gold
	16: 1, 17: 1, 18: 1, 204: 1, 318: 1, 319: 1, 320: 1,  # stone
	77: 1, 78: 1, 79: 1, 205: 1, 312: 1, 313: 1, 314: 1,  # wood
	5: 1, 6: 1, 7: 1, 202: 1, 300: 1, 301: 1, 302: 1,  # food
	# Special buildings.
	22: 1, 24: 1, 25: 1, 150: 1, 151: 1, 197: 1, 212: 1, 218: 1, 220: 1, 221: 1,
	222: 1, 223: 1, 224: 1, 229: 1, 231: 1, 232: 1, 233: 1, 234: 1, 244: 1, 261: 1,
	262: 1, 266: 1, 271: 1, 299: 1, 325: 1, 343: 1, 344: 1, 352: 1, 363: 1, 366: 1,
	378: 1, 387: 1, 389: 1, 397: 1, 415: 1, 428: 1, 430: 1, 470: 1, 486: 1, 1232: 1,
	1233: 1, 1255: 1, 1283: 1, 1284: 1, 1299: 1, 1316: 1, 1345: 1, 1346: 1, 1372: 1,
	1394: 1, 1405: 1, 1441: 1, 1463: 1, 1499: 1,
	226: 3,  # Nursery
	1529: 2,  # Soul Mixer
}

## Groups of items of which a map can have at most one item in total.
const ONE_PER_GROUP: Array[Array] = [
	[11, 190, 191],  # sheep ranches
	[12, 192, 193],  # cow ranches
]

## Functional subcategories of which a map can have at most one building.
const ONE_PER_SUBCAT: Array[int] = [
	132,  # markets
	136,  # eagle buildings
]
