extends SceneTree
# Invoked from a comparison-only PCK. Both engine binaries render this exact
# static game scene with identical assets and no replay, UI or input.
func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 var game = load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.active = false
 game.menu.visible = false
 game.controls.visible = false
 game.race_menu.visible = false
 game.results_screen.cancel()
 game.music.stop()
 # Stabilize the same race camera and scene before reading the framebuffer.
 await create_timer(2.0).timeout
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 if image == null or image.is_empty():
  push_error("comparison viewport readback failed")
  quit(1)
  return
 var output := "Z:/tmp/wmc-ab/" + OS.get_environment("WMC_AB_NAME") + ".png"
 var result := image.save_png(output)
 if result != OK:
  push_error("comparison image save failed: %s" % result)
  quit(1)
  return
 print("COMPARISON_CAPTURE ", output, " ", image.get_width(), "x", image.get_height())
 game.queue_free()
 await process_frame
 quit(0)
