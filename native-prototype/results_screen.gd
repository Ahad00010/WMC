extends Control

signal main_menu_requested
const DISPLAY = preload("res://assets/MGPDisplay-Medium.otf")
const TEXT = preload("res://assets/MGPText-Bold.ttf")
const INLINE = preload("res://assets/MGPInline-Regular.otf")
const RESULTS_MUSIC = preload("res://assets/results-music.mp3")
const TISSOT = preload("res://assets/tissot.png")
const RIDER = preload("res://assets/marc-rider.glb")
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
var rider_view: SubViewport
var rider_figure: Node3D
var leaving := false
var leave_clock := 0.0
var leave_volume := 0.0

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
 menu_button.pressed.connect(_request_menu)
 canvas.add_child(menu_button)
 menu_button.visible = false
 player = AudioStreamPlayer.new()
 player.stream = RESULTS_MUSIC
 add_child(player)
 _make_rider_scene()
 resized.connect(_fit)
 _fit()

func _make_rider_scene() -> void:
 rider_view = SubViewport.new()
 rider_view.size = Vector2i(500, 813)
 rider_view.transparent_bg = true
 rider_view.own_world_3d = true
 rider_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
 add_child(rider_view)
 var world := Node3D.new()
 rider_view.add_child(world)
 var camera := Camera3D.new()
 world.add_child(camera)
 camera.position = Vector3(0, 0.60, 3.45)
 camera.fov = 33
 camera.look_at(Vector3(0, 0.49, 0), Vector3.UP)
 camera.current = true
 var light := DirectionalLight3D.new()
 world.add_child(light)
 light.rotation_degrees = Vector3(-35, -30, 0)
 light.light_energy = 1.2
 var environment := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color(0, 0, 0, 0)
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color.WHITE
 env.ambient_light_energy = 0.8
 environment.environment = env
 world.add_child(environment)
 rider_figure = Node3D.new()
 world.add_child(rider_figure)
 var model: Node3D = RIDER.instantiate()
 rider_figure.add_child(model)
 model.position.y = 0.12
 model.rotation.x = -0.72

func _request_menu() -> void:
 if leaving:
  return
 leaving = true
 leave_clock = 0.0
 leave_volume = db_to_linear(player.volume_db) if player.playing else 0.0
 menu_button.disabled = true

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
 leaving = false
 leave_clock = 0.0
 if menu_button:
  menu_button.disabled = false
 if rider_view:
  rider_view.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _process(dt: float) -> void:
 if running:
  advance(dt)

func advance(dt: float) -> void:
 if not running:
  return
 if leaving:
  leave_clock += maxf(dt, 0.0)
  player.volume_db = linear_to_db(maxf(0.0001, leave_volume * (1.0 - clampf(leave_clock / 0.8, 0.0, 1.0))))
  if leave_clock >= 0.8:
   leaving = false
   main_menu_requested.emit()
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
 rider_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if phase == "grand_prix" else SubViewport.UPDATE_DISABLED
 if phase == "grand_prix":
  rider_figure.rotation.y = 0.08 * sin(clock * 0.45)
  rider_figure.rotation.z = 0.015 * sin(clock * 0.8)
  rider_figure.position.y = 0.008 * sin(clock * 1.3)
 menu_button.visible = phase == "winner"
 var menu_intro := clampf((clock - 63.35) / 0.5, 0.0, 1.0)
 menu_button.position.x = 42.0 - 35.0 * (1.0 - menu_intro)
 menu_button.modulate.a = menu_intro
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
 var duration := maxf(1.0 / 60.0, float(replay_frames[-1].time) - first + 1.0 / 60.0)
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
 var stage_factor := minf(size.x / 1280.0, size.y / 720.0)
 var stage_origin := (size - Vector2(1280, 720) * stage_factor) * 0.5
 var phase_start := 43.0 if championship else 23.0
 var intro := clampf((clock - phase_start - 0.25) / 0.65, 0.0, 1.0)
 intro = 1.0 - pow(1.0 - intro, 3.0)
 if not championship:
  var rider_intro := clampf((clock - 23.0) / 0.65, 0.0, 1.0)
  draw_texture_rect(rider_view.get_texture(), Rect2(0, 35 + 55 * (1.0 - rider_intro), 345, 660), false, Color(1, 1, 1, rider_intro))
 draw_set_transform(stage_origin + Vector2(100.0 * (1.0 - intro), 0) * stage_factor, 0.0, Vector2.ONE * stage_factor)
 var content_x := 350.0
 draw_string(DISPLAY, Vector2(content_x, 67), "WMC", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color.WHITE)
 draw_string(TEXT, Vector2(content_x + 145, 65), hashtag, HORIZONTAL_ALIGNMENT_LEFT, 250, 18, Color.WHITE)
 draw_string(TEXT, Vector2(content_x, 97), circuit, HORIZONTAL_ALIGNMENT_LEFT, 890, 17, Color.WHITE)
 draw_string(DISPLAY, Vector2(content_x, 155), "WORLD CHAMPIONSHIP" if championship else "GRAND PRIX RESULTS", HORIZONTAL_ALIGNMENT_LEFT, 890, 48 if championship else 52, Color.WHITE)
 if championship:
  draw_rect(Rect2(content_x, 185, 880, 52), Color("08080c"))
  draw_string(TEXT, Vector2(content_x + 18, 219), "Championship standings unavailable for practice", HORIZONTAL_ALIGNMENT_LEFT, 840, 18, Color.WHITE)
 else:
  draw_string(TEXT, Vector2(content_x, 182), "Points are not recorded for this race", HORIZONTAL_ALIGNMENT_LEFT, 850, 13, Color("d3d3d8"))
  for i in range(mini(entries.size(), 10)):
   var entry: Dictionary = entries[i]
   var row_intro := clampf((clock - 23.3 - i * 0.035) / 0.3, 0.0, 1.0)
   if row_intro <= 0.0:
    continue
   draw_set_transform(stage_origin + Vector2((100.0 * (1.0 - row_intro)) * stage_factor, 0), 0.0, Vector2.ONE * stage_factor)
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
  var winner_intro := clampf((clock - 25.65) / 0.65, 0.0, 1.0)
  if winner_intro > 0.0:
   draw_set_transform(stage_origin + Vector2(85, 620 - 75 * (1.0 - winner_intro)) * stage_factor, -PI / 2, Vector2.ONE * stage_factor)
   draw_string(INLINE, Vector2.ZERO, "WINNER", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color(1, 1, 1, winner_intro))
  # Restore the stage transform after rotating the winner word.
  var factor := minf(size.x / 1280.0, size.y / 720.0)
  draw_set_transform((size - Vector2(1280, 720) * factor) * 0.5, 0.0, Vector2.ONE * factor)
 draw_set_transform(stage_origin, 0.0, Vector2.ONE * stage_factor)
 draw_texture_rect(TISSOT, Rect2(content_x, 672, 125, 25), false)
 draw_texture_rect(FIM, Rect2(1080, 670, 60, 27), false)
 draw_string(TEXT, Vector2(1144, 692), "|", HORIZONTAL_ALIGNMENT_LEFT, 14, 20, Color("999999"))
 draw_string(DISPLAY, Vector2(1162, 692), "WMC", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("bbbbbb"))

