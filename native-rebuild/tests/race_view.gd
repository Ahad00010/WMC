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
	for dimensions in [Vector2(960, 540), Vector2(1280, 720), Vector2(2400, 1080)]:
		game._menu.size = dimensions
		game._menu._fit()
		var card: Control = game._menu._card
		assert(card.position.x >= 0 and card.position.y >= 0)
		assert((card.position + card.size * card.scale).x <= dimensions.x + 1)
		assert((card.position + card.size * card.scale).y <= dimensions.y + 1)
	game._ambience.stop()
	game._engine_audio.stop()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	quit(0)
