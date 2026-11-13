extends Control

signal main_menu_requested
const DISPLAY = preload("res://assets/MGPDisplay-Medium.otf")
const TEXT = preload("res://assets/MGPText-Bold.ttf")
const INLINE = preload("res://assets/MGPInline-Regular.otf")
const RESULTS_MUSIC = preload("res://assets/results-music.mp3")
const TISSOT = preload("res://assets/tissot.png")
const FIM = preload("res://assets/fim.png")
const POINTS = [25,20,16,13,11,10,9,8,7,6,5,4,3,2,1]
const COLORS = {"blue":Color("176bb3"), "red":Color("d81822"), "yellow":Color("f2e800"), "orange":Color("f47b20"), "green":Color("268950"), "cyan":Color("00a6bb"), "purple":Color("6d27a6"), "pink":Color("da5696"), "white":Color("f4f4f4"), "black":Color("262626"), "silver":Color("b2b9bb")}
var entries: Array = []
var circuit := ""
var hashtag := ""
var clock := 0.0
var running := false
var phase := "waiting"
var player: AudioStreamPlayer
var menu_button: Button
var canvas: Control
var volume := 1.0
var muted := false
var cued := false
var replay_frames: Array = []
var replay_texture: ImageTexture
var replay_index := -1

func setup() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 visible = false
 canvas = Control.new()
 canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(canvas)
 canvas.set_anchors_preset(Control.PRESET_CENTER)
 canvas.offset_left = -640
 canvas.offset_right = 640
 canvas.offset_top = -360
 canvas.offset_bottom = 360
 # Drawing uses this node, while the button is anchored on the centered stage.
 menu_button = Button.new()
 menu_button.text = "MAIN MENU"
 menu_button.position = Vector2(42, 638)
 menu_button.size = Vector2(210, 55)
 menu_button.add_theme_font_override("font", TEXT)
 menu_button.add_theme_font_size_override("font_size", 17)
 menu_button.pressed.connect(func(): main_menu_requested.emit())
 canvas.add_child(menu_button)
 menu_button.visible = false
 player = AudioStreamPlayer.new()
 player.stream = RESULTS_MUSIC
 add_child(player)
 resized.connect(_fit)
 _fit()

func _fit() -> void:
 if canvas == null:
  return
 var factor := minf(size.x / 1280.0, size.y / 720.0)
 canvas.pivot_offset = Vector2(640, 360)
 canvas.scale = Vector2.ONE * factor
 queue_redraw()

func begin(classification: Array, circuit_name: String, tag: String, captured: Array = []) -> void:
 cancel()
 replay_frames = captured
 replay_index = -1
 replay_texture = null
 entries = classification.duplicate(true)
 circuit = circuit_name.replace("\n", " ")
 hashtag = tag
 clock = 0.0
 phase = "waiting"
 running = true
 visible = true
 menu_button.visible = false
 queue_redraw()

func cancel() -> void:
 running = false
 visible = false
 if player:
  player.stop()
 if menu_button:
  menu_button.visible = false
 cued = false

func _process(dt: float) -> void:
 if running:
  advance(dt)

func advance(dt: float) -> void:
 if not running:
  return
 clock += maxf(dt, 0.0)
 if clock >= 20.0 and not cued:
  cued = true
  player.volume_db = -80.0
  player.play()
 if clock < 23.0:
  phase = "waiting"
 elif clock < 43.0:
  phase = "grand_prix"
 elif clock < 63.0:
  phase = "championship"
 elif clock < 63.35:
  phase = "fade"
 else:
  phase = "winner"
 menu_button.visible = phase == "winner"
 if phase == "winner":
  _update_replay()
 if cued:
  var fade_in := clampf((clock - 20.0) / 3.0, 0.0, 1.0)
  var fade_out := 1.0 - clampf((clock - 70.35) / 1.5, 0.0, 1.0)
  player.volume_db = linear_to_db(maxf(0.0001, 0.8 * volume * fade_in * fade_out if not muted else 0.0001))
  if fade_out <= 0.0 and player.playing:
   player.stop()
 queue_redraw()

