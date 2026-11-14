class_name WmcRaceSummary
extends Control

# Practice never records championship points. The separate standings page is
# explicit about that instead of inventing a championship leader.
const TEXT = preload("res://assets/fonts/MGPText-Bold.ttf")
const DISPLAY = preload("res://assets/fonts/MGPDisplay-Bold.otf")
const INLINE = preload("res://assets/fonts/MGPInline-Regular.otf")
const RIDER = preload("res://assets/models/marc-rider.glb")
const TISSOT = preload("res://assets/graphics/tissot-reference.png")
const FIM = preload("res://assets/graphics/fim-reference.png")
const RESULTS_DURATION := 10.0
const CHAMPIONSHIP_DURATION := 5.0
const TOTAL_DURATION := RESULTS_DURATION + CHAMPIONSHIP_DURATION
const POINTS := [25, 20, 16, 13, 11, 10, 9, 8, 7, 6]
const REFERENCE := Vector2(1280, 720)

var _rider_view: SubViewport
var _rider_figure: Node3D
var _elapsed := 0.0
var _rows: Array[Dictionary] = []
var _signature := ""
var _circuit_name := ""
var _circuit_tag := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_make_rider_scene()
	resized.connect(queue_redraw)

func _make_rider_scene() -> void:
	_rider_view = SubViewport.new()
	_rider_view.size = Vector2i(500, 813)
	_rider_view.transparent_bg = true
	_rider_view.own_world_3d = true
	_rider_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_rider_view)
	var world := Node3D.new()
	_rider_view.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 0.60, 3.45)
	camera.fov = 33.0
	camera.look_at(Vector3(0, 0.49, 0), Vector3.UP)
	camera.current = true
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 1.2
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0, 0, 0, 0)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.8
	environment.environment = settings
	world.add_child(environment)
	_rider_figure = Node3D.new()
	world.add_child(_rider_figure)
	var model: Node3D = RIDER.instantiate()
	_rider_figure.add_child(model)
	_stand_rider(model)
	# Keep the original results rider's model pose and final framing together.
	model.position.y = 0.12
	model.rotation.x = -0.72

# This model is unrigged: deform private mesh copies once, not the race models.
func _stand_rider(node: Node) -> void:
	if node is MeshInstance3D and (node.name == "Pilot_M_Pilot_0" or node.name == "Pilot_Decals_M_Pilot_Decals_0"):
		var original: Mesh = node.mesh
		if original:
			var posed := ArrayMesh.new()
			var c := cos(0.72)
			var s := sin(0.72)
			for surface in range(original.get_surface_count()):
				var arrays := original.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for i in vertices.size():
					var v := vertices[i]
					var up := v.y * c + v.z * s
					var depth := -v.y * s + v.z * c
					var weight := clampf((0.14 - up) / 0.48, 0.0, 1.0)
					weight = weight * weight * (3.0 - 2.0 * weight)
					up -= 0.28 * weight
					v.x *= 1.0 - 0.20 * weight
					depth += (-0.15 - depth) * 0.55 * weight
					v.y = up * c - depth * s
					v.z = up * s + depth * c
					vertices[i] = v
				arrays[Mesh.ARRAY_VERTEX] = vertices
				posed.add_surface_from_arrays(original.surface_get_primitive_type(surface), arrays)
				posed.surface_set_material(surface, original.surface_get_material(surface))
			node.mesh = posed
	for child in node.get_children():
		_stand_rider(child)

func begin(circuit_name: String = "", tag: String = "") -> void:
	_circuit_name = circuit_name
	_circuit_tag = tag
	_elapsed = 0.0
	_rows.clear()
	_signature = ""
	visible = true
	_rider_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	queue_redraw()

func close() -> void:
	visible = false
	if _rider_view:
		_rider_view.render_target_update_mode = SubViewport.UPDATE_DISABLED

