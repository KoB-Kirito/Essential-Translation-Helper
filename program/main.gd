class_name Main
extends MarginContainer
# editor logic


@export var UI: UI
@export var SourceEditor: Editor
@export var TargetEditor: Editor
@export var SourceEditorOptions: EditorOptions
@export var TargetEditorOptions: EditorOptions
@export var SourceSaveMenu: SaveMenu
@export var TargetSaveMenu: SaveMenu



### Merge ###

func _ready() -> void:
	Data.status_update.connect(on_status_update)
	Data.merged.connect(on_merged)
	
	# deferr start
	await get_tree().create_timer(0.5).timeout
	
	Data.merge()
	%StillWorkingTimer.start()


func _on_still_working_timer_timeout() -> void:
	# check thread
	if Data.working_thread.is_alive():
		%StatusLabel.text += "."
		%LoadingBar.value += 234 # TODO: Calculate from processing time
		
	else:
		%StillWorkingTimer.stop()
		Data.working_thread.wait_to_finish()


func on_status_update(status: String, line_number: int):
	%StillWorkingTimer.stop()
	%StatusLabel.text = status
	%LoadingBar.value = line_number
	%StillWorkingTimer.start()


func on_merged(source: SourceData, target: TargetData):
	%StillWorkingTimer.stop()
	
	SourceEditor.setup_gutters()
	TargetEditor.setup_gutters()
	
	# set text
	TargetEditor.placeholder_text = ""
	TargetEditor.text = target.output.left(target.output.length() - 1)
	TargetEditor.clear_undo_history()
	SourceEditor.text = source.output.left(source.output.length() - 1)
	SourceEditor.clear_undo_history()
	
	TargetEditor.save_line_history()
	SourceEditor.save_line_history()
	
	# insert gutter data
	# source
	if SourceEditor.get_line_count() > 1:
		for line in range(SourceEditor.get_line_count()):
			# icon
			SourceEditor.set_line_icon(line, source.line_icon[line])
			
			# line number > parsing
			SourceEditor.set_line_gutter_metadata(line, Gutter.LINE_NUMBER, source.line_parsed_to[line])
			
			# section
			#SourceEditor.set_line_gutter_text(line, Gutter.SECTION, source.section[line])
			#SourceEditor.set_line_gutter_metadata(line, Gutter.SECTION, Data.source_section_data[source.section[line]].numbered)
			
			# history
			#SourceEditor.set_line_gutter_metadata(line, Gutter.HISTORY, SourceEditor.get_line(line))
	
	# target
	for line in range(TargetEditor.get_line_count()):
		# icon
		TargetEditor.set_line_icon(line, target.line_icon[line])
		
		# line number > parsing
		TargetEditor.set_line_gutter_metadata(line, Gutter.LINE_NUMBER, target.line_parsed_from[line])
		
		# section
		#TargetEditor.set_line_gutter_text(line, Gutter.SECTION, target.section[line])
		#TargetEditor.set_line_gutter_metadata(line, Gutter.SECTION, Data.target_section_data[target.section[line]].numbered)
		
		# history
		#TargetEditor.set_line_gutter_metadata(line, Gutter.HISTORY, TargetEditor.get_line(line))
	
	# fill section selector
	for section in Data.source_section_data:
		var section_name: String = get_section_name(section, source.map_names)
		
		if section in source.removed_sections:
			%SourceSectionButton.add_icon_item(UI.jump_minus, section + section_name)
		elif section in source.edited_sections:
			%SourceSectionButton.add_icon_item(UI.jump_edited, section + section_name)
		else:
			%SourceSectionButton.add_item(section + section_name)
		
	%SourceSectionButton.select(SourceEditor.JUMP_INDEX_OFFSET)
	
	for section in Data.target_section_data:
		var section_name: String = get_section_name(section, target.map_names)
		
		if section in target.added_sections:
			%TargetSectionButton.add_icon_item(UI.jump_plus, section + section_name)
		elif section in target.edited_sections:
			%TargetSectionButton.add_icon_item(UI.jump_edited, section + section_name)
		else:
			%TargetSectionButton.add_item(section + section_name)
		
	%TargetSectionButton.select(TargetEditor.JUMP_INDEX_OFFSET)
	
	# fill labels
	print("removed sections: ", source.removed_sections.size())
	print("edited sections: ", source.edited_sections.size())
	
	#%SectionsRemovedLabel.text = str(source.removed_sections.size())
	#%SourceSectionsEditedLabel.text = str(source.edited_sections.size())
	#%LinesRemovedLabel.text = str(source.original_removed_lines_count)
	
	print("added sections: ", target.added_sections.size())
	print("edited sections: ", target.edited_sections.size())
	
	#%SectionsAddedLabel.text = str(target.added_sections.size())
	#%TargetSectionsEditedLabel.text = str(target.edited_sections.size())
	#%LinesAddedLabel.text = str(target.original_added_lines_count)
	#%TranslationsParsedLabel.text = str(target.translations_parsed_count)
	#%TranslationsFoundLabel.text = str(target.translations_found_count)
	
	UI.update_source_labels()
	UI.update_target_labels()
	
	
	# enable editor
	TargetEditor.editable = true
	TargetEditor.context_menu_enabled = true
	TargetEditor.shortcut_keys_enabled = true
	TargetEditor.selecting_enabled = true
	TargetEditor.minimap_draw = true
	TargetEditor.highlight_current_line = true
	
	UI.set_normal_state()
	
	# hide source editor if empty
	if SourceEditor.get_line_count() <= 1:
		UI._on_target_button_pressed()
	
	SourceEditorOptions.load_editor_options()
	TargetEditorOptions.load_editor_options()


