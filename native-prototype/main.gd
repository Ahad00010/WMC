extends Node3D

# A native rendering/controls benchmark, not a port of the multiplayer rules.
const BIKE = preload("res://assets/bike-mobile.glb")
const RIDER = preload("res://assets/marc-rider.glb")
const DISPLAY_FONT = preload("res://assets/MGPDisplay-Medium.otf")
const TEXT_FONT = preload("res://assets/MGPText-Bold.ttf")
const AUTH_SCRIPT = preload("res://auth.gd")
const MENU_MUSIC = preload("res://assets/menu-music.mp3")
const ASPHALT = preload("res://assets/asphalt.png")
const ROAD_WIDTH := 9.0
const REPLAY_FPS := 24.0
const MAX_SPEED := 88.0
const ENGINE_RATE := 22050.0
var track: Array[Vector3] = []
var bike: Node3D
var visual: Node3D
var camera: Camera3D
var replay_view: SubViewport
var replay_camera: Camera3D
var replay_enabled := false
var replay_clock := 0.0
var speed := 0.0
var heading := 0.0
var steer := 0.0
var impact_cooldown := 0.0
var nearest := 0
var elapsed := 0.0
var active := false
var mobile := false
var touch := {"accelerate": false, "brake": false, "left": false, "right": false}
var hud: Label
var controls: Control
var pause_panel: Control
var paused := false
var engine_player: AudioStreamPlayer
var engine_playback: AudioStreamGeneratorPlayback
var engine_phase := 0.0
var engine_sub_phase := 0.0
var engine_filtered := 0.0
var engine_rpm := 0.18
var engine_gain := 0.0
var menu: Control
var music: AudioStreamPlayer
var music_muted := false
var music_target := 0.0
var auth_status: Label
var auth_button: Button
var sign_out_button: Button
var auth: Node
var profile: Dictionary = {}
var profile_panel: Control
var profile_error: Label
var profile_name: LineEdit
var profile_username: LineEdit
var profile_number: SpinBox
var profile_color: OptionButton
var profile_save: Button

func _ready() -> void:
 mobile = OS.has_feature("mobile")
 _read_track()
 _make_world()
 _make_ui()
 _reset()
 _make_audio()
 _make_auth()

func _read_track() -> void:
 var points = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sepang.json"))
 # Subdivide the original centreline so kerb markings and barriers remain
 # evenly spaced on long straights as well as around bends.
 for i in range(points.size()):
  var point: Array = points[i]
  var next: Array = points[(i + 1) % points.size()]
  var a := Vector3(float(point[0]), 0.0, float(point[1]))
  var b := Vector3(float(next[0]), 0.0, float(next[1]))
  var count := maxi(1, ceili(a.distance_to(b) / 5.0))
  for j in range(count):
   track.append(a.lerp(b, float(j) / float(count)))

func _material(color: Color) -> StandardMaterial3D:
 var mat := StandardMaterial3D.new()
 mat.albedo_color = color
 mat.roughness = 0.95
 mat.cull_mode = BaseMaterial3D.CULL_DISABLED
 return mat

func _make_world() -> void:
 var environment := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color("91b3d1")
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("dce8ff")
 env.ambient_light_energy = 0.8
 environment.environment = env
 add_child(environment)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-55, -30, 0)
 sun.light_energy = 1.1
 add_child(sun)
 var ground := MeshInstance3D.new()
 var ground_mesh := PlaneMesh.new()
 ground_mesh.size = Vector2(4000, 4000)
 ground.mesh = ground_mesh
 ground.position.y = -0.1
 ground.material_override = _material(Color("4b7542"))
 add_child(ground)
 _make_track_surfaces()
 _make_barriers()
 _make_start_finish()
 _make_trees()
 bike = Node3D.new()
 add_child(bike)
 visual = Node3D.new()
 bike.add_child(visual)
 visual.add_child(BIKE.instantiate())
 var rider := RIDER.instantiate()
 rider.position.y = 0.72374
 visual.add_child(rider)
 camera = Camera3D.new()
 add_child(camera)
 camera.current = true
 camera.fov = 58
 camera.far = 2200
 # The extra viewport renders the live scene at replay resolution. It is a GPU
 # load experiment, NOT a recorder or reconstructed replay.
 replay_view = SubViewport.new()
 replay_view.size = Vector2i(854, 480) if mobile else Vector2i(1920, 1080)
 replay_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
 replay_view.world_3d = get_viewport().world_3d
 add_child(replay_view)
 replay_camera = Camera3D.new()
 replay_camera.fov = 48
 replay_camera.far = 2200
 replay_view.add_child(replay_camera)
 replay_camera.current = true


