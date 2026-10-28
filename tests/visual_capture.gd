extends SceneTree
## Render actual game views under Xvfb in CI; never substitute a mockup for QA.
const Main = preload("res://scenes/main.tscn")
var game

func _initialize() -> void:
	call_deferred("run")

func capture(name_value: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path = ProjectSettings.globalize_path("res://dist/"+name_value+".png")
	var error = root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Screenshot failed: " + path)
		quit(1)
	print("CAPTURE ",name_value)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dist"))
	game = Main.instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	await capture("FallBoard-board")
	game._on_cell_clicked(Vector2i(0,1))
	game.board.hover_cell = Vector2i(0,0)
	game._refresh()
	await capture("FallBoard-preview")
	game._load_level(2)
	game._on_cell_clicked(Vector2i(0,1))
	game.board.hover_cell = Vector2i(1,1)
	game._refresh()
	await capture("FallBoard-blocked")
	game._show_guide()
	await capture("FallBoard-guide")
	game._load_level(0)
	game._on_cell_clicked(Vector2i(0,1))
	game._on_cell_clicked(Vector2i(0,0))
	await create_timer(0.7).timeout
	game._on_cell_clicked(Vector2i(2,1))
	game._on_cell_clicked(Vector2i(2,0))
	await create_timer(0.7).timeout
	await capture("FallBoard-victory")
	game._load_level(0)
	root.size = Vector2i(960,600)
	await create_timer(0.3).timeout
	await capture("FallBoard-small")
	game.queue_free()
	await process_frame
	quit()