func _update_replay() -> void:
 if replay_frames.is_empty():
  return
 var first := float(replay_frames[0].time)
 var duration := maxf(1.0 / 24.0, float(replay_frames[-1].time) - first + 1.0 / 24.0)
 var t := first + fmod(maxf(0.0, clock - 63.35), duration)
 var index := 0
 while index + 1 < replay_frames.size() and float(replay_frames[index + 1].time) <= t:
  index += 1
 if index == replay_index:
  return
 var image := Image.new()
 if image.load(replay_frames[index].path) == OK:
  replay_texture = ImageTexture.create_from_image(image)
  replay_index = index

func _draw() -> void:
 if not running or phase == "waiting":
  return
 # Map fixed reference coordinates to the same centered stage as its button.
 var factor := minf(size.x / 1280.0, size.y / 720.0)
 var origin := (size - Vector2(1280, 720) * factor) * 0.5
 draw_rect(Rect2(Vector2.ZERO, size), Color("09090d"))
 draw_set_transform(origin, 0.0, Vector2.ONE * factor)
 draw_rect(Rect2(0, 0, 1280, 720), Color("13111b"))
 for y in [30, 90, 150, 220, 310, 390, 495, 610]:
  for n in range(9, 0, -1):
   draw_rect(Rect2(0, y - n * 2, 1280, n * 4), Color(0.85, 0.05, 0.09, 0.012))
  draw_rect(Rect2(0, y, 1280, 3), Color(0.82, 0.07, 0.10, 0.32))
 if phase == "winner":
  _draw_winner()
 elif phase == "fade":
  _draw_results(true)
  draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, clampf((clock - 63.0) / 0.35, 0.0, 1.0)))
 else:
  _draw_results(phase == "championship")
 draw_set_transform(Vector2.ZERO)

