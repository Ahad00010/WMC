class_name WmcDiagnostics
extends Node
# Small append-only session log; never writes frames, account tokens or profile data.
var file: FileAccess
var _time := 0.0
var _game: Node

func setup(game: Node) -> void:
	_game = game
	var path := "user://WMC-diagnostics.txt"
	if OS.has_feature("windows"):
		var beside_executable := OS.get_executable_path().get_base_dir().path_join("WMC-diagnostics.txt")
		file = FileAccess.open(beside_executable, FileAccess.WRITE)
	if not file:
		file = FileAccess.open(path, FileAccess.WRITE)
	note("START Godot=%s renderer=%s device=%s" % [Engine.get_version_info().string, RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])

func note(message: String) -> void:
	if file:
		file.store_line("%s  %s" % [Time.get_datetime_string_from_system(), message])
		file.flush()

func _process(delta: float) -> void:
	_time += delta
	if _time < 5.0 or not _game:
		return
	_time = 0.0
	var capture_ms := 0.0
	if _game._footage:
		capture_ms = _game._footage.last_readback_ms
	note("STATE fps=%d running=%s paused=%s riders=%d readback_ms=%.2f" % [Engine.get_frames_per_second(), _game._race_running, _game.paused, _game._riders.size(), capture_ms])
	note("GRAPHICS buffer_mb=%.1f texture_mb=%.1f video_mb=%.1f" % [float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)) / 1048576.0, float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)) / 1048576.0, float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / 1048576.0])
	if _game._footage:
		var capture = _game._footage
		note("CAPTURE reads=%d skipped=%d slow=%d average_ms=%.2f target_fps=%.1f" % [capture.readback_count, capture.skipped_count, capture.slow_readbacks, capture.average_readback_ms, 1.0 / capture.interval])

func _exit_tree() -> void:
	note("STOP")
	if file:
		file.close()
		file = null
