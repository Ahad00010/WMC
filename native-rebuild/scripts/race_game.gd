extends Node3D

## Native practice race with shared player/AI physics and a real race-world
## capture path. Online race rules and championship flow remain separate work.
var race_laps := 3
var speed_factor := 1
var fill_ai := false
var countdown := 0.0
var paused := false
const AI_NAMES := [
	"A. MARTIN", "L. BIANCHI", "K. SATO", "M. RAHMAN", "D. SILVA",
	"R. EVANS", "N. PETROV", "F. MORALES", "J. PARK",
]
const AI_COLOURS := [
	Color("3185fc"), Color("ef3f46"), Color("f1bd38"),
	Color("f17d32"), Color("40ad76"), Color("46b7ce"),
	Color("9362bf"),
	Color("d7589a"), Color("d6dde4"),
]

var circuit: WmcCircuit
var _current_circuit_id := "sepang"
var _world: Node3D
var _track_root: Node3D
var _riders_root: Node3D
var _camera: Camera3D
var _hud: WmcRaceHud
var _player: WmcRaceBike
var _riders: Array[WmcRaceBike] = []
var _brains: Dictionary = {}
var _footage: WmcFootageCapture
var _winner_frames: Array = []
var _winner_name := ""
var _winner_number := 10
const FINISH_CRUISE_SECONDS := 8.0
var _finish_delay := -1.0
var _summary_started := false
var _finish_screen: WmcFinishScreen
var _pause_menu: WmcPauseMenu
var _summary: WmcRaceSummary
var _profile_service: WmcProfileService
var _profile_editor: WmcProfileEditor
var _profile: Dictionary = {}
var _diagnostics: WmcDiagnostics
var _race_time_seconds := 0.0
var _simulation_time := 0.0
var _ambience: AudioStreamPlayer
var _engine_audio: AudioStreamPlayer
var _results_audio: AudioStreamPlayer
var _music_tweens: Dictionary = {}
var _engine_phase := 0.0
var _menu: WmcMainMenu
var _race_running := false


func _ready() -> void:
	_diagnostics = WmcDiagnostics.new()
	add_child(_diagnostics)
	_diagnostics.setup(self)
	_create_world()
	_create_camera()
	_create_interface()
	_create_ambience()
	_create_menu()
	_create_finish_screen()
	_create_summary()
	_create_pause_menu()
	_create_profile()
	# Newly-created UI children must complete _ready before their fields are used.
	call_deferred("_initialize_session")

func _initialize_session() -> void:
	_load_circuit(_current_circuit_id)
	_hud.visible = false


