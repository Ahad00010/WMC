class_name WmcFootageCapture
extends Node

# Captures the real shared 3D world, never reconstructed rider transforms.
# A bounded worker queue prevents JPEG encoding and disk work on the race loop.
const WINDOW_SECONDS := 7.0
const MAX_FRAMES := 420
var view: SubViewport
var camera: Camera3D
var worker := Thread.new()
var mutex := Mutex.new()
var wake := Semaphore.new()
var queue: Array = []
var frames: Array = []
var running := false
var stopping := false
var pending := false
var accumulator := 0.0
var interval := 1.0 / 30.0
var last_readback_ms := 0.0
var average_readback_ms := 0.0
var readback_count := 0
var skipped_count := 0
var slow_readbacks := 0

func begin(shared_world: World3D) -> void:
	view = SubViewport.new()
	view.name = "FootageViewport"
	view.size = Vector2i(854, 480) if OS.has_feature("mobile") else Vector2i(1920, 1080)
	view.world_3d = shared_world
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.own_world_3d = false
	add_child(view)
	camera = Camera3D.new()
	camera.fov = 48.0
	view.add_child(camera)
	camera.make_current()
	stopping = false
	running = worker.start(_encode) == OK
	RenderingServer.frame_post_draw.connect(_after_draw)

func capture(delta: float, time: float, leader: Node3D, heading: float) -> void:
	if not running or pending or DisplayServer.get_name() == "headless":
		return
	accumulator += delta
	if accumulator < interval:
		return
	accumulator = fmod(accumulator, interval)
	mutex.lock()
	var capacity := queue.size() < 2
	mutex.unlock()
	if not capacity:
		skipped_count += 1
		return
	var forward := Vector3(sin(heading), 0, cos(heading))
	camera.global_position = leader.global_position + forward.rotated(Vector3.UP, 1.3) * 9.0 + Vector3.UP * 3.2
	camera.look_at(leader.global_position + Vector3.UP, Vector3.UP)
	_pending_time = time
	pending = true
	view.render_target_update_mode = SubViewport.UPDATE_ONCE

var _pending_time := 0.0
func _after_draw() -> void:
	if not running or not pending:
		return
	pending = false
	var start := Time.get_ticks_usec()
	var image := view.get_texture().get_image()
	last_readback_ms = float(Time.get_ticks_usec() - start) / 1000.0
	readback_count += 1
	average_readback_ms = last_readback_ms if readback_count == 1 else lerpf(average_readback_ms, last_readback_ms, 0.18)
	# A large blocking readback is a warning sign, not proof of the earlier
	# display freeze's cause. Back off rapidly; resume smoothly on recovery.
	if last_readback_ms >= 100.0:
		slow_readbacks += 1
		interval = maxf(interval, 0.5)
	else:
		var target_rate := clampf(1000.0 / maxf(16.7, average_readback_ms * 4.0), 8.0, 60.0)
		interval = lerpf(interval, 1.0 / target_rate, 0.12)
	if not image or image.is_empty():
		return
	mutex.lock()
	if queue.size() < 2 and not stopping:
		queue.append({"image": image, "time": _pending_time})
		wake.post()
	mutex.unlock()

func _encode() -> void:
	while true:
		wake.wait()
		mutex.lock()
		if queue.is_empty():
			var done := stopping
			mutex.unlock()
			if done:
				return
			continue
		var job: Dictionary = queue.pop_front()
		mutex.unlock()
		var data: PackedByteArray = job.image.save_jpg_to_buffer(0.78)
		if not data.is_empty():
			mutex.lock()
			frames.append({"time": job.time, "jpeg": data})
			while frames.size() > MAX_FRAMES or (frames.size() > 1 and float(frames[0].time) < float(job.time) - WINDOW_SECONDS):
				frames.pop_front()
			mutex.unlock()

func finish() -> Array:
	# Discard a pending frame: its world may already be across the line.
	pending = false
	if view:
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if running:
		mutex.lock()
		stopping = true
		mutex.unlock()
		wake.post()
		worker.wait_to_finish()
		running = false
	return frames.duplicate()

func _exit_tree() -> void:
	finish()
	if RenderingServer.frame_post_draw.is_connected(_after_draw):
		RenderingServer.frame_post_draw.disconnect(_after_draw)
