class_name WmcReplayRecorder
extends RefCounted

## Stores observed live rider transforms at 30 Hz. It does not infer paths,
## teleport riders, or synthesize a replay from race results. Playback and
## recorded-video export are deliberately not exposed until that feature is
## completed in a later stage.
const SAMPLE_RATE_HZ := 30.0
const MAX_SECONDS := 900.0

var elapsed_seconds := 0.0
var _accumulator := 0.0
var _frames: Dictionary = {}


func begin(riders: Array[WmcRaceBike]) -> void:
	elapsed_seconds = 0.0
	_accumulator = 0.0
	_frames.clear()
	for rider in riders:
		_frames[rider.rider_id] = []


func capture(delta: float, riders: Array[WmcRaceBike]) -> void:
	if elapsed_seconds >= MAX_SECONDS:
		return
	elapsed_seconds += delta
	_accumulator += delta
	var sample_interval := 1.0 / SAMPLE_RATE_HZ
	if _accumulator < sample_interval:
		return
	_accumulator = fmod(_accumulator, sample_interval)
	for rider in riders:
		var rider_frames: Array = _frames.get(rider.rider_id, [])
		rider_frames.append({
			"time": elapsed_seconds,
			"transform": rider.global_transform,
			"speed": rider.speed_metres_per_second,
			"progress": rider.race_progress_samples,
		})
		_frames[rider.rider_id] = rider_frames


func recorded_frames_for(rider_id: String) -> Array:
	return _frames.get(rider_id, []).duplicate(true)


func rider_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for rider_id in _frames:
		ids.append(rider_id)
	return ids
