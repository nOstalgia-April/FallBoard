extends SceneTree
const Battle = preload("res://scripts/battle.gd")
var passed = 0
var failed = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + description)

func piece(id: String, team: int, position: Array, values: Array) -> Dictionary:
	return {"id":id,"name":id,"team":team,"position":position,"values":values}

func fixture(entries: Array) -> FallBattle:
	var b = Battle.new()
	b.setup({"pieces":entries})
	return b

func run() -> void:
	test_contact_faces()
	test_moves_and_costs()
	test_blocks()
	test_turns_and_endings()
	test_ai()
	var levels = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	for index in range(levels.size()):
		var b = Battle.new()
		b.setup(levels[index])
		check(b.count(0)==2 and b.count(1)==2,"2v2 level %d" % (index+1))
		var cells = {}
		for p in b.pieces:
			check(Battle.inside(p.pos) and not cells.has(p.pos),"valid unique spawn")
			cells[p.pos] = true
			check(p.values.size()==4,"four contact values")
			for value in p.values:
				check(value>=1 and value<=9,"values in 1..9")
		if index == 1:
			check(b.legal_actions().all(func(a): return a.outcome != "fall"),"level 2 no immediate kill")
		if index == 2:
			check(b.preview("P1",Vector2i(1,1)).get("outcome")=="blocked","level 3 requires clearing teammate")
			check(b.by_id("P1").values.max()<=b.by_id("E2").values[3],"A cannot push Y from left")
			check(b.by_id("P2").values.max()<=b.by_id("E1").values[2],"B cannot push X upward")
		var solution = solve(b)
		check(not solution.is_empty(),"level %d solvable against actual AI" % (index+1))
		print("SOLUTION ",index+1,": ",JSON.stringify(solution))
	print("RESULT: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)

func test_contact_faces() -> void:
	for direction in range(4):
		var target = Vector2i(1,1)+Battle.DIRECTIONS[direction]
		var av = [1,1,1,1]
		av[direction] = 7
		var dv = [9,9,9,9]
		dv[(direction+2)%4] = 3
		var b = fixture([piece("P",0,[1,1],av),piece("E",1,[target.x,target.y],dv)])
		var event = b.preview("P",target)
		check(event.attack==7 and event.defense==3,"opposing contact faces %d" % direction)
		check(event.outcome=="fall","all four lethal edges")
		var before = b.key()
		b.preview("P",target)
		check(before==b.key(),"preview does not mutate state")
		b.act("P",target)
		check(b.result=="victory" and not b.by_id("E").alive,"fall immediately ends battle")
		check(b.by_id("P").values==av and b.by_id("E").values==dv,"attack does not alter values")
	for defense in [7,8]:
		var b = fixture([piece("P",0,[0,1],[1,7,1,1]),piece("E",1,[1,1],[1,1,1,defense])])
		var event = b.act("P",Vector2i(1,1))
		check(event.outcome=="fail" and b.ap==1,"equal or weaker attack costs AP")
		check(b.by_id("E").pos==Vector2i(1,1),"failed attack stays put")
	var push = fixture([piece("P",0,[0,1],[1,7,1,1]),piece("E",1,[1,1],[1,1,1,2])])
	check(push.act("P",Vector2i(1,1)).outcome=="push","successful push")
	check(push.by_id("E").pos==Vector2i(2,1) and push.by_id("P").pos==Vector2i(0,1),"only defender moves one cell")

func test_moves_and_costs() -> void:
	var b = fixture([piece("P",0,[0,0],[1,2,3,4]),piece("Q",0,[1,0],[4,3,2,1]),piece("E",1,[2,2],[2,2,2,2])])
	for cell in [Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,1),Vector2i(0,2),Vector2i(1,0)]:
		check(b.act("P",cell).is_empty() and b.ap==2,"illegal movement costs no AP")
	check(b.act("E",Vector2i(2,1)).is_empty(),"cannot control enemy")
	b.act("P",Vector2i(0,1))
	check(b.ap==1 and b.side==0,"move costs 1 AP")
	b.act("P",Vector2i(1,1))
	check(b.by_id("P").pos==Vector2i(1,1) and b.side==1 and b.ap==2,"same piece may act twice; automatic turn")
	check(b.by_id("P").values==[1,2,3,4],"moving does not rotate")
	check(b.preview("P",Vector2i(1,2)).is_empty(),"wrong team preview invalid")

