extends Node

## Shared setting retained for the PC GUI Scale choices that will appear in the
## settings screen: Default, 1, 2, and 3. Mobile keeps responsive sizing.
const SETTING_PATH := "user://wmc-native-settings.cfg"
const NAMES := ["Default", "1", "2", "3"]
var selected_mode := 0
var master := 1.0
var music := 0.7
var engine := 1.0


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTING_PATH) == OK:
		selected_mode = clampi(int(config.get_value("display", "gui_scale", 0)), 0, 3)
		master = clampf(float(config.get_value("audio", "master", 1.0)), 0.0, 1.0)
		music = clampf(float(config.get_value("audio", "music", 0.7)), 0.0, 1.0)
		engine = clampf(float(config.get_value("audio", "engine", 1.0)), 0.0, 1.0)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master)
	config.set_value("audio", "music", music)
	config.set_value("audio", "engine", engine)
	config.set_value("display", "gui_scale", selected_mode)
	config.save(SETTING_PATH)


func cycle() -> String:
	selected_mode = (selected_mode + 1) % NAMES.size()
	save_settings()
	return NAMES[selected_mode]


func set_mode(mode: int) -> void:
	selected_mode = clampi(mode, 0, 3)
	save_settings()


func mode_name() -> String:
	return NAMES[selected_mode]


func hud_scale(_shortest_side: float) -> float:
	if OS.has_feature("mobile"):
		return 1.0
	match selected_mode:
		2:
			return 1.22
		3:
			return 1.45
		_:
			# Default and explicit 1 preserve the base responsive desktop scale.
			return 1.0
