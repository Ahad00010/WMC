extends SceneTree
# Run inside the exported Windows engine under Wine, with an actual renderer.
# This exercises ANGLE/GL rendering and readback, not the user's Intel driver.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/Race.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	game._menu.race_requested.emit("sepang", 1, 1, true)
	game._footage.view.size = Vector2i(640, 360)
	game.countdown = 0.0
	await create_timer(4.0).timeout
	if game._riders.size() != 10 or game._footage.readback_count < 3:
		push_error("Windows engine did not render the AI race and capture frames")
		quit(1)
		return
	game._player.laps_completed = game.race_laps
	game._finish_completed_riders()
	if game._winner_frames.size() < 3:
		push_error("Windows capture did not retain live race frames")
		quit(1)
		return
	game._finish_delay = game._summary.TOTAL_DURATION
	game._physics_process(0.01)
	await create_timer(0.3).timeout
	game._finish_delay = 0.01
	game._physics_process(0.02)
	await create_timer(0.5).timeout
	if not game._finish_screen.visible or game._finish_screen._screen.texture == null:
		push_error("Windows playback did not show a captured frame")
		quit(1)
		return
	if game._ambience:
		game._ambience.stop()
	if game._engine_audio:
		game._engine_audio.stop()
	if game._results_audio:
		game._results_audio.stop()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	quit(0)
