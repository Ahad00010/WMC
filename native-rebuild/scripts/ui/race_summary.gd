class_name WmcRaceSummary
extends Control
const TEXT = preload("res://assets/fonts/MGPText-Bold.ttf")
const DISPLAY = preload("res://assets/fonts/MGPDisplay-Bold.otf")
var _panel: Control
var _rows: VBoxContainer
var _cached := ""
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = Control.new()
	_panel.size = Vector2(600, 560)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var background := ColorRect.new()
	background.size = _panel.size
	background.color = Color(0.025, 0.035, 0.05, 0.9)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(background)
	var stripe := ColorRect.new()
	stripe.size = Vector2(600, 5)
	stripe.color = Color("ee3041")
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(stripe)
	var title := Label.new()
	title.text = "RACE RESULTS"
	title.position = Vector2(25, 15)
	title.add_theme_font_override("font", DISPLAY)
	title.add_theme_font_size_override("font_size", 40)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(title)
	_rows = VBoxContainer.new()
	_rows.position = Vector2(25, 90)
	_rows.size = Vector2(550, 420)
	_rows.add_theme_constant_override("separation", 2)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_rows)
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	if not _panel:
		return
	var factor := minf((size.x - 40.0) / 1000.0, (size.y - 60.0) / 560.0)
	_panel.scale = Vector2.ONE * maxf(0.1, factor)
	# Remain above the bottom mobile driving controls while the player cruises.
	_panel.position = Vector2((size.x - _panel.size.x * factor) * 0.5, 24)

func begin() -> void:
	visible = true
	_cached = ""
	_panel.modulate.a = 0.0
	var transition := create_tween()
	transition.tween_property(_panel, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)

func update_results(riders: Array[WmcRaceBike]) -> void:
	if not visible:
		return
	var ordered := riders.duplicate()
	ordered.sort_custom(func(a: WmcRaceBike, b: WmcRaceBike) -> bool:
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.finish_time_seconds < b.finish_time_seconds
		return a.race_progress_samples > b.race_progress_samples
	)
	var lines: Array[String] = []
	for i in ordered.size():
		var rider: WmcRaceBike = ordered[i]
		var time := _format_time(rider.finish_time_seconds) if rider.finished else "ON TRACK"
		lines.append("%02d       %s       %s" % [i + 1, rider.display_name, time])
	var signature := "\n".join(lines)
	if signature == _cached:
		return
	_cached = signature
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for line in lines:
		var label := Label.new()
		label.text = line
		label.custom_minimum_size = Vector2(550, 37)
		label.add_theme_font_override("font", TEXT)
		label.add_theme_font_size_override("font_size", 19)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.add_child(label)

func _format_time(seconds: float) -> String:
	var milliseconds := maxi(0, roundi(seconds * 1000.0))
	return "%d:%02d.%03d" % [milliseconds / 60000, (milliseconds / 1000) % 60, milliseconds % 1000]
