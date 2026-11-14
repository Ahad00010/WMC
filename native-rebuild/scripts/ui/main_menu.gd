class_name WmcMainMenu
extends Control

signal race_requested(circuit_id: String, laps: int, speed: int, ai: bool)
signal audio_changed
signal account_requested
signal sign_out_requested
signal settings_closed
var signed_in := false
var account_status := ""

const DISPLAY = preload("res://assets/fonts/MGPDisplay-Bold.otf")
const TEXT = preload("res://assets/fonts/MGPText-Bold.ttf")
const CHECK_OFF = preload("res://assets/check-off.svg")
const CHECK_ON = preload("res://assets/check-on.svg")
const THUMB = preload("res://assets/slider-thumb.svg")
const DESIGN_SIZE := Vector2(1000, 600)
var _card: Control
var _content: Control
var _title: Label
var _back: Button
var _page := "home"
var _fade: Tween
var _laps := 3
var _speed := 1
var _ai := false
var _settings_return := "home"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.022, 0.035, 0.93)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = Control.new()
	_card.size = DESIGN_SIZE
	add_child(_card)
	var panel := ColorRect.new()
	panel.size = DESIGN_SIZE
	panel.color = Color("151b24")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(panel)
	var stripe := ColorRect.new()
	stripe.size = Vector2(1000, 5)
	stripe.color = Color("ef3041")
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(stripe)
	var kicker := _label(_card, "WORLD MOTORBIKE CHAMPIONSHIP  /  RACE CONTROL", Vector2(42, 28), Vector2(800, 25), 16, false)
	kicker.add_theme_color_override("font_color", Color("f53f4d"))
	_title = _label(_card, "WMC", Vector2(42, 60), Vector2(900, 115), 82, true)
	_content = Control.new()
	_content.position = Vector2(42, 190)
	_content.size = Vector2(916, 340)
	_card.add_child(_content)
	_back = _button(_card, "← BACK", Vector2(42, 540), Vector2(155, 45), false)
	_back.pressed.connect(func():
		var previous := "mode"
		if _page == "settings":
			if _settings_return == "pause":
				settings_closed.emit()
				return
			previous = _settings_return
		elif _page == "mode":
			previous = "home"
		elif _page == "circuit":
			previous = "practice"
		_show_page(previous)
	)
	resized.connect(_fit)
	UiScale.changed.connect(_fit)
	_fit()
	_show_page("home")

func _fit() -> void:
	if not _card or size.x <= 0 or size.y <= 0:
		return
	var factor := minf((size.x - 32.0) / DESIGN_SIZE.x, (size.y - 32.0) / DESIGN_SIZE.y)
	factor = minf(factor, UiScale.panel_scale()) if not OS.has_feature("mobile") else factor
	_card.scale = Vector2.ONE * maxf(0.1, factor)
	_card.position = (size - DESIGN_SIZE * factor) * 0.5

