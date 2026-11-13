extends RefCounted
# Real rendered frames, bounded to the most recent 7 seconds. Encoding and
# disk writes happen on one worker; a full queue drops frames instead of
# growing memory without limit or stalling the race with compression.
const CAPACITY := 420
const DIRECTORY := "user://replay_frames"
var worker := Thread.new()
var mutex := Mutex.new()
var wake := Semaphore.new()
var jobs: Array = []
var written: Array = []
var stopping := false
var sequence := 0
var started := false
var marker_path := ""
var marker: FileAccess
var rejected := 0

func start(stage_path: String = "") -> void:
 marker_path = stage_path
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
 stopping = false
 started = worker.start(_work) == OK

func can_accept() -> bool:
 if not started:
  return false
 mutex.lock()
 var available := not stopping and jobs.size() < 2
 mutex.unlock()
 return available

# Copy only validated, tightly packed GPU output into an independent image.
# The worker never touches the renderer's returned image or shared pixel data.
func submit(image: Image, timestamp: float) -> void:
 if not started or image == null or image.is_empty():
  return
 if not can_accept():
  return
 var format := image.get_format()
 var width := image.get_width()
 var height := image.get_height()
 var channels := 3 if format == Image.FORMAT_RGB8 else 4 if format == Image.FORMAT_RGBA8 else 0
 if channels == 0 or width <= 0 or height <= 0 or width > 4096 or height > 4096 or image.has_mipmaps():
  rejected += 1
  return
 var pixels := image.get_data()
 if pixels.size() != width * height * channels:
  rejected += 1
  return
 var snapshot := Image.create_from_data(width, height, false, format, pixels.duplicate())
 if snapshot == null or snapshot.is_empty():
  rejected += 1
  return
 mutex.lock()
 if stopping or jobs.size() >= 2:
  mutex.unlock()
  return
 var id := sequence
 sequence += 1
 jobs.append({"image": snapshot, "time": timestamp, "id": id})
 mutex.unlock()
 wake.post()

func _mark(stage: String, id: int) -> void:
 if not marker:
  return
 marker.seek(0)
 marker.store_line("%d frame=%d %s                                                  " % [Time.get_ticks_msec(), id, stage])
 marker.flush()

func _work() -> void:
 if not marker_path.is_empty():
  marker = FileAccess.open(marker_path, FileAccess.WRITE_READ)
 _mark("worker-started", -1)
 while true:
  wake.wait()
  mutex.lock()
  if jobs.is_empty():
   var done := stopping
   mutex.unlock()
   if done:
    _mark("worker-stopped", -1)
    if marker:
     marker.close()
     marker = null
    return
   continue
  var job: Dictionary = jobs.pop_front()
  mutex.unlock()
  var path := "%s/frame_%03d.jpg" % [DIRECTORY, int(job.id) % CAPACITY]
  _mark("jpeg-begin", job.id)
  var bytes: PackedByteArray = job.image.save_jpg_to_buffer(0.76)
  _mark("jpeg-complete", job.id)
  _mark("file-write-begin", job.id)
  var file := FileAccess.open(path, FileAccess.WRITE)
  if file and not bytes.is_empty():
   file.store_buffer(bytes)
   file.close()
   _mark("file-write-complete", job.id)
   mutex.lock()
   written.append({"path":path, "time":job.time, "id":job.id})
   while written.size() > CAPACITY or (written.size() > 1 and float(written[0].time) < float(job.time) - 7.0):
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