func _textured_material() -> StandardMaterial3D:
 var mat := _material(Color.WHITE)
 var image := ASPHALT.get_image()
 image.generate_mipmaps()
 mat.albedo_texture = ImageTexture.create_from_image(image)
 mat.texture_repeat = true
 mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 return mat

# Continuous road and shoulders follow the same centreline as the driving logic.
# They are grouped into a handful of meshes, not thousands of individual objects.
func _ribbon(inner: float, outer: float, height: float, kind: String) -> void:
 var vertices := PackedVector3Array()
 var normals := PackedVector3Array()
 var uvs := PackedVector2Array()
 var colors := PackedColorArray()
 var distance := 0.0
 for i in range(track.size()):
  var a := track[i]
  var b := track[(i + 1) % track.size()]
  var previous := track[(i - 1 + track.size()) % track.size()]
  var following := track[(i + 2) % track.size()]
  var side_a := Vector3(-(b - previous).z, 0, (b - previous).x).normalized()
  var side_b := Vector3(-(following - a).z, 0, (following - a).x).normalized()
  var length := a.distance_to(b)
  var aa := a + side_a * inner + Vector3.UP * height
  var ab := a + side_a * outer + Vector3.UP * height
  var ba := b + side_b * inner + Vector3.UP * height
  var bb := b + side_b * outer + Vector3.UP * height
  var tile := 12.0
  var ua := inner / tile
  var ub := outer / tile
  var va := distance / tile
  var vb := (distance + length) / tile
  var tint := Color.WHITE
  if kind == "kerb":
   tint = Color("d62730") if int(distance / 6.0) % 2 == 0 else Color("f1f0e8")
  for entry in [[aa,Vector2(ua,va)], [ba,Vector2(ua,vb)], [bb,Vector2(ub,vb)], [aa,Vector2(ua,va)], [bb,Vector2(ub,vb)], [ab,Vector2(ub,va)]]:
   vertices.append(entry[0])
   uvs.append(entry[1])
   normals.append(Vector3.UP)
   colors.append(tint)
  distance += length
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_NORMAL] = normals
 arrays[Mesh.ARRAY_TEX_UV] = uvs
 arrays[Mesh.ARRAY_COLOR] = colors
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
 var surface := MeshInstance3D.new()
 surface.name = "Track_" + kind
 surface.mesh = mesh
 if kind == "asphalt":
  surface.material_override = _textured_material()
 elif kind == "kerb":
  var material := _material(Color.WHITE)
  material.vertex_color_use_as_albedo = true
  surface.material_override = material
 else:
  surface.material_override = _material(Color("ad9b75"))
 add_child(surface)

func _make_track_surfaces() -> void:
 _ribbon(-ROAD_WIDTH, ROAD_WIDTH, 0.01, "asphalt")
 _ribbon(ROAD_WIDTH, ROAD_WIDTH + 2.0, 0.025, "kerb")
 _ribbon(-ROAD_WIDTH - 2.0, -ROAD_WIDTH, 0.025, "kerb")
 _ribbon(ROAD_WIDTH + 2.0, ROAD_WIDTH + 9.0, 0.0, "gravel")
 _ribbon(-ROAD_WIDTH - 9.0, -ROAD_WIDTH - 2.0, 0.0, "gravel")

