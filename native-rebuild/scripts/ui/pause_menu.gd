class_name WmcPauseMenu
extends Control
signal resume_requested
signal main_menu_requested
signal settings_requested
const FONT = preload("res://assets/fonts/MGPText-Bold.ttf")
const DISPLAY = preload("res://assets/fonts/MGPDisplay-Bold.otf")
var _card: Control
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.03, 0.88)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = Control.new()
	_card.size = Vector2(560, 400)
	add_child(_card)
	var panel := ColorRect.new()
	panel.size = _card.size
	panel.color = Color("151b24")
	_card.add_child(panel)
	var stripe := ColorRect.new()
	stripe.size = Vector2(560, 5)
	stripe.color = Color("ef3041")
	_card.add_child(stripe)
	var title := Label.new()
	title.text = "PAUSED"
	title.position = Vector2(35, 30)
	title.add_theme_font_override("font", DISPLAY)
	title.add_theme_font_size_override("font_size", 58)
	_card.add_child(title)
	var resume := _button("RESUME", 150)
	resume.pressed.connect(func(): resume_requested.emit())
	var settings := _button("SETTINGS", 220)
	settings.pressed.connect(func(): settings_requested.emit())
	var home := _button("MAIN MENU", 290)
	home.pressed.connect(func(): main_menu_requested.emit())
	resized.connect(_fit)
	_fit()

func _button(text: String, y: float) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(35, y)
	button.size = Vector2(490, 60)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 20)
	button.focus_mode = Control.FOCUS_NONE
	_card.add_child(button)
	return button

func _fit() -> void:
	if not _card:
		return
	var factor := minf((size.x - 32.0) / 560.0, (size.y - 32.0) / 400.0)
	_card.scale = Vector2.ONE * maxf(0.1, factor)
	_card.position = (size - _card.size * factor) * 0.5
