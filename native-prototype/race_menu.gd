extends Control
signal start_requested(circuit: String, laps: int, speed: int, fill: bool)
signal sound_toggled
const MAP = preload("res://circuit_map.gd")
const DISPLAY_FONT = preload("res://assets/MGPDisplay-Medium.otf")
const TEXT_FONT = preload("res://assets/MGPText-Bold.ttf")
const CHECK_OFF = preload("res://assets/check-off.svg")
const CHECK_ON = preload("res://assets/check-on.svg")
const SLIDER_THUMB = preload("res://assets/slider-thumb.svg")
const NAMES = {"sepang":"PETRONAS SEPANG\nINTERNATIONAL CIRCUIT", "silverstone":"SILVERSTONE CIRCUIT", "assen":"TT CIRCUIT ASSEN", "brno":"AUTOMOTODROM BRNO\nCIRCUIT", "monza":"AUTODROMO NAZIONALE\nMONZA", "jerez":"CIRCUITO DE JEREZ"}
var page := "mode"
var gui_factor := 1.0
var card: Control
var heading: Label
var body: Control
var back: Button
var sound_button: Button
var close_button: Button
var top_bar: ColorRect
var lap_slider: HSlider
var laps_label: Label
var speed_choice: OptionButton
var ai_check: CheckBox
var sources: Dictionary
var selected_laps := 3
var selected_speed := 1
var selected_fill := false

func setup(circuit_sources: Dictionary) -> void:
 sources = circuit_sources
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 visible = false
 var shade := ColorRect.new()
 shade.color = Color(0.01, 0.015, 0.025, 0.9)
 add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 card = Control.new()
 add_child(card)
 card.set_anchors_preset(Control.PRESET_CENTER)
 card.offset_left = -510
 card.offset_right = 510
 card.offset_top = -340
 card.offset_bottom = 340
 var bg := ColorRect.new()
 bg.color = Color("14181f")
 card.add_child(bg)
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 top_bar = ColorRect.new()
 top_bar.color = Color("ed2534")
 top_bar.size = Vector2(1020, 5)
 card.add_child(top_bar)
 var eyebrow := _label(card, "WORLD MOTORBIKE CHAMPIONSHIP", 16, Vector2(36, 15))
 eyebrow.add_theme_color_override("font_color", Color("f32c3b"))
 heading = _label(card, "", 42, Vector2(36, 52), true)
 sound_button = _button(card, "Sound: on", Vector2(750, 20), Vector2(175, 50), 17)
 sound_button.pressed.connect(func(): sound_toggled.emit())
 close_button = _button(card, "✕", Vector2(950, 18), Vector2(48, 48), 24)
 close_button.pressed.connect(func(): visible = false)
 body = Control.new()
 body.position = Vector2(36, 118)
 body.size = Vector2(948, 480)
 card.add_child(body)
 back = _button(card, "← BACK", Vector2(36, 616), Vector2(130, 42), 16)
 back.pressed.connect(func(): show_page("practice" if page == "circuit" else "mode"))
 show_page("mode")

func _label(parent: Control, text: String, font_size: int, pos: Vector2, display := false) -> Label:
 var label := Label.new()
 label.text = text
 label.position = pos
 label.add_theme_font_override("font", DISPLAY_FONT if display else TEXT_FONT)
 label.add_theme_font_size_override("font_size", font_size)
 parent.add_child(label)
 return label

func _button(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int) -> Button:
 var button := Button.new()
 button.text = text
 button.position = pos
 button.size = size
 button.focus_mode = Control.FOCUS_NONE
 button.add_theme_font_override("font", TEXT_FONT)
 button.add_theme_font_size_override("font_size", font_size)
 parent.add_child(button)
 return button

func show_page(next: String) -> void:
 page = next
 var compact := page != "circuit"
 var width := 800.0 if compact else 1020.0
 var height := 380.0 if compact else 680.0
 card.offset_left = -width / 2
 card.offset_right = width / 2
 card.offset_top = -height / 2
 card.offset_bottom = height / 2
 top_bar.size.x = width
 heading.add_theme_font_size_override("font_size", 38 if compact else 42)
 sound_button.position.x = 570 if compact else 750
 close_button.position.x = 730 if compact else 950
 body.size = Vector2(728, 180) if compact else Vector2(948, 480)
 back.position.y = 315 if compact else 616
 apply_scale()
 heading.text = {"mode":"CHOOSE YOUR MODE", "practice":"PRACTICE", "circuit":"CIRCUIT"}[page]
 back.visible = page != "mode"
 for child in body.get_children():
  body.remove_child(child)
  child.queue_free()
 if page == "mode":
  _choice("PRACTICE", "Race on your own or with AI riders.", 0, false, func(): show_page("practice"))
  _choice("MULTIPLAYER", "Under development", 368, true, func(): pass)
 elif page == "practice":
  _choice("RACE", "Choose a circuit, laps and AI riders.", 0, false, func(): show_page("circuit"))
  _choice("QUALIFYING", "Under development", 368, true, func(): pass)
 else:
  _make_circuits()

func apply_scale() -> void:
 if not card:
  return
 # Keep the centred panel on screen even at the largest GUI setting.
 var max_fit := minf((size.x - 24) / maxf(card.size.x, 1), (size.y - 24) / maxf(card.size.y, 1))
 card.pivot_offset = card.size * 0.5
 card.scale = Vector2.ONE * minf(gui_factor, max_fit)

