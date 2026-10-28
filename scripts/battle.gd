class_name FallBattle
extends RefCounted
## Pure rules. Rendering, animation and time never influence the result.
## Values are always [up, right, down, left]; pieces never rotate.

const DIRECTIONS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const PLAYER = 0
const ENEMY = 1
const MAX_ROUNDS = 20
const AP_PER_TURN = 2

var pieces: Array = []
var side: int = PLAYER
var ap: int = AP_PER_TURN
var round_number: int = 1
var result: String = ""
var actions_taken: int = 0

func setup(level: Dictionary) -> void:
	pieces.clear()
	for source in level.pieces:
		var piece: Dictionary = source.duplicate(true)
		piece.pos = Vector2i(int(source.position[0]), int(source.position[1]))
		piece.alive = true
		pieces.append(piece)
	side = PLAYER
	ap = AP_PER_TURN
	round_number = 1
	result = ""
	actions_taken = 0

func copy() -> FallBattle:
	var other = FallBattle.new()
	other.pieces = pieces.duplicate(true)
	other.side = side
	other.ap = ap
	other.round_number = round_number
	other.result = result
	other.actions_taken = actions_taken
	return other

static func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < 3 and cell.y >= 0 and cell.y < 3

func at(cell: Vector2i) -> Dictionary:
	for piece in pieces:
		if piece.alive and piece.pos == cell:
			return piece
	return {}

func by_id(id: String) -> Dictionary:
	for piece in pieces:
		if piece.id == id:
			return piece
	return {}

func count(team: int) -> int:
	var total = 0
	for piece in pieces:
		if piece.alive and int(piece.team) == team:
			total += 1
	return total

func preview(id: String, target: Vector2i) -> Dictionary:
	var attacker = by_id(id)
	if result != "" or ap <= 0 or attacker.is_empty():
		return {}
	if not attacker.alive or int(attacker.team) != side or not inside(target):
		return {}
	var delta: Vector2i = target - attacker.pos
	var direction = DIRECTIONS.find(delta)
	if direction < 0:
		return {}
	var defender = at(target)
	var event = {"id": id, "from": attacker.pos, "target": target, "direction": direction, "team": side}
	if defender.is_empty():
		event.kind = "move"
		event.outcome = "move"
		return event
	if int(defender.team) == side:
		return {}
	event.kind = "attack"
	event.defender = defender.id
	event.attack = int(attacker.values[direction])
	event.defense = int(defender.values[(direction + 2) % 4])
	event.destination = target + delta
	if event.attack <= event.defense:
		event.outcome = "fail"
	elif not inside(event.destination):
		event.outcome = "fall"
	elif not at(event.destination).is_empty():
		event.outcome = "blocked"
	else:
		event.outcome = "push"
	return event

func legal_actions() -> Array:
	var actions: Array = []
	# Stable order: file order P1, P2, E1, E2; then up, right, down, left.
	for piece in pieces:
		if not piece.alive or int(piece.team) != side:
			continue
		for delta in DIRECTIONS:
			var action = preview(piece.id, piece.pos + delta)
			if not action.is_empty():
				actions.append(action)
	return actions

func act(id: String, target: Vector2i) -> Dictionary:
	var event = preview(id, target)
	if event.is_empty():
		return {}
	if event.kind == "move":
		by_id(id).pos = target
	elif event.outcome == "push":
		by_id(event.defender).pos = event.destination
	elif event.outcome == "fall":
		by_id(event.defender).pos = event.destination
		by_id(event.defender).alive = false
	ap -= 1
	actions_taken += 1
	_check_result()
	if result == "" and ap == 0:
		end_turn()
	event.result = result
	return event

func end_turn() -> void:
	if result != "":
		return
	if side == ENEMY:
		if round_number == MAX_ROUNDS:
			result = "stalemate"
			ap = 0
			return
		round_number += 1
	side = 1 - side
	ap = AP_PER_TURN

func _check_result() -> void:
	if count(ENEMY) == 0:
		result = "victory"
	elif count(PLAYER) == 0:
		result = "defeat"

func ai_action() -> Dictionary:
	if side != ENEMY or result != "":
		return {}
	var choices = legal_actions()
	for outcome in ["fall", "push"]:
		for action in choices:
			if action.outcome == outcome:
				return action
	var best: Dictionary = {}
	var best_distance = 999
	# Choose the move whose destination is nearest to a surviving player.
	# Ties retain piece order and then up/right/down/left order.
	for action in choices:
		if action.kind != "move":
			continue
		var distance = 999
		for player in pieces:
			if player.alive and int(player.team) == PLAYER:
				var delta: Vector2i = player.pos - action.target
				distance = mini(distance, absi(delta.x) + absi(delta.y))
		if distance < best_distance:
			best_distance = distance
			best = action
	return best

func key() -> String:
	var state = "%d:%d:%d:%s" % [side, ap, round_number, result]
	for piece in pieces:
		state += "|%s:%s:%s" % [piece.id, piece.pos, piece.alive]
	return state