func advance(delta: float) -> void:
	if not visible:
		return
	_elapsed += maxf(0.0, delta)
	var showing_rider := _elapsed < RESULTS_DURATION
	_rider_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if showing_rider else SubViewport.UPDATE_DISABLED
	if showing_rider:
		_rider_figure.rotation.y = 0.08 * sin(_elapsed * 0.45)
		_rider_figure.rotation.z = 0.015 * sin(_elapsed * 0.8)
		_rider_figure.position.y = 0.008 * sin(_elapsed * 1.3)
	# Redraw each simulation tick; a time threshold can accidentally halve FPS.
	queue_redraw()

func update_results(riders: Array[WmcRaceBike]) -> void:
	if not visible:
		return
	var ordered := riders.duplicate()
	ordered.sort_custom(func(a: WmcRaceBike, b: WmcRaceBike) -> bool:
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.finish_time_seconds < b.finish_time_seconds
		return a.race_progress_samples > b.race_progress_samples
	)
	var rows: Array[Dictionary] = []
	for rider: WmcRaceBike in ordered:
		rows.append({"name": rider.display_name, "finished": rider.finished, "time": rider.finish_time_seconds, "number": rider.racing_number, "color": rider.plate_color})
	var signature := str(rows)
	if signature != _signature:
		_signature = signature
		_rows = rows
		queue_redraw()

func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var factor := minf(size.x / REFERENCE.x, size.y / REFERENCE.y)
	var intro := 1.0 - pow(1.0 - clampf(_elapsed / 0.55, 0.0, 1.0), 3.0)
	var origin := (size - REFERENCE * factor) * 0.5 + Vector2(0, 36.0 * (1.0 - intro) * factor)
	draw_set_transform(origin, 0.0, Vector2.ONE * factor)
	for y in [35, 105, 220, 370, 500, 615]:
		draw_rect(Rect2(0, y, 1280, 2), Color(0.85, 0.08, 0.12, 0.25))
	var championship := _elapsed >= RESULTS_DURATION
	if not championship:
		var intro := clampf(_elapsed / 0.65, 0.0, 1.0)
		draw_texture_rect(_rider_view.get_texture(), Rect2(0, 35 + 55 * (1.0 - intro), 345, 660), false, Color(1, 1, 1, intro))
		_draw_results()
	else:
		_draw_championship()
	# Crossfade through dark at the page boundary without moving the rider
	# independently of the reference stage.
	var boundary := absf(_elapsed - RESULTS_DURATION)
	if boundary < 0.35:
		draw_rect(Rect2(Vector2.ZERO, REFERENCE), Color(0.02, 0.015, 0.025, 1.0 - boundary / 0.35))
	draw_set_transform(Vector2.ZERO)
	var opening := clampf(_elapsed / 0.55, 0.0, 1.0)
	if opening < 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 1.0 - opening))

func _draw_header(title: String, intro: float) -> void:
	var x := 350.0 + 70.0 * (1.0 - intro)
	draw_string(DISPLAY, Vector2(x, 67), "WMC", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color.WHITE)
	draw_string(TEXT, Vector2(x + 145, 65), _circuit_tag, HORIZONTAL_ALIGNMENT_LEFT, 250, 18, Color.WHITE)
	draw_string(TEXT, Vector2(x, 97), _circuit_name, HORIZONTAL_ALIGNMENT_LEFT, 880, 17, Color.WHITE)
	draw_string(DISPLAY, Vector2(x, 155), title, HORIZONTAL_ALIGNMENT_LEFT, 890, 48 if title == "WORLD CHAMPIONSHIP" else 52, Color.WHITE)

