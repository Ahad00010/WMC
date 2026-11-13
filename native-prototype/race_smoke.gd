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
 game._start_from_menu()
 if not game.race_menu.visible or game.race_menu.page != "mode":
  _fail("Play did not open mode selection")
  return
 game.race_menu.sound_toggled.emit()
 if not game.music_muted or game.sound_button.text != "Sound: off" or game.race_menu.sound_button.text != "Sound: off":
  _fail("Sound toggle did not synchronize across menus")
  return
 game.race_menu.sound_toggled.emit()
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
 circuit_button.pressed.emit()
 await create_timer(0.6).timeout
 if not game.active or not game.racing or game.race_laps != 2 or game.speed_factor != 2 or game.ai_riders.size() != 9 or not game.mini_map.show_riders:
  _fail("Race selection did not start with selected settings")
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
 if game.active or not game.finish_panel.visible or not game.finish_text.text.contains("POSITION"):
  _fail("Finishing a lap did not end the race")
  return
 game._return_to_menu()
 if not game.menu.visible or game.ai_riders.size() != 0 or game.finish_panel.visible:
  _fail("Returning to menu did not clear race state")
  return
 game.queue_free()
 quit(0)