func test_blocks() -> void:
	for team in [0,1]:
		var b = fixture([piece("P",0,[0,1],[1,8,1,1]),piece("E",1,[1,1],[1,1,1,2]),piece("BLOCK",team,[2,1],[1,1,1,1])])
		var event = b.act("P",Vector2i(1,1))
		check(event.outcome=="blocked" and b.ap==1,"either team's piece blocks; costs 1 AP")
		check(b.by_id("P").pos==Vector2i(0,1) and b.by_id("E").pos==Vector2i(1,1) and b.by_id("BLOCK").pos==Vector2i(2,1),"no chain push or overlap")

func test_turns_and_endings() -> void:
	var b = fixture([piece("P",0,[0,0],[1,1,1,1]),piece("E",1,[0,1],[9,9,9,9])])
	b.end_turn()
	check(b.side==1 and b.ap==2 and b.round_number==1,"early end discards AP")
	b.act("E",Vector2i(0,0))
	check(b.result=="defeat","all players dead => defeat")
	var key = b.key()
	check(b.act("E",Vector2i(1,1)).is_empty(),"no action after game over")
	b.end_turn()
	check(b.key()==key,"no turns after game over")
	b = fixture([piece("P",0,[0,0],[1,1,1,1]),piece("E",1,[2,2],[1,1,1,1])])
	for i in range(39):
		b.end_turn()
	check(b.round_number==20 and b.side==1 and b.result=="","not stalemate at start of round 20 enemy turn")
	b.end_turn()
	check(b.result=="stalemate" and b.round_number==20,"stalemate after both sides of round 20")
	b = fixture([piece("P",0,[0,0],[1,1,1,1]),piece("E",1,[0,1],[9,9,9,9])])
	b.round_number = 20
	b.side = 1
	b.ap = 1
	b.act("E",Vector2i(0,0))
	check(b.result=="defeat","final action elimination takes precedence over stalemate")
	b.setup({"pieces":[piece("P",0,[1,1],[1,1,1,1]),piece("E",1,[0,0],[1,1,1,1])]})
	check(b.result=="" and b.side==0 and b.ap==2 and b.round_number==1 and b.actions_taken==0,"restart resets all battle state")

func test_ai() -> void:
	var b = fixture([piece("P",0,[0,0],[1,1,1,1]),piece("Q",0,[1,1],[1,1,1,1]),piece("E",1,[0,1],[9,9,9,9])])
	b.side = 1
	check(b.ai_action().outcome=="fall","AI prioritizes kill over push")
	var first = b.ai_action()
	check(first==b.ai_action(),"AI repeated choice deterministic")
	b = fixture([piece("P",0,[1,1],[1,1,1,1]),piece("E",1,[0,1],[9,9,9,9])])
	b.side = 1
	check(b.ai_action().outcome=="push","AI prioritizes valid push over moves")
	b = fixture([piece("P",0,[2,2],[9,9,9,9]),piece("E",1,[0,0],[1,1,1,1])])
	b.side = 1
	check(b.ai_action().target==Vector2i(1,0),"AI Manhattan distance and direction tie break")
	b = fixture([piece("P",0,[1,0],[9,9,9,9]),piece("Q",0,[0,1],[9,9,9,9]),piece("E",1,[0,0],[1,1,1,1])])
	b.side = 1
	check(b.ai_action().is_empty(),"AI ends when no move or effective attack exists")

func solve(start: FallBattle) -> Array:
	# Breadth-first actual player actions; fully simulate deterministic AI between turns.
	var queue: Array = [{"state":start,"path":[]}]
	var cursor = 0
	var seen = {}
	while cursor < queue.size() and cursor < 80000:
		var entry: Dictionary = queue[cursor]
		cursor += 1
		var current: FallBattle = entry.state
		if current.result=="victory":
			print("Solver explored ",cursor," states")
			return entry.path
		if current.result!="" or current.round_number>10:
			continue
		var actions = current.legal_actions()
		actions.append({"kind":"end"})
		for action in actions:
			var next = current.copy()
			var path: Array = entry.path.duplicate()
			if action.kind=="end":
				next.end_turn()
				path.append("END")
			else:
				var event = next.act(action.id,action.target)
				path.append("%s>%s%d:%s" % [action.id,char(65+action.target.x),action.target.y+1,event.outcome])
			while next.side==1 and next.result=="":
				var ai = next.ai_action()
				if ai.is_empty():
					next.end_turn()
				else:
					next.act(ai.id,ai.target)
			var key = next.key()
			if not seen.has(key):
				seen[key]=true
				queue.append({"state":next,"path":path})
	return []
