class_name HealthBar
extends Node2D
## The health bar of the client over an item in a battle (IsoFightingElement):
## BarraVidaMC for the player, BarraVidaEnemyMC for an enemy, at 0.6 of its
## size. Its red part (barraRoja) covers the share of the life that the item
## lost (updateVida). The node sits on the position of the item; the bar is
## centred on it.

const SCALE := 0.6

var _bar: UiClip
var _red: UiClip
var _width := 0.0  # Of the bar in its own pixels, with the red part as the art draws it.
var _red_width := 0.0  # Of the red part in its own pixels.


## ui: a library for the map (UiLibrary.for_map()). size: 2 for the enemies
## of a tournament, which the client shows twice as big.
func _init(ui: UiLibrary, enemy: bool, size := 1.0) -> void:
	_bar = ui.make("BarraVidaEnemyMC" if enemy else "BarraVidaMC")
	_bar.scale = Vector2.ONE * SCALE * size
	add_child(_bar)
	_width = _bar.bounds().size.x
	_red = _bar.clip("barraRoja")
	_red_width = _red.bounds().size.x
	_bar.position.x = -_width * _bar.scale.x / 2


static func can_make(ui: UiLibrary) -> bool:
	return ui != null and ui.has_symbol("BarraVidaMC") and ui.has_symbol("BarraVidaEnemyMC")


## share: the life left, from 0 to 1.
func show_life(share: float) -> void:
	if _red_width > 0:
		_red.scale.x = (1 - clampf(share, 0, 1)) * _width / _red_width


## The client puts the bar 5 pixels above the graphic of the item, whose
## height is graphic_height: y = -height - 5 from the position of the item.
func place(item_position: Vector2, graphic_height: float) -> void:
	position = item_position - Vector2(0, graphic_height + 5)
