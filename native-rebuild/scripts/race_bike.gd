class_name WmcRaceBike
extends Node3D

## Kinematic motorcycle model used by both the human player and AI riders.
## It is deliberately shared so AI receives no movement or speed advantage.
const MAX_SPEED := 82.0 # metres per second, roughly 295 km/h
const GRID_DISTANCE_SAMPLES := 13

var rider_id := ""
var display_name := ""
var racing_number := 10
var plate_color := Color.RED
var is_player := false
var circuit: WmcCircuit
var speed_metres_per_second := 0.0
var heading := 0.0
var steer_amount := 0.0
var lean_amount := 0.0
var pitch_amount := 0.0
var lateral_offset := 0.0
var track_index := 0
var race_progress_samples := 0.0
var laps_completed := 0
var finished := false
var finish_time_seconds := -1.0
var _push_velocity := Vector3.ZERO
var _impact_cooldown := 0.0
var _grid_position := 1
var _visual_pivot: Node3D
var _number_label: Label3D


func configure(
		track: WmcCircuit,
		grid_position: int,
		id_value: String,
		name_value: String,
		player_controlled: bool,
		accent: Color
	) -> void:
	circuit = track
	rider_id = id_value
	display_name = name_value
	is_player = player_controlled
	plate_color = accent
	_place_on_grid(grid_position)
	_build_visual(accent)


func drive(command: Vector3, delta: float, hard_brake := false) -> void:
	if circuit == null or delta <= 0.0:
		return
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	var previous_index := track_index
	_update_nearest_track_point()
	var throttle := clampf(command.x, 0.0, 1.0)
	var brake := clampf(command.y, 0.0, 1.0)
	var target_steer := clampf(command.z, -1.0, 1.0)
	var off_road := absf(lateral_offset) > circuit.kerb_edge(track_index)
	var grip := 0.5 if off_road else (0.92 if absf(lateral_offset) > circuit.road_half_width(track_index) else 1.0)
	var maximum_speed := MAX_SPEED * (0.38 if off_road else 1.0)

	var acceleration := 0.0
	if throttle > 0.0:
		acceleration += 18.0 * (1.0 - pow(maxf(speed_metres_per_second, 0.0) / maximum_speed, 1.55)) * throttle
	if hard_brake:
		acceleration = -45.0 * grip * signf(speed_metres_per_second)
	elif brake > 0.0:
		acceleration -= (39.0 * grip if speed_metres_per_second > 0.4 else 9.0) * brake
	if throttle <= 0.0 and brake <= 0.0:
		acceleration -= (1.35 + 0.00075 * speed_metres_per_second * speed_metres_per_second) * signf(speed_metres_per_second)
	if speed_metres_per_second > maximum_speed:
		acceleration -= minf(42.0, (speed_metres_per_second - maximum_speed) * 3.0 + 8.0)
	acceleration -= 2.2 * absf(steer_amount) * (absf(speed_metres_per_second) / MAX_SPEED) * signf(speed_metres_per_second)

	var old_speed := speed_metres_per_second
	speed_metres_per_second = maxf(-9.0, speed_metres_per_second + acceleration * delta)
	if (hard_brake or (throttle == 0.0 and brake == 0.0)) and old_speed * speed_metres_per_second < 0.0:
		speed_metres_per_second = 0.0
	steer_amount = move_toward(steer_amount, target_steer, delta * (6.0 if absf(target_steer) > 0.01 else 10.0))
	var speed_abs := absf(speed_metres_per_second)
	var yaw_speed := steer_amount * minf(1.9, 18.0 * grip / maxf(speed_abs, 0.01)) * minf(1.0, speed_abs / 4.0)
	heading += yaw_speed * delta * (-0.7 if speed_metres_per_second < 0.0 else 1.0)
	var forward := Vector3(sin(heading), 0.0, cos(heading))
	global_position += (forward * speed_metres_per_second + _push_velocity) * delta
	_push_velocity = _push_velocity.lerp(Vector3.ZERO, minf(1.0, 3.2 * delta))

	_update_nearest_track_point()
	_apply_track_limits(delta)
	_update_progress(previous_index)
	_update_visual(delta, throttle, brake)


func apply_contact_push(push: Vector3) -> void:
	_push_velocity += Vector3(push.x, 0.0, push.z)


func reset_to_grid() -> void:
	if circuit:
		_place_on_grid(_grid_position)


func _place_on_grid(grid_position: int) -> void:
	_grid_position = grid_position
	var row := (grid_position - 1) / 2
	var side := 1.0 if grid_position % 2 == 1 else -1.0
	track_index = circuit.wrap_index(circuit.size() - GRID_DISTANCE_SAMPLES - row * 4)
	global_position = circuit.samples[track_index] + circuit.lefts[track_index] * side * 2.0
	heading = circuit.heading_at(track_index)
	rotation.y = heading
	speed_metres_per_second = 0.0
	steer_amount = 0.0
	lean_amount = 0.0
	pitch_amount = 0.0
	lateral_offset = side * 2.0
	_push_velocity = Vector3.ZERO
	_impact_cooldown = 0.0
	# A rider begins just before the timing line. Passing it after a complete
	# lap increments race progress; this avoids treating the grid as a lap.
	race_progress_samples = float(track_index - circuit.size())
	laps_completed = 0
	finished = false
	finish_time_seconds = -1.0


