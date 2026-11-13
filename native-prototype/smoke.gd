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
 # Check the actual resolved layout, not just visibility. Anchored positions
 # must remain centered after the parent is resized to a wide mobile aspect.
 var overlays = [game.menu, game.pause_panel, game.profile_panel]
 var widths = [760.0, 280.0, 500.0]
 for n in range(overlays.size()):
  var panel: Control = overlays[n]
  var card: Control = panel.get_child(1)
  var original_size := panel.size
  for panel_width in [1280.0, 1600.0]:
   panel.size = Vector2(panel_width, 720)
   var expected_x: float = (panel_width - widths[n]) / 2.0
   if absf(card.position.x - expected_x) > 1.0 or card.position.x < 0 or card.position.x + widths[n] > panel_width:
    push_error("Overlay %d is off-screen at width %d: %s" % [n, panel_width, card.position])
    quit(1)
    return
  panel.size = original_size
 # The contents themselves (not merely the card) must be centered.
 var menu_card: Control = game.menu.get_child(1)
 for child in menu_card.get_children():
  if child is Label:
   if child.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER or absf(child.position.x + child.size.x * 0.5 - menu_card.size.x * 0.5) > 1.0:
    push_error("Menu label is not centered: %s" % child.text)
    quit(1)
    return
 var visible_items = []
 for child in menu_card.get_children():
  if child is Control and child.visible and not (child is Label and child.text.is_empty()):
   if child.position.x < 0 or child.position.y < 0 or child.position.x + child.size.x > menu_card.size.x + 1 or child.position.y + child.size.y > menu_card.size.y + 1:
    push_error("Menu item outside card: %s" % child.name)
    quit(1)
    return
   for previous in visible_items:
    if child.get_rect().intersects(previous.get_rect()):
     push_error("Menu items overlap: %s %s and %s %s" % [child.name, child.get_rect(), previous.name, previous.get_rect()])
     quit(1)
     return
   visible_items.append(child)
 var brand: Label = menu_card.get_node("Brand")
 if brand.get_theme_font_size("font_size") < 115:
  push_error("Menu branding is too small")
  quit(1)
  return
 var play: Button = menu_card.get_node("Play")
 if play.size.x < 190 or play.size.y < 70 or absf(play.position.x + play.size.x * 0.5 - menu_card.size.x * 0.5) > 1.0:
  push_error("Play button is not centered")
  quit(1)
  return
 var actions: HBoxContainer = menu_card.get_node("AccountActions")
 for signed_in in [false, true]:
  game.sign_out_button.visible = signed_in
  await process_frame
  var visible_buttons = actions.get_children().filter(func(button): return button.visible)
  var first: Control = visible_buttons.front()
  var last: Control = visible_buttons.back()
  if absf((first.position.x + last.position.x + last.size.x) * 0.5 - actions.size.x * 0.5) > 1.0:
   push_error("Account buttons are not centered")
   quit(1)
   return
 game.sign_out_button.visible = false
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
 # Reset must immediately align bike and camera, before the next physics frame.
 game.bike.rotation.y = 1.9
 game.visual.rotation.z = 0.7
 game._reset()
 if absf(angle_difference(game.bike.rotation.y, game.heading)) > 0.001 or absf(game.visual.rotation.z) > 0.001:
  push_error("Reset did not align the bike to the grid")
  quit(1)
  return
 game.active = true
 game.touch["accelerate"] = true
 for i in range(120):
  game._physics_process(1.0 / 60.0)
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
 game.auth.operation = "save"
 game.auth._response(HTTPRequest.RESULT_SUCCESS, 409, PackedStringArray(), '{"code":"23505"}'.to_utf8_buffer())
 if not game.profile_error.text.contains("already taken") or game.auth.access_token.is_empty():
  push_error("Duplicate username error lost the session or was not shown")
  quit(1)
  return
 game.auth.operation = "save"
 game.auth._response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), '[{"username":"testrider","display_name":"Test Rider","rider_number":93,"plate_color":"red"}]'.to_utf8_buffer())
 if game.profile_panel.visible or game.profile.get("rider_number") != 93 or game.auth_button.text != "Edit profile":
  push_error("Saved profile was not applied to the menu")
  quit(1)
  return
 game.auth.access_token = ""
 game.auth.user_id = ""
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
 # Exercise separate simultaneous screen touches, slide-out, cancellation and pause.
 if ProjectSettings.get_setting("display/window/handheld/orientation") != DisplayServer.SCREEN_SENSOR_LANDSCAPE or ProjectSettings.get_setting("display/window/stretch/aspect") != "expand":
  push_error("Mobile display must fill the screen in landscape")
  quit(1)
  return
 game.mobile = true
 game._make_ui()
 game.controls.visible = true
 game.active = true
 await process_frame
 var left_pad: Control = game.touch_pads["left"]
 var right_pad: Control = game.touch_pads["right"]
 var gas_pad: Control = game.touch_pads["accelerate"]
 if left_pad.get_global_rect().intersects(right_pad.get_global_rect()):
  push_error("Mobile steering buttons overlap")
  quit(1)
  return
 var steer_touch := InputEventScreenTouch.new()
 steer_touch.index = 0
 steer_touch.position = left_pad.get_global_rect().get_center()
 steer_touch.pressed = true
 game._input(steer_touch)
 var gas_touch := InputEventScreenTouch.new()
 gas_touch.index = 1
 gas_touch.position = gas_pad.get_global_rect().get_center()
 gas_touch.pressed = true
 game._input(gas_touch)
 if not game.touch.left or not game.touch.accelerate or not left_pad.pressed or not gas_pad.pressed:
  push_error("Simultaneous steering and throttle did not work")
  quit(1)
  return
 var drag := InputEventScreenDrag.new()
 drag.index = 0
 drag.position = right_pad.get_global_rect().get_center()
 game._input(drag)
 if game.touch.left or not game.touch.right or not game.touch.accelerate:
  push_error("Sliding between steering controls broke multitouch")
  quit(1)
  return
 gas_touch.pressed = false
 game._input(gas_touch)
 if game.touch.accelerate or not game.touch.right:
  push_error("Releasing one finger released the wrong control")
  quit(1)
  return
 game._pause_game()
 if game.touch.right or not game.fingers.is_empty():
  push_error("Pausing left a touch control stuck")
  quit(1)
  return
 game._resume_game()
 game.queue_free()
 quit(0)
