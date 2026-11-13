class_name Paginator
extends RefCounted
## The pages of the lists of the client windows (Paginator): the elements of a
## page in rows, in a container of the window, and the arrows to the next and
## the previous page. An arrow that leads nowhere is at half alpha and does
## nothing (showDisabled). Element n of a page is at column n % per_row and row
## n / per_row; a column is the width of an element plus gap.x wide, a row its
## height plus gap.y. After the last elements of the list, a closing item can
## follow in the next row. Without elements the page shows a text.

const DISABLED_ALPHA := 0.5

var _container: Control
var _previous: UiClip
var _next: UiClip
var _elements: Array[Control] = []
var _per_row: int
var _per_page: int
var _gap: Vector2
var _closing: Control
var _closing_limit := 0
var _page := 0


## container: the clip in which the page shows. previous, next: the arrow
## clips, or null. per_row, rows: the elements on a page.
func _init(container: Control, previous: UiClip, next: UiClip, per_row: int, rows: int, gap: Vector2) -> void:
	_container = container
	_previous = previous
	_next = next
	_per_row = per_row
	_per_page = per_row * rows
	_gap = gap
	for arrow: UiClip in [previous, next]:
		if arrow != null:
			arrow.make_button()
	if previous != null:
		previous.pressed.connect(func() -> void: _turn(-1))
	if next != null:
		next.pressed.connect(func() -> void: _turn(1))


## The elements of the list; it shows the first page.
func show_list(elements: Array[Control], empty_text: Label = null) -> void:
	for element in _elements:
		if element.get_parent() == _container:
			_container.remove_child(element)
	_elements = elements
	_page = 0
	if empty_text != null and elements.is_empty():
		_container.add_child(empty_text)
	_draw()


## An item after the last element, in the next row, when the last page has
## fewer than limit elements (closingItem, maxElementsToShowClosing).
func set_closing(item: Control, limit: int) -> void:
	_closing = item
	_closing_limit = limit


func page_count() -> int:
	return maxi(ceili(float(_elements.size()) / _per_page), 1)


func _turn(step: int) -> void:
	var page := clampi(_page + step, 0, page_count() - 1)
	if page == _page:
		return
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	_page = page
	_draw()


func _draw() -> void:
	for child in _container.get_children():
		if child in _elements or child == _closing:
			_container.remove_child(child)
	var first := _page * _per_page
	var shown := 0
	for i in range(first, mini(first + _per_page, _elements.size())):
		var element := _elements[i]
		var size := _size(element)
		element.position = Vector2(shown % _per_row * (size.x + _gap.x), shown / _per_row * (size.y + _gap.y))
		_container.add_child(element)
		shown += 1
	if _closing != null and shown < _closing_limit:
		_closing.position = Vector2(0, (shown / _per_row + 1) * (_size(_closing).y + _gap.y))
		_container.add_child(_closing)
	if _previous != null:
		_previous.modulate.a = DISABLED_ALPHA if _page <= 0 else 1.0
	if _next != null:
		_next.modulate.a = DISABLED_ALPHA if _page >= page_count() - 1 else 1.0


## The size of an element as Flash measures it (width and height of the display object, with its scale).
static func _size(element: Control) -> Vector2:
	return ((element as UiClip).bounds().size if element is UiClip else element.size) * element.scale
