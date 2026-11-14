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
	game._menu._show_page("circuit")
	var tiles: Array[Button] = []
	for child in game._menu._content.get_children():
		if child is Button:
			tiles.append(child)
	assert(tiles.size() == 6)
	for i in tiles.size():
		for j in range(i + 1, tiles.size()):
			assert(not Rect2(tiles[i].position, tiles[i].size).intersects(Rect2(tiles[j].position, tiles[j].size)), "Circuit tiles overlap")
	var old_scale: int = UiScale.selected_mode
	UiScale.set_mode(1)
	var small_card: float = game._menu._card.scale.x
	UiScale.set_mode(3)
	assert(game._menu._card.scale.x > small_card, "GUI Scale must resize the menu immediately")
	UiScale.set_mode(old_scale)
	game._menu.race_requested.emit("assen", 2, 1, true)
	await process_frame
	assert(game._race_running and game._hud.visible and game.circuit.id == "assen")
	assert(game._riders.size() == 10)
	# Player and AI must reference the same immutable imported bike meshes and
	# textures, rather than creating a separate GPU copy for every AI rider.
	var player_model: Node = game._player.get_node("VisualPivot/DucatiBike")
	var ai_model: Node = game._riders[1].get_node("VisualPivot/DucatiBike")
	var player_meshes := player_model.find_children("*", "MeshInstance3D", true, false)
	var ai_meshes := ai_model.find_children("*", "MeshInstance3D", true, false)
	assert(not player_meshes.is_empty() and player_meshes.size() == ai_meshes.size())
	for i in player_meshes.size():
		var player_mesh: MeshInstance3D = player_meshes[i]
		var ai_mesh: MeshInstance3D = ai_meshes[i]
		assert(player_mesh.mesh == ai_mesh.mesh, "AI duplicated bike mesh resources")
		for surface in player_mesh.mesh.get_surface_count():
			assert(player_mesh.get_active_material(surface) == ai_mesh.get_active_material(surface), "AI duplicated bike material resources")
	assert(game.race_laps == 2 and game.countdown > 0.0)
	assert(not game._hud._speed_label.text.is_empty() and game._hud.tower._rows.size() == 10, "HUD must be populated during countdown")
	assert(game._hud._display_font.get_string_size(game._hud._track_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, game._hud._track_label.get_theme_font_size("font_size")).x <= game._hud._track_label.size.x + 1.0, "Circuit name is clipped")
	var left_key := InputEventKey.new()
	left_key.keycode = KEY_A
	left_key.pressed = true
	Input.parse_input_event(left_key)
	assert(game._player_command().z > 0.0, "A must turn left in the chase camera")
	left_key.pressed = false
	Input.parse_input_event(left_key)
	var right_key := InputEventKey.new()
	right_key.keycode = KEY_D
	right_key.pressed = true
	Input.parse_input_event(right_key)
	assert(game._player_command().z < 0.0, "D must turn right in the chase camera")
	right_key.pressed = false
	Input.parse_input_event(right_key)
	game._toggle_pause()
	assert(game.paused and game._pause_menu.visible and not game._race_running)
	game._pause_menu.settings_requested.emit()
	assert(game._menu.visible and game._menu._page == "settings")
	game._menu.settings_closed.emit()
	assert(game._pause_menu.visible and not game._menu.visible)
	game._toggle_pause()
	assert(game._race_running and not game.paused)
	# Exercise two independently held touch indices and a drag-out release.
	var controls: WmcTouchControls = game._hud.touch_controls
	controls.visible = true
	controls.size = Vector2(1280, 720)
	controls._recalculate_layout()
	var steer := InputEventScreenTouch.new()
	steer.index = 7
	steer.pressed = true
	steer.position = controls._left_rect.get_center()
	controls._input(steer)
	var throttle := InputEventScreenTouch.new()
	throttle.index = 8
	throttle.pressed = true
	throttle.position = controls._throttle_rect.get_center()
	controls._input(throttle)
	assert(controls.command() == Vector3(1, 0, -1), "Steering and throttle must work together")
	steer.pressed = false
	controls._input(steer)
	assert(controls.command() == Vector3(1, 0, 0), "Releasing steering must not release throttle")
	controls.clear()
	controls.visible = false
	game.countdown = 0.0
	var start_time: float = game._race_time_seconds
	game._player.drive(Vector3(0.0, 1.0, 0.0), 0.1)
	assert(game._player.speed_metres_per_second < 0.0, "Brake must reverse from rest")
	game._player.drive(Vector3.ZERO, 0.1, true)
	assert(game._player.speed_metres_per_second == 0.0, "Hard brake must stop reverse rather than accelerate forwards")
	game._player.laps_completed = game.race_laps
	game._finish_completed_riders()
	assert(game._player.finished and game._winner_name == game._player.display_name)
	assert(not game._summary.visible and game._race_running, "Player must be able to see and cruise after finishing")
	game._finish_delay = game._summary.TOTAL_DURATION
	game._physics_process(0.01)
	assert(game._summary.visible and game._race_running, "Finish order must show after the cruising period")
	assert(game._summary._rider_view.size == Vector2i(500, 813), "Results rider reference framing changed")
	assert(game._winner_number == game._player.racing_number)
	game._summary.advance(game._summary.RESULTS_DURATION + 0.5)
	assert(game._summary._elapsed > game._summary.RESULTS_DURATION and game._summary._rider_view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Championship transition did not switch off rider viewport")
	game._physics_process(0.01)
	assert(game._race_time_seconds == start_time, "Finishing must freeze the player timer")
	for dimensions in [Vector2(960, 540), Vector2(1280, 720), Vector2(2400, 1080)]:
		game._menu.size = dimensions
		game._menu._fit()
		var card: Control = game._menu._card
		assert(card.position.x >= 0 and card.position.y >= 0)
		assert((card.position + card.size * card.scale).x <= dimensions.x + 1)
		assert((card.position + card.size * card.scale).y <= dimensions.y + 1)
		game._finish_screen.size = dimensions
		game._finish_screen._card_intro = 1.0
		game._finish_screen._fit()
		var winner: Control = game._finish_screen._card
		assert(winner.position.x >= 0 and winner.position.y >= 0)
		assert((winner.position + winner.size * winner.scale).x <= dimensions.x + 1)
		assert((winner.position + winner.size * winner.scale).y <= dimensions.y + 1)
	game._summary.main_menu_requested.emit()
	assert(game._summary._menu_button.disabled, "Early exit must prevent duplicate presses")
	await create_timer(0.7).timeout
	assert(game._menu.visible and not game._race_running and not game._summary.visible, "Early exit did not return to the menu")
	if game._ambience:
		game._ambience.stop()
	if game._engine_audio:
		game._engine_audio.stop()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	quit(0)