func _draw_results(championship: bool) -> void:
 var content_x := 350.0
 draw_string(DISPLAY, Vector2(content_x, 67), "WMC", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color.WHITE)
 draw_string(TEXT, Vector2(content_x + 120, 65), hashtag, HORIZONTAL_ALIGNMENT_LEFT, 250, 18, Color.WHITE)
 draw_string(TEXT, Vector2(content_x, 97), circuit, HORIZONTAL_ALIGNMENT_LEFT, 890, 17, Color.WHITE)
 draw_string(DISPLAY, Vector2(content_x, 155), "WORLD CHAMPIONSHIP" if championship else "GRAND PRIX RESULTS", HORIZONTAL_ALIGNMENT_LEFT, 890, 48 if championship else 52, Color.WHITE)
 if championship:
  draw_rect(Rect2(content_x, 185, 880, 52), Color("08080c"))
  draw_string(TEXT, Vector2(content_x + 18, 219), "Championship standings unavailable for practice", HORIZONTAL_ALIGNMENT_LEFT, 840, 18, Color.WHITE)
 else:
  draw_string(TEXT, Vector2(content_x, 182), "Points are not recorded for this race", HORIZONTAL_ALIGNMENT_LEFT, 850, 13, Color("d3d3d8"))
  for i in range(mini(entries.size(), 10)):
   var entry: Dictionary = entries[i]
   var y := 195.0 + i * 42.0
   draw_rect(Rect2(content_x, y, 880, 36), Color("07070a"))
   draw_string(TEXT, Vector2(content_x + 12, y + 26), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 45, 20, Color.WHITE)
   var color: Color = COLORS.get(entry.get("color", "red"), Color("e4202c"))
   draw_rect(Rect2(content_x + 60, y + 5, 56, 27), color)
   var ink := Color.BLACK if entry.get("color", "red") in ["yellow", "white", "cyan", "silver"] else Color.WHITE
   draw_string(TEXT, Vector2(content_x + 60, y + 25), str(entry.number), HORIZONTAL_ALIGNMENT_CENTER, 56, 18, ink)
   draw_string(TEXT, Vector2(content_x + 135, y + 25), str(entry.name).to_upper().substr(0, 22), HORIZONTAL_ALIGNMENT_LEFT, 330, 18, Color.WHITE)
   var done: bool = entry.finished
   var points := "+%d" % POINTS[i] if done and i < POINTS.size() else "—"
   draw_string(TEXT, Vector2(content_x + 520, y + 25), points, HORIZONTAL_ALIGNMENT_CENTER, 70, 17, Color.WHITE)
   draw_string(TEXT, Vector2(content_x + 600, y + 25), _format_time(float(entry.finish_time)) if done else "UNFINISHED", HORIZONTAL_ALIGNMENT_RIGHT, 145, 16, Color.WHITE)
   draw_string(DISPLAY, Vector2(content_x + 770, y + 23), "WMC93", HORIZONTAL_ALIGNMENT_LEFT, 85, 12, Color.WHITE)
  var stage_factor := minf(size.x / 1280.0, size.y / 720.0)
  var stage_origin := (size - Vector2(1280, 720) * stage_factor) * 0.5
  draw_set_transform(stage_origin + Vector2(85, 620) * stage_factor, -PI / 2, Vector2.ONE * stage_factor)
  draw_string(INLINE, Vector2.ZERO, "WINNER", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color.WHITE)
  # Restore the stage transform after rotating the winner word.
  var factor := minf(size.x / 1280.0, size.y / 720.0)
  draw_set_transform((size - Vector2(1280, 720) * factor) * 0.5, 0.0, Vector2.ONE * factor)
 draw_texture_rect(TISSOT, Rect2(content_x, 672, 125, 25), false)
 draw_texture_rect(FIM, Rect2(1080, 670, 60, 27), false)
 draw_string(DISPLAY, Vector2(1160, 694), "WMC", HORIZONTAL_ALIGNMENT_LEFT, 70, 22, Color("bbbbbb"))

func _draw_winner() -> void:
 if replay_texture:
  draw_texture_rect(replay_texture, Rect2(0, 0, 1280, 720), false)
 draw_string(TEXT, Vector2(40, 60), "RACE COMPLETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
 if entries.is_empty():
  return
 var winner: Dictionary = entries[0]
 draw_rect(Rect2(900, 470, 330, 135), Color("08080b"))
 draw_string(INLINE, Vector2(920, 502), "RACE WINNER", HORIZONTAL_ALIGNMENT_LEFT, 285, 21, Color.WHITE)
 draw_rect(Rect2(910, 514, 310, 53), COLORS.get(winner.get("color", "red"), Color("e4202c")))
 draw_string(TEXT, Vector2(920, 538), str(winner.name).to_upper().substr(0, 20), HORIZONTAL_ALIGNMENT_LEFT, 200, 17, Color.WHITE)
 draw_string(TEXT, Vector2(920, 557), "WMC GRAND PRIX TEAM", HORIZONTAL_ALIGNMENT_LEFT, 220, 10, Color.WHITE)
 draw_string(DISPLAY, Vector2(1152, 552), str(winner.number), HORIZONTAL_ALIGNMENT_LEFT, 60, 32, Color.WHITE)
 draw_string(DISPLAY, Vector2(920, 597), "+25 POINTS", HORIZONTAL_ALIGNMENT_LEFT, 240, 21, Color.WHITE)
 draw_texture_rect(TISSOT, Rect2(910, 612, 125, 25), false)

func _format_time(value: float) -> String:
 if not is_finite(value):
  return "—"
 var ms := roundi(maxf(value, 0.0) * 1000.0)
 return "%d:%02d.%03d" % [int(ms / 60000), int(ms / 1000) % 60, ms % 1000]
