extends SceneTree
const Kart = preload("res://scripts/kart.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	var game: Node = Kart.new()
	root.add_child(game)
	game.setup(null)
	var track: int = 0
	var output: String = "user://kart-preview.png"
	var pause_capture: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		if arg.begins_with("--track="):
			track = int(arg.trim_prefix("--track="))
		if arg=="--pause":
			pause_capture = true
	game.start([0,3],[0,1],track,2)
	game.phase = "race"
	game.elapsed = 8.0
	game.racers[0].item = 1
	game.racers[1].item = 6
	if pause_capture:
		game.toggle_pause()
	for i: int in range(18):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output)
	print("KART CAPTURE ",output)
	quit()
