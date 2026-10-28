extends SceneTree
const Main = preload("res://scenes/main.tscn")
var game
var passed = 0
var failed = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("UI FAIL: " + description)

func idle() -> void:
	var ticks = 0
	while game.busy and ticks < 120:
		await create_timer(0.05).timeout
		ticks += 1
	check(not game.busy,"animation/AI finishes")

func action(id: String, cell: Vector2i) -> void:
	game._on_cell_clicked(game.battle.by_id(id).pos)
	game._on_cell_clicked(cell)
	await idle()

func run() -> void:
	game = Main.instantiate()
	root.add_child(game)
	await process_frame
	check(game.battle.count(0)==2 and game.battle.count(1)==2,"initial roster")
	game._on_cell_clicked(Vector2i(0,1))
	check(game.selected=="P1","mouse selection handler")
	game.board.hover_cell = Vector2i(0,0)
	game._refresh()
	check(game.labels.comparison.text=="7 > 2","exact attack preview")
	check(game.labels.outcome.text.contains("推落"),"lethal preview")
	check(game.board.views.P1.face==0 and game.board.views.E1.face==2,"both contact faces highlighted")
	await action("P1",Vector2i(0,0))
	check(game.battle.ap==1 and game.battle.count(1)==1,"first elimination and AP HUD")
	await action("P2",Vector2i(2,0))
	check(game.battle.result=="victory" and is_instance_valid(game.modal),"victory overlay")
	game._load_level(2)
	game._on_cell_clicked(Vector2i(0,1))
	game.board.hover_cell = Vector2i(1,1)
	game._refresh()
	check(game.labels.outcome.text.contains("阻挡"),"blocked preview")
	await action("P1",Vector2i(1,1))
	check(game.battle.ap==1 and game.battle.by_id("E1").pos==Vector2i(1,1),"blocked attack costs AP without overlap")
	game._on_cell_clicked(Vector2i(2,1))
	game.board.hover_cell = Vector2i(1,1)
	game._refresh()
	check(game.labels.comparison.text=="1 ≤ 9" and game.labels.outcome.text.contains("失败"),"failed preview")
	# Restart while AI is waiting, then allow every old callback time to fire.
	game._load_level(2)
	game._end_turn()
	check(game.busy,"enemy turn starts")
	game._load_level(0)
	var key = game.battle.key()
	await create_timer(2.0).timeout
	check(game.battle.key()==key and not game.busy,"restart cancels stale AI")
	# Restart during a fall animation; the new views must remain intact.
	game._on_cell_clicked(Vector2i(0,1))
	game._on_cell_clicked(Vector2i(0,0))
	game._load_level(1)
	key = game.battle.key()
	await create_timer(0.8).timeout
	check(game.battle.key()==key and game.board.views.size()==4,"restart cancels animation continuation")
	await action("P1",Vector2i(0,1))
	await action("P1",Vector2i(0,0))
	await action("P2",Vector2i(2,2))
	check(game.battle.result=="victory","level 2 win through UI and asynchronous AI")
	game._load_level(2)
	var route = [
		["P2",Vector2i(2,2)],["P1",Vector2i(1,1)],
		["P1",Vector2i(1,1)],["P1",Vector2i(2,1)],
		["P1",Vector2i(1,1)],["P1",Vector2i(0,2)],
		["P2",Vector2i(2,1)],["P2",Vector2i(2,0)]
	]
	for step in route:
		await action(step[0],step[1])
	check(game.battle.result=="victory","level 3 cooperation win through UI")
	game._load_level(2)
	# Immediate end allows the strong enemy to push A off the left edge after movement.
	for i in range(20):
		if game.battle.result!="":
			break
		game._end_turn()
		await idle()
	check(game.battle.result!="" and is_instance_valid(game.modal),"AI reaches a terminal UI state")
	game._load_level(0)
	game.battle.round_number = 20
	game.battle.side = 1
	game.battle.end_turn()
	game._finish()
	check(game.battle.result=="stalemate" and is_instance_valid(game.modal),"stalemate overlay")
	game.queue_free()
	await process_frame
	print("UI RESULT: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