func _make_barriers() -> void:
 var box := BoxMesh.new()
 box.size = Vector3(0.7, 1.05, 5.2)
 box.material = _material(Color.WHITE)
 var instances := MultiMesh.new()
 instances.transform_format = MultiMesh.TRANSFORM_3D
 instances.use_colors = true
 instances.mesh = box
 instances.instance_count = track.size() * 2
 var count := 0
 for i in range(track.size()):
  var a := track[i]
  var b := track[(i + 1) % track.size()]
  var forward := (b - a).normalized()
  var side := Vector3(-forward.z, 0, forward.x)
  var basis := Basis(Vector3.UP, atan2(forward.x, forward.z)).scaled(Vector3(1, 1, a.distance_to(b) / 5.0))
  for direction in [-1, 1]:
   instances.set_instance_transform(count, Transform3D(basis, (a + b) * 0.5 + side * direction * (ROAD_WIDTH + 9.4) + Vector3.UP * 0.525))
   instances.set_instance_color(count, Color("e53639") if int(i / 3) % 2 == 0 else Color("f3f2ec"))
   count += 1
 # Multimesh vertex colors tint its white material.
 box.material.vertex_color_use_as_albedo = true
 var barriers := MultiMeshInstance3D.new()
 barriers.name = "Track_Barriers"
 barriers.multimesh = instances
 add_child(barriers)

func _box(parent: Node3D, size: Vector3, position: Vector3, material: Material) -> void:
 var box := BoxMesh.new()
 box.size = size
 var node := MeshInstance3D.new()
 node.mesh = box
 node.material_override = material
 node.position = position
 parent.add_child(node)

func _make_start_finish() -> void:
 var group := Node3D.new()
 group.position = track[0]
 var forward := (track[1] - track[0]).normalized()
 group.rotation.y = atan2(forward.x, forward.z)
 add_child(group)
 var dark := _material(Color("20242c"))
 var red := _material(Color("dc2733"))
 var white := _material(Color("f5f5f0"))
 for side in [-1, 1]:
  _box(group, Vector3(0.8, 8.0, 0.8), Vector3(side * 15.0, 4, 0), dark)
  # Lightweight grandstands alongside the start straight.
  for tier in range(4):
   var height := 1.3 * (tier + 1)
   _box(group, Vector3(4, height, 80), Vector3(side * (25.0 + tier * 4.0), height * 0.5, 30), _material(Color("4a4d55")))
  _box(group, Vector3(18, 0.6, 80), Vector3(side * 31.0, 9, 30), red)
 _box(group, Vector3(31, 2.3, 0.7), Vector3(0, 8, 0), dark)
 var sign := Label3D.new()
 sign.text = "WMC     START  /  FINISH"
 sign.font_size = 80
 sign.pixel_size = 0.01
 sign.position = Vector3(0, 8, -0.4)
 sign.rotation.y = PI
 sign.modulate = Color.WHITE
 group.add_child(sign)
 # Actual chequered line on the track.
 for x in range(18):
  for z in range(2):
   _box(group, Vector3(1.0, 0.02, 0.8), Vector3(-8.5 + x, 0.05, -1.0 + z * 0.8), white if (x + z) % 2 == 0 else dark)

func _make_trees() -> void:
 var rng := RandomNumberGenerator.new()
 rng.seed = 9310
 var trunk := CylinderMesh.new()
 trunk.top_radius = 0.3
 trunk.bottom_radius = 0.45
 trunk.height = 3
 trunk.material = _material(Color("5a4030"))
 var crown := CylinderMesh.new()
 crown.top_radius = 0
 crown.bottom_radius = 3.3
 crown.height = 9
 crown.radial_segments = 7
 crown.material = _material(Color("285d2c"))
 var trunks := MultiMesh.new()
 var crowns := MultiMesh.new()
 for multi in [trunks, crowns]:
  multi.transform_format = MultiMesh.TRANSFORM_3D
  multi.instance_count = 150 if mobile else 220
 trunks.mesh = trunk
 crowns.mesh = crown
 var placed := 0
 var attempts := 0
 while placed < trunks.instance_count and attempts < 5000:
  attempts += 1
  var x := rng.randf_range(-1300, 1300)
  var z := rng.randf_range(-1300, 1300)
  var point := Vector3(x, 0, z)
  var clear := point.distance_to(track[0]) > 110
  for i in range(0, track.size(), 10):
   if point.distance_squared_to(track[i]) < 70.0 * 70.0:
    clear = false
    break
  if not clear:
   continue
  var scale := rng.randf_range(0.85, 1.35)
  var basis := Basis.IDENTITY.scaled(Vector3.ONE * scale)
  trunks.set_instance_transform(placed, Transform3D(basis, point + Vector3.UP * 1.5 * scale))
  crowns.set_instance_transform(placed, Transform3D(basis, point + Vector3.UP * 7.5 * scale))
  placed += 1
 trunks.visible_instance_count = placed
 crowns.visible_instance_count = placed
 for multi in [trunks, crowns]:
  var node := MultiMeshInstance3D.new()
  node.name = "Track_Trees"
  node.multimesh = multi
  add_child(node)

