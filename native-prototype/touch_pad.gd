extends Control

const FONT = preload("res://assets/MGPDisplay-Medium.otf")
var caption := ""
var pressed := false:
 set(value):
  if pressed != value:
   pressed = value
   queue_redraw()

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
 var center := size * 0.5
 var radius := minf(size.x, size.y) * 0.41
 # Soft layered halo around a circular, high-contrast touch target.
 for i in range(7, 0, -1):
  draw_arc(center, radius + i * 2.0, 0, TAU, 64, Color(1.0, 0.06, 0.12, 0.018 if not pressed else 0.038), 3.0, true)
 draw_circle(center, radius, Color(0.33, 0.025, 0.045, 0.83) if not pressed else Color(0.86, 0.06, 0.09, 0.94))
 draw_arc(center, radius - 1.0, 0, TAU, 64, Color(1.0, 0.22, 0.26, 0.95), 3.0, true)
 var font_size := 23 if caption.length() <= 2 else 19
 var text_size := FONT.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
 draw_string(FONT, Vector2(center.x - text_size.x / 2.0, center.y + (FONT.get_ascent(font_size) - FONT.get_descent(font_size)) / 2.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
