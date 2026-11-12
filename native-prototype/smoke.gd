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
 if game.speed < 25.0 or game.bike.position.distance_to(start) < 1.0:
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
 await process_frame
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
 game.menu.visible = false
 game.controls.visible = true
 var preserved_position: Vector3 = game.bike.position
 var preserved_speed: float = game.speed
 var escape := InputEventKey.new()
 escape.keycode = KEY_ESCAPE
 escape.pressed = true
 game._unhandled_key_input(escape)
 if not game.paused or game.active or not game.pause_panel.visible:
  push_error("Escape did not open the pause menu")
  quit(1)
  return
 game._physics_process(0.1)
 if game.bike.position != preserved_position or game.speed != preserved_speed:
  push_error("Bike moved while paused")
  quit(1)
  return
 game._resume_game()
 if game.paused or not game.active or game.bike.position != preserved_position:
  push_error("Resume did not preserve the race state")
  quit(1)
  return
 game.touch["accelerate"] = true
 var recovery: float = game.speed
 game._physics_process(0.5)
 if game.speed - recovery < 4.0:
  push_error("Acceleration after braking is too slow")
  quit(1)
  return
 # Real reverse control: S/mobile brake from rest must move backwards.
 game._reset()
 game.active = true
 game.touch["brake"] = true
 var reverse_start: Vector3 = game.bike.position
 for i in range(60):
  game._physics_process(1.0 / 60.0)
 if game.speed >= -1.0 or game.bike.position.distance_to(reverse_start) < 0.5:
  push_error("Brake from rest did not reverse")
  quit(1)
  return
 # The visible walls have matching physical track bounds on both sides.
 for wall_side in [-1, 1]:
  game._reset()
  game.active = true
  var direction: Vector3 = (game.track[1] - game.track[0]).normalized()
  var side := Vector3(-direction.z, 0, direction.x)
  game.bike.position = game.track[0] + side * wall_side * 24.0 + Vector3.UP * 0.05
  game.speed = 25.0
  game._physics_process(1.0 / 60.0)
  var hit: Dictionary = game._track_projection()
  if absf(hit.lat) > game.ROAD_WIDTH + 9.001 or game.speed >= 25.0:
   push_error("Bike passed through a barrier or failed to slow")
   quit(1)
   return
 # Accelerating while steering on asphalt must not be treated as gravel.
 game._reset()
 game.active = true
 game.speed = 18.0
 game.touch["left"] = true
 game.touch["accelerate"] = true
 var corner_speed: float = game.speed
 for i in range(20):
  game._physics_process(1.0 / 60.0)
 if game.speed <= corner_speed:
  push_error("Bike failed to accelerate while cornering on asphalt")
  quit(1)
  return
 # Editor opens with existing data and validates before any network request.
 game.profile = {"display_name":"Test Rider", "username":"testrider", "rider_number":93, "plate_color":"red"}
 game._open_profile_editor()
 if not game.profile_panel.visible or game.profile_name.text != "Test Rider" or game.profile_username.text != "testrider" or int(game.profile_number.value) != 93 or game.profile_color.get_selected_metadata() != "red":
  push_error("Profile editor failed to populate saved fields")
  quit(1)
  return
 game.auth.access_token = "test-only-token"
 game.auth.user_id = "test-only-id"
 game.auth.save_profile("Test Rider", "invalid name!", 93, "red")
 if not game.profile_error.text.contains("Username"):
  push_error("Profile validation failed")
  quit(1)
  return
 game.auth.access_token = ""
 game.auth.user_id = ""
 game.profile_panel.visible = false
 if game.engine_player == null or not game.engine_player.stream is AudioStreamGenerator:
  push_error("Native engine audio was not initialized")
  quit(1)
  return
 game._pause_game()
 game._return_to_menu()
 if not game.menu.visible or game.controls.visible or game.speed != 0.0 or game.active:
  push_error("Main menu did not reset the session")
  quit(1)
  return
 game.queue_free()
 quit(0)
