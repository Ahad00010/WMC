class_name WmcTouchControls
extends Control

## Four independently-held zones support steering and throttle/brake at the
## same time. They do not rely on a single GUI button, which is important for
## Android multi-touch input.
var _touches: Dictionary = {}
var _left_rect := Rect2()
var _right_rect := Rect2()
var _throttle_rect := Rect2()
var _brake_rect := Rect2()
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = load("res://assets/fonts/MGPText-Bold.ttf") as Font
	resized.connect(_recalculate_layout)
	_recalculate_layout()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		queue_redraw()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index] = event.position
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touches[-1] = event.position
		else:
			_touches.erase(-1)
		queue_redraw()
	elif event is InputEventMouseMotion and _touches.has(-1):
		_touches[-1] = event.position
		queue_redraw()


func command() -> Vector3:
	var left := false
	var right := false
	var throttle := false
	var brake := false
	for touch_position: Vector2 in _touches.values():
		left = left or _left_rect.has_point(touch_position)
		right = right or _right_rect.has_point(touch_position)
		throttle = throttle or _throttle_rect.has_point(touch_position)
		brake = brake or _brake_rect.has_point(touch_position)
	return Vector3(1.0 if throttle else 0.0, 1.0 if brake else 0.0, float(int(right) - int(left)))


func clear() -> void:
	_touches.clear()
	queue_redraw()


func _recalculate_layout() -> void:
	var layout := layout_for_size(size)
	_left_rect = layout["left"]
	_right_rect = layout["right"]
	_throttle_rect = layout["throttle"]
	_brake_rect = layout["brake"]
	queue_redraw()


static func layout_for_size(viewport_size: Vector2) -> Dictionary:
	var shortest_side := minf(viewport_size.x, viewport_size.y)
	var button_size := clampf(shortest_side * 0.145, 64.0, 128.0)
	var margin := clampf(shortest_side * 0.035, 16.0, 48.0)
	var gap := clampf(shortest_side * 0.018, 10.0, 22.0)
	var bottom := viewport_size.y - margin - button_size
	return {
		"left": Rect2(margin, bottom, button_size, button_size),
		"right": Rect2(margin + button_size + gap, bottom, button_size, button_size),
		"throttle": Rect2(viewport_size.x - margin - button_size, bottom, button_size, button_size),
		"brake": Rect2(viewport_size.x - margin - button_size, bottom - button_size - gap, button_size, button_size),
	}


func _draw() -> void:
	_draw_zone(_left_rect, "◀", _is_held(_left_rect), Color(0.12, 0.16, 0.23, 0.68))
	_draw_zone(_right_rect, "▶", _is_held(_right_rect), Color(0.12, 0.16, 0.23, 0.68))
	_draw_zone(_throttle_rect, "GO", _is_held(_throttle_rect), Color(0.78, 0.05, 0.10, 0.74))
	_draw_zone(_brake_rect, "BRAKE", _is_held(_brake_rect), Color(0.95, 0.72, 0.08, 0.70))


func _draw_zone(rectangle: Rect2, caption: String, active: bool, colour: Color) -> void:
	var radius := rectangle.size.x * 0.24
	var style := StyleBoxFlat.new()
	style.bg_color = colour.lightened(0.20) if active else colour
	style.border_color = Color(1.0, 1.0, 1.0, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(roundi(radius))
	draw_style_box(style, rectangle)
	if _font:
		var font_size := roundi(clampf(rectangle.size.x * (0.31 if caption.length() <= 2 else 0.18), 16.0, 38.0))
		var baseline := rectangle.position.y + rectangle.size.y * 0.5 + float(font_size) * 0.35
		draw_string(_font, Vector2(rectangle.position.x, baseline), caption, HORIZONTAL_ALIGNMENT_CENTER, rectangle.size.x, font_size, Color.WHITE)


func _is_held(rectangle: Rect2) -> bool:
	for touch_position: Vector2 in _touches.values():
		if rectangle.has_point(touch_position):
			return true
	return false
