extends SceneTree
# Exercises the real renderer and GPU viewport readback under Xvfb/Mesa in CI.
# It is not a replacement for testing the user's Windows Intel/ANGLE driver.
func _initialize() -> void:
 call_deferred("_run")

func _fail(message: String) -> void:
 push_error(message)
 quit(1)

func _run() -> void:
 if DisplayServer.get_name() == "headless":
  _fail("Rendering smoke test requires a real display backend")
  return
 var game = load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 # Keep the software renderer test practical without changing exported quality.
 game.replay_view.size = Vector2i(640, 360)
 game.capture_setting = true
 game._start_race("sepang", 1, 1, true)
 await create_timer(1.0).timeout
 _set_w(true)
 await create_timer(1.0).timeout
 if not game.countdown or not Input.is_key_pressed(KEY_W) or game.speed != 0.0:
  _fail("W during countdown should keep the bike on the grid")
  return
 await create_timer(5.0).timeout
 if not game.active or game.countdown or game.ai_riders.size() != 9:
  _fail("Rendered AI race did not complete start countdown")
  return
 if game.speed <= 0.0 or game.engine_gain <= 0.0:
  _fail("Holding W through countdown did not accelerate with engine audio")
  return
 _set_w(false)
 if game.capture_readbacks < 3 or not game.recorder or game.recorder.sequence < 3 or game.recorder.rejected != 0:
  _fail("Rendered race did not successfully capture real viewport frames")
  return
 # Verify that the real rendered viewport survives the JPEG capture path.
 var original: Image = game.replay_view.get_texture().get_image()
 game._return_to_menu()
 var recorder = load("res://replay_recorder.gd").new()
 recorder.start()
 recorder.submit(original, 1.0)
 var frames: Array = recorder.finish()
 if frames.is_empty():
  _fail("Rendered viewport image was rejected by encoder")
  return
 var replay_image := Image.new()
 if replay_image.load(frames[0].path) != OK:
  _fail("Recorded viewport image could not be decoded")
  return
 var errors: Dictionary = original.compute_image_metrics(replay_image, true)
 if float(errors.get("mean", INF)) > 15.0:
  _fail("Replay image differs excessively from the rendered frame")
  return
 recorder.clear()
 game.capture_setting = false
 game._start_race("sepang", 1, 1, false)
 await create_timer(5.0).timeout
 if not game.active or game.countdown or not game.ai_riders.is_empty() or game.recorder != null:
  _fail("Rendered solo race with capture disabled did not start correctly")
  return
 _set_w(true)
 await create_timer(2.0).timeout
 if game.speed <= 0.0 or game.engine_gain <= 0.0:
  _fail("W pressed after lights did not accelerate with engine audio")
  return
 _set_w(false)
 game._return_to_menu()
 # Regression: the diagonal card graphic must not paint over its black heading.
 game.results_screen.begin([{"name":"Rider", "number":"93", "color":"red"}], "TEST", "#TEST")
 game.results_screen.advance(70.0)
 await process_frame
 await RenderingServer.frame_post_draw
 var screen := root.get_texture().get_image()
 var viewport_size := Vector2(screen.get_width(), screen.get_height())
 var factor := minf(viewport_size.x / 1280.0, viewport_size.y / 720.0)
 var origin := (viewport_size - Vector2(1280, 720) * factor) * 0.5
 var point := origin + Vector2(1205, 480) * factor
 if screen.get_pixel(clampi(int(point.x), 0, screen.get_width() - 1), clampi(int(point.y), 0, screen.get_height() - 1)).r > 0.08:
  _fail("Winner graphic painted over heading")
  return
 game.results_screen.cancel()
 game.queue_free()
 await process_frame
 quit(0)

func _set_w(pressed: bool) -> void:
 var event := InputEventKey.new()
 event.keycode = KEY_W
 event.pressed = pressed
 Input.parse_input_event(event)