func _reset() -> void:
 nearest = 0
 bike.position = track[0] + Vector3.UP * 0.05
 var direction := (track[1] - track[0]).normalized()
 heading = atan2(direction.x, direction.z)
 camera.position = bike.position - direction * 7.0 + Vector3.UP * 3.0
 camera.look_at(bike.position + direction * 7.0 + Vector3.UP, Vector3.UP)
 speed = 0.0
 steer = 0.0
 impact_cooldown = 0.0
 elapsed = 0.0
 active = false
 paused = false
 replay_enabled = false
 replay_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
 for key in touch:
  touch[key] = false

# Project onto nearby road segments, rather than measuring to sparse point
# samples. This keeps surface classification stable through corners.
func _track_projection() -> Dictionary:
 var best := INF
 var closest := nearest
 var best_point := Vector3.ZERO
 var best_side := Vector3.RIGHT
 for offset in range(-40, 41):
  var i := posmod(nearest + offset, track.size())
  var a := track[i]
  var b := track[(i + 1) % track.size()]
  var point := Geometry3D.get_closest_point_to_segment(bike.position, a, b)
  var d := bike.position.distance_squared_to(point)
  if d < best:
   best = d
   closest = i
   best_point = point
   var tangent := (b - a).normalized()
   best_side = Vector3(-tangent.z, 0, tangent.x)
 nearest = closest
 return {"point": best_point, "side": best_side, "lat": (bike.position - best_point).dot(best_side)}

func _physics_process(dt: float) -> void:
 if not active:
  return
 elapsed += dt
 var throttle: bool = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or touch.accelerate
 var hard_brake: bool = Input.is_key_pressed(KEY_SPACE)
 var braking: bool = Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or touch.brake
 var left: bool = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or touch.left
 var right: bool = Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or touch.right
 var surface := _track_projection()
 var offset: float = absf(surface.lat)
 var grip := 0.5 if offset > ROAD_WIDTH + 2.0 else (0.92 if offset > ROAD_WIDTH else 1.0)
 var max_speed := MAX_SPEED * 0.36 if offset > ROAD_WIDTH + 2.0 else MAX_SPEED
 var acceleration := 0.0
 if throttle:
  acceleration = 17.0 * (1.0 - pow(maxf(speed, 0.0) / max_speed, 1.6))
  if speed < 0:
   acceleration = 22.0
 if braking or hard_brake:
  if hard_brake:
   acceleration = -40.0 * grip if speed > 0 else (40.0 * grip if speed < 0 else 0.0)
  elif speed > 0.4:
   acceleration = -30.0 * grip
  elif not throttle:
   acceleration = -9.0 if speed > -9.0 else 0.0
 if not throttle and not braking and not hard_brake:
  acceleration = -(1.3 + 0.0007 * speed * speed) * signf(speed)
 if speed > max_speed:
  acceleration -= minf(40.0, (speed - max_speed) * 3.0 + 8.0)
 acceleration -= 2.2 * absf(steer) * (absf(speed) / MAX_SPEED) * signf(speed)
 var old_speed := speed
 speed += acceleration * dt
 if (hard_brake or (not throttle and not braking)) and old_speed * speed <= 0:
  speed = 0.0
 var target := float(int(left) - int(right))
 var response := 5.5 if target != 0.0 else (16.0 if braking or hard_brake else 9.0)
 steer = lerpf(steer, target, minf(1.0, dt * response))
 var absolute_speed := absf(speed)
 # The old prototype turned at a fixed rate even at high speed, throwing the
 # bike straight into gravel in normal corners. Match the website's speed/grip curve.
 var yaw := steer * minf(1.9, 18.0 * grip / maxf(absolute_speed, 0.01)) * minf(1.0, absolute_speed / 4.0) * (1.0 if speed >= 0 else -0.7)
 heading += yaw * dt
 var forward := Vector3(sin(heading), 0, cos(heading))
 bike.position += forward * speed * dt
 surface = _track_projection()
 var lateral: float = surface.lat
 var wall := ROAD_WIDTH + 9.0
 if absf(lateral) > wall:
  var side: Vector3 = surface.side
  bike.position -= side * (lateral - signf(lateral) * wall)
  if impact_cooldown <= 0.0:
   speed *= 0.6
   impact_cooldown = 0.5
  speed -= speed * minf(1.0, 2.2 * dt)
 impact_cooldown = maxf(0.0, impact_cooldown - dt)
 bike.rotation.y = heading
 visual.rotation.z = lerpf(visual.rotation.z, -steer * clampf(absolute_speed / 24.0, 0.0, 1.0) * 1.05, minf(1, dt * 6.5))
 camera.position = bike.position - forward * 7.0 + Vector3.UP * 3.0
 camera.look_at(bike.position + forward * 7.0 + Vector3.UP, Vector3.UP)
 camera.rotate_object_local(Vector3.BACK, -visual.rotation.z * 0.07)

