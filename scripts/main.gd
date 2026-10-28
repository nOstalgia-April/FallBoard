extends Control
## UI orchestrator. A generation counter cancels stale AI/animation continuations
## when a level is restarted or changed during an enemy turn.

const Battle = preload("res://scripts/battle.gd")
const BoardView = preload("res://scripts/board_view.gd")
const FONT = preload("res://assets/fonts/FallBoardSans.ttf")
const INK = Color("e5eae1")
const MUTED = Color("90a29e")
const MINT = Color("b5ef9e")
const CORAL = Color("f39b8d")

var levels: Array
var battle: FallBattle
var level_index = 0
var generation = 0
var busy = false
var selected = ""
var wins: Array[int] = []
var lines: Array[String] = []
var stage: Control
var board: Control
var labels: Dictionary = {}
var level_buttons: Array[Button] = []
var end_button: Button
var hint_button: Button
var modal: Control
var hint_open = false

func _ready() -> void:
	levels = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	var theme_resource = Theme.new()
	theme_resource.default_font = FONT
	theme_resource.default_font_size = 16
	theme = theme_resource
	_build_ui()
	resized.connect(_fit)
	_fit()
	_load_level(0)
	# Local QA can inspect a rendered game through -- --screenshot=absolute.png.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshot="):
			_capture(argument.trim_prefix("--screenshot="))

func _fit() -> void:
	var factor = minf(size.x / 1440.0, size.y / 900.0)
	stage.scale = Vector2.ONE * factor
	stage.position = (size - Vector2(1440,900)*factor)/2.0
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("10171c"))
	for x in range(0,int(size.x),36):
		for y in range(0,int(size.y),36):
			draw_circle(Vector2(x,y),0.65,Color("243038"))

func _build_ui() -> void:
	stage = Control.new()
	stage.size = Vector2(1440,900)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	_label("FALLBOARD",Vector2(54,30),Vector2(450,57),42,INK)
	_label("九格之间，一推定局。",Vector2(57,91),Vector2(400,26),16,MUTED)
	_label("PUSH PROTOTYPE  /  v0.1",Vector2(850,55),Vector2(270,28),14,MUTED)
	_button("玩法说明  ?",Rect2(1120,43,130,44),_show_guide)
	_button("重新开始  R",Rect2(1264,43,130,44),func(): _load_level(level_index))
	_rule(Rect2(54,132,1340,1))
	_label("FIELD NOTES  /  战术训练",Vector2(56,164),Vector2(300,24),13,MUTED)
	labels.level_number = _label("01",Vector2(53,197),Vector2(250,91),76,MINT)
	labels.level_title = _label("临界一推",Vector2(56,295),Vector2(290,40),30,INK)
	labels.level_tag = _label("LEARN THE EDGE",Vector2(58,343),Vector2(310,24),12,MUTED)
	labels.description = _label("",Vector2(58,390),Vector2(285,114),19,INK)
	_label("选择关卡",Vector2(58,536),Vector2(260,26),13,MUTED)
	for i in range(3):
		var index = i
		var button = _button("",Rect2(54,575+i*62,282,50),func(): _load_level(index))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("outline_size",0)
		level_buttons.append(button)
	_rule(Rect2(56,782,278,1))
	_label("胜利条件",Vector2(58,800),Vector2(260,24),13,MUTED)
	_label("将所有敌人推出棋盘",Vector2(58,830),Vector2(280,28),18,INK)
	labels.turn = _label("你的回合",Vector2(400,160),Vector2(300,40),25,MINT)
	labels.round = _label("ROUND 01 / 20",Vector2(741,166),Vector2(220,28),15,MUTED)
	board = BoardView.new()
	board.position = Vector2(370,200)
	board.size = Vector2(600,600)
	board.font = FONT
	board.cell_clicked.connect(_on_cell_clicked)
	board.cell_hovered.connect(func(_cell): _preview())
	stage.add_child(board)
	labels.ap = _label("●  ●   2 / 2 AP",Vector2(400,810),Vector2(300,36),23,MINT)
	end_button = _button("结束回合  →",Rect2(730,804,210,50),_end_turn,true)
	_label("左键选择 / 行动     ·     方向键行动     ·     E 结束回合",Vector2(400,863),Vector2(620,24),12,MUTED)
	_rule(Rect2(996,166,1,674))
	_label("TACTICAL READOUT",Vector2(1030,166),Vector2(350,25),13,MUTED)
	labels.preview_title = _label("先选择一枚棋子",Vector2(1030,209),Vector2(350,36),23,INK)
	labels.comparison = _label("—",Vector2(1028,263),Vector2(355,72),58,INK)
	labels.outcome = _label("等待指令",Vector2(1030,354),Vector2(350,36),25,MINT)
	labels.preview_body = _label("绿色圆点是可移动位置。\n珊瑚色边框标出可攻击目标。",Vector2(1030,406),Vector2(348,84),17,MUTED)
	_rule(Rect2(1030,509,349,1))
	labels.roster = _label("我方 2 / 2     敌方 2 / 2",Vector2(1030,533),Vector2(350,30),20,INK)
	_label("●  A / B 我方     ■  X / Y 敌方",Vector2(1030,574),Vector2(350,26),14,MUTED)
	hint_button = _button("查看本关提示",Rect2(1030,623,348,43),_toggle_hint)
	labels.log = _label("",Vector2(1030,692),Vector2(350,148),15,MUTED)
	labels.log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label("严格大于才能击退 · 棋盘外即死亡",Vector2(1030,859),Vector2(370,26),12,MUTED)

