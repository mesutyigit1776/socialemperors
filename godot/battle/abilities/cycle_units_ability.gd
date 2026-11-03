class_name CycleUnitsAbility
extends BattleAbility
## Units whose delegates give them a cycle of special animations (see
## BattleAbility.special_intervals); while a special animation plays, an
## attack is the special attack.
##
## - amazon (AmazonDelegate): a whirlwind: at frame 41 and then once a second,
##   5 times, the samurai whirlwind of the client (3 tiles).
## - archangel_ii (Arcangel2Delegate): three special attacks in turn: 0.3
##   seconds later the target takes twice the attack; a whirlwind like the
##   Amazon's from frame 14; 2 seconds without acting, then it heals itself by
##   100.
## - valkyrie_ii (ValkyrDelegate): the aura of Wallace (see HeroAbility).
## - werewolf (WarewolfDelegate): a target unit that is not a boss and can be
##   converted becomes a werewolf of its side with 300 life, which is poisoned
##   (half the attack a second until it dies) and does not convert others.
##   The normal attack pushes a target unit 1 tile one time in two.
## - winged_knight (WingedKnightDelegate): on each tile within 2 tiles, not its
##   own, the enemy unit takes the attack and flies 0 to 7 tiles, once in each
##   special animation.
## - gryphon (GryphonDelegate): at frame 30, the 4 nearest enemies in range,
##   not on its tile, take half the attack, and units fly 2 tiles.
## - white_mage (WhiteMageDelegate): a light beam (12 frames, 1 second) that
##   holds the target with electricity for 1 second; the special attack heals
##   the own soldiers within 2 tiles by its attack.
## - black_mage (BlackMageDelegate): a skull (11 frames); the special attack
##   brings black mage skeletons (item 718) until 3 are alive.
## - water_wizard (WaterWizardDelegate): a water beam (11 frames, 1 second); the
##   special attack brings a hurricane (item 728) for 20 seconds, one at a time.
## - big_zombie (BigZombieDelegate): hits like a melee unit. Special attack 1
##   casts the Poisonous Flood with a side of 2 tiles on the tile 2 tiles in
##   front of it, at the level of the player; special attack 2 throws its head at
##   the target, which flies 2 tiles; it cannot act until the head is back.
## - evil_black_dragon (EvilBlackDragonDelegate): a red electric beam (12
##   frames, 1 second); the special attack throws an egg with a Black Draggy
##   (item 725) while fewer than 3 are alive. No state, push or swallow acts
##   on it.

const UNITS := {
	721: "amazon",
	724: "archangel_ii",
	759: "valkyrie_ii",
	735: "werewolf",
	662: "winged_knight",
	700: "gryphon",
	706: "white_mage",
	712: "black_mage",
	727: "water_wizard",
	707: "big_zombie", 738: "big_zombie",
	740: "evil_black_dragon",
}
## Item id -> [intervals, durations] of the cycle.
const CYCLES := {
	"amazon": [[150], [20]],
	"archangel_ii": [[100, 100, 100], [30, 30, 30]],
	"valkyrie_ii": [[140], [70]],
	"werewolf": [[200], [70]],
	"winged_knight": [[105], [35]],
	"gryphon": [[105], [70]],
	"white_mage": [[105], [35]],
	"black_mage": [[105], [35]],
	"water_wizard": [[105], [35]],
	"big_zombie": [[70, 70], [35, 35]],
	"evil_black_dragon": [[35], [16]],
}
const SP1 := UnitSprite.Action.SPECIAL
const SP2 := SP1 + 1
const SKELETON := 718
const HURRICANE := 728
const HURRICANE_SECONDS := 20
const BLACK_DRAGGY := 725
const ZOMBIE_STEPS := {1: Vector2i(-2, -2), 2: Vector2i(0, -2), 3: Vector2i(2, -2), 4: Vector2i(2, 0), 5: Vector2i(2, 2), 6: Vector2i(-2, 0), 7: Vector2i(-2, -2), 8: Vector2i(0, 2)}
const POISON_FLOOD := 8

var _kind := ""
var _busy_special := false  # The special attack of this special animation has started.
var _converted := false  # A werewolf that a werewolf made.
var _skeletons: Array[BattleFighter] = []


