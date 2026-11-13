extends Control

const FONT = preload("res://assets/MGPText-Bold.ttf")
const COLORS = {"blue":Color("2767c9"), "red":Color("e4202c"), "yellow":Color("eac534"), "orange":Color("ef7b24"), "green":Color("299857"), "cyan":Color("41b9c8"), "purple":Color("874cc2"), "pink":Color("d9579d"), "white":Color("eeeeee"), "black":Color("161616"), "silver":Color("a8adb4")}
var rank := 1
var label := "RIDER"
var number := "93"
var is_player := false
var finished := false
var plate_color := "red"

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO, size), Color("282b30") if is_player else Color("141616"))
 draw_rect(Rect2(0, 0, 34, size.y), Color("303234"))
 var plate: Color = COLORS.get(plate_color, Color("e4202c"))
 draw_rect(Rect2(size.x - 40, 0, 40, size.y), plate)
 if finished:
  for y in range(2):
   for x in range(2):
    draw_rect(Rect2(size.x - 53 + x * 5, 8 + y * 5, 5, 5), Color.WHITE if (x + y) % 2 == 0 else Color.BLACK)
 draw_string(FONT, Vector2(0, 21), str(rank), HORIZONTAL_ALIGNMENT_CENTER, 34, 14, Color.WHITE)
 draw_string(FONT, Vector2(39, 21), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - (96 if finished else 82), 13, Color.WHITE)
 var text_color := Color.BLACK if plate_color in ["yellow", "white", "cyan", "silver"] else Color.WHITE
 draw_string(FONT, Vector2(size.x - 40, 21), number, HORIZONTAL_ALIGNMENT_CENTER, 40, 14, text_color)