## -> name of map if found in provided map section, or section name if in provided list
func get_section_name(section: StringName, map_names: Array[String]) -> String:
	# check array
	if map_names.is_empty():
		return ""
	
	# ignore comment section
	if section.begins_with("#"):
		return ""
	
	var section_name: String = section.replace("[", "").replace("]", "")
	
	if section_name.begins_with("Map"):
		# add map name
		section_name = section_name.replace("Map", "")
		if map_names.size() - 1 >= int(section_name) and not map_names[int(section_name)].is_empty():
			return " " + map_names[int(section_name)]
		
		return ""
	
	# add section name
	var section_names: Array[String] = get_section_names()
	if section_names.size() - 1 >= int(section_name) and not section_names[int(section_name)].is_empty():
		return " " + section_names[int(section_name)]
	
	return ""


func get_section_names() -> Array[String]:
	# ToDo: Make user configurable
	return ["",                     # 0
			"Pokemon Names",        # 1
			"Pokedex Titles",       # 2
			"Pokedex Entries",      # 3
			"Pokedex Form",         # 4
			"Move Names",           # 5
			"Move Descriptions",    # 6
			"Item Names",           # 7
			"Item Descriptions",    # 8
			"Ability Names",        # 9
			"Ability Descriptions", # 10
			"Elemental Types",      # 11
			"Trainer Types",        # 12
			"Trainer Names",        # 13
			"Frontier Intro",       # 14
			"Frontier Win",         # 15
			"Frontier Lose",        # 16
			"Region Names",         # 17
			"Place Names",          # 18
			"Place Descriptions",   # 19
			"Map Names",            # 20
			"Phone Messages",       # 21
			"Script Texts",         # 22
			]



### Save File ###

func save_all() -> void:
	SourceSaveMenu.save_file()
	TargetSaveMenu.save_file()


### Hotkeys ###

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("save_all"):
		save_all()
		
	elif event.is_action_pressed("transfer_line"):
		transfer_source_line_to_target()
		
	elif event.is_action_pressed("jump_last"):
		if SourceEditor.has_focus():
			SourceEditor.jump_last()
			
		elif TargetEditor.has_focus():
			TargetEditor.jump_last()
		
	elif event.is_action_pressed("jump_next"):
		if SourceEditor.has_focus():
			SourceEditor.jump_next()
			
		elif TargetEditor.has_focus():
			TargetEditor.jump_next()
		
	elif event.is_action_pressed("entry_done"):
		if SourceEditor.has_focus():
			SourceEditor.mark_as_done()
			
		elif TargetEditor.has_focus():
			TargetEditor.mark_as_done()


func current_line_is_an_entry(editor: Editor) -> bool:
	var current_line_icon: int = editor.get_line_gutter_metadata(editor.caret_current_line, Gutter.ICON)
	return current_line_icon == Icon.ADDED_LINE or \
			current_line_icon == Icon.REMOVED_LINE or \
			current_line_icon == Icon.EDITED_LINE



func transfer_source_line_to_target() -> void:
	# only allow when edited entries are selected
	if not current_line_is_an_entry(SourceEditor):
		UI.show_status_message(Side.SOURCE, "No removed or edited line selected", Color.RED, 1.0)
		return
	if not current_line_is_an_entry(TargetEditor):
		UI.show_status_message(Side.TARGET, "No added or edited line selected", Color.RED, 1.0)
		return
	
	var source_translated_line: int = SourceEditor.caret_current_line
	while SourceEditor.get_line_gutter_metadata(source_translated_line, Gutter.LINE_TYPE) != LineType.TRANSLATION:
		source_translated_line += 1
		if source_translated_line >= SourceEditor.get_line_count():
			UI.show_status_message(Side.SOURCE, "Can't find translated line to copy", Color.RED)
			return
	
	var target_translated_line: int = TargetEditor.caret_current_line
	while TargetEditor.get_line_gutter_metadata(target_translated_line, Gutter.LINE_TYPE) != LineType.TRANSLATION:
		target_translated_line += 1
		if target_translated_line >= TargetEditor.get_line_count():
			UI.show_status_message(Side.TARGET, "Can't find translated line to paste", Color.RED)
			return
	
	TargetEditor.set_line(target_translated_line, SourceEditor.get_line(source_translated_line))
	UI.show_status_message(Side.SOURCE, "Copied line", Color.GREEN, 1.0)
	UI.show_status_message(Side.TARGET, "Pasted line", Color.GREEN, 1.0)
	
	SourceEditor.mark_as_done()
	TargetEditor.mark_as_done()
	#TODO: Mark both as done, set icon as parsed. save line number
