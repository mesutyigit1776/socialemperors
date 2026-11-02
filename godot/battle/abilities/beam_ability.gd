class_name BeamAbility
extends BattleAbility
## The dragons that shoot beams (AbstractBeamDelegate of the client). An attack
## starts a beam: after the shot delay, a beam goes to the target and hurts it
## with the attack of the dragon when it ends. The dragon does not attack again
## while its beam lasts; when it walks, the beam stops.
##
## The limit attacks of these dragons (smash, healing beams) start only from
## the buttons of the player, see roadmap step 3.2.

## Item id -> [beam graphic in <data>/fx, shot delay in frames].
const UNITS := {
	891: ["p.blackBeam", 13],  # Black Bahamut Dragon
	793: ["p.energyBeam", 13],  # Angelical Dragon
	777: ["p.crystalBeam", 12],  # Crystal Dragon
	888: ["p.egyptianBeam", 13],  # Pharaoh Bahamut Dragon
	846: ["p.necroBeam", 13],  # Green Bahamut Dragon
	826: ["p.necroBeam", 13],  # Death Dragon (NecroDragonDelegate)
	845: ["p.necroBeam", 13],  # Death Dragon Rider (NecroDragonDelegate)
	798: ["p.beamBlackDragonFire", 12],  # Rubies Dragon
	847: ["p.lavaBeam", 13],  # Volcano Dragon
}
const BEAM_FRAMES := 15  ## The client lets a beam of a dragon last 0.5 seconds.

var _beaming := false
var _beam := 0  # Counts the beams, so that an old beam does nothing.


func configure(item_id: int) -> void:
	var data: Array = UNITS.get(item_id, ["p.energyBeam", 12])
	shot_graphic = data[0]
	shot_delay = data[1]
	beam = true
	beam_frames = BEAM_FRAMES


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _beaming:
		return false
	_beaming = true
	_beam += 1
	var beam_id := _beam
	var target := fighter.target
	sim.after(shot_delay, func() -> void:
		if beam_id != _beam or fighter.dead or fighter.moving or target == null or target.dead or fighter.target != target:
			_beaming = false
			return
		sim.shoot(fighter, target, shot_graphic, fighter.attack, func(_shot: BattleProjectile) -> void:
			if beam_id == _beam:
				_beaming = false))
	return false


func on_update(_sim: BattleSim, fighter: BattleFighter) -> void:
	if _beaming and fighter.moving:
		_beaming = false
		_beam += 1
