extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A renderer is required")
		quit(1)
		return
	var game = load("res://scenes/Race.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.0).timeout
	game._menu.race_requested.emit("sepang", 1, 1, true)
	await create_timer(1.0).timeout
	game.countdown = 0.0
	# Smaller test viewport keeps software renderer smoke time practical.
	game._footage.view.size = Vector2i(640, 360)
	await create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/wmc-rebuild-race.png")
	game._player.laps_completed = game.race_laps
	game._finish_completed_riders()
	var frames: Array = game._winner_frames
	if frames.size() < 3:
		push_error("Real world capture failed: %d frames" % frames.size())
		quit(1)
		return
	var image := Image.new()
	if image.load_jpg_from_buffer(frames[0].jpeg) != OK or image.get_width() != 640:
		push_error("Captured footage did not decode")
		quit(1)
		return
	if game._camera.is_position_behind(game._player.global_position):
		push_error("Rider is behind the follow camera")
		quit(1)
		return
	game._finish_delay = 0.01
	game._physics_process(0.02)
	if not game._finish_screen.visible:
		push_error("Finish did not start the winner playback flow")
		quit(1)
		return
	await create_timer(0.5).timeout
	if game._finish_screen._screen.texture == null:
		push_error("Captured footage did not appear in playback")
		quit(1)
		return
	game._finish_screen._clock = 100.0
	game._finish_screen._process(0.01)
	await process_frame
	if not game._finish_screen._card.visible:
		push_error("Winner card was not shown after playback")
		quit(1)
		return
	if game._ambience:
		game._ambience.stop()
	if game._engine_audio:
		game._engine_audio.stop()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	quit(0)
