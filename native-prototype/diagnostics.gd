extends RefCounted
# Breadcrumbs are flushed to disk so an abrupt exit leaves recent state.
# Engine/script errors are logged separately by Godot's file logger.
var file: FileAccess
var path := ""
var clock := 0.0

func start() -> void:
 if OS.has_feature("windows") and not OS.has_feature("editor"):
  path = OS.get_executable_path().get_base_dir().path_join("WMC-diagnostics.txt")
  file = FileAccess.open(path, FileAccess.READ_WRITE)
  if not file:
   file = FileAccess.open(path, FileAccess.WRITE_READ)
 if not file:
  path = "user://WMC-diagnostics.txt"
  file = FileAccess.open(path, FileAccess.READ_WRITE)
  if not file:
   file = FileAccess.open(path, FileAccess.WRITE_READ)
 if file:
  file.seek_end()
  note("START os=%s godot=%s video=%s engine_log=%s" % [OS.get_name(), Engine.get_version_info().string, RenderingServer.get_video_adapter_name(), ProjectSettings.globalize_path("user://logs/godot.log")])

func note(message: String) -> void:
 if not file:
  return
 file.store_line("%s %s" % [Time.get_datetime_string_from_system(), message])
 file.flush()

func update(dt: float, game: Node) -> void:
 clock += dt
 if clock < 5.0:
  return
 clock = 0.0
 note("state active=%s racing=%s paused=%s circuit=%s lap=%d/%d ai=%d speed=%.1f fps=%d capture=%s" % [game.active, game.racing, game.paused, game.circuit_id, mini(game.race_laps, maxi(1, floori(game.player_progress / maxi(1, game.track.size())) + 1)), game.race_laps, game.ai_riders.size(), game.speed, Engine.get_frames_per_second(), game.replay_enabled])

func stop() -> void:
 note("CLEAN EXIT")
 if file:
  file.close()
  file = null
