extends MarginContainer


func _on_old_open_button_pressed() -> void:
	%OldFileDialog.title = "Open the old intl file (your current translation)"
	set_default_directory(%OldFileDialog)
	%OldFileDialog.popup()

func _on_new_open_button_pressed() -> void:
	%NewFileDialog.title = "Open the new intl file (untranslated)"
	set_default_directory(%NewFileDialog)
	%NewFileDialog.popup()


func set_default_directory(file_dialog: FileDialog):
	if Globals.last_directory.is_empty():
		file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		
	else:
		file_dialog.current_dir = Globals.last_directory


func _on_old_file_dialog_file_selected(path: String) -> void:
	Globals.last_directory = path.get_base_dir()
	%OldPathTextEdit.text = path
	handle_changed_path(%OldPathTextEdit, %OldInfoLabel)

func _on_new_file_dialog_file_selected(path: String) -> void:
	Globals.last_directory = path.get_base_dir()
	%NewPathTextEdit.text = path
	handle_changed_path(%NewPathTextEdit, %NewInfoLabel, true)


func _on_old_path_text_edit_text_changed() -> void:
	handle_changed_path(%OldPathTextEdit, %OldInfoLabel)

func _on_new_path_text_edit_text_changed() -> void:
	handle_changed_path(%NewPathTextEdit, %NewInfoLabel, true)


func handle_changed_path(text_edit: TextEdit, info_label: Label, new_intl: bool = false):
	info_label.modulate = Color.WHITE
	%MergeButton.disabled = true
	
	if text_edit.text == null:
		return
	
	if %OldPathTextEdit.text == %NewPathTextEdit.text:
		%NewInfoLabel.modulate = Color.RED
		%NewInfoLabel.text = "Path is identical"
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
	
	info_label.text = Data.parse_lines(FileAccess.get_file_as_string(text_edit.text).replace("\r", "").split("\n"), new_intl)
	info_label.modulate = Color.GREEN
	
	if %OldInfoLabel.modulate == Color.GREEN and %NewInfoLabel.modulate == Color.GREEN:
		%MergeButton.disabled = false


func _on_merge_button_pressed() -> void:
	get_tree().change_scene_to_file("res://program/merge.tscn")


func _on_mark_new_check_box_toggled(button_pressed: bool) -> void:
	Globals.mark_new_lines = button_pressed
