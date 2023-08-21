extends MarginContainer


@onready var UI := %UI as UI # for auto-completion


func _ready() -> void:
	%DeferrTimer.start()

func _on_deferr_timer_timeout() -> void:
	Data.status_update.connect(status_update)
	Data.merged.connect(merged)
	Data.merge()
	%StillWorkingTimer.start()


func status_update(status: String):
	%StillWorkingTimer.stop()
	%StatusLabel.text = status
	%StillWorkingTimer.start()


func merged(target_output: String, added_sections: Array[StringName], target_edited_sections: Array[StringName], added_lines: Array[int], real_added_lines: int, translated_lines: Array[int],
		source_output: String, removed_sections: Array[StringName], source_edited_sections: Array[StringName], removed_lines: Array[int], real_removed_lines: int):
	%StillWorkingTimer.stop()
	
	## add spacing gutter
	#%TargetTextEdit.add_gutter()
	#%TargetTextEdit.set_gutter_width(0, 8)
	#%SourceTextEdit.add_gutter()
	#%SourceTextEdit.set_gutter_width(0, 8)
	
	# add icon gutter
	%TargetTextEdit.add_gutter()
	%TargetTextEdit.set_gutter_type(0, TextEdit.GUTTER_TYPE_ICON)
	%SourceTextEdit.add_gutter()
	%SourceTextEdit.set_gutter_type(0, TextEdit.GUTTER_TYPE_ICON)
	
	# add line gutter
	%TargetTextEdit.add_gutter()
	%TargetTextEdit.set_gutter_type(1, TextEdit.GUTTER_TYPE_STRING)
	%SourceTextEdit.add_gutter()
	%SourceTextEdit.set_gutter_type(1, TextEdit.GUTTER_TYPE_STRING)
	
	# set text
	%TargetTextEdit.placeholder_text = ""
	%TargetTextEdit.text = target_output.left(target_output.length() - 1)
	%TargetTextEdit.clear_undo_history()
	%SourceTextEdit.text = source_output.left(source_output.length() - 1)
	%SourceTextEdit.clear_undo_history()
	
	# mark lines
	for i in range(%TargetTextEdit.get_line_count()):
		if i in added_lines:
			%TargetTextEdit.set_line_gutter_icon(i, UI.ICON_GUTTER, UI.gutter_plus)
			%TargetTextEdit.set_line_gutter_metadata(i, UI.ICON_GUTTER, true)
			%TargetTextEdit.set_line_background_color(i, Color(0.56, 1.0, 0.52, 0.6))
			
		elif i in translated_lines:
			%TargetTextEdit.set_line_gutter_icon(i, UI.ICON_GUTTER, UI.gutter_arrow)
			%TargetTextEdit.set_line_background_color(i, Color(0.37, 0.56, 1.0, 0.6))
	
	for i in range(%SourceTextEdit.get_line_count()):
		if i in removed_lines:
			%SourceTextEdit.set_line_gutter_icon(i, UI.ICON_GUTTER, UI.gutter_minus)
			%SourceTextEdit.set_line_gutter_metadata(i, UI.ICON_GUTTER, true)
			%SourceTextEdit.set_line_background_color(i, Color(1.0, 0.52, 0.45, 0.6))
	
	# fill section selector
	for section in Data.old_section_data:
		if section in removed_sections:
			%SourceSectionButton.add_icon_item(UI.jump_minus_section, section)
		elif section in source_edited_sections:
			%SourceSectionButton.add_icon_item(UI.jump_minus, section)
		else:
			%SourceSectionButton.add_item(section)
	%SourceSectionButton.select(3)
	
	for section in Data.new_section_data:
		if section in added_sections:
			%TargetSectionButton.add_icon_item(UI.jump_plus_section, section)
		elif section in target_edited_sections:
			%TargetSectionButton.add_icon_item(UI.jump_plus, section)
		else:
			%TargetSectionButton.add_item(section)
	%TargetSectionButton.select(3)
	
	# show menus
	%SourceMenuContainer.visible = true
	%TargetMenuContainer.visible = true
	%TabContainer.visible = true
	
	# set window
	var window = get_window()
	window.size = Vector2i(900, 600)
	window.min_size = Vector2i(800, 250)
	window.unresizable = false
	
	# enable editor
	%SourceTextEdit.visible = true
	%TargetTextEdit.editable = true
	%TargetTextEdit.context_menu_enabled = true
	%TargetTextEdit.shortcut_keys_enabled = true
	%TargetTextEdit.selecting_enabled = true
	%TargetTextEdit.minimap_draw = true
	
	# setup jump
	print(%SourceTextEdit.get_caret_count())
	print(%TargetTextEdit.get_caret_count())
	UI.update_last_next(%SourceTextEdit, 0)
	UI.update_last_next(%TargetTextEdit, 0)
	
	# fill labels
	%StatusLabel.visible = false
	%TranslationsParsedLabel.visible = true
	%SectionsAddedLabel.visible = true
	%LinesAddedLabel.visible = true
	%SectionsRemovedLabel.visible = true
	%LinesRemovedLabel.visible = true
	
	%TranslationsParsedLabel.text = "Parsed Translations: " + str(translated_lines.size())
	%SectionsAddedLabel.text = "New Sections: " + str(added_sections.size()) + " (" + str(target_edited_sections.size()) + ")"
	%LinesAddedLabel.text = "New Lines: " + str(real_added_lines)
	%SectionsRemovedLabel.text = "Removed Sections: " + str(removed_sections.size()) + " (" + str(source_edited_sections.size()) + ")"
	%LinesRemovedLabel.text = "Removed Lines: " + str(real_removed_lines)


func _on_still_working_timer_timeout() -> void:
	# check thread
	if Data.thread.is_alive():
		%StatusLabel.text += "."
		
	else:
		%StillWorkingTimer.stop()
		Data.thread.wait_to_finish()


### Save File ###

func _on_save_button_pressed() -> void:
	%SaveFileDialog.current_dir = Globals.last_directory
	%SaveFileDialog.popup()


func _on_save_file_dialog_file_selected(path: String) -> void:
	Globals.last_directory = path.get_base_dir()
	
	# force overwrite
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(%TargetTextEdit.text.replace("\n", "\r\n"))
	file.close()
	
	# set status label
	UI.show_status_message("Saved " + path, Color.GREEN)
