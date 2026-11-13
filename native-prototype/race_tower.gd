extends Control

const ROW = preload("res://race_tower_row.gd")
const FONT = preload("res://assets/MGPText-Bold.ttf")
const DISPLAY = preload("res://assets/MGPDisplay-Medium.otf")
var rows := {}
var targets := {}
var lap := 1
var total_laps := 3
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
 queue_redraw()

func update_standings(entries: Array, current_lap: int, laps: int) -> void:
 lap = current_lap
 total_laps = laps
 for i in range(entries.size()):
  var entry: Dictionary = entries[i]
  var id: String = entry.id
  if not rows.has(id):
   var row = ROW.new()
   row.size = Vector2(200, 30)
   row.position = Vector2(0, 74 + i * 31)
   add_child(row)
   rows[id] = row
  var row: Control = rows[id]
  row.rank = i + 1
  row.label = str(entry.name).substr(0, 11)
  row.number = str(entry.number)
  row.is_player = entry.is_player
  row.queue_redraw()
  var target := 74.0 + i * 31.0
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

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.04, 0.05, 0.88))
 draw_rect(Rect2(0, 0, size.x, 4), Color("e4202c"))
 draw_string(DISPLAY, Vector2(10, 33), "WMC", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color.WHITE)
 draw_string(FONT, Vector2(10, 59), "RACE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
 draw_string(FONT, Vector2(84, 59), "LAP %d/%d" % [lap, total_laps], HORIZONTAL_ALIGNMENT_RIGHT, 105, 14, Color.WHITE)
