class_name WmcAiRider
extends RefCounted

## Steering controller for practice riders. It sends only the same throttle,
## brake and steer values accepted by WmcRaceBike; it never moves a bike itself.
var pace_multiplier := 1.0
var aggression := 1.0

func _init(seed: int) -> void:
	var seeded_rng := RandomNumberGenerator.new()
	seeded_rng.seed = seed
	pace_multiplier = seeded_rng.randf_range(0.91, 1.04)
	aggression = seeded_rng.randf_range(0.92, 1.08)


func command_for(bike: WmcRaceBike, circuit: WmcCircuit) -> Vector3:
	var lookahead := clampf(9.0 + absf(bike.speed_metres_per_second) * 0.34, 9.0, 34.0)
	var target_index := circuit.sample_ahead(bike.track_index, lookahead)
	var target := circuit.samples[target_index]
	var to_target := target - bike.global_position
	var desired_heading := atan2(to_target.x, to_target.z)
	var angle_error := _wrap_angle(desired_heading - bike.heading)

	var curve_radians := 0.0
	for metres in range(12, 70, 8):
		var from_heading := circuit.heading_at(circuit.sample_ahead(bike.track_index, float(metres)))
		var to_heading := circuit.heading_at(circuit.sample_ahead(bike.track_index, float(metres + 8)))
		curve_radians = maxf(curve_radians, absf(_wrap_angle(to_heading - from_heading)))
	var target_speed := clampf(75.0 / (1.0 + curve_radians * 7.5), 17.0, 69.0) * pace_multiplier
	if absf(bike.lateral_offset) > circuit.road_half_width(bike.track_index):
		target_speed *= 0.72

	var throttle := 1.0 if bike.speed_metres_per_second < target_speed - 0.8 else 0.0
	var brake := 1.0 if bike.speed_metres_per_second > target_speed + 2.0 * aggression else 0.0
	var steer := clampf(angle_error * 2.25, -1.0, 1.0)
	return Vector3(throttle, brake, steer)


func _wrap_angle(angle: float) -> float:
	return atan2(sin(angle), cos(angle))
