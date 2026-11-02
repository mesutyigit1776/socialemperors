class_name ShotAbility
extends BattleAbility
## The abilities of the client that only change the shots or other fixed
## properties of a unit: the graphic of its shots, the delay of a shot after
## the attack, beams, a ranged unit that hits like a melee unit, the size of
## its graphic, and the effects that do not act on it.

## Item id -> properties: "shot" (graphic in <data>/fx), "delay" (frames),
## "beam" (frames until a beam hurts), "melee" (true: ranged_melee), "scale",
## "immune" (true: push, freeze, poison, swallow, conversion and stun do not act),
## "cycle" ([intervals, durations] of a cycle of special animations; the unit
## does not attack while one plays, as in the client).
const UNITS := {
	818: {"shot": "p.arrow", "delay": 5},  # Skeleton Archer (ArcherSkeletonDelegate)
	850: {"shot": "p.lightBall", "delay": 12},  # Bahamut Draggy
	790: {"shot": "p.crystalBall", "delay": 10},  # Crystal Draggy
	890: {"shot": "p.crystalBall", "delay": 12},  # Pharaoh Draggy (EgyptianDraggyDelegate)
	# Castle III (FireCastleDelegate): fire arrows. The client also draws a
	# stream of fire arrows without damage while the castle keeps its target;
	# the port does not draw it.
	198: {"shot": "p.fireArrow"},
	785: {"shot": "p.bullDragonBeam", "delay": 13, "beam": 30},  # Furious Bull Dragon
	778: {"shot": "p.zeusLightning", "delay": 6, "scale": 0.8},  # God Zeus
	828: {"shot": "p.zeusLightning", "delay": 6, "scale": 0.8},  # Furious Zeus
	710: {"shot": "p.lightMiniBeam"},  # Golden Draggie (GoldenDragonDelegate)
	765: {"melee": true},  # Hades
	784: {"shot": "p.energyBallBullDragon", "delay": 12},  # Horned Draggy
	705: {"shot": "p.lance", "cycle": [[105], [35]]},  # Celestial Lancer (LancerDelegate)
	2101: {"melee": true},  # Medieval Ether Messiah
	2102: {"melee": true},  # Medieval Samurai
	# Rodas Colossus: it hits like a melee unit, so its light beam never leaves.
	764: {"melee": true},
	813: {"shot": "p.fireBall_02", "delay": 10},  # Rubies Draggy
	782: {"shot": "p.spike", "melee": true},  # Spiky Spider
	779: {"shot": "p.ulisesArrow", "delay": 10},  # Ulysses
	849: {"shot": "p.lavaBall_01", "delay": 10},  # Volcano Draggy
}

func configure(item_id: int) -> void:
	var data: Dictionary = UNITS.get(item_id, {})
	shot_graphic = data.get("shot", "")
	shot_delay = data.get("delay", 0)
	if data.has("beam"):
		beam = true
		beam_frames = data["beam"]
	ranged_melee = data.get("melee", false)
	if data.has("cycle"):
		special_intervals.assign(data["cycle"][0])
		special_durations.assign(data["cycle"][1])
	scale = data.get("scale", 1.0)
	if data.get("immune", false):
		immune_to_push = true
		immune_to_freeze = true
		immune_to_poison = true
		immune_to_swallow = true
		immune_to_conversion = true
		immune_to_stun = true

