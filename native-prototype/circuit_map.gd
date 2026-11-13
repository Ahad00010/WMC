extends Control

var points: Array[Vector2] = []
var player_position := Vector2.ZERO
var opponents: Array[Vector2] = []
var show_riders := false
var bounds := Rect2()

func set_points(source: Array) -> void:
 points.clear()
 for p in source:
  points.append(Vector2(p.x, p.z) if p is Vector3 else Vector2(float(p[0]), float(p[1])))
 if points.is_empty():
  queue_redraw()
  return
 var low := points[0]
 var high := low
 for p in points:
  low = low.min(p)
  high = high.max(p)
 bounds = Rect2(low, high - low)
 queue_redraw()

func _map(p: Vector2) -> Vector2:
 var available := size - Vector2(24, 24)
 var scale_factor := minf(available.x / maxf(bounds.size.x, 1), available.y / maxf(bounds.size.y, 1))
 return (size - bounds.size * scale_factor) * 0.5 + (p - bounds.position) * scale_factor

func _draw() -> void:
 if points.size() < 2:
  return
 var line := PackedVector2Array()
 for p in points:
  line.append(_map(p))
 line.append(line[0])
 draw_polyline(line, Color(0.94, 0.95, 0.97), 2.8, true)
 if show_riders:
  for p in opponents:
   draw_circle(_map(p), 3.0, Color("ffba47"))
  draw_circle(_map(player_position), 5.0, Color("ff343e"))
