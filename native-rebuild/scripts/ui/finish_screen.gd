class_name WmcFinishScreen
extends Control
signal main_menu_requested
const DISPLAY = preload("res://assets/fonts/MGPDisplay-Bold.otf")
const TEXT = preload("res://assets/fonts/MGPText-Bold.ttf")
var _frames: Array = []
var _clock := 0.0
var _first_time := 0.0
var _frame_index := -1
var _screen: TextureRect
var _portrait: TextureRect
var _card: Control
var _winner: Label
var _menu: Button
var _phase := "hidden"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_screen = TextureRect.new()
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_screen)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.025, 0.5)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = Control.new()
	_card.size = Vector2(840, 460)
	add_child(_card)
	var background := ColorRect.new()
	background.size = _card.size
	background.color = Color("121720")
	_card.add_child(background)
	_portrait = TextureRect.new()
	_portrait.position = Vector2(500, 6)
	_portrait.size = Vector2(340, 454)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.modulate = Color(0.9, 0.9, 0.9, 0.7)
	_card.add_child(_portrait)
	var stripe := ColorRect.new()
	stripe.size = Vector2(840, 6)
	stripe.color = Color("ee2c3d")
	_card.add_child(stripe)
	_add_label("RACE WINNER", Vector2(45, 36), 34, DISPLAY, Color("ef3445"))
	_winner = _add_label("", Vector2(45, 115), 60, DISPLAY, Color.WHITE)
	_winner.size.x = 440
	_add_label("WMC GRAND PRIX TEAM", Vector2(45, 235), 24, TEXT, Color("c8d0dc"))
	_add_label("+25 POINTS", Vector2(45, 285), 28, DISPLAY, Color.WHITE)
	_menu = Button.new()
	_menu.text = "MAIN MENU"
	_menu.position = Vector2(45, 365)
	_menu.size = Vector2(240, 58)
	_menu.add_theme_font_override("font", TEXT)
	_menu.add_theme_font_size_override("font_size", 19)
	_menu.pressed.connect(func(): main_menu_requested.emit())
	_card.add_child(_menu)
	resized.connect(_fit)
	_fit()

func _add_label(text: String, pos: Vector2, font_size: int, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = Vector2(750, 90)
	label.clip_text = true
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_card.add_child(label)
	return label

func _fit() -> void:
	if not _card:
		return
	var factor := minf((size.x - 32) / 840.0, (size.y - 32) / 460.0)
	_card.scale = Vector2.ONE * maxf(0.1, factor)
	_card.position = (size - _card.size * factor) * 0.5

func begin(footage: Array, winner_name: String) -> void:
	_frames = footage
	_winner.text = winner_name
	visible = true
	_card.visible = false
	_clock = 0.0
	_frame_index = -1
	_screen.texture = null
	_portrait.texture = null
	_first_time = float(_frames[0].time) if not _frames.is_empty() else 0.0
	_phase = "replay" if not _frames.is_empty() else "card"
	if _phase == "card":
		_show_card()

func _process(delta: float) -> void:
	if _phase != "replay":
		return
	_clock += delta
	var last := _frames.size() - 1
	var index := maxi(0, _frame_index)
	while index < last and float(_frames[index + 1].time) - _first_time <= _clock:
		index += 1
	if index != _frame_index:
		var image := Image.new()
		if image.load_jpg_from_buffer(_frames[index].jpeg) == OK:
			_screen.texture = ImageTexture.create_from_image(image)
			_portrait.texture = _screen.texture
		_frame_index = index
	if _clock >= float(_frames[last].time) - _first_time + 0.25:
		_show_card()

func _show_card() -> void:
	_phase = "card"
	_card.visible = true
	_card.modulate.a = 0.0
	var transition := create_tween()
	transition.tween_property(_card, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)

func close() -> void:
	_phase = "hidden"
	visible = false
	_frames.clear()
	_screen.texture = null
	_portrait.texture = null
