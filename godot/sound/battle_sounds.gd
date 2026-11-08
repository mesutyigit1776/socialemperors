class_name BattleSounds
extends RefCounted
## Plays the sounds of a battle as the client plays them: the shots of the
## units (IsoUnit.shootProjectil), the hits of melee attackers
## (IsoFightingElement.recibirAtaque), the deaths of units
## (SoundManager.playDeadSfx) and the magic particles (MagicParticle). The
## abilities send their own sounds with BattleSim.sound_played.

## Unit -> the sound of each of its shots.
const SHOT_SOUNDS := {
	# Archers, archers on horses, the high elf, the troll and elf archers, the
	# fire and royal archers, the octopuses and the warriors of Atlantis.
	516: SoundEffect.ATTACK_ARCHER, 517: SoundEffect.ATTACK_ARCHER, 518: SoundEffect.ATTACK_ARCHER,
	515: SoundEffect.ATTACK_ARCHER, 557: SoundEffect.ATTACK_ARCHER, 589: SoundEffect.ATTACK_ARCHER,
	627: SoundEffect.ATTACK_ARCHER, 646: SoundEffect.ATTACK_ARCHER, 675: SoundEffect.ATTACK_ARCHER,
	633: SoundEffect.ATTACK_ARCHER, 548: SoundEffect.ATTACK_ARCHER, 624: SoundEffect.ATTACK_ARCHER,
	689: SoundEffect.ATTACK_ARCHER, 620: SoundEffect.ATTACK_ARCHER, 680: SoundEffect.ATTACK_ARCHER,
	622: SoundEffect.ATTACK_ARCHER,
	# Scorpions, the mobile tower, the elf ballista, axe throwers, the viking,
	# the penguin, the lightning shooters, the green draggy, the big zombie and
	# the archangel.
	520: SoundEffect.ATTACK_BIG_ARCHER, 586: SoundEffect.ATTACK_BIG_ARCHER, 602: SoundEffect.ATTACK_BIG_ARCHER,
	634: SoundEffect.ATTACK_BIG_ARCHER, 530: SoundEffect.ATTACK_BIG_ARCHER, 551: SoundEffect.ATTACK_BIG_ARCHER,
	598: SoundEffect.ATTACK_BIG_ARCHER, 607: SoundEffect.ATTACK_BIG_ARCHER, 546: SoundEffect.ATTACK_BIG_ARCHER,
	693: SoundEffect.ATTACK_BIG_ARCHER, 550: SoundEffect.ATTACK_BIG_ARCHER, 692: SoundEffect.ATTACK_BIG_ARCHER,
	553: SoundEffect.ATTACK_BIG_ARCHER, 698: SoundEffect.ATTACK_BIG_ARCHER, 707: SoundEffect.ATTACK_BIG_ARCHER,
	711: SoundEffect.ATTACK_BIG_ARCHER,
	# Catapults, boulder throwers, cannons, the ship, the zeppelin, the fire
	# cannon, the draggies of fire and the ent.
	521: SoundEffect.ATTACK_CANNON, 587: SoundEffect.ATTACK_CANNON, 605: SoundEffect.ATTACK_CANNON,
	767: SoundEffect.ATTACK_CANNON, 522: SoundEffect.ATTACK_CANNON, 588: SoundEffect.ATTACK_CANNON,
	542: SoundEffect.ATTACK_CANNON, 583: SoundEffect.ATTACK_CANNON, 568: SoundEffect.ATTACK_CANNON,
	638: SoundEffect.ATTACK_CANNON, 672: SoundEffect.ATTACK_CANNON, 635: SoundEffect.ATTACK_CANNON,
}
## The peasant women, the healers, Xena and the valkyrie.
const FEMALE_UNITS: Array[int] = [501, 581, 502, 590, 533, 554]
const GOLEM := 537
const YETI := 544
## The Three-Headed Dragon (ThreeHeadedDragonDelegate) beats its wings at
## these frames (from 1, as in the client) of the clips of its actions.
const THREE_HEADED_DRAGONS: Array[int] = [2057, 2058]
const WING_FRAMES := {
	UnitSprite.Action.IDLE: [2], UnitSprite.Action.WALKING: [2], UnitSprite.Action.ATTACKING: [1, 23],
	UnitSprite.Action.SPECIAL: [1, 23], UnitSprite.Action.SPECIAL + 1: [1, 23], UnitSprite.Action.SPECIAL + 2: [1, 23],
	UnitSprite.Action.SPECIAL + 3: [1, 23], UnitSprite.Action.SPECIAL + 4: [1, 23], UnitSprite.Action.SPECIAL + 5: [15, 44, 63],
}
## Particle type -> the sound when the particle comes (the auras and the
## doubles of MagicParticle).
const PARTICLE_START_SOUNDS := {
	MagicParticles.AURA_WALLACE: SoundEffect.MAGIC_HEAL, MagicParticles.AURA_DRUMMER: SoundEffect.ATTACK_CANNON,
	MagicParticles.DUPLICATE: SoundEffect.MAGIC_HEAL,
}
## Particle type -> the sound when the particle attacks.
const PARTICLE_ATTACK_SOUNDS := {
	MagicParticles.FIRE_RED: SoundEffect.MAGIC_FIRE, MagicParticles.FIRE_ARROW: SoundEffect.MAGIC_FIRE,
	MagicParticles.FIRE_GREEN: SoundEffect.MAGIC_FIRE,
	MagicParticles.STONE: SoundEffect.MAGIC_PLOF, MagicParticles.LIGHTNING: SoundEffect.MAGIC_PLOF,
	MagicParticles.LIGHTNING_HUGE: SoundEffect.MAGIC_PLOF, MagicParticles.ARCHANGEL_BEAM: SoundEffect.MAGIC_PLOF,
	MagicParticles.HUGE_BEAM: SoundEffect.MAGIC_PLOF, MagicParticles.SWORDS_RAIN: SoundEffect.MAGIC_PLOF,
	MagicParticles.CRYSTAL_RAIN: SoundEffect.MAGIC_PLOF, MagicParticles.NECRO_RAIN: SoundEffect.MAGIC_PLOF,
	MagicParticles.FIRE_BLUE: SoundEffect.MAGIC_HEAL, MagicParticles.STARS: SoundEffect.MAGIC_HEAL,
	MagicParticles.STARS_PERMANENT: SoundEffect.MAGIC_HEAL, MagicParticles.AURA_VALKYRIE: SoundEffect.MAGIC_HEAL,
	MagicParticles.EXPANSIVE_WAVE: SoundEffect.ATTACK_CANNON,
}