func _process(dt: float) -> void:
 if music:
  var volume := db_to_linear(music.volume_db)
  volume = move_toward(volume, 0.0 if music_muted else music_target, dt * 0.55 / 0.85)
  music.volume_db = linear_to_db(maxf(volume, 0.0001))
  if music_target == 0.0 and volume <= 0.0001 and music.playing:
   music.stop()
 _update_engine(dt)
 if active and replay_enabled:
  replay_clock += dt
  if replay_clock >= 1.0 / REPLAY_FPS:
   replay_clock = fmod(replay_clock, 1.0 / REPLAY_FPS)
   var forward := Vector3(sin(heading), 0, cos(heading))
   replay_camera.position = bike.position + forward.rotated(Vector3.UP, 1.5) * 6.0 + Vector3.UP * 2.0
   replay_camera.look_at(bike.position + Vector3.UP, Vector3.UP)
   replay_view.render_target_update_mode = SubViewport.UPDATE_ONCE
 if active:
  hud.text = "%d KM/H    |    %02d:%02d    |    %d FPS" % [roundi(speed * 3.6), int(elapsed) / 60, int(elapsed) % 60, Engine.get_frames_per_second()]

func _label(parent: Control, text: String, size: int, pos: Vector2) -> Label:
 var label := Label.new()
 label.text = text
 label.position = pos
 label.add_theme_font_override("font", TEXT_FONT)
 label.add_theme_font_size_override("font_size", size)
 label.add_theme_color_override("font_color", Color.WHITE)
 parent.add_child(label)
 return label

func _button(parent: Control, text: String, pos: Vector2, size: Vector2) -> Button:
 var button := Button.new()
 button.text = text
 button.position = pos
 button.size = size
 button.focus_mode = Control.FOCUS_NONE
 button.add_theme_font_override("font", TEXT_FONT)
 button.add_theme_font_size_override("font_size", 22)
 parent.add_child(button)
 return button