func configure(item_id: int) -> void:
	_kind = UNITS[item_id]
	special_intervals.assign(CYCLES[_kind][0])
	special_durations.assign(CYCLES[_kind][1])
	match _kind:
		"winged_knight", "big_zombie":
			ranged_melee = true
		"white_mage":
			shot_graphic = "p.lightBeam"
			shot_delay = 12
			beam = true
			beam_frames = BattleSim.FRAMES_PER_SECOND
		"black_mage":
			shot_graphic = "p.ghostlySkull"
			shot_delay = 11
		"water_wizard":
			shot_graphic = "p.beamWater"
			shot_delay = 11
			beam = true
			beam_frames = BattleSim.FRAMES_PER_SECOND
		"evil_black_dragon":
			shot_graphic = "p.electricityRedBeam"
			shot_delay = 12
			beam = true
			beam_frames = BattleSim.FRAMES_PER_SECOND
			immune_to_push = true
			immune_to_freeze = true
			immune_to_burn = true
			immune_to_poison = true
			immune_to_electricity = true
			immune_to_swallow = true
			immune_to_conversion = true


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	if fighter.animation != BattleFighter.Pose.SPECIAL:
		_busy_special = false
		return _normal(sim, fighter, target)
	if _busy_special:
		return false
	match _kind:
		"amazon":
			_busy_special = true
			_whirlwind(sim, fighter, 41)
		"archangel_ii":
			_busy_special = true
			match fighter.special_index:
				0:
					sim.after(9, func() -> void:
						if not fighter.dead and fighter.target != null and not fighter.target.dead:
							sim.receive_attack(fighter.target, fighter.attack * 2, fighter))
				1:
					_whirlwind(sim, fighter, 14)
				_:
					SpecialUnit.show_particle(sim, fighter, fighter.tile, MagicParticles.STARS)
					sim.play_special(fighter, SP1 + 2, 2 * BattleSim.FRAMES_PER_SECOND, {}, func() -> void: sim.heal(fighter, 100, fighter), true)
		"valkyrie_ii":
			_busy_special = true
			SpecialUnit.show_particle(sim, fighter, fighter.tile, MagicParticles.AURA_WALLACE)
			HeroAbility.wallace_aura(sim, fighter)
		"werewolf":
			if not _converted:
				_busy_special = true
				_convert(sim, fighter, target)
		"winged_knight":
			_busy_special = true
			for y in range(-2, 3):
				for x in range(-2, 3):
					if x == 0 and y == 0:
						continue
					var found := sim.items_near(fighter.tile + Vector2i(x, y), 0, 1, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
						return not item.dead and item.is_valid_target())
					if not found.is_empty() and found[0].is_unit():
						sim.receive_attack(found[0], fighter.attack, fighter)
						if not found[0].dead:
							sim.push_in_air(found[0], fighter, int(2 * sim.rng.randf() * 4))
		"gryphon":
			_busy_special = true
			sim.after(30, func() -> void:
				if fighter.dead:
					return
				for enemy in sim.items_near(fighter.tile, fighter.attack_range, 4, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return not item.dead):
					sim.receive_attack(enemy, fighter.attack / 2, fighter)
					if enemy.is_unit() and not enemy.dead:
						sim.push_in_air(enemy, fighter, 2))
		"white_mage":
			_busy_special = true
			for ally in HeroAbility._aura_units(sim, fighter, 2):
				sim.heal(ally, fighter.attack, fighter)
				SpecialUnit.show_particle(sim, fighter, ally.tile, MagicParticles.STARS)
		"black_mage":
			_busy_special = true
			_skeletons = _skeletons.filter(func(skeleton: BattleFighter) -> bool: return not skeleton.dead and skeleton in sim.fighters)
			while _skeletons.size() < 3:
				var skeleton := sim.spawn(sim.config_item(SKELETON), fighter.tile, fighter.team)
				if skeleton == null:
					break
				SpecialUnit.show_particle(sim, fighter, skeleton.tile, MagicParticles.LIGHTNING)
				_skeletons.append(skeleton)
		"water_wizard":
			_busy_special = true
			var hurricane := sim.spawn(sim.config_item(HURRICANE), fighter.tile, fighter.team)
			if hurricane != null:
				sim.after(HURRICANE_SECONDS * BattleSim.FRAMES_PER_SECOND, func() -> void:
					if hurricane in sim.fighters:
						sim.remove_item(hurricane))
		"big_zombie":
			_busy_special = true
			if fighter.special_index == 0:
				var flood := sim.unit_spell(POISON_FLOOD) as PoisonFloodSpell
				if flood != null:
					flood.poison_at(sim, fighter.tile + ZOMBIE_STEPS[direction(fighter)], 2, sim.unit_spell_level(POISON_FLOOD), enemy_side(fighter))
			elif target != null and not target.dead:
				fighter.incapacitated = true
				sim.shoot(fighter, target, "p.zombieHead", fighter.attack, func(_shot: BattleProjectile) -> void:
					if target.is_unit() and not target.dead:
						sim.push_in_air(target, fighter, 2)
					sim.after(15, func() -> void:
						if not fighter.dead:
							fighter.incapacitated = fighter.frozen or fighter.stunned or fighter.in_air))
		"evil_black_dragon":
			if minions_alive < 3:
				_busy_special = true
				SpecialUnit.egg_minion(sim, fighter, BLACK_DRAGGY)
	return false


func _normal(sim: BattleSim, fighter: BattleFighter, target: BattleFighter) -> bool:
	if target == null or target.dead:
		return true
	match _kind:
		"werewolf":
			if not _converted and target.is_unit() and sim.rng.randf() < 0.5:
				sim.push_in_air(target, fighter, 1, 15)
		"white_mage":
			sim.after(shot_delay, func() -> void:
				if not fighter.dead and not target.dead and target.is_unit():
					sim.electrocute(target, fighter, 0, 10, 3))
	return true


## The samurai whirlwind at frame first and then once a second, 5 times in all.
static func _whirlwind(sim: BattleSim, fighter: BattleFighter, first: int) -> void:
	var events := {first: func() -> void: SpecialUnit.samurai_whirlwind(sim, fighter, 3)}
	for second in range(1, 5):
		events[second * BattleSim.FRAMES_PER_SECOND] = func() -> void: SpecialUnit.samurai_whirlwind(sim, fighter, 3)
	sim.play_special(fighter, SP1, 5 * BattleSim.FRAMES_PER_SECOND, events, Callable(), true)


func _convert(sim: BattleSim, fighter: BattleFighter, target: BattleFighter) -> void:
	if target == null or target.dead or not target.is_unit() or target.def.subcat_functional == BattleSim.SUBCAT_BOSS:
		return
	if target.ability != null and target.ability.immune_to_conversion:
		return
	var tile := target.tile
	sim.kill(target, fighter)
	var wolf := sim.spawn(fighter.def, tile, fighter.team)
	if wolf == null:
		return
	wolf.health = 300
	if wolf.ability is CycleUnitsAbility:
		wolf.ability._converted = true
		wolf.ability.scale = 0.8
	sim.poison(wolf, fighter.attack / 2, 1000, 0, fighter)
