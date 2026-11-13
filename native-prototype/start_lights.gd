extends Control

const FONT = preload("res://assets/MGPDisplay-Medium.otf")
const RELEASE_TIME := 3.5
var clock := 0.0

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE

func lit_count() -> int:
 if clock >= RELEASE_TIME:
  return 0
 return mini(5, floori(clock / 0.5) + 1)

func _draw() -> void:
 var panel := Rect2(Vector2.ZERO, size)
 draw_rect(panel, Color(0.03, 0.035, 0.05, 0.9))
 for i in range(5):
  var center := Vector2(36 + i * 48, 38)
  var lit := i < lit_count()
  draw_circle(center, 17, Color("ef2634") if lit else Color("45161d"))
  if lit:
   draw_arc(center, 20, 0, TAU, 32, Color(1, 0.12, 0.14, 0.25), 4, true)
 if clock >= RELEASE_TIME:
  draw_string(FONT, Vector2(92, 99), "GO!", HORIZONTAL_ALIGNMENT_CENTER, 80, 23, Color("ffffff"))