func _show_page(page: String) -> void:
	_page = page
	_back.visible = page != "home"
	_title.text = {"home": "WMC", "mode": "CHOOSE YOUR MODE", "practice": "PRACTICE", "circuit": "SELECT A CIRCUIT", "settings": "SETTINGS"}[page]
	_title.add_theme_font_size_override("font_size", 82 if page == "home" else 55)
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	if page == "home":
		_label(_content, "YOUR GRID. YOUR RACE.", Vector2(0, 12), Vector2(850, 52), 30, true)
		_label(_content, "Choose a circuit and take to the track.", Vector2(0, 80), Vector2(850, 45), 21, false)
		var play := _button(_content, "PLAY  →", Vector2(0, 190), Vector2(280, 72), true)
		play.pressed.connect(func(): _show_page("mode"))
		var settings := _button(_content, "SETTINGS", Vector2(310, 190), Vector2(260, 72), false)
		var account := _button(_content, "EDIT PROFILE" if signed_in else "SIGN IN", Vector2(600, 190), Vector2(260, 72), false)
		account.pressed.connect(func(): account_requested.emit())
		_label(_content, account_status, Vector2(0, 280), Vector2(570, 40), 16, false)
		if signed_in:
			var logout := _button(_content, "SIGN OUT", Vector2(600, 280), Vector2(260, 48), false)
			logout.pressed.connect(func(): sign_out_requested.emit())
		settings.pressed.connect(func():
			_settings_return = "home"
			_show_page("settings")
		)
	elif page == "mode":
		var practice := _button(_content, "PRACTICE  →", Vector2(0, 30), Vector2(438, 125), true)
		practice.pressed.connect(func(): _show_page("practice"))
		var multiplayer := _button(_content, "MULTIPLAYER\nUNDER DEVELOPMENT", Vector2(478, 30), Vector2(438, 125), false)
		multiplayer.disabled = true
	elif page == "practice":
		_label(_content, "RACE LAPS", Vector2(0, 12), Vector2(270, 40), 20, false)
		var laps := SpinBox.new()
		laps.position = Vector2(0, 55)
		laps.size = Vector2(200, 55)
		laps.min_value = 1
		laps.max_value = 10
		laps.step = 1
		laps.value = _laps
		laps.value_changed.connect(func(value: float): _laps = int(value))
		_content.add_child(laps)
		_label(_content, "BIKE SPEED  /  PRACTICE ONLY", Vector2(250, 12), Vector2(450, 40), 20, false)
		var speed := OptionButton.new()
		speed.position = Vector2(250, 55)
		speed.size = Vector2(220, 55)
		for i in range(1, 5):
			speed.add_item("%dx" % i)
		speed.select(_speed - 1)
		speed.item_selected.connect(func(index: int): _speed = index + 1)
		_content.add_child(speed)
		var fill := CheckBox.new()
		fill.text = "FILL GRID WITH 9 AI RIDERS"
		fill.position = Vector2(0, 140)
		fill.size = Vector2(600, 55)
		fill.button_pressed = _ai
		fill.add_theme_icon_override("unchecked", CHECK_OFF)
		fill.add_theme_icon_override("checked", CHECK_ON)
		fill.add_theme_font_override("font", TEXT)
		fill.add_theme_font_size_override("font_size", 20)
		fill.toggled.connect(func(value: bool): _ai = value)
		_content.add_child(fill)
		var next := _button(_content, "CHOOSE CIRCUIT  →", Vector2(0, 230), Vector2(360, 70), true)
		next.pressed.connect(func(): _show_page("circuit"))
		var qualifying := _button(_content, "QUALIFYING / COMING SOON", Vector2(400, 230), Vector2(400, 70), false)
		qualifying.disabled = true
	elif page == "settings":
		_add_volume("MASTER", 0, UiScale.master, func(value: float): UiScale.master = value)
		_add_volume("MUSIC", 90, UiScale.music, func(value: float): UiScale.music = value)
		_add_volume("ENGINE", 180, UiScale.engine, func(value: float): UiScale.engine = value)
		if not OS.has_feature("mobile"):
			_label(_content, "GUI SCALE", Vector2(570, 10), Vector2(250, 40), 19, false)
			var scale := OptionButton.new()
			scale.position = Vector2(570, 56)
			scale.size = Vector2(240, 52)
			for name in UiScale.NAMES:
				scale.add_item(name)
			scale.select(UiScale.selected_mode)
			scale.item_selected.connect(func(index: int): UiScale.set_mode(index))
			_content.add_child(scale)
	else:
		var ids := WmcCircuitData.ids()
		for i in ids.size():
			var id: String = ids[i]
			var info: Dictionary = WmcCircuitData.circuits[id]
			var button := _button(_content, str(info["name"]), Vector2((i % 3) * 310, (i / 3) * 145), Vector2(296, 125), false)
			button.add_theme_font_size_override("font_size", 16)
			button.pressed.connect(func(): race_requested.emit(id, _laps, _speed, _ai))
	if _fade and _fade.is_valid():
		_fade.kill()
	_content.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(_content, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _label(parent: Control, text: String, pos: Vector2, dimensions: Vector2, font_size: int, display: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", DISPLAY if display else TEXT)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Control, text: String, pos: Vector2, dimensions: Vector2, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = dimensions
	button.focus_mode = Control.FOCUS_NONE
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.clip_text = true
	button.add_theme_font_override("font", TEXT)
	button.add_theme_font_size_override("font_size", 22)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("de2636") if primary else Color("252d38")
	normal.border_color = Color("f25260") if primary else Color("697484")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	var hover := normal.duplicate()
	hover.bg_color = Color("fc394b") if primary else Color("364352")
	var disabled_style := normal.duplicate()
	disabled_style.bg_color = Color("1c222a")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled_style)
	parent.add_child(button)
	return button

func _add_volume(title: String, y: float, current: float, update: Callable) -> void:
	_label(_content, title, Vector2(0, y), Vector2(180, 40), 19, false)
	var slider := HSlider.new()
	slider.position = Vector2(190, y + 3)
	slider.size = Vector2(290, 44)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = current
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color("76808f")
	rail.content_margin_top = 4
	rail.content_margin_bottom = 4
	var active_rail := rail.duplicate()
	active_rail.bg_color = Color("ef3041")
	slider.add_theme_stylebox_override("slider", rail)
	slider.add_theme_stylebox_override("grabber_area", active_rail)
	slider.add_theme_stylebox_override("grabber_area_highlight", active_rail)
	slider.add_theme_icon_override("grabber", THUMB)
	slider.add_theme_icon_override("grabber_highlight", THUMB)
	slider.value_changed.connect(func(value: float):
		update.call(value)
		UiScale.save_settings()
		audio_changed.emit()
	)
	_content.add_child(slider)
