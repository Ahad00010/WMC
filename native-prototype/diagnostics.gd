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
 if game.replay_enabled:
  note("capture readbacks=%d skipped=%d avg_readback_ms=%.2f recent_readback_ms=%.2f target_fps=%.1f godot_memory_mb=%.1f" % [game.capture_readbacks, game.capture_skipped, float(game.capture_readback_us) / max(1, game.capture_readbacks) / 1000.0, game.capture_readback_ema_ms, game.capture_target_fps, OS.get_static_memory_usage() / 1048576.0])

func stop() -> void:
 note("CLEAN EXIT")
 if file:
  file.close()
  file = null
