class_name TopoAbility
extends BattleAbility
## The Mole (TopoDelegate of the client), a ranged unit that hits like a melee
## unit.
##
## - Its special attack (every 280 frames, for 90 frames) opens cracks on
##   about a tenth of the tiles within 5 tiles of it, later with the distance
##   (3 frames for each tile). Each crack swallows one unit next to it, like
##   the Hell Abyss spell with an area of 1. The client looks for these units
##   on the enemy side of the battle, also when the mole is an enemy; the port
##   does the same. A crack is the hole of the Hell Abyss at 0.4 of its size
##   (MagicParticleSpell with the asset of the spell of the Mole); like the
##   hole of the spell, it stays at its last frame.
## - Each normal attack on a unit pushes it 2 tiles away.

const RANGE := 5
const CHANCE := 0.1
const DELAY_PER_TILE := 3
const CRACK_ATTACK_FRAME := 10  ## BattleSpell.DEFAULT_ATTACK_FRAME
const HELL_ABYSS := 7  ## The spell of the Mole (SpellCrack).
const CRACK_LOOK := {"scale": 0.4, "frames": -1}

var _in_special := false


func _init() -> void:
	ranged_melee = true
	special_intervals = [280]
	special_durations = [90]


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if in_special(fighter, 0):
		if not _in_special:
			_in_special = true
			_cracks(sim, fighter)
		return false
	if fighter.target.is_unit():
		sim.push_in_air(fighter.target, fighter, 2)
	_in_special = false
	return true


func _cracks(sim: BattleSim, fighter: BattleFighter) -> void:
	# Only the view uses the spell: it draws the cracks.
	var abyss := sim.unit_spell(HELL_ABYSS)
	for dx in range(-RANGE, RANGE + 1):
		for dy in range(-RANGE, RANGE + 1):
			var tile := fighter.tile + Vector2i(dx, dy)
			if sim.rng.randf() > CHANCE or tile.x <= 0 or tile.y <= 0 or tile.x >= IsoGrid.MAP_TILES or tile.y >= IsoGrid.MAP_TILES:
				continue
			if abyss != null:
				abyss.show_particle(sim, tile, (absi(dx) + absi(dy)) * DELAY_PER_TILE, CRACK_LOOK)
			sim.after((absi(dx) + absi(dy)) * DELAY_PER_TILE + CRACK_ATTACK_FRAME, func() -> void:
				for unit in sim.items_near(tile, 1, 1, BattleFighter.Team.ENEMY, true, _can_fall):
					sim.swallow(unit))


static func _can_fall(item: BattleFighter) -> bool:
	return item.is_unit() and not item.dead and item.def.subcat_functional != BattleSim.SUBCAT_BOSS
