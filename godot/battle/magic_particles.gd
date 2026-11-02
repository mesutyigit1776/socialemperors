class_name MagicParticles
extends RefCounted
## The magic particles of the client (MagicParticle): effects on one tile that
## attack the item there at a fixed frame after they appear. The client plays
## the graphic of each type from the library of magic particles; the battle
## needs only the type and the frame of its attack, see BattleSim.particle().

const FIRE_RED := 1
const FIRE_BLUE := 2
const STONE := 3
const FIRE_GREEN := 4
const STARS := 5
const AURA_WALLACE := 6
const DUPLICATE := 7
const LIGHTNING := 8
const AURA_VALKYRIE := 9
const NONE := 10
const SLIME := 11
const SLIME_SPLASH := 12
const CONVERSION := 13
const EXPANSIVE_WAVE := 14
const FREEZE_UNITS := 15
const AURA_DRUMMER := 16
const STARS_PERMANENT := 17
const WATER := 18
const EXTERNAL := 19
const ROOT := 20
const FIRE_ARROW := 21
const LIGHTNING_HUGE := 22
const SNAKE_TAIL := 24
const SPARTAN_SPEAR := 25
const BALL_EXPLOSION := 27
const ARCHANGEL_BEAM := 29
const HUGE_BEAM := 30
const AURA_ARCHANGEL := 31
const SOUL := 32
const HOLE := 33
const FROG := 35
const SPIDERWEB := 37
const MAGMA := 38
const CRYSTAL_RAIN := 40
const CRYSTAL_EXPLOSION := 41
const NECRO_RAIN := 44
const SWORDS_RAIN := 49
const LIMIT_AREA := 50
const FIRE_METEOR := 23
const FALLING_BOULDER := 26
const COBRA_TAIL := 28
const SCREW := 34
const SMOKE := 36
const HADES_SPIKE := 39
const ZEUS_LIGHTNING := 42
const ANVIL := 43
const LIGHTING_LASER := 46
const LIGHTING_NECRO := 47
const MULTICOLOR_RAIN := 51
const FROZEN_RAIN := 52
const FIRE_EXPLOSION_SMALL := 53
const FIRE_RAIN := 54
const SPIDERWEB_LARGE := 55
const FALLING_STAR := 56
const THUNDERBOLT := 57
const MAGMA_BALL_RAIN := 58
const CARNIVOROUS_PLANT := 59
const KILLER_ROOTS := 60
const RAY := 62
const HELL_INVOCATION := 64
const HEAVY_ROCK_RAIN := 66
const ROCK_HOLE := 67
const ACID_RAIN := 68
const GREEN_FLAME := 69
const ICE_BLOCK := 70
const HEAVY_ROCKS := 71
const WIND_ARROWS := 72
const SWORD_RAIN := 73
const STRANGLING_PLANTS := 74
const BALL_HEALTH := 79
const FIRE_EXPLOSION := 81
const MEGA_EXPLOSION := 82
const GOLDEN_SEAL := 75
const SKULL_SEAL := 76
const SKULL_EXPLOSION := 77
const SEAL_HEALTH := 78
const FIRE_PIT := 80
const SPIKES_RAIN := 83
const RAIN_PRIEST_GLADIATOR := 63
const GLADIATOR_NET := 65
const ROCKS_RAIN := 84
const DIAMONDS_RAIN := 85
const FIREBALL_RAIN := 86
const MOON_SEAL := 87
const THUNDER_L := 88
const ROCKS := 89
const ICE_SHARD := 90
const PLATINUM_SWORD := 91
const PURPLE_RAY := 92

## Type -> the frame at which the particle attacks; -1: it never attacks.
## Other types attack at DEFAULT_ATTACK_FRAME.
const ATTACK_FRAMES := {
	FIRE_RED: 15, FIRE_BLUE: 15, ROOT: 15, STONE: 30, LIGHTNING: 10, FIRE_GREEN: 1, STARS: 1,
	STARS_PERMANENT: 1, AURA_DRUMMER: 59, AURA_WALLACE: 140, AURA_ARCHANGEL: 220, AURA_VALKYRIE: 35,
	DUPLICATE: 600, SLIME: 1200, SLIME_SPLASH: 20, LIGHTNING_HUGE: 12, CONVERSION: 720,
	EXPANSIVE_WAVE: 0, FREEZE_UNITS: 120, WATER: 0, FIRE_ARROW: 20, SNAKE_TAIL: 5,
	SPARTAN_SPEAR: 11, BALL_EXPLOSION: 0, ARCHANGEL_BEAM: 7, HUGE_BEAM: 7, NONE: 0, SOUL: 0,
	HOLE: 0, FROG: 120, SPIDERWEB: 120, MAGMA: 0, CRYSTAL_RAIN: 30, SWORDS_RAIN: 19,
	MEGA_EXPLOSION: 0, CRYSTAL_EXPLOSION: 0, NECRO_RAIN: 15, LIMIT_AREA: -1, GOLDEN_SEAL: -1,
	SKULL_SEAL: 92, SKULL_EXPLOSION: 90, SEAL_HEALTH: 20, FIRE_PIT: 10, SPIKES_RAIN: 13,
}
const DEFAULT_ATTACK_FRAME := 15


static func attack_frame(type: int) -> int:
	return ATTACK_FRAMES.get(type, DEFAULT_ATTACK_FRAME)
