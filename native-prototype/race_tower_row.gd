extends Control

const FONT = preload("res://assets/MGPText-Bold.ttf")
var rank := 1
var label := "RIDER"
var number := "93"
var is_player := false

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO, size), Color("292d35") if is_player else Color("181c22"))
 draw_rect(Rect2(0, 0, 34, size.y), Color("343840"))
 draw_rect(Rect2(size.x - 40, 0, 40, size.y), Color("d32634") if is_player else Color("484f59"))
 draw_string(FONT, Vector2(0, 22), str(rank), HORIZONTAL_ALIGNMENT_CENTER, 34, 14, Color.WHITE)
 draw_string(FONT, Vector2(39, 22), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 82, 13, Color.WHITE)
 draw_string(FONT, Vector2(size.x - 40, 22), number, HORIZONTAL_ALIGNMENT_CENTER, 40, 14, Color.WHITE)
