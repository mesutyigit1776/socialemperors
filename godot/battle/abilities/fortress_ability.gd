class_name FortressAbility
extends BattleAbility
## The Fortress (FortressDelegate of the client). It fires a cannonball at its
## target with its attack, and each unit in it (BattleFighter.units_inside)
## fires an arrow of ARROW_DAMAGE at a target of its own at the same time.
##
## Each unit keeps its target while that target is on the map and within half
## the range of the Fortress. A unit without a target takes the next of the
## nearest opponents of the Fortress (units or buildings, at most one for each
## unit in it) around the centre of the Fortress, within its range plus half
## its width. As in the client, two units can take the same target, the check
## stops when no new target is left, and a unit does not shoot at a dead target.
## The arrow of unit n starts at the place "unit<n>" of the graphic of the
## Fortress, where the client shows the unit.

const ARROW_DAMAGE := 1
const ARROW := "p.arrow"

var _targets: Array[BattleFighter] = []


func configure(_item_id: int) -> void:
	shot_graphic = "p.cannonBall"


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var count := fighter.units_inside
	if count <= 0:
		return true
	_targets.resize(count)
	var half_width := roundi(fighter.def.width / 2.0)
	var centre := fighter.tile - Vector2i(half_width, half_width)
	var found := sim.items_near(centre, fighter.attack_range + half_width, count, enemy_side(fighter), false, func(item: BattleFighter) -> bool:
		return not item.dead and item.is_valid_target())
	var next := 0
	for i in count:
		if next >= found.size():
			break
		var kept := _targets[i]
		if kept != null and (not kept in sim.fighters or sim.distance(fighter, kept) > fighter.attack_range / 2.0):
			kept = null
		if kept == null:
			kept = found[next]
			next += 1
		_targets[i] = kept
	for i in _targets.size():
		var target := _targets[i]
		if target != null and not target.dead:
			var place: Variant = fighter.graphic.named_point("unit%d" % (i + 1)) if fighter.graphic != null else null
			sim.shoot(fighter, target, ARROW, ARROW_DAMAGE, Callable(), place)
	return true
