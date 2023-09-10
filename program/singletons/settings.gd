#autoload Settings
extends Node
# persistent settings

# window
var window_position_intro: Vector2i
var window_position_loading: Vector2i
var window_position_main: Vector2i
var window_maximized_main: bool
var window_size_main: Vector2i
var window_content_scale: float

# file system
var source_last_working_directory: String
var target_last_working_directory: String
var source_path: String
var target_path: String

# settings
var mark_new_lines: bool
var mark_new_lines_text: String

var map_name_section: StringName

var split_horizontal: bool

# theme
var color_background: Color
var color_font: Color
var color_removed_line: Color
var color_edited_line: Color
var color_added_line: Color
var color_translation_parsed: Color
var color_translation_found: Color

# editor options
## [Side][EditorOptions]
var editor_options: Dictionary


func _init() -> void:
	set_default_settings()


func set_default_settings() -> void:
	window_position_intro = Vector2i.ZERO
	window_position_loading = Vector2i.ZERO
	window_position_main = Vector2i.ZERO
	window_maximized_main = false
	window_size_main = Vector2i(1280, 720)
	window_content_scale = 1.0
	
	source_last_working_directory = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	target_last_working_directory = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	source_path = ""
	target_path = ""
	
	mark_new_lines = false
	mark_new_lines_text = ""
	
	map_name_section = "[20]"
	
	split_horizontal = false
	
	color_background = Color(0.1, 0.11, 0.12)
	color_font = Color(0.83, 0.83, 0.83)
	color_removed_line = Color(0.81, 0.3, 0.22)
	color_edited_line = Color(0.75, 0.71, 0.1)
	color_added_line = Color(0.36, 0.74, 0.34)
	color_translation_parsed = Color(0.26, 0.38, 0.65)
	color_translation_found = Color(0.26, 0.38, 0.65)
	
	editor_options = {
		Side.SOURCE: {
			EditorOptions.MAP: true,
			EditorOptions.LINE_NUMBERS: true,
			EditorOptions.LINE_COLORS: true,
			EditorOptions.CONTROL_CHARACTERS: false,
			EditorOptions.HIGHLIGHT_LINE: true,
			EditorOptions.HISTORY: false,
			EditorOptions.SYNC_H_SCROLL: true,
			EditorOptions.SYNC: true,
		},
		Side.TARGET: {
			EditorOptions.MAP: true,
			EditorOptions.LINE_NUMBERS: true,
			EditorOptions.LINE_COLORS: true,
			EditorOptions.CONTROL_CHARACTERS: false,
			EditorOptions.HIGHLIGHT_LINE: true,
			EditorOptions.HISTORY: false,
			EditorOptions.SYNC_H_SCROLL: true,
			EditorOptions.SYNC: true,
		},
	}




### Persistent Settings ###

const SETTINGS_FILE: String = "settings.ini"
@onready var settings_path: String = OS.get_user_data_dir() + "/" + SETTINGS_FILE


func save_settings() -> void:
	var config_file = ConfigFile.new()
	
	config_file.set_value("Window", "window_position_intro", window_position_intro)
	config_file.set_value("Window", "window_position_loading", window_position_loading)
	config_file.set_value("Window", "window_position_main", window_position_main)
	config_file.set_value("Window", "window_maximized_main", window_maximized_main)
	config_file.set_value("Window", "window_size_main", window_size_main)
	config_file.set_value("Window", "window_content_scale", window_content_scale)
	
	config_file.set_value("FileSystem", "source_last_working_directory", source_last_working_directory)
	config_file.set_value("FileSystem", "target_last_working_directory", target_last_working_directory)
	config_file.set_value("FileSystem", "source_path", source_path)
	config_file.set_value("FileSystem", "target_path", target_path)
	
	config_file.set_value("Settings", "mark_new_lines", mark_new_lines)
	config_file.set_value("Settings", "mark_new_lines_text", mark_new_lines_text)
	
	config_file.set_value("Settings", "map_name_section", map_name_section)
	
	config_file.set_value("Settings", "split_horizontal", split_horizontal)
	
	config_file.set_value("Theme", "color_background", color_background)
	config_file.set_value("Theme", "color_font", color_font)
	config_file.set_value("Theme", "color_removed_line", color_removed_line)
	config_file.set_value("Theme", "color_edited_line", color_edited_line)
	config_file.set_value("Theme", "color_added_line", color_added_line)
	config_file.set_value("Theme", "color_translation_parsed", color_translation_parsed)
	config_file.set_value("Theme", "color_translation_found", color_translation_found)
	
	config_file.set_value("EditorOptions", "editor_options", editor_options)
	
	config_file.save(settings_path)


func load_settings() -> void:
	if not FileAccess.file_exists(settings_path):
		push_warning(settings_path + " not found")
		return
	
	var config = ConfigFile.new()
	var result = config.load(settings_path)
	
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
