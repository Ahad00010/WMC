extends SceneTree

func _initialize() -> void:
 call_deferred("_run")

func _fail(message: String) -> void:
 push_error(message)
 quit(1)

func _run() -> void:
 var recorder = load("res://replay_recorder.gd").new()
 var marker := "user://capture-stress-marker.txt"
 recorder.start(marker)
 var image := Image.create(320, 180, false, Image.FORMAT_RGBA8)
 image.fill(Color(0.8, 0.1, 0.2))
 var deadline := Time.get_ticks_msec() + 60000
 for i in range(600):
  while not recorder.can_accept() and Time.get_ticks_msec() < deadline:
   OS.delay_msec(1)
  if Time.get_ticks_msec() >= deadline:
   recorder.clear()
   _fail("Capture worker timed out")
   return
  recorder.submit(image, i / 60.0)
  if i == 0:
   # Mutating the caller's image after submission must not alter the queued frame.
   image.fill(Color(0.1, 0.8, 0.2))
 var frames: Array = recorder.finish()
 if frames.is_empty() or frames.size() > 420 or float(frames[-1].time) - float(frames[0].time) > 7.001:
  recorder.clear()
  _fail("Replay ring did not keep the bounded seven-second window")
  return
 for i in range(1, frames.size()):
  if int(frames[i].id) <= int(frames[i - 1].id):
   recorder.clear()
   _fail("Replay frames are out of order")
   return
 var marker_file := FileAccess.open(marker, FileAccess.READ)
 if not marker_file or not marker_file.get_as_text().contains("worker-stopped"):
  recorder.clear()
  _fail("Encoder marker was not flushed")
  return
 marker_file.close()
 recorder.clear()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(marker))
 quit(0)
