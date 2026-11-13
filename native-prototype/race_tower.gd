extends Control

const ROW = preload("res://race_tower_row.gd")
const FONT = preload("res://assets/MGPText-Bold.ttf")
const DISPLAY = preload("res://assets/MGPDisplay-Medium.otf")
const INLINE = preload("res://assets/MGPInline-Regular.otf")
const HEAD_HEIGHT := 112.0
const ROW_HEIGHT := 30.0
var rows := {}
var targets := {}
var lap := 1
var total_laps := 3
var lap_progress := 0.0
var finished := false
var hashtag := "#MalaysianGP"
var initialized := false
var animations := {}

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE

func reset() -> void:
 for animation in animations.values():
  if animation.is_valid():
   animation.kill()
 animations.clear()
 for row in rows.values():
  row.queue_free()
 rows.clear()
 targets.clear()
 initialized = false
 finished = false
 lap_progress = 0.0
 queue_redraw()

func update_standings(entries: Array, current_lap: int, laps: int, current_progress := 0.0, race_finished := false, circuit_hashtag := "#MalaysianGP") -> void:
 lap = current_lap
 total_laps = laps
 lap_progress = clampf(current_progress, 0.0, 1.0)
 finished = race_finished
 hashtag = circuit_hashtag
 size.y = HEAD_HEIGHT + entries.size() * ROW_HEIGHT + 25.0
 for i in range(entries.size()):
  var entry: Dictionary = entries[i]
  var id: String = entry.id
  if not rows.has(id):
   var row = ROW.new()
   row.size = Vector2(200, 29)
   row.position = Vector2(0, HEAD_HEIGHT + i * ROW_HEIGHT)
   add_child(row)
   rows[id] = row
  var row: Control = rows[id]
  row.rank = i + 1
  row.label = abbreviated_name(str(entry.name)).substr(0, 11) if entry.is_player else str(entry.name).substr(0, 11)
  row.number = str(entry.number)
  row.is_player = entry.is_player
  row.finished = bool(entry.get("finished", false))
  row.plate_color = str(entry.get("color", "red"))
  row.queue_redraw()
  var target := HEAD_HEIGHT + i * ROW_HEIGHT
  if targets.has(id) and float(targets[id]) != target:
   if animations.has(id) and animations[id].is_valid():
    animations[id].kill()
   var tween := create_tween().set_parallel(true)
   animations[id] = tween
   tween.tween_property(row, "position:y", target, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
   row.modulate = Color(1.6, 1.6, 1.6)
   tween.tween_property(row, "modulate", Color.WHITE, 0.5)
  elif not targets.has(id):
   row.position.y = target
  targets[id] = target
 initialized = true
 queue_redraw()

func display_state() -> String:
 if finished:
  return "FINISH"
 if lap >= total_laps:
  return "LAST LAP"
 return "%d/%d" % [lap, total_laps]

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.025, 0.03, 0.91))
 draw_string(DISPLAY, Vector2(9, 30), "WMC", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
 draw_string(FONT, Vector2(9, 53), "RACE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("aaaaaa"))
 var bar := Rect2(9, 61, size.x - 18, 5)
 draw_rect(bar, Color("666666"))
 if finished:
  for x in range(0, int(bar.size.x), 6):
   draw_rect(Rect2(bar.position + Vector2(x, 0), Vector2(mini(3, int(bar.size.x) - x), 5)), Color.WHITE)
 else:
  draw_rect(Rect2(bar.position, Vector2(bar.size.x * lap_progress, bar.size.y)), Color("ed2c31"))
 if finished or lap >= total_laps:
  draw_string(INLINE, Vector2(9, 99), display_state(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 18, 22, Color.WHITE)
 else:
  draw_string(FONT, Vector2(9, 82), "LAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
  draw_string(FONT, Vector2(9, 108), display_state(), HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color.WHITE)
 var footer_y := HEAD_HEIGHT + rows.size() * ROW_HEIGHT
 draw_rect(Rect2(0, footer_y, size.x, 25), Color("080808"))
 draw_string(FONT, Vector2(9, footer_y + 18), hashtag, HORIZONTAL_ALIGNMENT_LEFT, size.x - 18, 13, Color.WHITE)

static func abbreviated_name(full_name: String) -> String:
 var parts := full_name.strip_edges().split(" ", false)
 if parts.size() < 2:
  return full_name.strip_edges().to_upper()
 return (parts[0].left(1) + " " + parts[parts.size() - 1]).to_upper()
