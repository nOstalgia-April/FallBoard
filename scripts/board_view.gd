extends Control

signal cell_clicked(cell: Vector2i)
signal cell_hovered(cell: Vector2i)

const PieceView = preload("res://scripts/piece_view.gd")
const ORIGIN = Vector2(30, 30)
const STEP = 180.0
const MINT = Color("b5ef9e")
const CORAL = Color("f39b8d")

var battle: FallBattle
var font: Font
var selected = ""
var hover_cell = Vector2i(-9, -9)
var views: Dictionary = {}
var locked = false
var tweens: Array[Tween] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func():
		hover_cell = Vector2i(-9, -9)
		cell_hovered.emit(hover_cell)
		refresh()
	)

func reset(state: FallBattle) -> void:
	for tween in tweens:
		if tween.is_valid():
			tween.kill()
	tweens.clear()
	for view in views.values():
		remove_child(view)
		view.queue_free()
	views.clear()
	battle = state
	selected = ""
	for piece in battle.pieces:
		var view = PieceView.new()
		view.piece = piece
		view.font = font
		view.position = center(piece.pos)
		views[piece.id] = view
		add_child(view)
	refresh()

func center(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * STEP + Vector2.ONE * STEP / 2.0

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.x - ORIGIN.x) / STEP), floori((point.y - ORIGIN.y) / STEP))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell = cell_at(event.position)
		if cell != hover_cell:
			hover_cell = cell
			cell_hovered.emit(cell)
			refresh()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cell_clicked.emit(cell_at(event.position))
		accept_event()

func refresh() -> void:
	if battle == null:
		return
	var prediction = battle.preview(selected, hover_cell) if not locked else {}
	for id in views:
		var view = views[id]
		view.selected = id == selected and not locked
		view.face = -1
		if prediction.get("kind") == "attack":
			if id == selected:
				view.face = prediction.direction
			elif id == prediction.defender:
				view.face = (prediction.direction + 2) % 4
		view.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if battle == null or font == null:
		return
	var border = StyleBoxFlat.new()
	border.bg_color = Color("11191e")
	border.border_color = Color("3c4a43")
	border.set_border_width_all(1)
	border.set_corner_radius_all(24)
	draw_style_box(border, Rect2(ORIGIN - Vector2(14,14), Vector2(568,568)))
	for y in range(3):
		for x in range(3):
			var cell = Vector2i(x,y)
			var pos = ORIGIN + Vector2(cell) * STEP
			var action = battle.preview(selected, cell) if not locked else {}
			var tile = StyleBoxFlat.new()
			tile.bg_color = Color("202b31") if (x+y) % 2 == 0 else Color("1d272d")
			tile.border_color = Color("354047")
			tile.set_border_width_all(1)
			tile.set_corner_radius_all(12)
			if action.get("kind") == "move":
				tile.bg_color = Color("293d35")
				tile.border_color = Color("6c9460")
			elif action.get("kind") == "attack":
				tile.border_color = CORAL
				tile.set_border_width_all(2)
			if cell == hover_cell and not locked:
				tile.bg_color = tile.bg_color.lightened(0.055)
			draw_style_box(tile, Rect2(pos + Vector2(4,4), Vector2(172,172)))
			draw_string(font, pos + Vector2(16,25), "%s%d" % [char(65+x), y+1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("6f817e"))
			if action.get("kind") == "move":
				draw_circle(center(cell), 6, MINT, true, -1, true)
				draw_arc(center(cell), 17, 0, TAU, 32, Color(MINT,0.3), 1, true)
	# Edge ticks make the lethal boundary explicit without a noisy texture.
	for i in range(3):
		var v = 120.0 + STEP*i
		for p in [Vector2(v,8),Vector2(v,592)]:
			draw_line(p-Vector2(12,0),p+Vector2(12,0),Color("a27164"),2,true)
		for p in [Vector2(8,v),Vector2(592,v)]:
			draw_line(p-Vector2(0,12),p+Vector2(0,12),Color("a27164"),2,true)
	var prediction = battle.preview(selected, hover_cell) if not locked else {}
	if prediction.get("kind") == "attack":
		var delta = Vector2(FallBattle.DIRECTIONS[prediction.direction])
		var start = center(prediction.target) + delta*73
		var end = start + delta*48
		var color = MINT if prediction.outcome in ["push","fall"] else CORAL
		draw_line(start, end, color, 4, true)
		var tangent = Vector2(-delta.y, delta.x)
		draw_line(end, end-delta*10+tangent*8, color, 4, true)
		draw_line(end, end-delta*10-tangent*8, color, 4, true)

func animate(event: Dictionary) -> float:
	tweens = tweens.filter(func(t: Tween): return t.is_valid())
	var actor = views[event.id]
	var tween = create_tween()
	tweens.append(tween)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if event.kind == "move":
		tween.tween_property(actor, "position", center(event.target), 0.24)
		return 0.28
	var delta = Vector2(FallBattle.DIRECTIONS[event.direction])
	var home = center(event.from)
	tween.tween_property(actor, "position", home+delta*15, 0.10)
	tween.tween_property(actor, "position", home, 0.16)
	var defender = views[event.defender]
	var pushed = create_tween()
	tweens.append(pushed)
	pushed.tween_interval(0.08)
	if event.outcome == "fall":
		pushed.set_parallel(true)
		pushed.tween_property(defender, "position", center(event.destination), 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		pushed.tween_property(defender, "modulate:a", 0.0, 0.42)
		pushed.tween_property(defender, "scale", Vector2(0.64,0.64), 0.42)
		return 0.55
	elif event.outcome == "push":
		pushed.tween_property(defender,"position",center(event.destination),0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		return 0.38
	else:
		var original = center(event.target)
		pushed.tween_property(defender,"position",original+delta*5,0.07)
		pushed.tween_property(defender,"position",original,0.12)
		return 0.32
