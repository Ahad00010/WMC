extends RefCounted
# Decode a few recorded frames ahead on a worker. The main thread only uploads
# already-decoded images; memory and requests are bounded even on slow disks.
const AHEAD := 8
var thread := Thread.new()
var mutex := Mutex.new()
var wake := Semaphore.new()
var frames: Array = []
var wanted := 0
var cache := {}
var stopped := false
var started := false

func start(source: Array) -> void:
 frames = source.duplicate(true)
 if not frames.is_empty():
  started = thread.start(_work) == OK
  if started:
   wake.post()

func request(index: int) -> Image:
 if not started:
  return null
 mutex.lock()
 wanted = clampi(index, 0, frames.size() - 1)
 for key in cache.keys():
  if int(key) < wanted or int(key) >= wanted + AHEAD:
   cache.erase(key)
 var image: Image = cache.get(wanted)
 mutex.unlock()
 wake.post()
 return image

func _work() -> void:
 while true:
  wake.wait()
  while true:
   mutex.lock()
   if stopped:
    mutex.unlock()
    return
   var index := -1
   for i in range(wanted, mini(wanted + AHEAD, frames.size())):
    if not cache.has(i):
     index = i
     break
   mutex.unlock()
   if index < 0:
    break
   var image := Image.new()
   var ok := image.load(frames[index].path) == OK
   mutex.lock()
   if index >= wanted and index < wanted + AHEAD:
    # A failed read is cached too, so a damaged frame cannot spin forever.
    cache[index] = image if ok else null
   mutex.unlock()

func stop() -> void:
 if started:
  mutex.lock()
  stopped = true
  mutex.unlock()
  wake.post()
  thread.wait_to_finish()
  started = false
 cache.clear()
