class_name NumberLayer
extends CanvasLayer
## The layer of the floating numbers (ParticleSystem of the client), over the
## HUD and the windows. It moves them once each frame of the client, at 30
## frames a second.
##
## As in the client, a number shows from the frame after it is added, and
## when more than MAX_SHOWN numbers show, the update removes some of the
## oldest: it removes each number that it reaches while the list is too long,
## and then does not update the number after it in that frame.

const FRAME_SECONDS := 1.0 / 30.0
const MAX_SHOWN := 7
const LOW_MARGIN := 130.0

## The text of an absorbed part of a hit, with "#0#" for the number
## (AUX_ABSORBER of the configuration).
var absorbed_text := "#0# absorbed"
var _ui: UiLibrary
var _shown: Array[NumberParticle] = []
var _added: Array[NumberParticle] = []
var _time := 0.0


func _init(ui: UiLibrary, layer_index: int) -> void:
	_ui = ui
	layer = layer_index


## Shows values (see NumberParticle) that start at the screen point at, in
## the coordinates of the client (the content scale of the window applies).
func show_numbers(at: Vector2, values: Array, scale_factor := 1.0, life := NumberParticle.LIFE) -> void:
	var lines := values.map(func(pair: Array) -> Array:
		if pair[0] == NumberParticle.ABSORBED and pair[1] is int and pair[1] != 0:
			return [pair[0], absorbed_text.replace("#0#", str(pair[1]))]
		return pair)
	var particle := NumberParticle.new(_ui, at, lines, scale_factor, life)
	add_child(particle)
	_added.append(particle)


## The middle of the screen.
func middle() -> Vector2:
	return get_viewport().get_visible_rect().size / 2


## The middle of the screen, LOW_MARGIN above the bottom: the client shows
## some rewards there.
func low() -> Vector2:
	var size := get_viewport().get_visible_rect().size
	return Vector2(size.x / 2, size.y - LOW_MARGIN)


## Removes all numbers, as the client does at the end of a game screen.
func clear() -> void:
	for particle: NumberParticle in _shown + _added:
		particle.queue_free()
	_shown.clear()
	_added.clear()


func _process(delta: float) -> void:
	_time += delta
	while _time >= FRAME_SECONDS:
		_time -= FRAME_SECONDS
		_step()


func _step() -> void:
	_shown.append_array(_added)
	_added.clear()
	var i := 0
	while i < _shown.size():
		var particle := _shown[i]
		particle.step()
		if particle.dead or _shown.size() > MAX_SHOWN:
			particle.queue_free()
			_shown.remove_at(i)
		i += 1
