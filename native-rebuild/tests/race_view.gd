extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/Race.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game._menu.visible and not game._race_running)
	assert(game._riders.size() == 1)
	assert(game._player.global_position.distance_to(game.circuit.samples[game._player.track_index]) < 3.0)
	var target: Vector3 = game._player.global_position - game._camera.global_position
	assert((-game._camera.global_basis.z).dot(target.normalized()) > 0.8, "Camera is facing away from the rider")
	var road: MeshInstance3D = game._track_root.get_node("Asphalt")
	assert(road.material_override.albedo_texture != null)
	assert(road.material_override.cull_mode == BaseMaterial3D.CULL_DISABLED)
	game._menu.race_requested.emit("assen", 2, 1, true)
	await process_frame
	assert(game._race_running and game._hud.visible and game.circuit.id == "assen")
	assert(game._riders.size() == 10)
	assert(game.race_laps == 2 and game.countdown > 0.0)
	game._toggle_pause()
	assert(game.paused and game._pause_menu.visible and not game._race_running)
	game._pause_menu.settings_requested.emit()
	assert(game._menu.visible and game._menu._page == "settings")
	game._menu.settings_closed.emit()
	assert(game._pause_menu.visible and not game._menu.visible)
	game._toggle_pause()
	assert(game._race_running and not game.paused)
	game.countdown = 0.0
	var start_time: float = game._race_time_seconds
	game._player.drive(Vector3(0.0, 1.0, 0.0), 0.1)
	assert(game._player.speed_metres_per_second < 0.0, "Brake must reverse from rest")
	game._player.drive(Vector3.ZERO, 0.1, true)
	assert(game._player.speed_metres_per_second == 0.0, "Hard brake must stop reverse rather than accelerate forwards")
	game._player.laps_completed = game.race_laps
	game._finish_completed_riders()
	assert(game._player.finished and game._winner_name == game._player.display_name)
	assert(game._summary.visible and game._race_running, "Finish order must show while the player can still cruise")
	game._physics_process(0.01)
	assert(game._race_time_seconds == start_time, "Finishing must freeze the player timer")
	for dimensions in [Vector2(960, 540), Vector2(1280, 720), Vector2(2400, 1080)]:
		game._menu.size = dimensions
		game._menu._fit()
		var card: Control = game._menu._card
		assert(card.position.x >= 0 and card.position.y >= 0)
		assert((card.position + card.size * card.scale).x <= dimensions.x + 1)
		assert((card.position + card.size * card.scale).y <= dimensions.y + 1)
	if game._ambience:
		game._ambience.stop()
	if game._engine_audio:
		game._engine_audio.stop()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	quit(0)
