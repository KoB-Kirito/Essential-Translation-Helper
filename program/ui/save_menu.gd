class_name SaveMenu
extends MenuButton


enum {
	SAVE = 2,
	SAVE_AS = 3,
	COMPILE_DAT = 5,
	EXPORT_CSV = 7,
	EXPORT_TODO = 8,
	EXPORT_SECTIONS = 9
}


@export var UI: UI

@export_enum("Source", "Target") var SIDE: int = Side.SOURCE

var original_path: String
var asked_for_overwrite: bool = false

@onready var popup_menu: PopupMenu = get_popup()


func _ready() -> void:
	popup_menu.index_pressed.connect(on_popup_menu_button_pressed)
	
	popup_menu.set_item_text(0, get_file_name())
	
	if SIDE == Side.SOURCE:
		original_path = Settings.source_path
	else:
		original_path = Settings.target_path


func on_popup_menu_button_pressed(i: int) -> void:
	match i:
		SAVE:
			save_file()
		
		SAVE_AS:
			save_file_as()
		
		COMPILE_DAT:
			#TODO
			pass
		
		EXPORT_CSV:
			#TODO
			pass
		
		EXPORT_TODO:
			#TODO
			pass
		
		EXPORT_SECTIONS:
			#TODO
			pass


func get_working_directory() -> String:
	if SIDE == Side.SOURCE:
		return Settings.source_last_working_directory
	else:
		return Settings.target_last_working_directory


func set_working_directory(path: String) -> void:
	if SIDE == Side.SOURCE:
		Settings.source_last_working_directory = path.get_base_dir()
	else:
		Settings.target_last_working_directory = path.get_base_dir()


func get_file_path() -> String:
	if SIDE == Side.SOURCE:
		return Settings.source_path
	else:
		return Settings.target_path


func set_file_path(path: String) -> void:
	if SIDE == Side.SOURCE:
		Settings.source_path = path
	else:
		Settings.target_path = path


func get_file_name() -> String:
	if SIDE == Side.SOURCE:
		return Settings.source_path.get_file()
	else:
		return Settings.target_path.get_file()


@export var editor: Editor
@export var confirmation_dialog: ConfirmationDialog
func save_file() -> void:
	var path: String = get_file_path()
	
	if path.is_empty():
		save_file_as()
		return
	
	if not asked_for_overwrite and path == original_path:
		# ask if original file should be overwritten
		if OS.get_name() == "macOS":
			if DisplayServer.dialog_show("Warning", "Do you want to overwrite " + original_path + "?", ["OK", "Cancel"], on_native_confirmation_dialog):
				confirmation_dialog.popup()
		else:
			confirmation_dialog.popup()
		return
	
	# force overwrite
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(editor.text.replace("\n", "\r\n"))
	file.close()
	
	editor.save_line_history()
	
	# set status label
	UI.show_status_message(SIDE, "Saved " + path, Color.GREEN)


func on_native_confirmation_dialog(button_id: int) -> void:
	if button_id == 0: # OK
		_on_overwrite_confirmation_dialog_confirmed()


@export var save_as_file_dialog: FileDialog
func save_file_as() -> void:
	if DisplayServer.file_dialog_show("Save " + get_file_name(), get_working_directory(), "", false, DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, ["*.txt"], on_native_save_as_dialog_file_selected):
		# use internal file dialog if native does not work
		save_as_file_dialog.title = "Save " + get_file_name()
		save_as_file_dialog.current_path = get_working_directory()
		save_as_file_dialog.popup()


func on_native_save_as_dialog_file_selected(status: bool, selected_paths: PackedStringArray) -> void:
	if status:
		_on_save_as_dialog_file_selected(selected_paths[0])


func _on_save_as_dialog_file_selected(path: String) -> void:
	set_working_directory(path)
	set_file_path(path)
	
	popup_menu.set_item_text(0, get_file_name())
	
	asked_for_overwrite = true
	save_file()


func _on_overwrite_confirmation_dialog_confirmed() -> void:
	asked_for_overwrite = true
	save_file()
