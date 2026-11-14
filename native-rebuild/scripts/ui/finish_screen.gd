class_name WmcFinishScreen
extends Control
signal main_menu_requested
const TEXT = preload("res://assets/fonts/MGPText-Bold.ttf")
const STAGE := Vector2(1280, 720)
const CARD_POSITION := Vector2(900, 470)
var _frames: Array = []
var _clock := 0.0
var _first_time := 0.0
var _frame_index := -1
var _screen: TextureRect
var _card: WmcWinnerGraphic
var _menu: Button
var _early_menu: Button
var _phase := "hidden"
var _card_intro := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_screen = TextureRect.new()
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.025, 0.2)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_early_menu = _make_button("MAIN MENU")
	_early_menu.anchor_left = 1.0
	_early_menu.anchor_right = 1.0
	_early_menu.offset_left = -190
	_early_menu.offset_right = -24
	_early_menu.offset_top = 20
	_early_menu.offset_bottom = 72
	add_child(_early_menu)
	_card = WmcWinnerGraphic.new()
	_card.size = Vector2(320, 196)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_menu = _make_button("MAIN MENU")
	add_child(_menu)
	resized.connect(_fit)
	_fit()

func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", TEXT)
	button.add_theme_font_size_override("font_size", 17)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func(): main_menu_requested.emit())
	return button

func _fit() -> void:
	if not _card or not _menu:
		return
	var factor := minf(size.x / STAGE.x, size.y / STAGE.y)
	var origin := (size - STAGE * factor) * 0.5
	_card.scale = Vector2.ONE * factor
	_card.position = origin + (CARD_POSITION + Vector2(35.0 * (1.0 - _card_intro), 0)) * factor
	_menu.scale = Vector2.ONE * factor
	_menu.position = origin + Vector2(42, 638) * factor
	_menu.size = Vector2(210, 55)

func begin(footage: Array, winner_name: String, winner_number: int = 10) -> void:
	_frames = footage
	_card.configure(winner_name, winner_number)
	visible = true
	_card.visible = false
	_menu.visible = false
	_clock = 0.0
	_frame_index = -1
	_screen.texture = null
	_first_time = float(_frames[0].time) if not _frames.is_empty() else 0.0
	_phase = "replay" if not _frames.is_empty() else "card"
	_early_menu.visible = _phase == "replay"
	if _phase == "card":
		_show_card()

func _process(delta: float) -> void:
	if _phase == "card":
		_card_intro = minf(1.0, _card_intro + delta / 0.7)
		_card.modulate.a = _card_intro
		_menu.modulate.a = _card_intro
		_fit()
		return
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
			# Reuse a texture of the same size instead of allocating a new GPU
			# texture every frame during replay.
			var texture := _screen.texture as ImageTexture
			if texture and texture.get_width() == image.get_width() and texture.get_height() == image.get_height() and texture.get_format() == image.get_format():
				texture.update(image)
			else:
				_screen.texture = ImageTexture.create_from_image(image)
		_frame_index = index
	if _clock >= float(_frames[last].time) - _first_time + 0.25:
		_show_card()

func _show_card() -> void:
	_phase = "card"
	_early_menu.visible = false
	_card_intro = 0.0
	_card.visible = true
	_card.modulate.a = 0.0
	_menu.visible = true
	_menu.modulate.a = 0.0
	_fit()

func close() -> void:
	_phase = "hidden"
	visible = false
	_frames.clear()
	_screen.texture = null
