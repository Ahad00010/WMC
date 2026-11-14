class_name WmcStartLights
extends Control
var remaining := -1.0
func update_time(value: float) -> void:
	if remaining != value:
		remaining = value
		visible = value > 0.0
		queue_redraw()
func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, Color(0.025, 0.03, 0.04, 0.9))
	var radius := minf(size.y * 0.29, size.x / 14.0)
	var active := clampi(4 - ceili(remaining), 1, 3)
	for i in range(3):
		var centre := Vector2(size.x * (float(i) + 1.0) / 4.0, size.y * 0.5)
		draw_circle(centre, radius, Color("ef2435") if i < active else Color("51202a"))
