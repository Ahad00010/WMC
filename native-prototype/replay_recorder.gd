extends RefCounted
# Real rendered frames, bounded to the most recent 20 seconds. Encoding and
# disk writes happen on one worker; a full queue drops frames instead of
# growing memory without limit or stalling the race with compression.
const CAPACITY := 480
const DIRECTORY := "user://replay_frames"
var worker := Thread.new()
var mutex := Mutex.new()
var wake := Semaphore.new()
var jobs: Array = []
var written: Array = []
var stopping := false
var sequence := 0
var started := false

func start() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
 stopping = false
 started = worker.start(_work) == OK

func submit(image: Image, timestamp: float) -> void:
 if not started or image == null or image.is_empty():
  return
 mutex.lock()
 if jobs.size() >= 2:
  mutex.unlock()
  return
 var id := sequence
 sequence += 1
 jobs.append({"image": image, "time": timestamp, "id": id})
 mutex.unlock()
 wake.post()

func _work() -> void:
 while true:
  wake.wait()
  mutex.lock()
  if jobs.is_empty():
   var done := stopping
   mutex.unlock()
   if done:
    return
   continue
  var job: Dictionary = jobs.pop_front()
  mutex.unlock()
  var path := "%s/frame_%03d.jpg" % [DIRECTORY, int(job.id) % CAPACITY]
  var bytes: PackedByteArray = job.image.save_jpg_to_buffer(0.76)
  var file := FileAccess.open(path, FileAccess.WRITE)
  if file and not bytes.is_empty():
   file.store_buffer(bytes)
   file.close()
   mutex.lock()
   written.append({"path":path, "time":job.time, "id":job.id})
   while written.size() > CAPACITY or (written.size() > 1 and float(written[0].time) < float(job.time) - 20.0):
    written.pop_front()
   mutex.unlock()

func finish() -> Array:
 if started:
  mutex.lock()
  stopping = true
  mutex.unlock()
  wake.post()
  worker.wait_to_finish()
  started = false
 return written.duplicate(true)

func clear() -> void:
 finish()
 # Only delete our fixed ring of temporary files.
 for i in range(CAPACITY):
  var path := "%s/frame_%03d.jpg" % [DIRECTORY, i]
  if FileAccess.file_exists(path):
   DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 written.clear()
