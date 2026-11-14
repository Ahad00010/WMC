class_name WmcRaceHud
extends Control
signal pause_requested

var touch_controls: WmcTouchControls
var _display_font: Font
var _text_font: Font
var _timing_panel: Panel
var _track_panel: Panel
var _speed_label: Label
var _lap_label: Label
var _position_label: Label
var _track_label: Label
var _notice_label: Label
var _pause_button: Button
var tower: WmcRaceTower
var map: WmcRaceMap
var _notice_timer := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display_font = load("res://assets/fonts/MGPDisplay-Bold.otf") as Font
	_text_font = load("res://assets/fonts/MGPText-Bold.ttf") as Font
	_timing_panel = _make_panel(Color(0.025, 0.035, 0.06, 0.78))
	_track_panel = _make_panel(Color(0.025, 0.035, 0.06, 0.78))
	_speed_label = _make_label(_display_font, 44, HORIZONTAL_ALIGNMENT_LEFT)
	_lap_label = _make_label(_text_font, 22, HORIZONTAL_ALIGNMENT_LEFT)
	_position_label = _make_label(_text_font, 20, HORIZONTAL_ALIGNMENT_RIGHT)
	_track_label = _make_label(_display_font, 19, HORIZONTAL_ALIGNMENT_RIGHT)
	_notice_label = _make_label(_text_font, 17, HORIZONTAL_ALIGNMENT_CENTER)
	_notice_label.add_theme_color_override("font_color", Color(0.82, 0.88, 1.0, 0.92))

	_timing_panel.add_child(_speed_label)
	_timing_panel.add_child(_lap_label)
	_timing_panel.add_child(_position_label)
	_track_panel.add_child(_track_label)
	add_child(_timing_panel)
	add_child(_track_panel)
	add_child(_notice_label)
	_pause_button = Button.new()
	_pause_button.text = "Ⅱ"
	_pause_button.add_theme_font_override("font", _text_font)
	_pause_button.add_theme_font_size_override("font_size", 22)
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.pressed.connect(func(): pause_requested.emit())
	add_child(_pause_button)
	tower = WmcRaceTower.new()
	tower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tower)
	map = WmcRaceMap.new()
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map)
	touch_controls = WmcTouchControls.new()
	add_child(touch_controls)
	resized.connect(_layout)
	call_deferred("_layout")


func set_race_state(circuit: WmcCircuit, current_lap: int, total_laps: int, speed_mps: float, race_position: int, rider_count: int, elapsed_seconds: float) -> void:
	if not _speed_label:
		return
	_speed_label.text = "%03d" % roundi(maxf(0.0, speed_mps) * 3.6)
	_lap_label.text = "KM/H     LAP %d / %d     %s" % [current_lap, total_laps, _format_time(elapsed_seconds)]
	_position_label.text = "P%d / %d" % [race_position, rider_count]
	_track_label.text = circuit.display_name


func set_notice(message: String) -> void:
	if _notice_label:
		_notice_label.text = message
		_notice_label.modulate.a = 1.0
		_notice_timer = 1.5 if message == "GO!" or message == "RESUMED" else 0.0


func _process(delta: float) -> void:
	if _notice_timer > 0.0:
		_notice_timer = maxf(0.0, _notice_timer - delta)
		_notice_label.modulate.a = minf(1.0, _notice_timer * 2.0)

func refresh_scale() -> void:
	_layout()


func _layout() -> void:
	var viewport_size := size
	var shortest_side := minf(viewport_size.x, viewport_size.y)
	var margin := clampf(shortest_side * 0.030, 14.0, 42.0)
	var unit := UiScale.hud_scale(shortest_side)
	var timing_width := clampf(viewport_size.x * 0.31, 250.0 * unit, 420.0 * unit)
	var timing_height := clampf(shortest_side * 0.135, 76.0 * unit, 142.0 * unit)
	_timing_panel.position = Vector2(margin, margin)
	_timing_panel.size = Vector2(timing_width, timing_height)
	_speed_label.position = Vector2(14.0 * unit, 3.0 * unit)
	_speed_label.size = Vector2(timing_width * 0.48, timing_height * 0.53)
	_speed_label.add_theme_font_size_override("font_size", roundi(clampf(shortest_side * 0.072 * unit, 34.0, 76.0)))
	_lap_label.position = Vector2(16.0 * unit, timing_height * 0.59)
	_lap_label.size = Vector2(timing_width * 0.96, timing_height * 0.32)
	_lap_label.add_theme_font_size_override("font_size", roundi(clampf(shortest_side * 0.027 * unit, 15.0, 28.0)))
	_position_label.position = Vector2(timing_width * 0.60, 13.0 * unit)
	_position_label.size = Vector2(timing_width * 0.35, timing_height * 0.30)
	_position_label.add_theme_font_size_override("font_size", roundi(clampf(shortest_side * 0.034 * unit, 17.0, 34.0)))

	_pause_button.position = Vector2(viewport_size.x - margin - 62, margin + 85 * unit)
	_pause_button.size = Vector2(62, 52)
	tower.position = Vector2(margin, margin + timing_height + 10 * unit)
	tower.size = Vector2(155 * unit, minf(shortest_side * 0.46, 330 * unit))
	map.position = Vector2(viewport_size.x - margin - 180 * unit, margin + 145 * unit)
	map.size = Vector2(180 * unit, 115 * unit)
	var track_width := clampf(viewport_size.x * 0.42, 300.0 * unit, 680.0 * unit)
	var track_height := clampf(shortest_side * 0.070, 42.0 * unit, 78.0 * unit)
	_track_panel.position = Vector2(viewport_size.x - margin - track_width, margin)
	_track_panel.size = Vector2(track_width, track_height)
	_track_label.position = Vector2(12.0 * unit, 0.0)
	_track_label.size = Vector2(track_width - 24.0 * unit, track_height)
	_track_label.add_theme_font_size_override("font_size", roundi(clampf(shortest_side * 0.026 * unit, 14.0, 27.0)))
	_notice_label.position = Vector2(viewport_size.x * 0.21, margin + timing_height + 9.0 * unit)
	_notice_label.size = Vector2(viewport_size.x * 0.58, 28.0 * unit)
	_notice_label.add_theme_font_size_override("font_size", roundi(clampf(shortest_side * 0.021 * unit, 13.0, 22.0)))


func _make_panel(colour: Color) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = Color(0.92, 0.96, 1.0, 0.34)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_label(font: Font, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	return label


func _format_time(seconds: float) -> String:
	var milliseconds := max(0, roundi(seconds * 1000.0))
	var minutes := milliseconds / 60000
	var remainder_seconds := (milliseconds / 1000) % 60
	return "%d:%02d" % [minutes, remainder_seconds]