func _make_ui() -> void:
 var layer := CanvasLayer.new()
 add_child(layer)
 controls = Control.new()
 layer.add_child(controls)
 controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 controls.visible = false
 hud = _label(controls, "", 24, Vector2(26, 24))
 if mobile:
  var pause_button := _button(controls, "Ⅱ", Vector2(1185, 20), Vector2(65, 55))
  pause_button.pressed.connect(_pause_game)
  for item in [["◀", "left", Vector2(35, 575)], ["▶", "right", Vector2(175, 575)], ["BRAKE", "brake", Vector2(930, 575)], ["GAS", "accelerate", Vector2(1090, 575)]]:
   var key: String = item[1]
   var button := _button(controls, item[0], item[2], Vector2(125, 100))
   button.button_down.connect(func(): touch[key] = true)
   button.button_up.connect(func(): touch[key] = false)
 else:
  _label(controls, "W / ↑ GAS    S / ↓ BRAKE    A D / ← → STEER    ESC PAUSE", 18, Vector2(26, 680))
 _make_pause_menu(layer)
 _make_menu(layer)
 _make_profile_editor(layer)

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
  if active:
   _pause_game()
  elif paused:
   _resume_game()
  else:
   return
  get_viewport().set_input_as_handled()

func _clear_touch() -> void:
 for key in touch:
  touch[key] = false

func _make_pause_menu(layer: CanvasLayer) -> void:
 pause_panel = Control.new()
 layer.add_child(pause_panel)
 pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 pause_panel.visible = false
 var shade := ColorRect.new()
 shade.color = Color(0.02, 0.03, 0.05, 0.82)
 pause_panel.add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var title := _label(pause_panel, "PAUSED", 58, Vector2(500, 200))
 title.add_theme_font_override("font", DISPLAY_FONT)
 var resume := _button(pause_panel, "RESUME", Vector2(500, 320), Vector2(280, 55))
 resume.pressed.connect(_resume_game)
 var home := _button(pause_panel, "MAIN MENU", Vector2(500, 390), Vector2(280, 55))
 home.pressed.connect(_return_to_menu)

func _pause_game() -> void:
 if not active:
  return
 active = false
 paused = true
 _clear_touch()
 replay_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
 pause_panel.visible = true

func _resume_game() -> void:
 if not paused:
  return
 paused = false
 pause_panel.visible = false
 _clear_touch()
 active = true

func _return_to_menu() -> void:
 _reset()
 pause_panel.visible = false
 controls.visible = false
 menu.modulate.a = 1.0
 menu.mouse_filter = Control.MOUSE_FILTER_STOP
 menu.visible = true
 music_target = 0.55
 if not music.playing:
  music.volume_db = -80.0
  music.play()


func _make_audio() -> void:
 music = AudioStreamPlayer.new()
 var soundtrack = MENU_MUSIC.duplicate()
 soundtrack.loop = true
 music.stream = soundtrack
 music.volume_db = -80.0
 add_child(music)
 engine_player = AudioStreamPlayer.new()
 var generator := AudioStreamGenerator.new()
 generator.mix_rate = ENGINE_RATE
 generator.buffer_length = 0.12
 engine_player.stream = generator
 add_child(engine_player)
 engine_player.play()
 engine_playback = engine_player.get_stream_playback() as AudioStreamGeneratorPlayback
 music_target = 0.55
 music.play()

func _make_auth() -> void:
 auth = AUTH_SCRIPT.new()
 add_child(auth)
 auth.status_changed.connect(func(message: String): auth_status.text = message)
 auth.profile_loaded.connect(func(data: Dictionary):
  profile = data.duplicate()
  auth_button.text = "Edit profile"
  sign_out_button.visible = true
  profile_save.disabled = false
  if profile.is_empty():
   auth_status.text = "Complete your rider profile"
   _open_profile_editor()
  else:
   auth_status.text = "@%s  ·  #%s  ·  %s" % [profile.get("username", "rider"), profile.get("rider_number", "—"), profile.get("plate_color", "")]
   profile_panel.visible = false
 )
 auth.profile_error.connect(func(message: String):
  profile_save.disabled = false
  profile_error.text = message
 )

