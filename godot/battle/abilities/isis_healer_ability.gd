class_name IsisHealerAbility
extends BattleAbility
## The healers whose normal attack heals their target by their attack, with
## stars on the target.
##
## - The Isis Healer (IsisHealerDelegate of the client) heals by twice its
##   attack in its special animation.
## - The Megahealing Angel (AngelicalSuperHealerDelegate) also shows stars on
##   its own tile. Its limit button is in special_units/heroes.gd.

const ANGEL := 886

var _angel := false


func configure(item_id: int) -> void:
	_angel = item_id == ANGEL
	if not _angel:
		special_intervals = [240]
		special_durations = [120]


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	if target != null and target.is_unit():
		sim.heal(target, fighter.attack * (2 if not _angel and in_special(fighter, 0) else 1), fighter)
		# As in the client, the stars give an attack of 0 to an enemy on their tile.
		sim.particle(fighter, target.tile, MagicParticles.STARS, 0, 0)
		if _angel:
			sim.particle(fighter, fighter.tile, MagicParticles.STARS, 0, 0)
	return false
