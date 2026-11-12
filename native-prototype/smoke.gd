extends SceneTree

func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 var game = load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 if game.track.size() < 100 or game.bike == null:
  push_error("Missing native track or bike")
  quit(1)
  return
 var road = game.get_node_or_null("Track_asphalt")
 if road == null or road.material_override.albedo_texture == null or game.get_node_or_null("Track_Barriers") == null or game.get_node_or_null("Track_Trees") == null:
  push_error("Circuit visuals did not initialize")
  quit(1)
  return
 if not game.menu.visible or game.controls.visible or game.music == null or game.auth == null:
  push_error("Native opening screen did not initialize")
  quit(1)
  return
 for button in game.controls.find_children("*", "Button", true, false):
  if button.focus_mode != Control.FOCUS_NONE:
   push_error("Driving controls can accidentally activate a focused button")
   quit(1)
   return
 var start = game.bike.position
 game.active = true
 game.touch["accelerate"] = true
 for i in range(120):
  game._physics_process(1.0 / 60.0)
 if game.speed <= 0.0 or game.bike.position.distance_to(start) < 1.0:
  push_error("Native bike failed to accelerate")
  quit(1)
  return
 var before_brake: float = game.speed
 var before_position: Vector3 = game.bike.position
 var key := InputEventKey.new()
 key.keycode = KEY_SPACE
 key.pressed = true
 Input.parse_input_event(key)
 await process_frame
 game._physics_process(0.1)
 var release := InputEventKey.new()
 release.keycode = KEY_SPACE
 release.pressed = false
 Input.parse_input_event(release)
 if game.speed >= before_brake or game.bike.position.distance_to(before_position) > 10.0:
  push_error("Hard brake did not slow the bike without resetting")
  quit(1)
  return
 game.replay_enabled = true
 game._process(1.0 / 20.0)
 if game.replay_view.render_target_update_mode != SubViewport.UPDATE_ONCE:
  push_error("Live second camera failed to render")
  quit(1)
  return
 game._show_results()
 if not game.results.visible or game.active:
  push_error("Results preview did not open")
  quit(1)
  return
 game._reset()
 if game.speed != 0.0 or game.replay_enabled:
  push_error("Restart failed to reset state")
  quit(1)
  return
 game.queue_free()
 quit(0)
