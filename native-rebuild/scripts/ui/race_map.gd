class_name WmcRaceMap
extends Control
var _points := PackedVector2Array()
var _rider_points := PackedVector2Array()
var _minimum := Vector2.ZERO
var _span := Vector2.ONE
var _next_update := 0

func set_circuit(circuit: WmcCircuit) -> void:
	_points.clear()
	var maximum := Vector2(-INF, -INF)
	_minimum = Vector2(INF, INF)
	for sample in circuit.samples:
		var point := Vector2(sample.x, sample.z)
		_points.append(point)
		_minimum = _minimum.min(point)
		maximum = maximum.max(point)
	_span = maximum - _minimum
	_span.x = maxf(_span.x, 1.0)
	_span.y = maxf(_span.y, 1.0)
	queue_redraw()

func update_riders(riders: Array[WmcRaceBike]) -> void:
	# Keep the static polyline from being re-uploaded to the canvas every frame.
	var now := Time.get_ticks_msec()
	if now < _next_update:
		return
	_next_update = now + 200
	var next := PackedVector2Array()
	for rider in riders:
		next.append(Vector2(rider.global_position.x, rider.global_position.z))
	if next != _rider_points:
		_rider_points = next
		queue_redraw()

func _project(point: Vector2) -> Vector2:
	var factor := minf((size.x - 20.0) / _span.x, (size.y - 20.0) / _span.y)
	return (size - _span * factor) * 0.5 + (point - _minimum) * factor

func _draw() -> void:
	if _points.size() < 2:
		return
	var line := PackedVector2Array()
	for point in _points:
		line.append(_project(point))
	line.append(line[0])
	draw_polyline(line, Color(0.92, 0.94, 0.97, 0.85), 2.0, true)
	for i in _rider_points.size():
		draw_circle(_project(_rider_points[i]), 4.0 if i == 0 else 2.7, Color("f83f4d") if i == 0 else Color.WHITE)