func _choice(title: String, description: String, x: float, disabled: bool, action: Callable) -> void:
 var choice := _button(body, "", Vector2(x, 12), Vector2(350, 150), 18)
 choice.disabled = disabled
 var normal := StyleBoxFlat.new()
 normal.bg_color = Color("1c2027")
 normal.border_color = Color("ed2534")
 normal.border_width_left = 4
 choice.add_theme_stylebox_override("normal", normal)
 var highlighted := normal.duplicate()
 highlighted.bg_color = Color("2b3039")
 choice.add_theme_stylebox_override("hover", highlighted)
 choice.add_theme_stylebox_override("pressed", highlighted)
 choice.add_theme_stylebox_override("disabled", normal)
 choice.pressed.connect(action)
 var kicker := _label(choice, "PRACTICE" if page == "practice" else ("02 / ONLINE" if disabled else "01 / SOLO"), 14, Vector2(20, 10))
 kicker.add_theme_color_override("font_color", Color("ed2534"))
 var name_label := _label(choice, title, 29, Vector2(20, 38), true)
 var desc := _label(choice, description, 14, Vector2(20, 96))
 for label in [kicker, name_label, desc]:
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 if disabled:
  choice.modulate = Color(0.48, 0.48, 0.5, 1.0)

func _outlined_style(background: Color, border: Color, border_width := 2) -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color = background
 style.border_color = border
 style.set_border_width_all(border_width)
 style.set_corner_radius_all(3)
 return style

func _make_circuits() -> void:
 _label(body, "Race laps (1–10)", 19, Vector2(0, 0))
 laps_label = _label(body, "3", 22, Vector2(420, 0))
 lap_slider = HSlider.new()
 lap_slider.position = Vector2(0, 45)
 lap_slider.size = Vector2(460, 35)
 lap_slider.min_value = 1
 lap_slider.max_value = 10
 lap_slider.step = 1
 var rail := _outlined_style(Color("69717e"), Color("939ba7"), 1)
 rail.content_margin_top = 4
 rail.content_margin_bottom = 4
 var filled := _outlined_style(Color("ed2534"), Color("ed2534"), 1)
 filled.content_margin_top = 4
 filled.content_margin_bottom = 4
 lap_slider.add_theme_stylebox_override("slider", rail)
 lap_slider.add_theme_stylebox_override("grabber_area", filled)
 lap_slider.add_theme_stylebox_override("grabber_area_highlight", filled)
 lap_slider.add_theme_icon_override("grabber", SLIDER_THUMB)
 lap_slider.add_theme_icon_override("grabber_highlight", SLIDER_THUMB)
 lap_slider.value = selected_laps
 laps_label.text = str(selected_laps)
 lap_slider.value_changed.connect(func(value):
  selected_laps = int(value)
  laps_label.text = str(selected_laps)
 )
 body.add_child(lap_slider)
 _label(body, "Bike speed (practice only)", 19, Vector2(490, 0))
 speed_choice = OptionButton.new()
 speed_choice.position = Vector2(770, 0)
 speed_choice.size = Vector2(175, 48)
 speed_choice.add_theme_font_override("font", TEXT_FONT)
 speed_choice.add_theme_font_size_override("font_size", 17)
 var select_style := _outlined_style(Color("242a33"), Color("aab2bd"))
 var select_hover := _outlined_style(Color("343c48"), Color("f34752"))
 speed_choice.add_theme_stylebox_override("normal", select_style)
 speed_choice.add_theme_stylebox_override("hover", select_hover)
 speed_choice.add_theme_stylebox_override("pressed", select_hover)
 for factor in range(1, 5):
  speed_choice.add_item("%dx  %s" % [factor, "NORMAL" if factor == 1 else ""])
 speed_choice.select(selected_speed - 1)
 speed_choice.item_selected.connect(func(index): selected_speed = int(index) + 1)
 body.add_child(speed_choice)
 var index := 0
 for id in NAMES:
  var x := (index % 3) * 316
  var y := 80 + int(index / 3) * 158
  var choice := _button(body, "", Vector2(x, y), Vector2(305, 148), 14)
  var tile := _outlined_style(Color("20252d"), Color("818b98"))
  var tile_highlight := _outlined_style(Color("313946"), Color("fa3945"), 3)
  choice.add_theme_stylebox_override("normal", tile)
  choice.add_theme_stylebox_override("hover", tile_highlight)
  choice.add_theme_stylebox_override("pressed", tile_highlight)
  var map = MAP.new()
  map.position = Vector2(45, 3)
  map.size = Vector2(215, 86)
  map.mouse_filter = Control.MOUSE_FILTER_IGNORE
  choice.add_child(map)
  map.set_points(sources[id])
  var text := _label(choice, NAMES[id], 13, Vector2(0, 92))
  text.size.x = 305
  text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  text.mouse_filter = Control.MOUSE_FILTER_IGNORE
  var circuit: String = id
  choice.pressed.connect(func(): start_requested.emit(circuit, int(lap_slider.value), speed_choice.selected + 1, ai_check.button_pressed))
  index += 1
 ai_check = CheckBox.new()
 ai_check.button_pressed = selected_fill
 ai_check.toggled.connect(func(value): selected_fill = value)
 ai_check.text = "Fill grid with AI riders (9 AI, 10 riders total)"
 ai_check.position = Vector2(0, 400)
 ai_check.size = Vector2(700, 54)
 ai_check.add_theme_icon_override("unchecked", CHECK_OFF)
 ai_check.add_theme_icon_override("checked", CHECK_ON)
 ai_check.add_theme_constant_override("h_separation", 10)
 ai_check.add_theme_font_override("font", TEXT_FONT)
 ai_check.add_theme_font_size_override("font_size", 17)
 body.add_child(ai_check)
