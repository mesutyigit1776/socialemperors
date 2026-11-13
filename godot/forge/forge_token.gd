class_name ForgeToken
extends Sprite2D
## The picture of a forge item at the place where the player found it
## (IslandToken of the client). It falls FALL pixels with a bounce in 1 second
## and moves up to SIDE pixels to a side. Its size on the screen stays the same
## at each zoom. A click on it makes it twice as big while it fades out in 0.5
## seconds.

const TOKEN_SIZE := 1.2
const FALL := 120.0
const SIDE := 90.0

var _collected := false


func _init(picture: Texture2D, tile: Vector2i, rng: RandomNumberGenerator) -> void:
	texture = picture
	centered = false
	position = IsoGrid.tile_to_map(Vector2(tile))
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	var target := position + Vector2(rng.randf() * 2 * SIDE - SIDE, FALL)
	_fit()
	var fall := create_tween()
	fall.tween_property(self, "position:y", target.y, 1.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.parallel().tween_property(self, "position:x", target.x, 1.0)


func _process(_delta: float) -> void:
	if not _collected:
		_fit()


func _unhandled_input(event: InputEvent) -> void:
	if _collected or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not get_rect().has_point(to_local(get_global_mouse_position())):
		return
	get_viewport().set_input_as_handled()
	_collected = true
	var grow := create_tween().set_parallel()
	grow.tween_property(self, "position", position - get_rect().size * scale / 2, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	grow.tween_property(self, "scale", scale * 2, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	grow.tween_property(self, "modulate:a", 0.0, 0.5)
	grow.chain().tween_callback(queue_free)


func _fit() -> void:
	var zoom := get_viewport().get_canvas_transform().get_scale().x if is_inside_tree() else 1.0
	scale = Vector2.ONE * TOKEN_SIZE / maxf(zoom, 0.01)
