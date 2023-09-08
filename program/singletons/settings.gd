#autoload Settings
extends Node
# persistent settings


var window_position_intro: Vector2i # default centered
var window_position_main: Vector2i # default centered
var window_size_main: Vector2i = Vector2i(1280, 720)
var window_content_scale: float = 1.0

var source_last_working_directory: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
var target_last_working_directory: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
var source_path: String = ""
var target_path: String = ""

var mark_new_lines: bool = false
var mark_new_lines_text: String = ""

var map_name_section: StringName = "[20]"

var color_background: Color = Color(0.1, 0.11, 0.12, 1.0)
var color_font: Color = Color(0.83, 0.83, 0.83)
var color_removed_line: Color = Color(1.0, 0.52, 0.45, 0.6)
var color_edited_line: Color = Color(0.92, 0.92, 0, 0.6)
var color_added_line: Color = Color(0.56, 1.0, 0.52, 0.6)
var color_translation_parsed: Color = Color(0.37, 0.56, 1.0, 0.6)
var color_translation_found: Color = Color(0.37, 0.56, 1.0, 0.6)

## [Side][EditorOptions]
var editor_options: Dictionary = {
	Side.SOURCE: {
		EditorOptions.MAP: true,
		EditorOptions.LINE_NUMBERS: true,
		EditorOptions.LINE_COLORS: true,
		EditorOptions.CONTROL_CHARACTERS: false,
		EditorOptions.HIGHLIGHT_LINE: true,
		EditorOptions.HISTORY: false,
		EditorOptions.SYNC: true,
	},
	Side.TARGET: {
		EditorOptions.MAP: true,
		EditorOptions.LINE_NUMBERS: true,
		EditorOptions.LINE_COLORS: true,
		EditorOptions.CONTROL_CHARACTERS: false,
		EditorOptions.HIGHLIGHT_LINE: true,
		EditorOptions.HISTORY: false,
		EditorOptions.SYNC: true,
	},
}

### Persistent Settings ###

const SETTINGS_DIR: String = "user://"
const SETTINGS_FILE: String = "settings.ini"


func save_settings() -> void:
	var config_file = ConfigFile.new()
	
	config_file.set_value("Window", "window_position_intro", window_position_intro)
	config_file.set_value("Window", "window_position_main", window_position_main)
	config_file.set_value("Window", "window_size_main", window_size_main)
	config_file.set_value("Window", "window_content_scale", window_content_scale)
	
	config_file.set_value("FileSystem", "source_last_working_directory", source_last_working_directory)
	config_file.set_value("FileSystem", "target_last_working_directory", target_last_working_directory)
	
	config_file.set_value("Settings", "mark_new_lines", mark_new_lines)
	config_file.set_value("Settings", "mark_new_lines_text", mark_new_lines_text)
	#config_file.set_value("Settings", "", )
	
	config_file.save(SETTINGS_DIR + SETTINGS_FILE)


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_DIR + SETTINGS_FILE):
		push_warning(OS.get_user_data_dir() + SETTINGS_FILE + " not found")
		return
	
	var config = ConfigFile.new()
	var result = config.load(SETTINGS_DIR + SETTINGS_FILE)
	
	if result != OK:
		push_error(str(result) + ": Could not load " + OS.get_user_data_dir() + SETTINGS_FILE)
		return
		
	# load everything
	for section in config.get_sections():
		for key in config.get_section_keys(section):
			if key in self:
				set(key, config.get_value(section, key))
			else:
				push_error(key + " not found in settings")