func _physics_process(delta: float) -> void:
	if not _race_running or not _player:
		return
	if countdown > 0.0:
		countdown = maxf(0.0, countdown - delta)
		_hud.lights.update_time(countdown)
		_hud.set_notice("" if countdown > 0.0 else "GO!")
		return
	var stable_delta := minf(delta, 1.0 / 30.0)
	# Practice speed multiplies simulation steps, not step size; this keeps
	# contact and barriers from being skipped at high multipliers.
	for step in speed_factor:
		_simulation_time += stable_delta
		if not _player.finished:
			_race_time_seconds += stable_delta
		_player.drive(_player_command(), stable_delta, Input.is_key_pressed(KEY_SPACE))
		for rider in _riders:
			if rider == _player:
				continue
			var brain: WmcAiRider = _brains.get(rider.rider_id)
			rider.drive(brain.command_for(rider, circuit), stable_delta)
		_resolve_rider_contacts()
		_finish_completed_riders()
	if _footage and _winner_name.is_empty():
		var leader := _riders[0]
		for rider in _riders:
			if rider.race_progress_samples > leader.race_progress_samples:
				leader = rider
		_footage.capture(delta, Time.get_ticks_msec() / 1000.0, leader, leader.heading)
	if _finish_delay >= 0.0:
		_finish_delay -= delta
		if not _summary_started and _finish_delay <= WmcRaceSummary.TOTAL_DURATION:
			_summary_started = true
			_summary.begin(circuit.display_name, circuit.hashtag)
			_summary.update_results(_riders)
			_fade_music(_results_audio, true)
		if _finish_delay < 0.0:
			_race_running = false
			_hud.visible = false
			_summary.close()
			_finish_screen.begin(_winner_frames, _winner_name, _winner_number)
	_update_camera(stable_delta)
	_update_hud()
	_summary.update_results(_riders)
	_summary.advance(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and paused and _menu.visible:
			_menu.visible = false
			_pause_menu.visible = true
			_hud.refresh_scale()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and (_race_running or paused):
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return
		if not _race_running:
			return
		if event.keycode == KEY_F7 and not OS.has_feature("mobile"):
			var label := UiScale.cycle()
			_hud.refresh_scale()
			_hud.set_notice("GUI SCALE %s" % label.to_upper())
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R and _player:
			_player.reset_to_grid()
			_hud.set_notice("RIDER RESET")
			get_viewport().set_input_as_handled()


func _create_world() -> void:
	_world = Node3D.new()
	_world.name = "RaceWorld"
	add_child(_world)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("77a9d0")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d8e7f3")
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	_world.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("fff2dc")
	sun.light_energy = 1.0
	sun.rotation_degrees = Vector3(-54.0, -28.0, 0.0)
	# Keep this conservative for broad Compatibility-renderer coverage. This is
	# a default performance choice, not a claim about a specific Intel driver.
	sun.shadow_enabled = false
	_world.add_child(sun)


func _create_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "FollowCamera"
	_camera.fov = 58.0
	add_child(_camera)
	_camera.make_current()


func _create_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "RaceInterface"
	add_child(canvas)
	_hud = WmcRaceHud.new()
	canvas.add_child(_hud)
	_hud.pause_requested.connect(_toggle_pause)


func _create_menu() -> void:
	_menu = WmcMainMenu.new()
	$RaceInterface.add_child(_menu)
	_menu.race_requested.connect(func(id: String, laps: int, speed: int, ai: bool):
		race_laps = laps
		speed_factor = speed
		fill_ai = ai
		_load_circuit(id)
		_menu.visible = false
		_hud.visible = true
		_race_running = true
		countdown = 3.0
		_hud.lights.update_time(countdown)
		_start_capture()
		_diagnostics.note("RACE START circuit=%s laps=%d speed=%d ai=%s" % [id, laps, speed, ai])
		_fade_music(_ambience, false)
	)
	_menu.audio_changed.connect(_update_audio)


func _create_profile() -> void:
	_profile_service = WmcProfileService.new()
	add_child(_profile_service)
	_profile_editor = WmcProfileEditor.new()
	$RaceInterface.add_child(_profile_editor)
	_menu.account_requested.connect(func():
		if _profile_service.token.is_empty():
			_profile_service.sign_in()
		else:
			_profile_editor.open(_profile)
	)
	_profile_service.status_changed.connect(func(text: String):
		_menu.account_status = text
		if _menu.visible and _menu._page == "home":
			_menu._show_page("home")
	)
	_profile_service.profile_error.connect(func(text: String):
		_menu.account_status = text
		if _profile_editor.visible:
			_profile_editor.set_status(text)
		elif _menu.visible:
			_menu._show_page("home")
	)
	_profile_service.profile_loaded.connect(func(data: Dictionary):
		_profile = data.duplicate()
		_menu.signed_in = true
		_menu.account_status = "@%s  ·  #%d" % [str(_profile.get("username", "rider")), int(_profile.get("rider_number", 0))]
		if _profile.is_empty():
			_profile_editor.open(_profile)
		else:
			_profile_editor.visible = false
			_menu._show_page("home")
	)
	_profile_editor.save_requested.connect(_profile_service.save_profile)
	_menu.sign_out_requested.connect(func():
		_profile.clear()
		_menu.signed_in = false
		_profile_service.sign_out()
	)

func _create_summary() -> void:
	_summary = WmcRaceSummary.new()
	$RaceInterface.add_child(_summary)
	_summary.main_menu_requested.connect(_leave_results)

func _create_pause_menu() -> void:
	_pause_menu = WmcPauseMenu.new()
	$RaceInterface.add_child(_pause_menu)
	_pause_menu.resume_requested.connect(_toggle_pause)
	_pause_menu.main_menu_requested.connect(_go_home)
	_pause_menu.settings_requested.connect(func():
		_pause_menu.visible = false
		_menu.visible = true
		_menu._settings_return = "pause"
		_menu._show_page("settings")
	)
	_menu.settings_closed.connect(func():
		_menu.visible = false
		_pause_menu.visible = true
		_hud.refresh_scale()
	)

func _leave_results() -> void:
	_finish_screen._menu.disabled = true
	_finish_screen._early_menu.disabled = true
	_summary._menu_button.disabled = true
	_fade_music(_results_audio, false)
	await get_tree().create_timer(0.5).timeout
	_finish_screen._menu.disabled = false
	_finish_screen._early_menu.disabled = false
	_summary._menu_button.disabled = false
	_go_home()

func _go_home() -> void:
	_fade_music(_ambience, true)
	_fade_music(_results_audio, false)
	_race_running = false
	paused = false
	_pause_menu.visible = false
	_finish_screen.close()
	_summary.close()
	_hud.touch_controls.clear()
	_hud.visible = false
	if _footage:
		_footage.queue_free()
		_footage = null
	_winner_frames.clear()
	_menu.visible = true
	_menu._show_page("home")

func _create_finish_screen() -> void:
	_finish_screen = WmcFinishScreen.new()
	$RaceInterface.add_child(_finish_screen)
	_finish_screen.main_menu_requested.connect(_leave_results)

func _start_capture() -> void:
	if _footage:
		_footage.queue_free()
	_footage = WmcFootageCapture.new()
	add_child(_footage)
	_footage.begin(_world.get_world_3d())
	_winner_frames.clear()
	_winner_name = ""
	_winner_number = 10
	_finish_delay = -1.0
	_summary_started = false


func _create_ambience() -> void:
	# No mixer is needed in source-only headless tests. Rendered tests and
	# exported builds exercise real audio setup.
	if DisplayServer.get_name() == "headless":
		return
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "MenuTheme"
	_ambience.stream = load("res://assets/audio/menu-theme.mp3") as AudioStream
	_ambience.volume_db = -22.0
	add_child(_ambience)
	_update_audio()
	if _ambience.stream:
		_ambience.play()
	_engine_audio = AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.12
	_engine_audio.stream = generator
	add_child(_engine_audio)
	_engine_audio.play()
	_results_audio = AudioStreamPlayer.new()
	_results_audio.stream = load("res://assets/audio/results-theme.mp3") as AudioStream
	_results_audio.volume_db = -80.0
	add_child(_results_audio)


func _process(_delta: float) -> void:
	if not _engine_audio or not _engine_audio.playing:
		return
	var playback := _engine_audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	var speed := absf(_player.speed_metres_per_second) if _player else 0.0
	var frequency := 48.0 + minf(150.0, speed * 2.4)
	var gain := 0.09 * UiScale.master * UiScale.engine if _race_running else 0.0
	for i in playback.get_frames_available():
		_engine_phase = fmod(_engine_phase + TAU * frequency / 22050.0, TAU)
		var sample := (sin(_engine_phase) * 0.65 + sin(_engine_phase * 2.0) * 0.25) * gain
		playback.push_frame(Vector2(sample, sample))

func _fade_music(player: AudioStreamPlayer, play_music: bool) -> void:
	if not player or not player.stream:
		return
	if _music_tweens.has(player) and _music_tweens[player].is_valid():
		_music_tweens[player].kill()
	if play_music and not player.playing:
		player.volume_db = -80.0
		player.play()
	var destination := linear_to_db(maxf(0.0001, UiScale.master * UiScale.music)) - 10.0 if play_music else -80.0
	var fade := create_tween()
	_music_tweens[player] = fade
	fade.tween_property(player, "volume_db", destination, 0.5)
	if not play_music:
		fade.tween_callback(player.stop)

func _update_audio() -> void:
	if _ambience:
		_ambience.volume_db = linear_to_db(maxf(0.0001, UiScale.master * UiScale.music)) - 10.0

func _toggle_pause() -> void:
	paused = not paused
	_race_running = not paused
	_pause_menu.visible = paused
	if paused:
		_pause_menu.modulate.a = 0.0
		var fade := create_tween()
		fade.tween_property(_pause_menu, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	else:
		_pause_menu.modulate.a = 1.0
	_hud.touch_controls.clear()
	if paused:
		_hud.set_notice("PAUSED  •  ESC TO RESUME")
	else:
		_hud.set_notice("RESUMED")

func _load_circuit(circuit_id: String) -> void:
	_current_circuit_id = circuit_id
	circuit = WmcCircuitData.create(circuit_id)
	_race_time_seconds = 0.0
	_simulation_time = 0.0
	if _track_root:
		_track_root.queue_free()
	if _riders_root:
		_riders_root.queue_free()
	_track_root = Node3D.new()
	_track_root.name = "Track_%s" % circuit.id
	_world.add_child(_track_root)
	_riders_root = Node3D.new()
	_riders_root.name = "Riders"
	_world.add_child(_riders_root)
	_build_track()
	_spawn_riders()
	_hud.touch_controls.clear()
	_hud.map.set_circuit(circuit)
	_hud.set_notice("PRACTICE RACE  •  %s  •  F1–F6 SWITCH CIRCUIT" % circuit.hashtag)
	_update_camera(1.0)


func _build_track() -> void:
	var bounds := _track_bounds()
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(maxf(1900.0, bounds.x + 320.0), maxf(1900.0, bounds.y + 320.0))
	ground.mesh = ground_mesh
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("426f38")
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	ground.position.y = -0.08
	_track_root.add_child(ground)

	_add_ribbon("Asphalt", 0, 0.015, Color("292d35"), false)
	_add_ribbon("LeftKerb", 1, 0.025, Color("d82430"), true)
	_add_ribbon("RightKerb", 2, 0.025, Color("d82430"), true)
	_add_ribbon("LeftRunoff", 3, 0.008, Color("b5a27b"), false)
	_add_ribbon("RightRunoff", 4, 0.008, Color("b5a27b"), false)
	_add_barriers()
	_add_scenery()
	_add_start_line()


func _track_bounds() -> Vector2:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for point in circuit.samples:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.z)
		max_z = maxf(max_z, point.z)
	return Vector2(max_x - min_x, max_z - min_z)


func _add_ribbon(label: String, band: int, height: float, base_colour: Color, striped: bool) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := circuit.size()
	for index in count:
		var next_index := circuit.wrap_index(index + 1)
		var offsets := _band_offsets(index, band)
		var next_offsets := _band_offsets(next_index, band)
		var first_colour := _ribbon_colour(index, base_colour, striped)
		var second_colour := _ribbon_colour(next_index, base_colour, striped)
		var a := circuit.samples[index] + circuit.lefts[index] * offsets.x + Vector3.UP * height
		var b := circuit.samples[index] + circuit.lefts[index] * offsets.y + Vector3.UP * height
		var c := circuit.samples[next_index] + circuit.lefts[next_index] * next_offsets.x + Vector3.UP * height
		var d := circuit.samples[next_index] + circuit.lefts[next_index] * next_offsets.y + Vector3.UP * height
		_add_coloured_triangle(surface, a, c, b, first_colour, second_colour, first_colour)
		_add_coloured_triangle(surface, b, c, d, first_colour, second_colour, second_colour)
	surface.generate_normals()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	mesh_instance.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = base_colour
	if band == 0:
		material.albedo_color = Color.WHITE
		material.albedo_texture = load("res://assets/asphalt.png")
		material.texture_repeat = true
	material.vertex_color_use_as_albedo = striped
	material.roughness = 0.92
	# Track strips must be visible from above on every renderer.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material
	_track_root.add_child(mesh_instance)


func _band_offsets(index: int, band: int) -> Vector2:
	var road := circuit.road_half_width(index)
	var kerb := circuit.kerb_edge(index)
	var wall := circuit.wall_edge(index)
	match band:
		1:
			return Vector2(road, kerb)
		2:
			return Vector2(-kerb, -road)
		3:
			return Vector2(kerb, wall)
		4:
			return Vector2(-wall, -kerb)
		_:
			return Vector2(-road, road)


func _ribbon_colour(index: int, base_colour: Color, striped: bool) -> Color:
	if not striped:
		return base_colour
	return base_colour if (index / 9) % 2 == 0 else Color("f2f3f5")


func _add_coloured_triangle(surface: SurfaceTool, first: Vector3, second: Vector3, third: Vector3, first_colour: Color, second_colour: Color, third_colour: Color) -> void:
	surface.set_color(first_colour)
	surface.set_uv(Vector2(first.x, first.z) / 12.0)
	surface.add_vertex(first)
	surface.set_color(second_colour)
	surface.set_uv(Vector2(second.x, second.z) / 12.0)
	surface.add_vertex(second)
	surface.set_color(third_colour)
	surface.set_uv(Vector2(third.x, third.z) / 12.0)
	surface.add_vertex(third)


func _add_barriers() -> void:
	var barrier_mesh := BoxMesh.new()
	barrier_mesh.size = Vector3(0.55, 1.05, 5.4)
	var barrier_material := StandardMaterial3D.new()
	barrier_material.albedo_color = Color("e2e6e9")
	barrier_material.roughness = 0.72
	var instance_count := circuit.size() * 2
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.instance_count = instance_count
	multi_mesh.mesh = barrier_mesh
	var instance_index := 0
	for index in circuit.size():
		for side in [-1.0, 1.0]:
			var transform := Transform3D(Basis(Vector3.UP, circuit.heading_at(index)), circuit.samples[index] + circuit.lefts[index] * side * circuit.wall_edge(index) + Vector3.UP * 0.53)
			multi_mesh.set_instance_transform(instance_index, transform)
			instance_index += 1
	var barriers := MultiMeshInstance3D.new()
	barriers.name = "SafetyBarriers"
	barriers.multimesh = multi_mesh
	barriers.material_override = barrier_material
	_track_root.add_child(barriers)


func _add_scenery() -> void:
	# Shared low-cost instancing: scenery is outside barriers, not on the road.
	var tree_mesh := CylinderMesh.new()
	tree_mesh.top_radius = 0.1
	tree_mesh.bottom_radius = 3.2
	tree_mesh.height = 9.0
	tree_mesh.radial_segments = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("305532")
	material.roughness = 1.0
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = tree_mesh
	instances.instance_count = ceili(float(circuit.size()) / 22.0) * 2
	var n := 0
	for index in range(0, circuit.size(), 22):
		for side in [-1.0, 1.0]:
			var offset := circuit.wall_edge(index) + 22.0 + float(index % 4) * 4.0
			var tree_pos: Vector3 = circuit.samples[index] + circuit.lefts[index] * side * offset + Vector3.UP * 4.5
			instances.set_instance_transform(n, Transform3D(Basis.IDENTITY, tree_pos))
			n += 1
	var trees := MultiMeshInstance3D.new()
	trees.name = "Trees"
	trees.multimesh = instances
	trees.material_override = material
	_track_root.add_child(trees)


func _add_start_line() -> void:
	var line := MeshInstance3D.new()
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(circuit.road_half_width(0) * 2.0 + 5.0, 0.03, 0.55)
	line.mesh = line_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f7f7f4")
	line.material_override = material
	line.position = circuit.samples[0] + Vector3.UP * 0.05
	line.rotation.y = circuit.heading_at(0)
	_track_root.add_child(line)


func _spawn_riders() -> void:
	_riders.clear()
	_brains.clear()
	_player = WmcRaceBike.new()
	_player.name = "Player"
	_riders_root.add_child(_player)
	_player.configure(circuit, 1, "player", str(_profile.get("display_name", "YOU")), true, Color(str(_profile.get("plate_color", "red"))))
	_player.set_number(int(_profile.get("rider_number", 10)))
	_riders.append(_player)
	for index in (AI_NAMES.size() if fill_ai else 0):
		var rider := WmcRaceBike.new()
		rider.name = "AiRider%02d" % (index + 1)
		_riders_root.add_child(rider)
		rider.configure(circuit, index + 2, "ai-%02d" % (index + 1), AI_NAMES[index], false, AI_COLOURS[index])
		rider.set_number(index + 11)
		_riders.append(rider)
		_brains[rider.rider_id] = WmcAiRider.new(20261114 + index * 31)


func _player_command() -> Vector3:
	var keyboard_throttle := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	var keyboard_brake := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	var keyboard_left := Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var keyboard_right := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	var touch_command := _hud.touch_controls.command()
	return Vector3(
		maxf(1.0 if keyboard_throttle else 0.0, touch_command.x),
		maxf(1.0 if keyboard_brake else 0.0, touch_command.y),
		clampf(float(int(keyboard_right) - int(keyboard_left)) + touch_command.z, -1.0, 1.0)
	)


func _resolve_rider_contacts() -> void:
	for first_index in _riders.size():
		for second_index in range(first_index + 1, _riders.size()):
			var first := _riders[first_index]
			var second := _riders[second_index]
			var separation := second.global_position - first.global_position
			separation.y = 0.0
			var distance := separation.length()
			if distance >= 2.05:
				continue
			var direction := separation.normalized() if distance > 0.01 else circuit.lefts[first.track_index]
			var impulse := direction * (2.05 - distance) * 7.0
			first.apply_contact_push(-impulse)
			second.apply_contact_push(impulse)


func _finish_completed_riders() -> void:
	for rider in _riders:
		if not rider.finished and rider.laps_completed >= race_laps:
			rider.finished = true
			rider.finish_time_seconds = _simulation_time
			if _winner_name.is_empty():
				_diagnostics.note("RACE WINNER elapsed=%.2f" % _simulation_time)
				_winner_name = rider.display_name
				_winner_number = rider.racing_number
				if _footage:
					_winner_frames = _footage.finish()
			if rider == _player:
				_hud.set_notice("FINISH")
				_summary_started = false
				_finish_delay = FINISH_CRUISE_SECONDS + WmcRaceSummary.TOTAL_DURATION


func _update_camera(delta: float) -> void:
	if not _player:
		return
	var forward := Vector3(sin(_player.heading), 0.0, cos(_player.heading))
	var desired_position := _player.global_position - forward * 6.2 + Vector3.UP * 2.8
	_camera.global_position = _camera.global_position.lerp(desired_position, minf(1.0, delta * 5.0))
	_camera.look_at(_player.global_position + forward * 7.0 + Vector3.UP * 0.8, Vector3.UP)


func _update_hud() -> void:
	if not _player or not _hud:
		return
	var ordered := _riders.duplicate()
	ordered.sort_custom(func(first: WmcRaceBike, second: WmcRaceBike) -> bool:
		if first.finished != second.finished:
			return first.finished
		if first.finished:
			return first.finish_time_seconds < second.finish_time_seconds
		return first.race_progress_samples > second.race_progress_samples
	)
	var race_position := ordered.find(_player) + 1
	var shown_lap := mini(race_laps, _player.laps_completed + 1)
	_hud.set_race_state(circuit, shown_lap, race_laps, _player.speed_metres_per_second, race_position, _riders.size(), _race_time_seconds)
	_hud.tower.update_order(_riders, shown_lap, race_laps)
	_hud.map.update_riders(_riders)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _hud and _hud.touch_controls:
		_hud.touch_controls.clear()

func _exit_tree() -> void:
	if _ambience:
		_ambience.stop()
	if _results_audio:
		_results_audio.stop()
	if _engine_audio:
		_engine_audio.stop()
