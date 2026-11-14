class_name WmcMainMenu
extends Control

signal race_requested(circuit_id: String)

const DISPLAY = preload("res://assets/fonts/MGPDisplay-Bold.otf")
const TEXT = preload("res://assets/fonts/MGPText-Bold.ttf")
const DESIGN_SIZE := Vector2(1000, 600)
var _card: Control
var _content: Control
var _title: Label
var _back: Button
var _page := "home"
var _fade: Tween

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
	_back.pressed.connect(func(): _show_page("home" if _page == "mode" else "mode"))
	resized.connect(_fit)
	_fit()
	_show_page("home")

func _fit() -> void:
	if not _card or size.x <= 0 or size.y <= 0:
		return
	var factor := minf((size.x - 32.0) / DESIGN_SIZE.x, (size.y - 32.0) / DESIGN_SIZE.y)
	_card.scale = Vector2.ONE * maxf(0.1, factor)
	_card.position = (size - DESIGN_SIZE * factor) * 0.5

func _show_page(page: String) -> void:
	_page = page
	_back.visible = page != "home"
	_title.text = {"home": "WMC", "mode": "CHOOSE YOUR MODE", "circuit": "SELECT A CIRCUIT"}[page]
	_title.add_theme_font_size_override("font_size", 82 if page == "home" else 55)
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	if page == "home":
		_label(_content, "YOUR GRID. YOUR RACE.", Vector2(0, 12), Vector2(850, 52), 30, true)
		_label(_content, "Choose a circuit and take to the track.", Vector2(0, 80), Vector2(850, 45), 21, false)
		var play := _button(_content, "PLAY  →", Vector2(0, 190), Vector2(280, 72), true)
		play.pressed.connect(func(): _show_page("mode"))
	elif page == "mode":
		var practice := _button(_content, "PRACTICE  →", Vector2(0, 30), Vector2(438, 125), true)
		practice.pressed.connect(func(): _show_page("circuit"))
		var multiplayer := _button(_content, "MULTIPLAYER\nUNDER DEVELOPMENT", Vector2(478, 30), Vector2(438, 125), false)
		multiplayer.disabled = true
	else:
		var ids := WmcCircuitData.ids()
		for i in ids.size():
			var id: String = ids[i]
			var info: Dictionary = WmcCircuitData.circuits[id]
			var button := _button(_content, str(info["name"]), Vector2((i % 3) * 310, (i / 3) * 145), Vector2(296, 125), false)
			button.add_theme_font_size_override("font_size", 16)
			button.pressed.connect(func(): race_requested.emit(id))
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