func _make_menu(layer: CanvasLayer) -> void:
 menu = Control.new()
 layer.add_child(menu)
 menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade := ColorRect.new()
 shade.color = Color(0.03, 0.04, 0.06, 0.72)
 menu.add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var card := Control.new()
 card.position = Vector2(460, 100)
 card.size = Vector2(480, 560)
 menu.add_child(card)
 var eyebrow := _label(card, "TIME ATTACK · PETRONAS SEPANG INTERNATIONAL CIRCUIT", 11, Vector2(0, 0))
 eyebrow.add_theme_color_override("font_color", Color("ec2939"))
 var brand := _label(card, "WMC", 86, Vector2(0, 28))
 brand.add_theme_font_override("font", DISPLAY_FONT)
 _label(card, "World Motorbike Championship", 18, Vector2(0, 126))
 var description := _label(card, "Stay on the asphalt, brake before the corners,
and keep out of the gravel.", 15, Vector2(0, 170))
 description.add_theme_color_override("font_color", Color("c5cad1"))
 if mobile:
  _label(card, "Use the on-screen controls to ride.", 15, Vector2(0, 255))
 else:
  _label(card, "W   Throttle              S   Brake / reverse", 14, Vector2(0, 246))
  _label(card, "A  D   Lean left / right     Space   Hard brake", 14, Vector2(0, 275))
 # Sign-in uses the system browser and retrieves this account's own profile.
 var sound := _button(card, "Sound: on", Vector2(0, 326), Vector2(108, 38))
 sound.add_theme_font_size_override("font_size", 13)
 sound.pressed.connect(func():
  music_muted = not music_muted
  sound.text = "Sound: off" if music_muted else "Sound: on"
 )
 auth_button = _button(card, "Sign in with Google", Vector2(116, 326), Vector2(180, 38))
 auth_button.add_theme_font_size_override("font_size", 13)
 auth_button.pressed.connect(func():
  if auth.access_token.is_empty():
   auth.sign_in()
  else:
   _open_profile_editor()
 )
 sign_out_button = _button(card, "Sign out", Vector2(304, 326), Vector2(90, 38))
 sign_out_button.add_theme_font_size_override("font_size", 13)
 sign_out_button.visible = false
 sign_out_button.pressed.connect(func():
  auth.sign_out()
  auth_button.text = "Sign in with Google"
  profile.clear()
  profile_panel.visible = false
  sign_out_button.visible = false
 )
 auth_status = _label(card, "", 12, Vector2(0, 369))
 var play := _button(card, "PLAY", Vector2(0, 400), Vector2(125, 55))
 play.add_theme_font_override("font", DISPLAY_FONT)
 play.add_theme_font_size_override("font_size", 25)
 var red := StyleBoxFlat.new()
 red.bg_color = Color("e4202c")
 play.add_theme_stylebox_override("normal", red)
 var hover := red.duplicate()
 hover.bg_color = Color("ff3442")
 play.add_theme_stylebox_override("hover", hover)
 play.add_theme_stylebox_override("pressed", hover)
 play.pressed.connect(_start_from_menu)
 var credit := _label(card, "Bike: Ducati Lenovo Team - MotoGP26 by Kenny3D89 · CC BY 4.0
Native prototype · practice only", 11, Vector2(0, 477))
 credit.add_theme_color_override("font_color", Color("9da3aa"))

func _start_from_menu() -> void:
 if not menu.visible:
  return
 menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
 music_target = 0.0
 var tween := create_tween()
 tween.tween_property(menu, "modulate:a", 0.0, 0.45)
 tween.tween_callback(func():
  menu.visible = false
  _reset()
  controls.visible = true
  active = true
 )

# Synthesize the same sawtooth + half-frequency square blend used on the website.
# It follows the simulated RPM and is silent in menus and while paused.
func _update_engine(dt: float) -> void:
 if engine_playback == null:
  return
 var throttle: bool = active and (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or touch.accelerate)
 var gear := mini(6, 1 + floori(absf(speed) / 14.6))
 var fraction := minf(1.0, (absf(speed) - (gear - 1) * 14.6) / 14.6)
 var target_rpm := 0.18 if absf(speed) < 0.5 and not throttle else 0.3 + 0.7 * fraction
 engine_rpm = lerpf(engine_rpm, target_rpm, minf(1.0, dt * 10.0))
 var desired_gain := (0.03 + 0.05 * float(throttle) + 0.02 * engine_rpm) if active and not music_muted else 0.0
 engine_gain = lerpf(engine_gain, desired_gain, minf(1.0, dt * 16.0))
 var frequency := 48.0 + engine_rpm * 190.0
 var cutoff := 500.0 + engine_rpm * 1400.0 + float(throttle) * 500.0
 var filter := 1.0 - exp(-TAU * cutoff / ENGINE_RATE)
 var count := mini(engine_playback.get_frames_available(), 4096)
 for i in range(count):
  engine_phase = fposmod(engine_phase + frequency / ENGINE_RATE, 1.0)
  engine_sub_phase = fposmod(engine_sub_phase + frequency * 0.5 / ENGINE_RATE, 1.0)
  var saw := 2.0 * engine_phase - 1.0
  var square := 1.0 if engine_sub_phase < 0.5 else -1.0
  engine_filtered += filter * ((saw + square) * 0.5 - engine_filtered)
  var sample := engine_filtered * engine_gain
  engine_playback.push_frame(Vector2(sample, sample))


func _make_profile_editor(layer: CanvasLayer) -> void:
 profile_panel = Control.new()
 layer.add_child(profile_panel)
 profile_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 profile_panel.visible = false
 var backdrop := ColorRect.new()
 backdrop.color = Color(0.01, 0.02, 0.03, 0.93)
 profile_panel.add_child(backdrop)
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var card := Control.new()
 card.position = Vector2(390, 45)
 card.size = Vector2(500, 630)
 profile_panel.add_child(card)
 var title := _label(card, "RIDER PROFILE", 38, Vector2(0, 0))
 title.add_theme_font_override("font", DISPLAY_FONT)
 _label(card, "DISPLAY NAME", 16, Vector2(0, 70))
 profile_name = LineEdit.new()
 profile_name.position = Vector2(0, 96)
 profile_name.size = Vector2(490, 44)
 profile_name.max_length = 15
 profile_name.placeholder_text = "First and last name"
 card.add_child(profile_name)
 _label(card, "UNIQUE USERNAME", 16, Vector2(0, 154))
 profile_username = LineEdit.new()
 profile_username.position = Vector2(0, 180)
 profile_username.size = Vector2(490, 44)
 profile_username.max_length = 20
 profile_username.placeholder_text = "letters, numbers and underscores"
 card.add_child(profile_username)
 _label(card, "RACING NUMBER", 16, Vector2(0, 238))
 profile_number = SpinBox.new()
 profile_number.position = Vector2(0, 264)
 profile_number.size = Vector2(180, 44)
 profile_number.min_value = 10
 profile_number.max_value = 99
 profile_number.step = 1
 card.add_child(profile_number)
 _label(card, "NUMBER PLATE COLOR", 16, Vector2(0, 322))
 profile_color = OptionButton.new()
 profile_color.position = Vector2(0, 348)
 profile_color.size = Vector2(250, 44)
 for color in ["blue", "red", "yellow", "orange", "green", "cyan", "purple", "pink", "white", "black", "silver"]:
  profile_color.add_item(color.capitalize())
  profile_color.set_item_metadata(profile_color.item_count - 1, color)
 card.add_child(profile_color)
 profile_error = _label(card, "", 15, Vector2(0, 410))
 profile_error.add_theme_color_override("font_color", Color("ff7a7a"))
 profile_save = _button(card, "SAVE", Vector2(0, 470), Vector2(190, 52))
 profile_save.pressed.connect(func():
  profile_error.text = "Saving…"
  profile_save.disabled = true
  auth.save_profile(profile_name.text, profile_username.text, int(profile_number.value), str(profile_color.get_selected_metadata()))
 )
 var cancel := _button(card, "CANCEL", Vector2(205, 470), Vector2(190, 52))
 cancel.pressed.connect(func(): profile_panel.visible = false)

func _open_profile_editor() -> void:
 profile_error.text = ""
 profile_save.disabled = false
 profile_name.text = str(profile.get("display_name", ""))
 profile_username.text = str(profile.get("username", ""))
 profile_number.value = int(profile.get("rider_number", 10))
 var color := str(profile.get("plate_color", "blue"))
 for i in range(profile_color.item_count):
  if profile_color.get_item_metadata(i) == color:
   profile_color.select(i)
   break
 profile_panel.visible = true
