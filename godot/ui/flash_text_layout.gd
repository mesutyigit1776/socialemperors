class_name FlashTextLayout
extends RefCounted
## How Flash lays out the text of a field with an embedded font of the client,
## as Ruffle does (core/src/font/font_like.rs, core/src/html/line_wrapping.rs):
## the widths of lines, the line breaks of a field with word wrap and the
## height of a line. Godot measures the same glyphs a little wider: Flash takes
## the advance of each glyph in whole twips (1/20 pixel) and drops the rest, so
## a line of 70 characters is 1 to 2 pixels narrower than its exact width, and
## Godot breaks some lines before a word that Flash keeps.

var _advances: Dictionary  # Character code -> advance in 1024ths of the em.
var _ascent: float  # In 1024ths of the em, from the font layout.
var _descent: float


func _init(advances: Dictionary, line_metrics: Vector2) -> void:
	_advances = advances
	_ascent = line_metrics.x
	_descent = line_metrics.y


## The width in pixels of a text on one line at a font size. A character
## without a glyph in the font has no width.
func width(text: String, size: int) -> float:
	var twips := 0
	for i in text.length():
		twips += _advance_twips(text.unicode_at(i), size)
	return twips / 20.0


## The lines of a text in a field with word wrap that is width pixels wide.
## A line ends at a "\n" or before the first word that does not fit. A word
## ends after its spaces or after a hyphen (SWF 8 and later). A word wider than
## the field is broken after its last character that fits, at least one. The
## spaces at the end of a line are not part of it.
func wrap(text: String, size: int, field_width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var limit := roundi(field_width * 20.0)
	for paragraph in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
		var rest := paragraph
		while true:
			var end := _line_end(rest, size, limit)
			lines.append(rest.substr(0, end).rstrip(" "))
			rest = rest.substr(end)
			if rest.is_empty():
				break
	return lines


## The height in pixels of one line: the ascent and the descent of the font
## layout, each in whole twips, and the leading of the field.
func line_height(size: int, leading: float) -> float:
	return (floorf(_ascent * size * 20.0 / 1024.0) + floorf(_descent * size * 20.0 / 1024.0)) / 20.0 + leading


## The length of the first line of text (Ruffle's wrap_line).
func _line_end(text: String, size: int, limit: int) -> int:
	var remaining := limit
	var line_end := 0
	var word_start := 0
	for word_end in _breaks(text):
		var trimmed_end := word_end
		while trimmed_end > word_start and text.unicode_at(trimmed_end - 1) == 32:
			trimmed_end -= 1
		var measure := 0
		for i in range(word_start, trimmed_end):
			measure += _advance_twips(text.unicode_at(i), size)
		if measure <= remaining:
			line_end = word_end
			remaining -= measure
			word_start = trimmed_end
			continue
		if line_end == 0:
			# A word wider than the field at the start of a line.
			var fitting := 0
			var used := 0
			for i in range(word_start, trimmed_end):
				used += _advance_twips(text.unicode_at(i), size)
				if used > remaining:
					break
				fitting = i + 1
			return maxi(fitting, 1)
		return line_end
	return text.length()


## The ends of the words of a text: after the last space of a run of spaces,
## after a hyphen, and at the end.
func _breaks(text: String) -> PackedInt32Array:
	var ends := PackedInt32Array()
	for i in range(1, text.length()):
		var previous := text.unicode_at(i - 1)
		var current := text.unicode_at(i)
		if current == 32:
			continue
		if previous == 32 or previous == 45:
			ends.append(i)
	ends.append(text.length())
	return ends


func _advance_twips(code: int, size: int) -> int:
	return int(float(_advances.get(code, 0.0)) * size * 20.0 / 1024.0)
