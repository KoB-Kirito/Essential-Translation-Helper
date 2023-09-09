extends MarginContainer


@export var editor_scene: PackedScene


func _ready() -> void:
	Settings.load_settings()
	%SourcePathTextEdit.text = Settings.source_path
	handle_changed_path(%SourcePathTextEdit, %SourceInfoLabel, false)
	%TargetPathTextEdit.text = Settings.target_path
	handle_changed_path(%TargetPathTextEdit, %TargetInfoLabel, true)
	
	var window = get_window()
	
	# detect high dpi
	if Settings.window_content_scale == 1.0 and DisplayServer.screen_get_dpi() > 120:
		window.position -= window.size / 2
		Settings.window_content_scale = 2.0
		window.content_scale_factor = 2.0
		window.size *= 2.0
		
	else:
		window.content_scale_factor = Settings.window_content_scale
		window.size *= Settings.window_content_scale
	
	# set position
	if Settings.window_position_intro > Vector2i.ZERO:
		window.position = Settings.window_position_intro


func _on_source_open_button_pressed() -> void:
	if DisplayServer.file_dialog_show("Open source file..", Settings.source_last_working_directory, "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, ["*.txt"], _on_source_native_file_dialog_file_selected):
		# use internal file dialog if native does not work
		%SourceFileDialog.title = "Open source file.."
		%SourceFileDialog.current_path = Settings.source_last_working_directory
		%SourceFileDialog.popup()

func _on_target_open_button_pressed() -> void:
	if DisplayServer.file_dialog_show("Open target file..", Settings.target_last_working_directory, "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, ["*.txt"], _on_target_native_file_dialog_file_selected):
		# use internal file dialog if native does not work
		%TargetFileDialog.title = "Open target file.."
		%TargetFileDialog.current_path = Settings.target_last_working_directory
		%TargetFileDialog.popup()


func _on_source_native_file_dialog_file_selected(status: bool, selected_paths: PackedStringArray):
	if status:
		_on_source_file_dialog_file_selected(selected_paths[0])

func _on_target_native_file_dialog_file_selected(status: bool, selected_paths: PackedStringArray):
	if status:
		DisplayServer.window_move_to_foreground(get_window().get_window_id())
		_on_target_file_dialog_file_selected(selected_paths[0])


func _on_source_file_dialog_file_selected(path: String) -> void:
	Settings.source_last_working_directory = path.get_base_dir()
	%SourcePathTextEdit.text = path
	handle_changed_path(%SourcePathTextEdit, %SourceInfoLabel)

func _on_target_file_dialog_file_selected(path: String) -> void:
	Settings.target_last_working_directory = path.get_base_dir()
	%TargetPathTextEdit.text = path
	handle_changed_path(%TargetPathTextEdit, %TargetInfoLabel, true)


func _on_source_path_text_edit_text_changed() -> void:
	handle_changed_path(%SourcePathTextEdit, %SourceInfoLabel)

func _on_target_path_text_edit_text_changed() -> void:
	handle_changed_path(%TargetPathTextEdit, %TargetInfoLabel, true)


func handle_changed_path(text_edit: TextEdit, info_label: Label, is_target: bool = false):
	info_label.modulate = Color.WHITE
	info_label.text = ""
	%MergeButton.disabled = true
	
	if text_edit.text.is_empty():
		if is_target:
			return
		
		if %TargetInfoLabel.modulate == Color.GREEN:
			%MergeButton.text = "Open"
			%MergeButton.disabled = false
			return
	
	if %SourcePathTextEdit.text == %TargetPathTextEdit.text:
		%TargetInfoLabel.modulate = Color.RED
		%TargetInfoLabel.text = "Path is identical"
		return
	
	# remove linebreaks
	if text_edit.text.contains("\n"):
		text_edit.text = text_edit.text.replace("\n", "").replace("\r", "")
	
	if text_edit.text.length() < 3:
		return
	
	if text_edit.text.length() > 512:
		info_label.modulate = Color.RED
		info_label.text = "Path too long. This box is for the path to the file, not it's content"
		return
	
	if not FileAccess.file_exists(text_edit.text):
		info_label.modulate = Color.RED
		info_label.text = "File does not exist"
		return
	
	var file_lines: PackedStringArray = FileAccess.get_file_as_string(text_edit.text).replace("\r", "").split("\n")
	
	info_label.text = Data.parse_lines(file_lines, is_target)
	if info_label.text.begins_with("ERROR"):
		info_label.modulate = Color.RED
	else:
		info_label.modulate = Color.GREEN
	
	if %SourceInfoLabel.modulate == Color.GREEN and %TargetInfoLabel.modulate == Color.GREEN:
		%MergeButton.text = "Merge"
		%MergeButton.disabled = false
		
	elif %SourcePathTextEdit.text.is_empty() and %TargetInfoLabel.modulate == Color.GREEN:
		%MergeButton.text = "Open"
		%MergeButton.disabled = false
	
	# fill map names
	%MapNameOptionButton.clear()
	if not Data.target_section_data.is_empty():
		var last_found: bool = false
		for section: StringName in Data.target_section_data:
			# only numbered data sections can contain map names
			if Data.target_section_data[section].numbered and \
					section.replace("[", "").replace("]", "").is_valid_int():
				%MapNameOptionButton.add_item(section)
				if section == Settings.map_name_section:
					%MapNameOptionButton.select(%MapNameOptionButton.item_count - 1)
					last_found = true
		if %MapNameOptionButton.item_count > 0 and last_found == false:
			# select last numbered section by default
			%MapNameOptionButton.select(%MapNameOptionButton.item_count - 1)
			Settings.map_name_section = %MapNameOptionButton.get_item_text(%MapNameOptionButton.item_count - 1)
			print("last selected not found. selected last: ", Settings.map_name_section)


func _on_merge_button_pressed() -> void:
	Settings.source_path = %SourcePathTextEdit.text
	Settings.target_path = %TargetPathTextEdit.text
	
	Settings.mark_new_lines_text = %MarkNewTextEdit.text
	
	Settings.window_position_intro = get_window().position
	
	get_tree().change_scene_to_packed(editor_scene)


func _on_mark_new_check_box_toggled(button_pressed: bool) -> void:
	Settings.mark_new_lines = button_pressed
	%MarkNewTextEdit.editable = button_pressed
	%MarkNewTextEdit.selecting_enabled = button_pressed


func _on_mark_new_text_edit_text_changed() -> void:
	%MarkInfoLabel.text = ""
	
	if %MarkNewTextEdit.text == null:
		return
	
	# remove linebreaks
	if %MarkNewTextEdit.text.contains("\n"):
		%MarkNewTextEdit.text = %MarkNewTextEdit.text.replace("\n", "").replace("\r", "")
	
	if %MarkNewTextEdit.text.length() > 100:
		%MarkInfoLabel.text = "Text is too long"


func _on_source_path_text_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.double_click:
		_on_source_open_button_pressed()


func _on_target_path_text_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.double_click:
		_on_target_open_button_pressed()


func _on_map_name_option_button_item_selected(index: int) -> void:
	Settings.map_name_section = %MapNameOptionButton.get_item_text(index)
	print("map_name_section set to ", Settings.map_name_section)