func _draw_results() -> void:
	var intro := 1.0 - pow(1.0 - clampf(_elapsed / 0.65, 0.0, 1.0), 3.0)
	_draw_header("GRAND PRIX RESULTS", intro)
	draw_string(TEXT, Vector2(350, 182), "Points are not recorded for this practice race", HORIZONTAL_ALIGNMENT_LEFT, 850, 13, Color("d3d3d8"))
	for i in mini(_rows.size(), 10):
		var row: Dictionary = _rows[i]
		var row_intro := clampf((_elapsed - 0.3 - i * 0.035) / 0.3, 0.0, 1.0)
		if row_intro <= 0.0:
			continue
		var x := 350.0 + 70.0 * (1.0 - row_intro)
		var y := 195.0 + i * 42.0
		draw_rect(Rect2(x, y, 880, 36), Color(0.015, 0.015, 0.02, 0.94))
		draw_string(TEXT, Vector2(x + 12, y + 26), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 45, 20, Color.WHITE)
		var plate: Color = row.color
		draw_rect(Rect2(x + 60, y + 5, 56, 27), plate)
		var ink := Color.BLACK if plate.get_luminance() > 0.55 else Color.WHITE
		draw_string(TEXT, Vector2(x + 60, y + 25), str(int(row.number)), HORIZONTAL_ALIGNMENT_CENTER, 56, 18, ink)
		draw_string(TEXT, Vector2(x + 135, y + 25), str(row.name).to_upper().substr(0, 22), HORIZONTAL_ALIGNMENT_LEFT, 330, 18, Color.WHITE)
		var result := _format_time(float(row.time)) if row.finished else "ON TRACK"
		draw_string(TEXT, Vector2(x + 590, y + 25), result, HORIZONTAL_ALIGNMENT_RIGHT, 145, 16, Color.WHITE)
		draw_string(DISPLAY, Vector2(x + 770, y + 23), "WMC", HORIZONTAL_ALIGNMENT_LEFT, 85, 12, Color.WHITE)
	var winner_intro := 1.0 - pow(1.0 - clampf((_elapsed - 1.2) / 0.48, 0.0, 1.0), 3.0)
	if winner_intro > 0.0:
		draw_set_transform((size - REFERENCE * minf(size.x / REFERENCE.x, size.y / REFERENCE.y)) * 0.5 + Vector2(85, 620 - 75 * (1.0 - winner_intro)) * minf(size.x / REFERENCE.x, size.y / REFERENCE.y), -PI / 2, Vector2.ONE * minf(size.x / REFERENCE.x, size.y / REFERENCE.y))
		draw_string(INLINE, Vector2.ZERO, "WINNER", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color(1, 1, 1, winner_intro))
		var factor := minf(size.x / REFERENCE.x, size.y / REFERENCE.y)
		draw_set_transform((size - REFERENCE * factor) * 0.5, 0.0, Vector2.ONE * factor)
	_draw_footer()

func _draw_championship() -> void:
	var intro := clampf((_elapsed - RESULTS_DURATION) / 0.7, 0.0, 1.0)
	_draw_header("WORLD CHAMPIONSHIP", intro)
	draw_rect(Rect2(350, 185, 880, 76), Color(0.015, 0.015, 0.02, 0.94))
	draw_string(TEXT, Vector2(370, 217), "Practice races do not award championship points.", HORIZONTAL_ALIGNMENT_LEFT, 830, 18, Color.WHITE)
	draw_string(TEXT, Vector2(370, 244), "Standings are recorded for authoritative online races.", HORIZONTAL_ALIGNMENT_LEFT, 830, 15, Color("c6cad1"))
	_draw_footer()

func _draw_footer() -> void:
	draw_texture_rect(TISSOT, Rect2(350, 672, 125, 25), false)
	draw_texture_rect(FIM, Rect2(1080, 670, 60, 27), false)
	draw_string(DISPLAY, Vector2(1162, 692), "WMC", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("bbbbbb"))

func _format_time(seconds: float) -> String:
	var milliseconds := maxi(0, roundi(seconds * 1000.0))
	return "%d:%02d.%03d" % [milliseconds / 60000, (milliseconds / 1000) % 60, milliseconds % 1000]
