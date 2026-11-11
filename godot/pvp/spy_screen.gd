class_name SpyScreen
extends Node2D
## The village of an enemy that the search found (GameMode.SPY of the
## client): its name, level and loot, and the buttons Attack, Find next and
## My town. Attack shows the start points of the client (popupLoadingAssault):
## the player chooses where the army lands, at 10 + 20 × column and row of a
## 5 × 5 grid of the map. The middle points are inside the village, so the
## port offers the points at the edge.

signal attack_requested(start_tile: Vector2i)
signal next_requested
signal home_requested

const GRID := 5
const FIRST_POINT := 10
const POINT_STEP := 20
## The client shows the village of the enemy at this zoom (Base.UpdateGame3).
const SPY_ZOOM := 0.5

var _view := VillageView.new()
var _camera := MapCamera.new()
var _column := VBoxContainer.new()
var _start := Vector2i(FIRST_POINT, FIRST_POINT)


## loot: see PvpBattle.loot_of(). next_cost: the gold of the next search.
func _init(enemy: Village, enemy_name: String, loot: Dictionary, next_cost: int, config: GameConfig, sprites: SpriteLibrary, start_position: Vector2) -> void:
	add_child(_view)
	_view.show_village(enemy, config, sprites)
	_camera.position = start_position
	_camera.set_mode_zoom(SPY_ZOOM)
	add_child(_camera)
	var layer := CanvasLayer.new()
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 10)
	panel.add_child(_column)
	layer.add_child(panel)
	add_child(layer)
	var title := Label.new()
	title.text = "%s  (level %d)" % [enemy_name, enemy.get_level()]
	title.add_theme_font_size_override("font_size", 20)
	_column.add_child(title)
	var resources := Label.new()
	resources.text = "Loot: %d gold, %d wood, %d stone, %d food" % [loot["g"], loot["w"], loot["s"], loot["f"]]
	_column.add_child(resources)
	var buttons := HBoxContainer.new()
	_button(buttons, config.text("PVP_ATTACK").strip_edges(), _show_start_points)
	_button(buttons, "%s (%d gold)" % [config.text("PVP_FIND_NEXT").strip_edges(), next_cost], func() -> void: next_requested.emit())
	_button(buttons, "My town", func() -> void: home_requested.emit())
	_column.add_child(buttons)


func _show_start_points() -> void:
	if _column.get_child_count() > 3:
		return
	var text := Label.new()
	text.text = "Where does your army land?"
	_column.add_child(text)
	var grid := GridContainer.new()
	grid.columns = GRID
	var group := ButtonGroup.new()
	for row in GRID:
		for column in GRID:
			var button := Button.new()
			button.custom_minimum_size = Vector2(28, 28)
			button.toggle_mode = true
			button.button_group = group
			var tile := Vector2i(FIRST_POINT + POINT_STEP * column, FIRST_POINT + POINT_STEP * row)
			button.disabled = row in range(1, GRID - 1) and column in range(1, GRID - 1)
			button.button_pressed = tile == _start
			button.toggled.connect(func(on: bool) -> void:
				if on:
					_start = tile)
			grid.add_child(button)
	_column.add_child(grid)
	var start := Button.new()
	start.text = "Start the attack"
	start.pressed.connect(func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)  # ButtonGenericTall
		attack_requested.emit(_start))
	_column.add_child(start)


func _button(parent: Container, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
