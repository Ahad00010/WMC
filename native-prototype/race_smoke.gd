extends SceneTree

func _initialize() -> void:
 call_deferred("_run")

func _fail(message: String) -> void:
 push_error(message)
 quit(1)

func _run() -> void:
 var game = load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 if game.circuit_sources.size() != 6:
  _fail("Six circuits are required")
  return
 # Verify capture stores and reads actual rendered image pixels, not positions.
 var recorder = load("res://replay_recorder.gd").new()
 recorder.start()
 var frame := Image.create(16, 16, false, Image.FORMAT_RGB8)
 frame.fill(Color.RED)
 recorder.submit(frame, 1.0)
 frame.fill(Color.BLUE)
 var unsupported := Image.create(16, 16, false, Image.FORMAT_L8)
 recorder.submit(unsupported, 1.1)
 var recorded: Array = recorder.finish()
 if recorded.size() != 1 or recorder.rejected != 1:
  _fail("Replay frame was not recorded")
  return
 var decoded := Image.new()
 if decoded.load(recorded[0].path) != OK or decoded.get_pixel(8, 8).r < 0.8:
  _fail("Replay frame did not preserve image pixels")
  return
 # Playback must run once, hold its last real image, and reveal controls afterwards.
 var sample: Array = [{"path": recorded[0].path, "time": 1.0}, {"path": recorded[0].path, "time": 8.0}]
 game.results_screen.begin([], "TEST", "#TEST", sample)
 game.results_screen.advance(63.35)
 if game.results_screen.menu_button.visible or game.results_screen.replay_duration != 7.0:
  _fail("Winner card appeared before seven-second replay")
  return
 await create_timer(0.1).timeout
 game.results_screen.advance(7.1)
 await create_timer(0.1).timeout
 game.results_screen.advance(0.01)
 if game.results_screen.replay_index != 1 or game.results_screen.menu_button.visible:
  _fail("Replay did not hold its final frame before revealing the card")
  return
 game.results_screen.advance(0.6)
 if not game.results_screen.menu_button.visible or game.results_screen.replay_index != 1:
  _fail("Winner controls did not appear over the held final frame")
  return
 game.results_screen.cancel()
 recorder.clear()
 if game._profile_number(13.0) != "13" or game._profile_number(null) != "—":
  _fail("Main menu rider number formatting failed")
  return
 # A slow readback must reduce work, while fast machines can ramp back up.
 if game._capture_rate(60.0, 18.39, 33.0) > 14.0 or game._capture_rate(24.0, 1.0, 70.0) <= 24.0 or game._capture_rate(60.0, 1.0, 100.0) > 60.0:
  _fail("Capture readback budget did not adapt")
  return
 # Settings are present on both platforms; GUI scaling is PC-only and saved.
 if game.settings_panel == null or game.settings_panel.gui_choice == null or game.settings_panel.gui_choice.item_count != 4:
  _fail("PC settings or GUI scale choices missing")
  return
 if game.settings_panel.capture_toggle == null:
  _fail("Replay capture diagnostic toggle missing")
  return
 game._capture_setting_changed(false)
 var capture_config := ConfigFile.new()
 if capture_config.load("user://settings.cfg") != OK or bool(capture_config.get_value("replay", "capture", true)):
  _fail("Replay capture setting not persisted")
  return
 game._capture_setting_changed(true)
 game._settings_changed(0.5, 0.6, 0.7, 3)
 var settings_file := ConfigFile.new()
 if settings_file.load("user://settings.cfg") != OK or int(settings_file.get_value("display", "gui_scale")) != 3 or absf(game.master_volume - 0.5) > 0.01 or absf(game._gui_factor() - 1.2) > 0.01:
  _fail("Audio or GUI settings not applied and persisted")
  return
 game._settings_changed(1.0, 1.0, 1.0, 0)
 var mobile_settings = load("res://settings_menu.gd").new()
 root.add_child(mobile_settings)
 mobile_settings.setup(true)
 if mobile_settings.gui_choice != null or mobile_settings.master_slider == null or mobile_settings.capture_toggle == null:
  _fail("Mobile settings should show audio but not PC GUI scale")
  return
 mobile_settings.queue_free()
 game._start_from_menu()
 if not game.race_menu.visible or game.race_menu.page != "mode":
  _fail("Play did not open mode selection")
  return
 game.race_menu.sound_toggled.emit()
 if not game.music_muted or game.sound_button.text != "Sound: off" or game.race_menu.sound_button.text != "Sound: off":
  _fail("Sound toggle did not synchronize across menus")
  return
 game.race_menu.sound_toggled.emit()
 await process_frame
 if game.race_menu.card.size.x > 810 or game.race_menu.card.size.y > 390:
  _fail("Mode menu is too large")
  return
 for choice in game.race_menu.body.get_children():
  if choice.get_rect().end.x > game.race_menu.body.size.x or choice.get_rect().end.y > game.race_menu.body.size.y or choice.size.x < 300:
   _fail("Mode choice is clipped or too small for touch")
   return
  for item in choice.get_children():
   if item is Control and (item.get_rect().position.x < 0 or item.get_rect().position.y < 0 or item.get_rect().end.x > choice.size.x or item.get_rect().end.y > choice.size.y):
    _fail("Text clipped inside mode choice: %s %s" % [item.name, item.get_rect()])
    return
 var choices = game.race_menu.body.get_children()
 if choices.size() != 2 or choices[0].disabled or not choices[1].disabled:
  _fail("Practice and disabled multiplayer choices incorrect")
  return
 choices[0].pressed.emit()
 choices = game.race_menu.body.get_children()
 if game.race_menu.page != "practice" or choices[0].disabled or not choices[1].disabled:
  _fail("Race and disabled qualifying choices incorrect")
  return
 choices[0].pressed.emit()
 if game.race_menu.page != "circuit" or game.race_menu.lap_slider.max_value != 10 or game.race_menu.speed_choice.item_count != 4:
  _fail("Practice circuit settings missing")
  return
 game.race_menu.lap_slider.value = 2
 game.race_menu.speed_choice.select(1)
 game.race_menu.speed_choice.item_selected.emit(1)
 game.race_menu.ai_check.button_pressed = true
 game.race_menu.show_page("practice")
 game.race_menu.show_page("circuit")
 if game.race_menu.lap_slider.value != 2 or game.race_menu.speed_choice.selected != 1 or not game.race_menu.ai_check.button_pressed:
  _fail("Practice settings were lost on back navigation")
  return
 for id in game.circuit_sources:
  game._change_circuit(id)
  if game.track.size() < 100 or game.circuit_id != id or game.mini_map.points.size() != game.track.size():
   _fail("Circuit did not build: " + id)
   return
 # Visible states are explicit, not dependent on a device's dark default theme.
 if not game.race_menu.ai_check.has_theme_icon_override("checked") or not game.race_menu.ai_check.has_theme_icon_override("unchecked") or game.race_menu.ai_check.get_theme_icon("checked") == game.race_menu.ai_check.get_theme_icon("unchecked"):
  _fail("AI checkbox states are not distinct")
  return
 if not game.race_menu.lap_slider.has_theme_stylebox_override("slider") or not game.race_menu.lap_slider.has_theme_icon_override("grabber") or not game.race_menu.speed_choice.has_theme_stylebox_override("normal"):
  _fail("Slider or speed dropdown lacks visible styling")
  return
 # Start from the actual circuit button signal, exercising the menu values.
 await process_frame
 var circuit_items = game.race_menu.body.get_children()
 for i in range(circuit_items.size()):
  var item: Control = circuit_items[i]
  if item.position.x < 0 or item.position.y < 0 or item.position.x + item.size.x > 949 or item.position.y + item.size.y > 481:
   _fail("Circuit selection item is outside its panel: %s %s" % [item.name, item.get_rect()])
   return
  for j in range(i):
   if item.get_rect().intersects(circuit_items[j].get_rect()):
    _fail("Circuit controls overlap: %s %s and %s %s" % [item.name, item.get_rect(), circuit_items[j].name, circuit_items[j].get_rect()])
    return
 var circuit_button: Button = null
 for child in game.race_menu.body.get_children():
  if child is Button and child.get_child_count() > 0 and child.get_child(0).has_method("set_points"):
   circuit_button = child
   break
 if circuit_button == null:
  _fail("No clickable circuit selection")
  return
 if not circuit_button.has_theme_stylebox_override("normal") or circuit_button.get_theme_stylebox("normal").border_width_left < 1:
  _fail("Circuit tiles lack visible borders")
  return
 circuit_button.pressed.emit()
 await create_timer(0.6).timeout
 if not game.active or not game.racing or game.race_laps != 2 or game.speed_factor != 2 or game.ai_riders.size() != 9 or not game.mini_map.show_riders:
  _fail("Race selection did not start with selected settings")
  return
 # Test the diagnostic isolation without changing AI simulation or replay.
 var model_root: Node = game.ai_riders[0].node
 game._set_ai_diagnostic_layers(model_root)
 var found_ai_mesh := false
 var todo: Array[Node] = [model_root]
 while not todo.is_empty():
  var item: Node = todo.pop_back()
  if item is VisualInstance3D:
   found_ai_mesh = true
   if item.layers != 2:
    _fail("AI diagnostic layers did not include an AI mesh")
    return
  todo.append_array(item.get_children())
 if not found_ai_mesh or (game.replay_camera.cull_mask & 2) == 0:
  _fail("AI diagnostic must preserve meshes in the replay camera")
  return
 # Restore the ordinary race visibility for the rest of this test.
 for item in model_root.find_children("*", "VisualInstance3D", true, false):
  item.layers = 1
 # The bike must already face down the selected straight before movement.
 if absf(angle_difference(game.bike.rotation.y, game.heading)) > 0.001:
  _fail("Bike starts sideways")
  return
 var tower_bottom: float = game.race_tower.position.y + game.race_tower.size.y * game.race_tower.scale.y
 if game.race_tower.scale.x < 0.99 or tower_bottom > game.controls.size.y - 145:
  _fail("Race tower did not scale up while leaving room for controls")
  return
 var original_controls_size: Vector2 = game.controls.size
 for width in [1280.0, 1568.0, 2400.0]:
  game.controls.size = Vector2(width, 720)
  game._resize_race_tower()
  var scaled_right: float = game.race_tower.position.x + game.race_tower.size.x * game.race_tower.scale.x
  var scaled_bottom: float = game.race_tower.position.y + game.race_tower.size.y * game.race_tower.scale.y
  if scaled_right >= game.mini_map.position.x or scaled_bottom > 575.0:
   _fail("Scaled tower overlaps map or driving controls at width %d" % width)
   return
 game.controls.size = original_controls_size
 game._resize_race_tower()
 # Countdown must freeze all riders and the race clock, including when paused.
 if not game.countdown or not game.start_lights.visible or game.start_lights.lit_count() < 1 or game.mini_map.opponents.size() != 9 or game.race_tower.rows.size() != 10:
  _fail("Start lights, map dots or race tower were not initialized")
  return
 var grid_position: Vector3 = game.bike.position
 if game.race_tower.get_rect().intersects(game.mini_map.get_rect()) or game.race_tower.get_rect().intersects(game.start_lights.get_rect()) or game.start_lights.get_rect().intersects(game.mini_map.get_rect()):
  _fail("Race HUD overlays collide")
  return
 for i in range(game.ai_riders.size()):
  var ai_node: Node = game.ai_riders[i].node
  if ai_node.get_child_count() != 2 or ai_node.get_child(0).scene_file_path != "res://assets/bike-ai.glb" or ai_node.get_child(1).scene_file_path != "res://assets/rider-ai.glb":
   _fail("Every AI must retain both optimized bike and rider models")
   return
  var rider_position: Vector3 = game.ai_riders[i].node.position
  if game.mini_map.opponents[i] != Vector2(rider_position.x, rider_position.z):
   _fail("AI dot does not match rider position")
   return
 var ai_grid: float = game.ai_riders[0].progress
 game.touch["accelerate"] = true
 game._physics_process(0.7)
 if game.bike.position != grid_position or game.speed != 0 or game.elapsed != 0 or float(game.ai_riders[0].progress) != ai_grid or game.start_lights.lit_count() < 2:
  _fail("Riders moved during red lights")
  return
 var paused_clock: float = game.countdown_clock
 game._pause_game()
 game._physics_process(0.5)
 if game.countdown_clock != paused_clock:
  _fail("Countdown did not pause")
  return
 game._resume_game()
 game._physics_process(2.0)
 if not game.countdown or game.start_lights.lit_count() != 5 or game.elapsed != 0:
  _fail("All five red lights should be lit before release")
  return
 game._physics_process(1.0)
 if game.countdown or game.start_lights.lit_count() != 0 or game.elapsed != 0:
  _fail("Lights did not go out before the race began")
  return
 game._process(0.4)
 if not game.start_lights.visible or game.start_lights.modulate.a <= 0.0 or game.start_lights.modulate.a >= 1.0:
  _fail("GO lights did not gradually fade")
  return
 game._process(0.8)
 if game.start_lights.visible:
  _fail("GO lights did not disappear after fading")
  return
 # Identical standings must not regenerate text/draw commands every update.
 var sample_row = game.race_tower.rows["ai0"]
 if sample_row.update_entry(sample_row.rank, sample_row.label, sample_row.number, sample_row.is_player, sample_row.finished, sample_row.plate_color):
  _fail("Unchanged tower row was marked for redraw")
  return
 if not sample_row.update_entry(sample_row.rank, sample_row.label, sample_row.number, sample_row.is_player, true, sample_row.plate_color):
  _fail("Changed tower row was not marked for redraw")
  return
 game._update_race_tower(game._standings(), 1)
 # Website-style lap display, progress bar, footer and finished rider indicators.
 game.race_laps = 3
 game.player_progress = game.track.size() * 0.5
 game._update_race_tower(game._standings(), 1)
 if game.race_tower.display_state() != "1/3" or absf(game.race_tower.lap_progress - 0.5) > 0.01:
  _fail("Tower does not show normal lap and within-lap progress")
  return
 game.player_progress = game.track.size() * 2.25
 game._update_race_tower(game._standings(), 3)
 if game.race_tower.display_state() != "LAST LAP" or absf(game.race_tower.lap_progress - 0.25) > 0.01:
  _fail("Tower does not show last lap")
  return
 game.race_laps = 1
 game.player_progress = 0
 game._update_race_tower(game._standings(), 1)
 if game.race_tower.display_state() != "LAST LAP":
  _fail("One-lap race must start on last lap")
  return
 game.race_laps = 2
 game.ai_riders[1].finished = true
 game.ai_riders[1].finish_time = 1.0
 game._update_race_tower(game._standings(), 1)
 if not game.race_tower.rows["ai1"].finished or game.race_tower.hashtag.is_empty():
  _fail("Finished rider flag or circuit footer missing")
  return
 game.ai_riders[1].finished = false
 game._update_race_tower(game._standings(), 1)
 # A genuine position change animates the tower rows, rather than just relabeling them.
 var old_target: float = game.race_tower.targets["ai0"]
 game.ai_riders[0].progress = 8.0
 game.race_tower.update_standings(game._standings(), 1, 2)
 if game.race_tower.targets["ai0"] >= old_target or not game.race_tower.animations.has("ai0"):
  _fail("Overtake did not reorder and animate the tower")
  return
 game.ai_riders[0].progress = ai_grid
 game._place_ai(game.ai_riders[0])
 game._update_map_markers()
 if game.mini_map.opponents.size() != 9:
  _fail("Map does not track all nine AI riders")
  return
 # The speed selector advances the real driving simulation, not just the HUD.
 game.touch["accelerate"] = true
 game.speed = 0.0
 var saved_position: Vector3 = game.bike.position
 var saved_heading: float = game.heading
 game._driving_step(1.0 / 60.0)
 var normal_gain: float = game.speed
 game.bike.position = saved_position
 game.heading = saved_heading
 game.speed = 0.0
 game._physics_process(1.0 / 60.0)
 if game.speed < normal_gain * 1.8:
  _fail("Speed multiplier did not change bike acceleration")
  return
 game.touch["accelerate"] = false
 var before: float = game.ai_riders[0].progress
 for i in range(120):
  game._update_ai(1.0 / 60.0)
 if float(game.ai_riders[0].progress) <= before or game.ai_riders[0].node.position.distance_to(game.track[0]) < 0.01:
  _fail("AI riders did not move")
  return
 if game.race_tower.abbreviated_name("Zachary Devs") != "Z DEVS":
  _fail("Tower rider name is not abbreviated")
  return
 game.profile["rider_number"] = 13.0
 for item in game._standings():
  if item.id == "player" and item.number != "13":
   _fail("Rider number contains a decimal")
   return
 # Reverse crossing alone must not complete a lap.
 game.nearest = game.track.size() - 1
 game.player_prev_index = 0
 game.player_progress = 0
 game._update_player_laps()
 if game.player_progress >= 0 or not game.active:
  _fail("Reverse crossing incorrectly counted as a lap")
  return
 game.player_prev_index = 0
 game.player_progress = 0
 game.race_laps = 1
 for i in range(1, game.track.size() + 1):
  game.nearest = i % game.track.size()
  game._update_player_laps()
 if not game.active or not game.results_screen.running or game.results_screen.phase != "waiting" or game.race_tower.display_state() != "FINISH" or not game.race_tower.rows["player"].finished:
  _fail("Finish tower or results sequence missing")
  return
 # The player can still coast or steer during the live post-finish interval.
 var finish_time: float = game.player_finish_time
 var finish_position: Vector3 = game.bike.position
 game.speed = 20.0
 game._physics_process(0.1)
 if game.bike.position.distance_to(finish_position) < 0.1 or game.player_finish_time != finish_time:
  _fail("Post-finish cruising or frozen result time failed")
  return
 game.results_screen.advance(20.0)
 if not game.results_screen.cued or game.results_screen.phase != "waiting":
  _fail("Results music cue timing is wrong")
  return
 game.results_screen.advance(3.0)
 if game.results_screen.phase != "grand_prix" or game.results_screen.entries.size() != 10:
  _fail("Grand Prix result presentation missing")
  return
 game.results_screen.advance(20.0)
 if game.results_screen.phase != "championship":
  _fail("Championship phase timing is wrong")
  return
 game.results_screen.advance(20.0)
 if game.results_screen.phase != "fade":
  _fail("Results fade timing is wrong")
  return
 game.results_screen.advance(0.4)
 if game.results_screen.phase != "winner" or not game.results_screen.menu_button.visible:
  _fail("Winner screen or main menu action is missing")
  return
 game.results_screen._request_menu()
 if not game.results_screen.leaving or game.results_screen.menu_button.disabled == false:
  _fail("Winner menu did not start audio fade")
  return
 game.results_screen.advance(0.81)
 if not game.menu.visible or game.ai_riders.size() != 0 or game.finish_panel.visible or game.results_screen.running:
  _fail("Returning to menu did not clear race state")
  return
 game.queue_free()
 quit(0)
