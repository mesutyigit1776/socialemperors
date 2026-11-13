class_name SelectionMark
extends RefCounted
## The mark of the client under a selected unit or building
## (IsoInteractiveElement.addIconoSeleccionado): PeanaMC under a unit,
## PeanaBuilding<w>x<w>MC under a building of width w (1 to 6), each for the
## player, an enemy ("Enemy") or a neutral item ("Neutral").

enum Party { PLAYER, ENEMY, NEUTRAL }

const PARTY_NAMES := {Party.PLAYER: "", Party.ENEMY: "Enemy", Party.NEUTRAL: "Neutral"}
const MAX_WIDTH := 6
## The client puts the mark of a unit half a tile below the position of the unit.
const UNIT_OFFSET := Vector2(0, IsoGrid.TILE_SIZE.y / 2)


## Puts a new mark under the graphic of an item: as in the client, it is a
## child of the node, drawn before it, so it moves and mirrors with the item.
## Returns the mark, or null when ui is null or the import has no such
## symbol. ui: a library for the map (UiLibrary.for_map()). width: of a
## building, in tiles.
static func attach(node: CanvasItem, ui: UiLibrary, party: Party, unit: bool, width := 1) -> UiClip:
	var symbol := "Peana%sMC" % PARTY_NAMES[party] if unit else "PeanaBuilding%s%dx%dMC" % [PARTY_NAMES[party], clampi(width, 1, MAX_WIDTH), clampi(width, 1, MAX_WIDTH)]
	if ui == null or not ui.has_symbol(symbol):
		return null
	var mark := ui.make(symbol)
	mark.show_behind_parent = true
	if unit:
		mark.position = UNIT_OFFSET
	node.add_child(mark)
	return mark


## True when the import has the marks.
static func can_attach(ui: UiLibrary) -> bool:
	return ui != null and ui.has_symbol("PeanaMC")
