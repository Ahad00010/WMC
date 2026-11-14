class_name WmcCircuit
extends RefCounted

## Runtime representation of one closed circuit. Source control points are
## scaled to their published lap length and resampled every five metres.
const SAMPLE_SPACING_METRES := 5.0

var id := ""
var display_name := ""
var hashtag := ""
var lap_length_metres := 0.0
var samples := PackedVector3Array()
var tangents := PackedVector3Array()
var lefts := PackedVector3Array()

func _init(
		circuit_id: String = "",
		title: String = "",
		tag: String = "",
		lap_length: float = 0.0,
		raw_points: PackedVector2Array = PackedVector2Array()
	) -> void:
	id = circuit_id
	display_name = title
	hashtag = tag
	lap_length_metres = lap_length
	_build_samples(raw_points)


func size() -> int:
	return samples.size()


func wrap_index(index: int) -> int:
	var count := size()
	if count == 0:
		return 0
	return posmod(index, count)


func road_half_width(index: int) -> float:
	# Matches the smooth 16–22 m-wide road profile used by the supplied web data.
	if size() == 0:
		return 8.0
	return 8.0 + 1.5 * (1.0 - cos(TAU * float(wrap_index(index)) / float(size())))


func kerb_edge(index: int) -> float:
	return road_half_width(index) + 2.5


func wall_edge(index: int) -> float:
	return road_half_width(index) + 10.0


func heading_at(index: int) -> float:
	var tangent := tangents[wrap_index(index)]
	return atan2(tangent.x, tangent.z)


func sample_ahead(index: int, metres: float) -> int:
	return wrap_index(index + roundi(metres / SAMPLE_SPACING_METRES))


func nearest_index(position: Vector3, hint: int = -1, window: int = 90) -> int:
	var count := size()
	if count == 0:
		return 0
	var best_index := 0 if hint < 0 else wrap_index(hint)
	var best_distance := INF
	var first := 0
	var last := count - 1
	if hint >= 0:
		first = -min(window, count - 1)
		last = min(window, count - 1)
	for offset in range(first, last + 1):
		var index := wrap_index(offset if hint < 0 else hint + offset)
		var delta := position - samples[index]
		var distance_squared := delta.x * delta.x + delta.z * delta.z
		if distance_squared < best_distance:
			best_distance = distance_squared
			best_index = index
	return best_index


func _build_samples(raw_points: PackedVector2Array) -> void:
	if raw_points.size() < 4:
		push_error("A circuit needs at least four points.")
		return
	var centroid := Vector2.ZERO
	for point in raw_points:
		centroid += point
	centroid /= float(raw_points.size())

	var unscaled_length := 0.0
	for point_index in raw_points.size():
		unscaled_length += raw_points[point_index].distance_to(raw_points[(point_index + 1) % raw_points.size()])
	if unscaled_length <= 0.001:
		push_error("Circuit source points have no length.")
		return
	var scale := lap_length_metres / unscaled_length
	var scaled := PackedVector2Array()
	for point in raw_points:
		scaled.append((point - centroid) * scale)

	for point_index in scaled.size():
		var start := scaled[point_index]
		var end := scaled[(point_index + 1) % scaled.size()]
		var segment_length := start.distance_to(end)
		var segment_count := max(1, roundi(segment_length / SAMPLE_SPACING_METRES))
		for step in segment_count:
			var point := start.lerp(end, float(step) / float(segment_count))
			samples.append(Vector3(point.x, 0.0, point.y))

	for index in samples.size():
		var before := samples[wrap_index(index - 1)]
		var after := samples[wrap_index(index + 1)]
		var tangent := (after - before).normalized()
		tangent.y = 0.0
		tangent = tangent.normalized()
		tangents.append(tangent)
		lefts.append(Vector3(tangent.z, 0.0, -tangent.x))