func _draw_winner() -> void:
 if replay_texture:
  draw_texture_rect(replay_texture, Rect2(0, 0, 1280, 720), false)
 draw_string(TEXT, Vector2(40, 60), "RACE COMPLETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
 if entries.is_empty():
  return
 var winner: Dictionary = entries[0]
 var factor := minf(size.x / 1280.0, size.y / 720.0)
 var origin := (size - Vector2(1280, 720) * factor) * 0.5
 var intro := clampf((clock - 63.35) / 0.7, 0.0, 1.0)
 intro = 1.0 - pow(1.0 - intro, 3.0)
 draw_set_transform(origin + Vector2(35.0 * (1.0 - intro), 0) * factor, 0.0, Vector2.ONE * factor)
 draw_rect(Rect2(900, 470, 320, 31), Color("050505"))
 draw_string(INLINE, Vector2(900, 493), "RACE WINNER", HORIZONTAL_ALIGNMENT_CENTER, 320, 21, Color(1, 1, 1, intro))
 # Layered diagonal streaks mirror the website's dark red/orange winner graphic.
 draw_rect(Rect2(900, 501, 320, 86), Color("201321"))
 var streaks := [Color("391828"), Color("9b242b"), Color("381727"), Color("af2926"), Color("ee5a24"), Color("7b1d25")]
 for i in range(streaks.size()):
  var y := 505.0 + i * 14.0
  draw_colored_polygon(PackedVector2Array([Vector2(900, y + 18), Vector2(1220, y - 28), Vector2(1220, y - 11), Vector2(900, y + 35)]), streaks[i])
 draw_string(TEXT, Vector2(912, 535), str(winner.name).to_upper().substr(0, 20), HORIZONTAL_ALIGNMENT_LEFT, 195, 17, Color.WHITE)
 draw_string(TEXT, Vector2(912, 556), "WMC GRAND PRIX TEAM", HORIZONTAL_ALIGNMENT_LEFT, 205, 10, Color.WHITE)
 draw_string(TEXT, Vector2(1140, 559), str(winner.number), HORIZONTAL_ALIGNMENT_CENTER, 68, 43, Color.WHITE)
 draw_rect(Rect2(900, 587, 320, 54), Color("050505"))
 draw_string(DISPLAY, Vector2(918, 620), "+25", HORIZONTAL_ALIGNMENT_LEFT, 100, 30, Color.WHITE)
 draw_string(DISPLAY, Vector2(918, 636), "POINTS", HORIZONTAL_ALIGNMENT_LEFT, 100, 13, Color.WHITE)
 draw_texture_rect(TISSOT, Rect2(900, 641, 125, 25), false)

func _format_time(value: float) -> String:
 if not is_finite(value):
  return "—"
 var ms := roundi(maxf(value, 0.0) * 1000.0)
 return "%d:%02d.%03d" % [int(ms / 60000), int(ms / 1000) % 60, ms % 1000]
