class_name WmcRaceTower
extends Control

const FONT = preload("res://assets/fonts/MGPText-Bold.ttf")
var _rows: Array[String] = []
var _lap_text := ""

func update_order(riders: Array[WmcRaceBike], lap: int, total: int) -> void:
	var sorted := riders.duplicate()
	sorted.sort_custom(func(a: WmcRaceBike, b: WmcRaceBike) -> bool:
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.finish_time_seconds < b.finish_time_seconds
		return a.race_progress_samples > b.race_progress_samples
	)
	var rows: Array[String] = []
	for rider in sorted:
		var parts := rider.display_name.to_upper().split(" ", false)
		var initials := str(parts[0]).replace(".", "") if parts.size() > 1 else ""
		var surname := str(parts[parts.size() - 1]).left(3)
		rows.append((initials + " " + surname).strip_edges())
	var new_lap := "LAST LAP" if lap == total else "LAP %d / %d" % [lap, total]
	if rows != _rows or new_lap != _lap_text:
		_rows = rows
		_lap_text = new_lap
		queue_redraw()

func _draw() -> void:
	var width := size.x
	var row_height := size.y / 11.0
	draw_rect(Rect2(0, 0, width, row_height), Color("df2638"))
	draw_string(FONT, Vector2(8, row_height * 0.75), _lap_text, HORIZONTAL_ALIGNMENT_LEFT, width - 16, maxi(11, roundi(row_height * 0.50)), Color.WHITE)
	for i in _rows.size():
		var y := (i + 1) * row_height
		draw_rect(Rect2(0, y, width, row_height - 1), Color(0.035, 0.045, 0.06, 0.88))
		draw_string(FONT, Vector2(8, y + row_height * 0.75), "%02d   %s" % [i + 1, _rows[i]], HORIZONTAL_ALIGNMENT_LEFT, width - 16, maxi(11, roundi(row_height * 0.49)), Color.WHITE)