func _label(value: String, position_value: Vector2, dimensions: Vector2, font_size: int, color: Color, parent: Node = null) -> Label:
	var label = Label.new()
	label.text = value
	label.position = position_value
	label.size = dimensions
	label.add_theme_font_override("font",FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else stage).add_child(label)
	return label

func _box(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(9)
	box.content_margin_left = 16
	box.content_margin_right = 16
	return box

func _button(value: String, rect: Rect2, action: Callable, primary = false, parent: Node = null) -> Button:
	var button = Button.new()
	button.text = value
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font",FONT)
	button.add_theme_font_size_override("font_size",16)
	button.add_theme_color_override("font_color",Color("1d2b22") if primary else INK)
	button.add_theme_color_override("font_hover_color",Color("1d2b22") if primary else MINT)
	button.add_theme_color_override("font_pressed_color",Color("1d2b22") if primary else MINT)
	button.add_theme_color_override("font_disabled_color",Color("708079"))
	button.add_theme_stylebox_override("normal",_box(MINT if primary else Color("1b252a"),Color("36453e")))
	button.add_theme_stylebox_override("hover",_box(Color("cefac1") if primary else Color("2b3934"),MINT))
	button.add_theme_stylebox_override("pressed",_box(Color("97cc83") if primary else Color("33483a"),MINT))
	button.add_theme_stylebox_override("disabled",_box(Color("25302b"),Color("36453e")))
	button.add_theme_stylebox_override("focus",_box(Color.TRANSPARENT,MINT))
	button.pressed.connect(action)
	(parent if parent != null else stage).add_child(button)
	return button

func _rule(rect: Rect2) -> void:
	var line = ColorRect.new()
	line.position = rect.position
	line.size = rect.size
	line.color = Color("33413e")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(line)

func _load_level(index: int) -> void:
	generation += 1
	_close_modal()
	level_index = index
	battle = Battle.new()
	battle.setup(levels[index])
	selected = ""
	busy = false
	hint_open = false
	lines = ["战斗开始。共享 2 点行动点。"]
	board.reset(battle)
	labels.level_number.text = levels[index].id
	labels.level_title.text = levels[index].title
	labels.level_tag.text = levels[index].tag
	labels.description.text = levels[index].description
	for i in range(3):
		level_buttons[i].text = "  %02d   %s%s" % [i+1,levels[i].subtitle,"  ✓" if i in wins else ""]
		level_buttons[i].add_theme_stylebox_override("normal",_box(Color("283c2e") if i == index else Color("1b252a"),MINT if i == index else Color("36453e")))
	_refresh()

func _refresh() -> void:
	board.locked = busy or battle.result != "" or battle.side != Battle.PLAYER
	board.selected = selected
	board.refresh()
	labels.turn.text = "战斗结束" if battle.result != "" else ("敌方行动中…" if battle.side == Battle.ENEMY else ("行动中…" if busy else "你的回合"))
	labels.turn.add_theme_color_override("font_color",CORAL if battle.side == Battle.ENEMY else MINT)
	labels.round.text = "ROUND %02d / 20" % battle.round_number
	labels.ap.text = "%s  %s   %d / 2 AP" % ["●" if battle.ap >= 1 else "○","●" if battle.ap >= 2 else "○",battle.ap]
	labels.ap.add_theme_color_override("font_color",CORAL if battle.side == Battle.ENEMY else MINT)
	labels.roster.text = "我方 %d / 2     敌方 %d / 2" % [battle.count(0),battle.count(1)]
	end_button.disabled = busy or battle.side != Battle.PLAYER or battle.result != ""
	hint_button.text = "收起本关提示" if hint_open else "查看本关提示"
	labels.log.text = levels[level_index].hint if hint_open else "行动记录\n" + "\n".join(lines)
	_preview()

func _preview() -> void:
	var preview = battle.preview(selected,board.hover_cell) if not busy and battle.side == Battle.PLAYER else {}
	labels.comparison.add_theme_color_override("font_color",INK)
	labels.outcome.add_theme_color_override("font_color",MINT)
	if preview.get("kind") == "attack":
		var direction_names = ["向上 ↑","向右 →","向下 ↓","向左 ←"]
		labels.preview_title.text = "%s → %s  /  %s" % [battle.by_id(selected).name,battle.by_id(preview.defender).name,direction_names[preview.direction]]
		labels.comparison.text = "%d %s %d" % [preview.attack,">" if preview.attack > preview.defense else "≤",preview.defense]
		var outcomes = {"fall":"推落 · 立即击杀","push":"击退 · 移动一格","blocked":"阻挡 · 位置不变","fail":"失败 · 数值不足"}
		labels.outcome.text = outcomes[preview.outcome]
		var descriptions = {"fall":"目标后方是棋盘外。\n点击攻击，消耗 1 AP。","push":"目标后方为空格。\n点击攻击，消耗 1 AP。","blocked":"目标后方有棋子，不能连锁击退。\n这次攻击仍会消耗 1 AP。","fail":"攻击值必须严格大于防御值。\n这次攻击仍会消耗 1 AP。"}
		labels.preview_body.text = descriptions[preview.outcome]
		if preview.outcome in ["blocked","fail"]:
			labels.outcome.add_theme_color_override("font_color",CORAL)
	elif preview.get("kind") == "move":
		labels.preview_title.text = "移动到 %s%d" % [char(65+preview.target.x),preview.target.y+1]
		labels.comparison.text = "1 AP"
		labels.outcome.text = "移动 · 相邻空格"
		labels.preview_body.text = "每次移动一格，不改变数字朝向。\n同一棋子可以连续行动。"
	else:
		labels.preview_title.text = "已选择 %s" % battle.by_id(selected).name if selected != "" else "先选择一枚棋子"
		labels.comparison.text = "—"
		labels.outcome.text = "悬停敌人，预览攻击" if selected != "" else "两枚棋子 · 两点行动"
		labels.preview_body.text = "绿色圆点是可移动位置。\n珊瑚色边框标出可攻击目标。"
		if busy or battle.side == Battle.ENEMY:
			labels.preview_title.text = "敌方正在思考" if battle.side == Battle.ENEMY else "执行行动"
			labels.outcome.text = "优先推落，其次击退"
			labels.preview_body.text = "敌方每回合也共享 2 AP。\n相同局面会做出相同选择。"

func _on_cell_clicked(cell: Vector2i) -> void:
	if busy or is_instance_valid(modal) or battle.result != "" or battle.side != Battle.PLAYER:
		return
	if not Battle.inside(cell):
		selected = ""
		_refresh()
		return
	var piece = battle.at(cell)
	if not piece.is_empty() and int(piece.team) == Battle.PLAYER:
		selected = piece.id
		_refresh()
		return
	if selected == "" or battle.preview(selected,cell).is_empty():
		return
	_player_action(cell)

func _player_action(cell: Vector2i) -> void:
	var token = generation
	busy = true
	var event = battle.act(selected,cell)
	if event.is_empty():
		busy = false
		return
	await _present_action(event,token)
	if token != generation:
		return
	busy = false
	if battle.result != "":
		_finish()
	elif battle.side == Battle.ENEMY:
		_enemy_turn(token)
	else:
		_refresh()

func _present_action(event: Dictionary, token: int) -> void:
	_refresh()
	var duration = board.animate(event)
	_log_action(event)
	await get_tree().create_timer(duration).timeout
	if token != generation:
		return
	if selected != "" and not battle.by_id(selected).alive:
		selected = ""
	_refresh()

func _end_turn() -> void:
	if busy or battle.result != "" or battle.side != Battle.PLAYER or is_instance_valid(modal):
		return
	_add_log("你结束了回合。")
	battle.end_turn()
	_enemy_turn(generation)

func _enemy_turn(token: int) -> void:
	busy = true
	selected = ""
	_refresh()
	while token == generation and battle.side == Battle.ENEMY and battle.result == "":
		await get_tree().create_timer(0.45).timeout
		if token != generation:
			return
		var action = battle.ai_action()
		if action.is_empty():
			_add_log("敌方无有效行动，结束回合。")
			battle.end_turn()
			break
		var event = battle.act(action.id,action.target)
		await _present_action(event,token)
	if token != generation:
		return
	busy = false
	if battle.result != "":
		_finish()
	else:
		_add_log("第 %d 轮 · 你的回合" % battle.round_number)
		_refresh()

func _log_action(event: Dictionary) -> void:
	var name_value: String = battle.by_id(event.id).name
	if event.kind == "move":
		_add_log("%s 移动到 %s%d" % [name_value,char(65+event.target.x),event.target.y+1])
	else:
		var result_names = {"fall":"推落","push":"击退","blocked":"被阻挡","fail":"失败"}
		_add_log("%s → %s  %d%s%d · %s" % [name_value,battle.by_id(event.defender).name,event.attack,">" if event.attack>event.defense else "≤",event.defense,result_names[event.outcome]])

func _add_log(value: String) -> void:
	lines.append(value)
	while lines.size() > 4:
		lines.pop_front()
	labels.log.text = levels[level_index].hint if hint_open else "行动记录\n" + "\n".join(lines)

func _toggle_hint() -> void:
	hint_open = not hint_open
	_refresh()

func _modal_base() -> Control:
	_close_modal()
	modal = Control.new()
	modal.size = Vector2(1440,900)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(modal)
	var dim = ColorRect.new()
	dim.color = Color(0.025,0.04,0.045,0.88)
	dim.size = Vector2(1440,900)
	modal.add_child(dim)
	var panel = Panel.new()
	panel.position = Vector2(370,180)
	panel.size = Vector2(700,540)
	panel.add_theme_stylebox_override("panel",_box(Color("1b272b"),Color("6b8b67")))
	modal.add_child(panel)
	return panel

func _close_modal() -> void:
	if is_instance_valid(modal):
		stage.remove_child(modal)
		modal.queue_free()
	modal = null

func _show_guide() -> void:
	var panel = _modal_base()
	_label("THE RULES / 玩法说明",Vector2(42,32),Vector2(610,30),14,MINT,panel)
	_label("比大小，找角度，推下去。",Vector2(42,84),Vector2(620,50),32,INK,panel)
	_label("1   点击 A 或 B，选中你的棋子。\n2   点击相邻空格移动，点击相邻敌人攻击。\n3   比较接触面的数字：只有严格大于才会击退。\n4   推到棋盘外立即死亡；后方有棋子则阻挡。\n5   双方各有 2 AP；移动、失败或被阻挡的攻击均耗 1 AP。\n6   数字固定、不能旋转。第 20 轮结束未分胜负则僵局。",Vector2(42,164),Vector2(620,235),18,INK,panel)
	_label("方向键：操作已选棋子    E：结束回合    R：重开    Esc：关闭 / 取消选择",Vector2(42,412),Vector2(630,28),13,MUTED,panel)
	_button("明白了，开始推落",Rect2(42,465,615,46),_close_modal,true,panel)

func _finish() -> void:
	selected = ""
	_refresh()
	if battle.result == "victory" and level_index not in wins:
		wins.append(level_index)
	var panel = _modal_base()
	var titles = {"victory":"胜利，棋盘归你。","defeat":"落下去，再来一次。","stalemate":"僵局，换一种走法。"}
	_label("BATTLE COMPLETE / 战斗结束",Vector2(42,38),Vector2(620,28),14,MINT,panel)
	_label(titles[battle.result],Vector2(42,111),Vector2(630,58),38,INK,panel)
	var summary = {"victory":"所有敌方棋子已被推落。","defeat":"所有己方棋子已被推落。","stalemate":"第 20 轮结束，双方仍有棋子存活。本局不计胜利。"}
	_label(summary[battle.result],Vector2(42,205),Vector2(630,36),19,MUTED,panel)
	_label("第 %d 轮     /     共 %d 次行动" % [battle.round_number,battle.actions_taken],Vector2(42,268),Vector2(630,40),23,INK,panel)
	_button("再试一次",Rect2(42,388,290,54),func(): _load_level(level_index),false,panel)
	if battle.result == "victory" and level_index < 2:
		_button("下一关  →",Rect2(352,388,305,54),func(): _load_level(level_index+1),true,panel)
	else:
		_button("回到第一关",Rect2(352,388,305,54),func(): _load_level(0),true,panel)
	_label("%s" % ("三关已完成。现在试试更少的行动。" if wins.size()==3 else "观察攻击预览，再决定下一步。"),Vector2(42,474),Vector2(630,28),16,MUTED,panel)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_R:
		_load_level(level_index)
	elif event.keycode == KEY_ESCAPE:
		if is_instance_valid(modal) and battle.result == "":
			_close_modal()
		else:
			selected = ""
			_refresh()
	elif event.keycode == KEY_E:
		_end_turn()
	elif event.keycode in [KEY_1,KEY_2,KEY_3] and not is_instance_valid(modal):
		_load_level(event.keycode-KEY_1)
	elif selected != "" and not busy and not is_instance_valid(modal):
		var keys = [KEY_UP,KEY_RIGHT,KEY_DOWN,KEY_LEFT]
		var direction = keys.find(event.keycode)
		if direction >= 0:
			_on_cell_clicked(battle.by_id(selected).pos+Battle.DIRECTIONS[direction])

func _capture(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
