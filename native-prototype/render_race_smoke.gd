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
 await create_timer(6.5).timeout
 if not game.active or game.countdown or game.ai_riders.size() != 9:
  _fail("Rendered AI race did not complete start countdown")
  return
 if game.capture_readbacks == 0 or not game.recorder or game.recorder.sequence == 0 or game.recorder.rejected != 0:
  _fail("Rendered race did not successfully capture real viewport frames")
  return
 game._return_to_menu()
 game.capture_setting = false
 game._start_race("sepang", 1, 1, false)
 await create_timer(5.0).timeout
 if not game.active or game.countdown or not game.ai_riders.is_empty() or game.recorder != null:
  _fail("Rendered solo race with capture disabled did not start correctly")
  return
 game._return_to_menu()
 game.queue_free()
 await process_frame
 quit(0)