static func listen(sim: BattleSim) -> void:
	sim.shot_fired.connect(func(shot: BattleProjectile) -> void:
		if shot.attacker != null and shot.attacker.is_unit() and SHOT_SOUNDS.has(shot.attacker.def.id):
			SoundPlayer.play(SHOT_SOUNDS[shot.attacker.def.id]))
	sim.hit.connect(func(_target: BattleFighter, attacker: BattleFighter, _damage: int, _critical: bool) -> void:
		if attacker != null and attacker.attack_range <= 1:
			SoundPlayer.play(SoundEffect.ATTACK_SWORD))
	sim.died.connect(func(fighter: BattleFighter, _killer: BattleFighter) -> void:
		if fighter.is_unit():
			SoundPlayer.play(death_sound(fighter.def)))
	sim.particle_added.connect(func(type: int, _tile: Vector2i, delay: int) -> void:
		if PARTICLE_START_SOUNDS.has(type):
			SoundPlayer.play(PARTICLE_START_SOUNDS[type])
		if PARTICLE_ATTACK_SOUNDS.has(type):
			SoundPlayer.play(PARTICLE_ATTACK_SOUNDS[type], (delay + MagicParticles.attack_frame(type)) * 1000 / BattleSim.FRAMES_PER_SECOND))
	sim.sound_played.connect(func(effect: int, delay_ms: int) -> void: SoundPlayer.play(effect, delay_ms))


## Plays the sounds that follow the graphic of the unit item_id.
static func watch_graphic(item_id: int, node: UnitSprite) -> void:
	if not item_id in THREE_HEADED_DRAGONS:
		return
	node.clip_frame_shown.connect(func(frame: int, clip_frame: int) -> void:
		if clip_frame + 1 in WING_FRAMES.get(frame / UnitSprite.FRAMES_PER_ACTION, []):
			SoundPlayer.play(SoundEffect.THREE_HEADED_MOVE, 0))


static func death_sound(def: GameConfig.ItemDef) -> int:
	if def.id in FEMALE_UNITS:
		return SoundEffect.DEAD_FEMALE
	if def.race == "t" or def.subcat_functional == BattleSim.SUBCAT_BOSS or def.id == GOLEM or def.id == YETI:
		return SoundEffect.DEAD_TROLL
	if def.subcat_functional == BattleSim.SUBCAT_SIEGE:
		return SoundEffect.DEAD_MECHANICAL
	return SoundEffect.DEAD_MALE
