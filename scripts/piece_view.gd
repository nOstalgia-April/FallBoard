extends Node2D
## Deliberately geometric: readable contact faces, no rotation or hidden stats.

const MINT = Color("b5ef9e")
const CORAL = Color("f39b8d")
var piece: Dictionary
var font: Font
var selected = false
var face = -1

func _draw() -> void:
	if piece.is_empty() or font == null:
		return
	var ally: bool = int(piece.team) == 0
	var accent = MINT if ally else CORAL
	var surface = Color("dce9da") if ally else Color("ead9d3")
	var body = StyleBoxFlat.new()
	body.bg_color = Color(0, 0, 0, 0.28)
	body.set_corner_radius_all(19)
	draw_style_box(body, Rect2(-64, -56, 128, 128))
	if selected:
		body.bg_color = Color(accent, 0.09)
		body.border_color = accent
		body.set_border_width_all(2)
		draw_style_box(body, Rect2(-72, -72, 144, 144))
	body.bg_color = surface
	body.border_color = accent if selected else surface.darkened(0.2)
	body.set_border_width_all(2)
	draw_style_box(body, Rect2(-64, -64, 128, 128))
	# The center identifies the piece; the four large digits are the rules.
	draw_circle(Vector2.ZERO, 21, Color("26352f") if ally else Color("483331"), true, -1, true)
	_text(piece.name, Vector2(0, 8), 23, accent)
	var positions = [Vector2(0, -36), Vector2(44, 9), Vector2(0, 52), Vector2(-44, 9)]
	for i in range(4):
		if face == i:
			var fill = StyleBoxFlat.new()
			fill.bg_color = Color("354736") if ally else Color("583e36")
			fill.set_corner_radius_all(7)
			draw_style_box(fill, Rect2(positions[i] + Vector2(-18, -26), Vector2(36, 34)))
		_text(str(int(piece.values[i])), positions[i], 26, accent if face == i else Color("25312f"))
	# Small shapes reinforce team color for color-vision accessibility.
	if ally:
		draw_circle(Vector2(-49, -49), 3, Color("517445"), true, -1, true)
	else:
		draw_rect(Rect2(-52, -52, 6, 6), Color("9b5b50"))

func _text(value: String, baseline: Vector2, size: int, color: Color) -> void:
	var width = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, baseline - Vector2(width / 2.0, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
