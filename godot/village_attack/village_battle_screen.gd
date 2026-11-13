class_name VillageBattleScreen
extends Node2D
## A fight in the village on the screen (VillageBattle): the village as a
## battle map with the controls of the battles (BattleScreen), the portrait
## buttons of special units and the spell book. In the client the fight is a
## part of the normal village; the port shows the village as a battle until
## the fight ends, and the player cannot build in this time.
##
## A captain's line shows over the unit for LINE_SECONDS seconds. The client
## shows no special bar for these fights; the port shows a line at the top
## with the number of enemies (STATUS_TEXT).

signal closed  ## The fight ended; the owner applies VillageBattle.apply().
signal village_changed  ## A spell changed the mana or the spells of the village; the owner saves it.

const LINE_SECONDS := 3.0
const LINE_OFFSET := Vector2(-60, -110)
const STATUS_TEXT := "Enemies in your village: %d"

var battle: VillageBattle
var _village: Village
var _config: GameConfig
var _view := BattleView.new()
var _camera := MapCamera.new()
var _screen: BattleScreen
var _windows := CanvasLayer.new()
var _status := Label.new()
var _lines := {}  # BattleFighter -> [Label, seconds left]
var _cast_ui: UiLibrary
var _spell_graphics: Dictionary
var _spells := {}  # Spell id -> BattleSpell of this fight.


## camera_position: where the village camera was, in map pixels.
func _init(village_battle: VillageBattle, village: Village, ui: UiLibrary, cast_ui: UiLibrary, spell_graphics: Dictionary, config: GameConfig, sprites: SpriteLibrary, effects: SpriteLibrary, camera_position: Vector2) -> void:
	battle = village_battle
	_village = village
	_config = config
	_cast_ui = cast_ui
	_spell_graphics = spell_graphics
	battle.sim.spell_graphics = spell_graphics
	battle.sim.spell_uses = village.spell_uses()
	add_child(_view)
	_view.show_battle(battle.sim, config, sprites, effects, VillageView.LAND_ITEM_BASE_ID + village.skin, VillageView.village_land_frames(village.owned_land))
	_camera.position = camera_position
	add_child(_camera)
	# After the camera, so that it gets the mouse first: a selection box does not move the map.
	_screen = BattleScreen.new(battle.sim, _view)
	add_child(_screen)
	_screen.stepped.connect(_on_stepped)
	# The client plays the battle music while the items of the player are
	# attacked in the village, and the music of the town again when nobody
	# attacks (IsoFightingElement.recibirAtaque and IsoEngine).
	battle.sim.hit.connect(func(target: BattleFighter, _attacker: BattleFighter, _damage: int, _critical: bool) -> void:
		if target.team == BattleFighter.Team.PLAYER:
			SoundPlayer.play_music(SoundPlayer.Music.BATTLE))
	battle.ended.connect(func() -> void:
		_screen.paused = true
		closed.emit())
	battle.said.connect(_show_line)
	add_child(_windows)
	_status.position = Vector2(20, 12)
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 4)
	_windows.add_child(_status)
	var buttons := UnitButtonPanel.new(battle.sim, ui, config)
	_screen.selection_changed.connect(buttons.show_selection)
	_windows.add_child(buttons)
	if SpellBook.is_shown(village):
		# After the battle screen, so that it gets the mouse first while the player aims.
		var book := SpellBook.new(ui, cast_ui, config, village, _windows)
		book.cast_on = _cast
		book.marker_layer = _view.under_items()
		book.changed.connect(func() -> void: village_changed.emit())
		add_child(book)
	_update_status()


## The fight started with a click of the player on an enemy: the unit of the
## player attacks it, as the click would order in the client.
func order_attack(unit: Village.PlacedItem, target_tile: Vector2i) -> void:
	var fighter := battle.fighter_of(unit)
	if fighter != null:
		var units: Array[BattleFighter] = [fighter]
		battle.sim.order(units, target_tile)


## Where the camera is, in map pixels; the village camera continues from there.
func camera_position() -> Vector2:
	return _camera.position


## The map of the fight, on which other screens can show things.
func map_view() -> BattleView:
	return _view


func _process(delta: float) -> void:
	for fighter: BattleFighter in _lines.keys():
		var entry: Array = _lines[fighter]
		entry[1] -= delta
		if entry[1] <= 0.0 or fighter.dead:
			entry[0].queue_free()
			_lines.erase(fighter)
		else:
			entry[0].position = fighter.position + LINE_OFFSET


func _on_stepped() -> void:
	battle.update()
	if not battle.sim.fighters.any(func(fighter: BattleFighter) -> bool: return fighter.attacking and not fighter.dead):
		SoundPlayer.play_music(SoundPlayer.town_music(_village.race))
	if battle.sim.frame % BattleSim.FRAMES_PER_SECOND == 0:
		_update_status()


func _update_status() -> void:
	var enemies := battle.sim.fighters.filter(func(fighter: BattleFighter) -> bool: return fighter.is_unit() and not fighter.dead and fighter.team == BattleFighter.Team.ENEMY).size()
	_status.text = STATUS_TEXT % enemies


func _show_line(unit: BattleFighter, text: String) -> void:
	if _lines.has(unit):
		_lines[unit][0].queue_free()
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.position = unit.position + LINE_OFFSET
	label.z_index = 10
	add_child(label)
	_lines[unit] = [label, LINE_SECONDS]


func _cast(spell: GameConfig.SpellDef, tile: Vector2i, level: int) -> void:
	if not _spells.has(spell.id):
		var created := BattleSpell.create(spell, _config, _spell_graphics.get(spell.img_name, {}))
		if created == null:
			return
		_spells[spell.id] = created
		_view.show_spell(created)
	_spells[spell.id].cast(battle.sim, tile, level)
