extends MarginContainer


@export var plus: Texture2D


func _ready() -> void:
	# set layout
	%ButtonsContainer.visible = false
	%TabContainer.visible = false
	
	%StartTimer.start()


func _on_start_timer_timeout() -> void:
	Data.status_update.connect(status_update)
	Data.merged.connect(merged)
	Data.merge()


func status_update(status: String):
	%StillWorkingTimer.stop()
	%StatusLabel.text = status
	%StillWorkingTimer.start()


func merged(output: String, added_sections: Array[StringName], added_lines: Array[int], translated_lines: Array[int]):
	%StillWorkingTimer.stop()
	
	%TextEdit.text = output.left(output.length() - 1)
	
	# add icon gutter
	%TextEdit.add_gutter(0)
	%TextEdit.set_gutter_type(0, TextEdit.GUTTER_TYPE_STRING)
	%LineNumberCheckBox.button_pressed = true
	%TextEdit.gutter_clicked.connect(gutter_clicked)
	
	for i in range(%TextEdit.get_line_count()):
		if i in added_lines:
			%TextEdit.set_line_gutter_text(i, 0, "+")
			%TextEdit.set_line_background_color(i, Color(0.56, 1.0, 0.52, 0.66))
			
		elif i in translated_lines:
			%TextEdit.set_line_gutter_text(i, 0, ">")
			%TextEdit.set_line_background_color(i, Color(0.37, 0.56, 1.0, 0.66))
	
	# show buttons
	%ButtonsContainer.visible = true
	%TabContainer.visible = true
	
	# set window
	var window = get_window()
	window.size = Vector2i(800, 600)
	window.unresizable = false
	
	%TextEdit.editable = true
	%TextEdit.context_menu_enabled = true
	%TextEdit.shortcut_keys_enabled = true
	%TextEdit.selecting_enabled = true
	%TextEdit.minimap_draw = true
	%SaveButton.disabled = false
	
	# fill section selector
	for section in Data.new_section_data:
		if section in added_sections:
			%SectionButton.add_icon_item(plus, section)
		else:
			%SectionButton.add_item(section)
	
	# fill labels
	%StatusLabel.visible = false
	%TranslationsParsedLabel.visible = true
	%SectionsAddedLabel.visible = true
	%LinesAddedLabel.visible = true
	%SectionsRemovedLabel.visible = true
	%LinesRemovedLabel.visible = true
	%TranslationsParsedLabel.text = "Parsed Translations: " + str(translated_lines.size())
	%SectionsAddedLabel.text = "New Sections: " + str(added_sections.size())
	%LinesAddedLabel.text = "New Lines: " + str(added_lines.size() - added_sections.size()) # ToDo: calculate unique lines > numbered lines
	#%SectionsRemovedLabel.text = "Removed Sections: " + str(removed_sections.size()) # ToDo
	#%LinesRemovedLabel.text = "Removed Lines: " + str(removed_lines.size()) # ToDo


func add_line_numbers():
	%TextEdit.add_gutter(1) # line numbers
	%TextEdit.set_gutter_type(1, TextEdit.GUTTER_TYPE_STRING)


const CHAR_WIDTH: int = 9
const LINE_NUMBER_MARGIN: int = 9

func update_line_numbers():
	var line_count := %TextEdit.get_line_count() as int
	var char_count: int
	
	if line_count < 10:
		char_count = 1
	elif line_count < 100:
		char_count = 2
	elif line_count < 1000:
		char_count = 3
	elif line_count < 10000:
		char_count = 4
	elif line_count < 100000:
		char_count = 5
	else:
		char_count = 6
	
	%TextEdit.set_gutter_width(1, char_count * CHAR_WIDTH + LINE_NUMBER_MARGIN)
	
	for i in range(line_count):
		var i_char_count: int
		if i < 9:
			i_char_count = 1
		elif i < 99:
			i_char_count = 2
		elif i < 999:
			i_char_count = 3
		elif i < 9999:
			i_char_count = 4
		elif i < 99999:
			i_char_count = 5
		else:
			i_char_count = 6
		%TextEdit.set_line_gutter_text(i, 1, get_padding(char_count - i_char_count) + str(i + 1))


func get_padding(count: int) -> String:
	match count:
		1:
			return " "
		2:
			return "  "
		3:
			return "   "
		4:
			return "    "
		5:
			return "     "
		6:
			return "      "
		7:
			return "       "
	return ""


func gutter_clicked(line: int, gutter: int):
	# select line
	%TextEdit.select(line, 0, line, %TextEdit.get_line(line).length())


func _on_save_button_pressed() -> void:
	%SaveFileDialog.current_dir = Data.last_directory
	%SaveFileDialog.popup()


func _on_save_file_dialog_file_selected(path: String) -> void:
	Data.last_directory = path.get_base_dir()
	
	# overwrite
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(%TextEdit.text.replace("\n", "\r\n"))
	file.close()
	%StatusLabel.text = "Saved " + path
	%StatusLabel.modulate = Color.GREEN
	%StatusLabel.visible = true
	%TranslationsParsedLabel.visible = false
	%SectionsAddedLabel.visible = false
	%LinesAddedLabel.visible = false
	%SectionsRemovedLabel.visible = false
	%LinesRemovedLabel.visible = false


func _on_text_edit_text_changed() -> void:
	if %LineNumberCheckBox.button_pressed:
		update_line_numbers()


func _on_still_working_timer_timeout() -> void:
	%StatusLabel.text += "."


func _on_control_check_box_toggled(button_pressed: bool) -> void:
	%TextEdit.draw_control_chars = button_pressed
	%TextEdit.draw_spaces = button_pressed
	%TextEdit.draw_tabs = button_pressed


func _on_line_number_check_box_toggled(button_pressed: bool) -> void:
	if button_pressed:
		add_line_numbers()
		update_line_numbers()
	else:
		%TextEdit.remove_gutter(1)


func _on_map_check_box_toggled(button_pressed: bool) -> void:
	%TextEdit.minimap_draw = button_pressed


func _on_section_button_item_selected(index: int) -> void:
	var section = %SectionButton.get_item_text(index)
	%TextEdit.set_line_as_first_visible(Data.new_section_data[section][Data.LINE])


func _on_about_button_pressed() -> void:
	# open link to github page
	OS.shell_open("https://github.com/KoB-Kirito/Intl-File-Merger")


func _on_source_button_pressed() -> void:
	%SourceButton.disabled = true
	%TargetButton.disabled = false
	%SplitButton.disabled = false
	%TextEditSource.visible = true
	%TextEdit.visible = false


func _on_target_button_pressed() -> void:
	%TargetButton.disabled = true
	%SourceButton.disabled = false
	%SplitButton.disabled = false
	%TextEdit.visible = true
	%TextEditSource.visible = false


func _on_split_button_pressed() -> void:
	%SplitButton.disabled = true
	%SourceButton.disabled = false
	%TargetButton.disabled = false
	%TextEdit.visible = true
	%TextEditSource.visible = true
