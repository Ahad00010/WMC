class_name WmcProfileEditor
extends Control
signal save_requested(display_name: String, username: String, number: int, color: String)
signal closed
const TEXT = preload("res://assets/fonts/MGPText-Bold.ttf")
const DISPLAY = preload("res://assets/fonts/MGPDisplay-Bold.otf")
const COLORS := ["blue", "red", "yellow", "orange", "green", "cyan", "purple", "pink", "white", "black", "silver"]
var _card: Control
var _name: LineEdit
var _username: LineEdit
var _number: SpinBox
var _color: OptionButton
var _status: Label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.025, 0.92)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = Control.new()
	_card.size = Vector2(860, 560)
	add_child(_card)
	var bg := ColorRect.new()
	bg.color = Color("151b24")
	bg.size = _card.size
	_card.add_child(bg)
	_label("RIDER PROFILE", Vector2(35, 20), 46, true)
	_label("DISPLAY NAME", Vector2(35, 105), 17)
	_label("UNIQUE USERNAME", Vector2(445, 105), 17)
	_name = _edit(Vector2(35, 140), "First and last name", 15)
	_username = _edit(Vector2(445, 140), "racing_username", 20)
	_label("RACING NUMBER", Vector2(35, 230), 17)
	_label("PLATE COLOR", Vector2(445, 230), 17)
	_number = SpinBox.new()
	_number.position = Vector2(35, 265)
	_number.size = Vector2(180, 50)
	_number.min_value = 10
	_number.max_value = 99
	_number.step = 1
	_card.add_child(_number)
	_color = OptionButton.new()
	_color.position = Vector2(445, 265)
	_color.size = Vector2(250, 50)
	for color in COLORS:
		_color.add_item(color.capitalize())
	_card.add_child(_color)
	_status = _label("", Vector2(35, 330), 17)
	_status.size = Vector2(790, 50)
	_status.add_theme_color_override("font_color", Color("ff7a80"))
	var save := _button("SAVE PROFILE", Vector2(35, 425))
	save.pressed.connect(func(): save_requested.emit(_name.text, _username.text, int(_number.value), COLORS[_color.selected]))
	var cancel := _button("CANCEL", Vector2(310, 425))
	cancel.pressed.connect(func(): visible = false; closed.emit())
	resized.connect(_fit)
	UiScale.changed.connect(_fit)
	_fit()

func open(profile: Dictionary) -> void:
	_name.text = str(profile.get("display_name", ""))
	_username.text = str(profile.get("username", ""))
	_number.value = clampi(int(profile.get("rider_number", 10)), 10, 99)
	_color.select(maxi(0, COLORS.find(str(profile.get("plate_color", "blue")))))
	_status.text = ""
	visible = true

func set_status(text: String) -> void:
	_status.text = text

func _fit() -> void:
	if not _card:
		return
	var factor := minf((size.x - 32.0) / _card.size.x, (size.y - 32.0) / _card.size.y)
	factor = minf(factor, UiScale.panel_scale()) if not OS.has_feature("mobile") else factor
	_card.scale = Vector2.ONE * maxf(0.1, factor)
	_card.position = (size - _card.size * factor) * 0.5

func _label(text: String, pos: Vector2, font_size: int, display := false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_override("font", DISPLAY if display else TEXT)
	label.add_theme_font_size_override("font_size", font_size)
	_card.add_child(label)
	return label

func _edit(pos: Vector2, placeholder: String, limit: int) -> LineEdit:
	var edit := LineEdit.new()
	edit.position = pos
	edit.size = Vector2(360, 52)
	edit.placeholder_text = placeholder
	edit.max_length = limit
	edit.add_theme_font_override("font", TEXT)
	edit.add_theme_font_size_override("font_size", 19)
	_card.add_child(edit)
	return edit

func _button(text: String, pos: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = Vector2(245, 58)
	button.add_theme_font_override("font", TEXT)
	button.add_theme_font_size_override("font_size", 18)
	_card.add_child(button)
	return button
