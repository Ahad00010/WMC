class_name WmcWinnerGraphic
extends Control
const INLINE = preload("res://assets/fonts/MGPInline-Regular.otf")
const DISPLAY = preload("res://assets/fonts/MGPDisplay-Bold.otf")
const TEXT = preload("res://assets/fonts/MGPText-Bold.ttf")
const TISSOT = preload("res://assets/graphics/tissot-reference.png")
var winner_name := ""
var winner_number := 10

func configure(display_name: String, number: int) -> void:
	winner_name = display_name.to_upper()
	winner_number = number
	queue_redraw()

func _draw() -> void:
	# Match the black heading / diagonal color bands / black points footer.
	draw_rect(Rect2(0, 31, 320, 86), Color("201321"))
	var colors := [Color("391828"), Color("9b242b"), Color("381727"), Color("af2926"), Color("ee5a24"), Color("7b1d25")]
	for i in colors.size():
		var y := 35.0 + i * 14.0
		draw_colored_polygon(PackedVector2Array([Vector2(0, y + 18), Vector2(320, y - 28), Vector2(320, y - 11), Vector2(0, y + 35)]), colors[i])
	# Draw the black header after stripes: bands must never cover the heading.
	draw_rect(Rect2(0, 0, 320, 31), Color("050505"))
	draw_string(INLINE, Vector2(0, 23), "RACE WINNER", HORIZONTAL_ALIGNMENT_CENTER, 320, 21, Color.WHITE)
	draw_string(TEXT, Vector2(12, 65), winner_name.substr(0, 20), HORIZONTAL_ALIGNMENT_LEFT, 195, 17, Color.WHITE)
	draw_string(TEXT, Vector2(12, 86), "WMC GRAND PRIX TEAM", HORIZONTAL_ALIGNMENT_LEFT, 205, 10, Color.WHITE)
	draw_string(TEXT, Vector2(240, 89), str(winner_number), HORIZONTAL_ALIGNMENT_CENTER, 68, 43, Color.WHITE)
	draw_rect(Rect2(0, 117, 320, 54), Color("050505"))
	draw_string(DISPLAY, Vector2(18, 150), "+25", HORIZONTAL_ALIGNMENT_LEFT, 100, 30, Color.WHITE)
	draw_string(DISPLAY, Vector2(18, 166), "POINTS", HORIZONTAL_ALIGNMENT_LEFT, 100, 13, Color.WHITE)
	draw_texture_rect(TISSOT, Rect2(0, 171, 125, 25), false)
