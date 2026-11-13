extends Control
signal settings_changed(master: float, music: float, engine: float, gui: int)
const FONT = preload("res://assets/MGPText-Bold.ttf")
const DISPLAY = preload("res://assets/MGPDisplay-Medium.otf")
const THUMB = preload("res://assets/slider-thumb.svg")
var master_slider: HSlider
var music_slider: HSlider
var engine_slider: HSlider
var gui_choice: OptionButton
var is_mobile := false

func setup(mobile: bool) -> void:
 is_mobile = mobile
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 visible = false
 var shade := ColorRect.new()
 shade.color = Color(0.01, 0.015, 0.02, 0.92)
 add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var card := Control.new()
 add_child(card)
 card.set_anchors_preset(Control.PRESET_CENTER)
 card.offset_left = -320
 card.offset_right = 320
 card.offset_top = -295
 card.offset_bottom = 295
 var bg := ColorRect.new()
 bg.color = Color("171b22")
 card.add_child(bg)
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var title := _label(card, "SETTINGS", Vector2(30, 20), 40, true)
 var line := ColorRect.new()
 line.position = Vector2(0, 0)
 line.size = Vector2(640, 4)
 line.color = Color("e4202c")
 card.add_child(line)
 master_slider = _slider(card, "MASTER VOLUME", 110)
 music_slider = _slider(card, "MUSIC", 210)
 engine_slider = _slider(card, "ENGINE", 310)
 if not mobile:
  _label(card, "GUI SCALE", Vector2(30, 405), 18)
  gui_choice = OptionButton.new()
  gui_choice.position = Vector2(330, 405)
  gui_choice.size = Vector2(230, 50)
  gui_choice.add_theme_font_override("font", FONT)
  gui_choice.add_theme_font_size_override("font_size", 17)
  for option in ["Default", "1 · Small", "2 · Normal", "3 · Large"]:
   gui_choice.add_item(option)
  gui_choice.item_selected.connect(func(_index): _notify())
  card.add_child(gui_choice)
 var close := Button.new()
 close.text = "DONE"
 close.position = Vector2(30, 505)
 close.size = Vector2(175, 52)
 close.add_theme_font_override("font", FONT)
 close.add_theme_font_size_override("font_size", 18)
 close.pressed.connect(func(): visible = false)
 card.add_child(close)

func _label(parent: Control, text: String, pos: Vector2, font_size: int, display := false) -> Label:
 var label := Label.new()
 label.text = text
 label.position = pos
 label.add_theme_font_override("font", DISPLAY if display else FONT)
 label.add_theme_font_size_override("font_size", font_size)
 parent.add_child(label)
 return label

func _slider(parent: Control, text: String, y: float) -> HSlider:
 _label(parent, text, Vector2(30, y), 18)
 var slider := HSlider.new()
 slider.position = Vector2(30, y + 40)
 slider.size = Vector2(530, 36)
 slider.min_value = 0
 slider.max_value = 1
 slider.step = 0.05
 var rail := StyleBoxFlat.new()
 rail.bg_color = Color("777f8b")
 rail.content_margin_top = 4
 rail.content_margin_bottom = 4
 var fill := StyleBoxFlat.new()
 fill.bg_color = Color("ed2534")
 fill.content_margin_top = 4
 fill.content_margin_bottom = 4
 slider.add_theme_stylebox_override("slider", rail)
 slider.add_theme_stylebox_override("grabber_area", fill)
 slider.add_theme_stylebox_override("grabber_area_highlight", fill)
 slider.add_theme_icon_override("grabber", THUMB)
 slider.add_theme_icon_override("grabber_highlight", THUMB)
 slider.value = 1
 slider.value_changed.connect(func(_value): _notify())
 parent.add_child(slider)
 return slider

func set_values(master: float, music: float, engine: float, gui: int) -> void:
 master_slider.set_value_no_signal(master)
 music_slider.set_value_no_signal(music)
 engine_slider.set_value_no_signal(engine)
 if gui_choice:
  gui_choice.select(clampi(gui, 0, 3))

func _notify() -> void:
 settings_changed.emit(master_slider.value, music_slider.value, engine_slider.value, gui_choice.selected if gui_choice else 0)
