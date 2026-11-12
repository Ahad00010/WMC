extends Node3D

# A native rendering/controls benchmark, not a port of the multiplayer rules.
const BIKE = preload("res://assets/bike-mobile.glb")
const RIDER = preload("res://assets/marc-rider.glb")
const DISPLAY_FONT = preload("res://assets/MGPDisplay-Medium.otf")
const TEXT_FONT = preload("res://assets/MGPText-Bold.ttf")
const ROAD_WIDTH := 9.0
const REPLAY_FPS := 24.0
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
var nearest := 0
var elapsed := 0.0
var active := false
var mobile := false
var touch := {"accelerate": false, "brake": false, "left": false, "right": false}
var hud: Label
var status: Label
var results: Control
var controls: Control

func _ready() -> void:
 mobile = OS.has_feature("mobile")
 _read_track()
 _make_world()
 _make_ui()
 _reset()

func _read_track() -> void:
 var points = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sepang.json"))
 for point in points:
  track.append(Vector3(float(point[0]), 0.0, float(point[1])))

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
 var vertices := PackedVector3Array()
 var normals := PackedVector3Array()
 for i in range(track.size()):
  var a := track[i]
  var b := track[(i + 1) % track.size()]
  var previous := track[(i - 1 + track.size()) % track.size()]
  var following := track[(i + 2) % track.size()]
  var side_a := Vector3(-(b - previous).z, 0, (b - previous).x).normalized() * ROAD_WIDTH
  var side_b := Vector3(-(following - a).z, 0, (following - a).x).normalized() * ROAD_WIDTH
  for vertex in [a - side_a, b - side_b, b + side_b, a - side_a, b + side_b, a + side_a]:
   vertices.append(vertex)
   normals.append(Vector3.UP)
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_NORMAL] = normals
 var road_mesh := ArrayMesh.new()
 road_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
 var road := MeshInstance3D.new()
 road.mesh = road_mesh
 road.material_override = _material(Color("33373c"))
 add_child(road)
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

func _reset() -> void:
 nearest = 0
 bike.position = track[0] + Vector3.UP * 0.05
 var direction := (track[1] - track[0]).normalized()
 heading = atan2(direction.x, direction.z)
 speed = 0.0
 steer = 0.0
 elapsed = 0.0
 active = false
 replay_enabled = false
 replay_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
 for key in touch:
  touch[key] = false

func _physics_process(dt: float) -> void:
 if not active:
  return
 elapsed += dt
 var throttle := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or touch.accelerate
 var braking := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or touch.brake
 var left := Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or touch.left
 var right := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or touch.right
 var turn := float(int(left) - int(right))
 steer = move_toward(steer, turn, dt * 3.5)
 if throttle:
  speed = minf(speed + 9.0 * dt, 75.0)
 elif braking:
  speed = maxf(speed - 22.0 * dt, 0.0)
 else:
  speed = maxf(speed - 1.8 * dt, 0.0)
 heading += steer * dt * clampf(speed / 35.0, 0.0, 1.0) * 0.8
 var forward := Vector3(sin(heading), 0, cos(heading))
 bike.position += forward * speed * dt
 bike.rotation.y = heading
 visual.rotation.z = lerpf(visual.rotation.z, -steer * clampf(speed / 50.0, 0.0, 1.0) * 0.35, minf(1, dt * 6))
 # Search the entire short point list; geometry remains native, not a WebView.
 var best := INF
 for i in range(track.size()):
  var dist := bike.position.distance_squared_to(track[i])
  if dist < best:
   best = dist
   nearest = i
 # Approximate the distance to the nearest road segment.
 var prev := track[(nearest - 1 + track.size()) % track.size()]
 var current := track[nearest]
 var next := track[(nearest + 1) % track.size()]
 var distance := minf(bike.position.distance_to(Geometry3D.get_closest_point_to_segment(bike.position, prev, current)), bike.position.distance_to(Geometry3D.get_closest_point_to_segment(bike.position, current, next)))
 if distance > ROAD_WIDTH + 2.0:
  speed = maxf(0, speed - 14.0 * dt)
 camera.position = bike.position - forward * 7.0 + Vector3.UP * 3.0
 camera.look_at(bike.position + forward * 7.0 + Vector3.UP, Vector3.UP)

func _process(dt: float) -> void:
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
 button.add_theme_font_override("font", TEXT_FONT)
 button.add_theme_font_size_override("font_size", 22)
 parent.add_child(button)
 return button

func _make_ui() -> void:
 var layer := CanvasLayer.new()
 add_child(layer)
 controls = Control.new()
 controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 layer.add_child(controls)
 hud = _label(controls, "", 24, Vector2(26, 24))
 status = _label(controls, "", 17, Vector2(26, 64))
 var start := _button(controls, "START / RESTART", Vector2(25, 110), Vector2(220, 52))
 start.pressed.connect(func():
  _reset()
  active = true
  results.visible = false
  status.text = "Native benchmark: replay view OFF | 24 fps target | no video recording"
 )
 var benchmark := _button(controls, "REPLAY VIEW: OFF", Vector2(25, 174), Vector2(220, 52))
 benchmark.pressed.connect(func():
  replay_enabled = not replay_enabled
  replay_clock = 0.0
  replay_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
  benchmark.text = "REPLAY VIEW: ON" if replay_enabled else "REPLAY VIEW: OFF"
  status.text = "Native benchmark: replay view %s | 24 fps target | no video recording" % ("ON" if replay_enabled else "OFF")
 )
 var finish := _button(controls, "RESULTS PREVIEW", Vector2(25, 238), Vector2(220, 52))
 finish.pressed.connect(_show_results)
 if mobile:
  for item in [["◀", "left", Vector2(35, 575)], ["▶", "right", Vector2(145, 575)], ["BRAKE", "brake", Vector2(930, 575)], ["GAS", "accelerate", Vector2(1090, 575)]]:
   var key: String = item[1]
   var button := _button(controls, item[0], item[2], Vector2(125, 100))
   button.button_down.connect(func(): touch[key] = true)
   button.button_up.connect(func(): touch[key] = false)
 else:
  _label(controls, "W / ↑ GAS    S / ↓ BRAKE    A D / ← → STEER", 18, Vector2(26, 680))
 results = ColorRect.new()
 results.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 results.color = Color("11101b")
 results.visible = false
 layer.add_child(results)
 var title := _label(results, "GRAND PRIX RESULTS", 65, Vector2(410, 120))
 title.add_theme_font_override("font", DISPLAY_FONT)
 _label(results, "WMC    #MalaysianGP", 25, Vector2(410, 55))
 _label(results, "1     93    NATIVE PROTOTYPE     +25     WMC93", 25, Vector2(410, 260))
 _label(results, "RESULTS UI PREVIEW — NOT A RECORDED RACE", 18, Vector2(410, 320))
 var result_rider := _label(results, "WINNER", 64, Vector2(65, 300))
 result_rider.add_theme_font_override("font", DISPLAY_FONT)
 var back := _button(results, "BACK TO TRACK", Vector2(410, 400), Vector2(260, 55))
 back.pressed.connect(func(): results.visible = false; active = true)

func _show_results() -> void:
 active = false
 replay_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
 results.visible = true
