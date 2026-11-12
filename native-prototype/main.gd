extends Node3D

# A native rendering/controls benchmark, not a port of the multiplayer rules.
const BIKE = preload("res://assets/bike-mobile.glb")
const RIDER = preload("res://assets/marc-rider.glb")
const DISPLAY_FONT = preload("res://assets/MGPDisplay-Medium.otf")
const TEXT_FONT = preload("res://assets/MGPText-Bold.ttf")
const ASPHALT = preload("res://assets/asphalt.png")
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
 var throttle: bool = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or touch.accelerate
 var braking: bool = Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or touch.brake
 var left: bool = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or touch.left
 var right: bool = Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or touch.right
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
 # Driving advances only a few metres per physics tick. Search locally so the
 # denser, better-looking road does not add a full-lap scan on every frame.
 var best := INF
 var closest := nearest
 for offset in range(-40, 41):
  var i := posmod(nearest + offset, track.size())
  var dist := bike.position.distance_squared_to(track[i])
  if dist < best:
   best = dist
   closest = i
 nearest = closest
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
 status = _label(controls, "Press START / RESTART to drive | replay view is a rendering test only", 17, Vector2(26, 64))
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
