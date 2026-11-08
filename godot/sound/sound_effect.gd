class_name SoundEffect
extends RefCounted
## The sound effects of the client (SoundManager.SFX_*). The battle and the
## screens give one of these to SoundPlayer.play(); BattleSim.play_sound()
## sends the ones of the battle.

enum {
	ACHIEVEMENT, BUILDING_MENU, BUTTON_CLICK, COLLECTION, LEVEL_UP, NEW_TOWN, ROLL_OVER, READY_TO_COLLECT,
	ATTACK_SWORD, ATTACK_ARCHER, ATTACK_CANNON, ATTACK_BIG_ARCHER, ROCKDRILLER,
	LUMBER, STONE, CONSTRUCTING, CONSTRUCTION_END,
	DEAD_MALE, DEAD_FEMALE, DEAD_MECHANICAL, DEAD_TROLL,
	MOVEMENT_EAGLE, MOVEMENT_SHIP,
	MAGIC_HEAL, MAGIC_FIRE, MAGIC_PLOF,
	THREE_HEADED_ROAR_SMALL, THREE_HEADED_ROAR_BIG, THREE_HEADED_ENERGY_BALLS, THREE_HEADED_WHIRLWIND,
	THREE_HEADED_POISON, THREE_HEADED_BEAM, THREE_HEADED_MOVE, THREE_HEADED_DEATH,
}

## Effect -> the sounds of the library of the client, by the name of their
## class (<data>/sound/sfx/<name>.mp3); the client plays one of them at random.
const FILES := {
	ACHIEVEMENT: ["AchievementSound"], BUILDING_MENU: ["BuildingMenuSound"], BUTTON_CLICK: ["ButtonClickSound"],
	COLLECTION: ["Collection2Sound"], LEVEL_UP: ["LevelUpSound"], NEW_TOWN: ["NewTownSound"],
	ROLL_OVER: ["RollOverSound"], READY_TO_COLLECT: ["FarmSound"],
	ATTACK_SWORD: ["Sword2Sound", "Sword5Sound"], ATTACK_ARCHER: ["Archer3Sound"], ATTACK_CANNON: ["CanonSound"],
	ATTACK_BIG_ARCHER: ["BallestaSound"], ROCKDRILLER: ["RockdrillerSound"],
	LUMBER: ["Lumber3Sound"], STONE: ["Rock6Sound"], CONSTRUCTING: ["BuildSound"], CONSTRUCTION_END: ["FinalConstruc1Sound"],
	DEAD_MALE: ["DieManSound"], DEAD_FEMALE: ["DieWomanSound"], DEAD_MECHANICAL: ["CatapMuerteSound"], DEAD_TROLL: ["MuerteTrol2Sound"],
	MOVEMENT_EAGLE: ["Aguila1Sound"], MOVEMENT_SHIP: ["Barco2Sound"],
	MAGIC_HEAL: ["CurarSound"], MAGIC_FIRE: ["FireballSound"], MAGIC_PLOF: ["BallSound"],
	THREE_HEADED_ROAR_SMALL: ["ThreeHeaded_GroarSmall"], THREE_HEADED_ROAR_BIG: ["ThreeHeaded_GroarBig"],
	THREE_HEADED_ENERGY_BALLS: ["ThreeHeaded_EnergyBalls"], THREE_HEADED_WHIRLWIND: ["ThreeHeaded_Whirlwind"],
	THREE_HEADED_POISON: ["ThreeHeaded_Poison"], THREE_HEADED_BEAM: ["ThreeHeaded_Beam"],
	THREE_HEADED_MOVE: ["ThreeHeaded_Move"], THREE_HEADED_DEATH: ["ThreeHeaded_Dead"],
}

## The number of copies of an effect that can play at the same time; others
## are not played (SoundManager.setSfxLimits). Other effects: 3.
const LIMITS := {
	ATTACK_SWORD: 5, ATTACK_ARCHER: 8, ATTACK_BIG_ARCHER: 5, ROCKDRILLER: 1, STONE: 2,
	CONSTRUCTING: 1, CONSTRUCTION_END: 2, MOVEMENT_SHIP: 1, MOVEMENT_EAGLE: 1,
}
const DEFAULT_LIMIT := 3
## The client plays the sound of a construction 9 times in a row.
const REPEATS := {CONSTRUCTING: 8}


static func limit(effect: int) -> int:
	return LIMITS.get(effect, DEFAULT_LIMIT)