func _update_nearest_track_point() -> void:
	track_index = circuit.nearest_index(global_position, track_index)
	var centre := circuit.samples[track_index]
	lateral_offset = (global_position - centre).dot(circuit.lefts[track_index])


func _apply_track_limits(delta: float) -> void:
	var wall := circuit.wall_edge(track_index)
	if absf(lateral_offset) <= wall:
		return
	var side := 1.0 if lateral_offset > 0.0 else -1.0
	var overlap := absf(lateral_offset) - wall
	global_position -= circuit.lefts[track_index] * side * overlap
	speed_metres_per_second *= 0.62
	if _impact_cooldown <= 0.0:
		heading = lerp_angle(heading, circuit.heading_at(track_index), minf(1.0, delta * 2.6))
		_impact_cooldown = 0.5
	_update_nearest_track_point()


func _update_progress(previous_index: int) -> void:
	var index_delta := track_index - previous_index
	var count := circuit.size()
	if index_delta > count / 2:
		index_delta -= count
	elif index_delta < -count / 2:
		index_delta += count
	# Reverse motion can reduce current progress but cannot undo a completed lap.
	race_progress_samples += float(index_delta)
	var complete_laps := maxi(0, floori(race_progress_samples / float(count)))
	laps_completed = maxi(laps_completed, complete_laps)


func _build_visual(accent: Color) -> void:
	for child in get_children():
		child.queue_free()
	_visual_pivot = Node3D.new()
	_visual_pivot.name = "VisualPivot"
	add_child(_visual_pivot)

	var bike_resource := load("res://assets/models/bike-mobile-low.glb") as PackedScene
	if bike_resource:
		var bike_model := bike_resource.instantiate()
		bike_model.name = "DucatiBike"
		_visual_pivot.add_child(bike_model)
	else:
		_add_fallback_bike(accent)

	var rider_resource := load("res://assets/models/marc-rider.glb") as PackedScene
	if rider_resource:
		var rider_model := rider_resource.instantiate()
		rider_model.name = "Rider"
		rider_model.position.y = 0.724
		_visual_pivot.add_child(rider_model)

	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.48, 0.10, 0.18)
	plate.mesh = plate_mesh
	var plate_material := StandardMaterial3D.new()
	plate_material.albedo_color = accent
	plate_material.metallic = 0.15
	plate.material_override = plate_material
	plate.position = Vector3(0.0, 1.0, -0.45)
	_visual_pivot.add_child(plate)
	_number_label = Label3D.new()
	_number_label.text = "10"
	_number_label.font = load("res://assets/fonts/MGPText-Bold.ttf")
	_number_label.font_size = 36
	_number_label.pixel_size = 0.003
	_number_label.position = Vector3(0.0, 1.065, -0.45)
	_number_label.rotation.x = -PI * 0.5
	_visual_pivot.add_child(_number_label)

func set_number(number: int) -> void:
	racing_number = clampi(number, 10, 99)
	if _number_label:
		_number_label.text = str(racing_number)


func _add_fallback_bike(accent: Color) -> void:
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.62, 0.42, 1.7)
	body.mesh = body_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = accent
	material.metallic = 0.4
	body.material_override = material
	body.position.y = 0.62
	_visual_pivot.add_child(body)
	for z in [-0.62, 0.62]:
		var wheel := MeshInstance3D.new()
		var wheel_mesh := CylinderMesh.new()
		wheel_mesh.top_radius = 0.30
		wheel_mesh.bottom_radius = 0.30
		wheel_mesh.height = 0.12
		wheel.mesh = wheel_mesh
		wheel.rotation.z = PI * 0.5
		wheel.position = Vector3(0.0, 0.31, z)
		_visual_pivot.add_child(wheel)


func _update_visual(delta: float, throttle: float, brake: float) -> void:
	rotation.y = heading
	var speed_factor := minf(1.0, absf(speed_metres_per_second) / 25.0)
	var target_lean := -steer_amount * 0.92 * speed_factor
	lean_amount = lerpf(lean_amount, target_lean, minf(1.0, delta * 6.5))
	var target_pitch := -0.15 * throttle * maxf(0.0, 1.0 - speed_metres_per_second / 30.0)
	if brake > 0.0 and speed_metres_per_second > 25.0:
		target_pitch = 0.06
	pitch_amount = lerpf(pitch_amount, target_pitch, minf(1.0, delta * 5.0))
	if _visual_pivot:
		_visual_pivot.rotation = Vector3(pitch_amount, 0.0, lean_amount)
