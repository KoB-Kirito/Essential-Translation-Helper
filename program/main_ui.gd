class_name UI
extends VBoxContainer
# editor user interface


const WINDOW_MIN_SIZE: Vector2i = Vector2i(600, 300)
const WINDOW_MIN_SIZE_SPLIT: Vector2i = Vector2i(900, 300)

@export var SourceEditor: Editor
@export var TargetEditor: Editor
@export var SourceEditorOptions: EditorOptions
@export var TargetEditorOptions: EditorOptions

@export_group("UI")
@export var save_grey: CompressedTexture2D
@export var save_blue: CompressedTexture2D

@export_group("Gutter")
@export var icon_removed_section: Texture2D
@export var icon_edited_section: Texture2D
@export var icon_added_section: Texture2D

@export var icon_removed_line: Texture2D
@export var icon_edited_line: Texture2D
@export var icon_added_line: Texture2D

@export var icon_translated_line_parsed: Texture2D
@export var icon_translated_line_found: Texture2D

@export var icon_reset: Texture2D

@export_group("Jump Menu")
@export var jump_minus: Texture2D
@export var jump_plus: Texture2D
@export var jump_edited: Texture2D


func set_loading_state() -> void:
	# hide all menus until merge is finished
	%SourceMenuContainer.hide()
	%TargetMenuContainer.hide()
	
	%TabContainer.hide()
	SourceEditor.hide()
	
	%SettingsButton.disabled = true
	%StatusLabel.show()
	%SourceInfoContainer.hide()
	%TargetInfoContainer.hide()
	
	# setup loading bar
	%LoadingBar.value = 0
	%LoadingBar.max_value = Data.source_file_line_count + Data.target_file_line_count
	%LoadingBar.show()
	
	# load settings
	%ScaleSlider.value = Settings.window_content_scale
	
	var window = get_window()
	window.content_scale_factor = Settings.window_content_scale
	window.size *= Settings.window_content_scale
	if Settings.window_position_loading > Vector2i.ZERO:
		window.position = Settings.window_position_loading
	
	# ToDo: Enable all corners while loading
	#TargetEditor.theme_override


func set_normal_state() -> void:
	%SourceMenuContainer.show()
	%TargetMenuContainer.show()
	
	%TabContainer.show()
	SourceEditor.show()
	
	%SettingsButton.disabled = false
	%StatusLabel.hide()
	%SourceInfoContainer.show()
	%TargetInfoContainer.show()
	
	%LoadingBar.hide()
	
	# show menus
	%SourceMenuContainer.visible = true
	%TargetMenuContainer.visible = true
	%TabContainer.visible = true
	
	# setup jump
	SourceEditor.update_last_next()
	TargetEditor.update_last_next()
	
	# apply settings
	SourceEditorOptions.load_editor_options()
	TargetEditorOptions.load_editor_options()
	
	if Settings.split_horizontal:
		toggle_split_orientation()
	
	# colors
	%BackgroundColorPickerButton.color = Settings.color_background
	%BackgroundColorPickerButton.get_theme_stylebox("normal").bg_color = Settings.color_background
	%FontColorPickerButton.color = Settings.color_font
	%FontColorPickerButton.get_theme_stylebox("normal").bg_color = Settings.color_font
	
	SourceEditor.add_theme_color_override("background_color", Settings.color_background)
	TargetEditor.add_theme_color_override("background_color", Settings.color_background)
	SourceEditor.add_theme_color_override("font_color", Settings.color_font)
	TargetEditor.add_theme_color_override("font_color", Settings.color_font)
	
	%RemovedColorPickerButton.color = Settings.color_removed_line
	%RemovedColorPickerButton.get_theme_stylebox("normal").bg_color = Settings.color_removed_line
	%EditedColorPickerButton.color = Settings.color_edited_line
	%EditedColorPickerButton.get_theme_stylebox("normal").bg_color = Settings.color_edited_line
	%AddedColorPickerButton.color = Settings.color_added_line
	%AddedColorPickerButton.get_theme_stylebox("normal").bg_color = Settings.color_added_line
	%ParsedColorPickerButton.color = Settings.color_translation_parsed
	%ParsedColorPickerButton.get_theme_stylebox("normal").bg_color = Settings.color_translation_parsed
	%FoundColorPickerButton.color = Settings.color_translation_found
	%FoundColorPickerButton.get_theme_stylebox("normal").bg_color = Settings.color_translation_found
	
	if SourceEditorOptions.popup_menu.is_item_checked(EditorOptions.LINE_COLORS):
		SourceEditorOptions.toggle_line_colors(SourceEditor, true)
	if TargetEditorOptions.popup_menu.is_item_checked(EditorOptions.LINE_COLORS):
		TargetEditorOptions.toggle_line_colors(TargetEditor, true)
	
	# set window
	var window = get_window()
	window.size = Settings.window_size_main
	window.min_size = WINDOW_MIN_SIZE_SPLIT * window.content_scale_factor
	window.unresizable = false
	
	if Settings.window_position_main > Vector2i.ZERO:
		window.position = Settings.window_position_main
	
	if Settings.window_maximized_main:
		window.mode = Window.MODE_MAXIMIZED



### Tab Modes ###

var current_tab_state: int = Side.BOTH


func _on_source_button_pressed() -> void:
	current_tab_state = Side.SOURCE
	
	%SourceButton.disabled = true
	%TargetButton.disabled = false
	%SplitButton.disabled = false
	
	SourceEditor.show()
	%SourceMenuContainer.show()
	%SourceInfoContainer.show()
	TargetEditor.hide()
	%TargetMenuContainer.hide()
	%TargetInfoContainer.hide()
	
	%HTopSeperator.hide()
	%HBotSeperator.hide()
	
	get_window().min_size = WINDOW_MIN_SIZE  * get_window().content_scale_factor

func _on_target_button_pressed() -> void:
	current_tab_state = Side.TARGET
	
	%TargetButton.disabled = true
	%SourceButton.disabled = false
	%SplitButton.disabled = false
	
	TargetEditor.show()
	%TargetMenuContainer.show()
	%TargetInfoContainer.show()
	SourceEditor.hide()
	%SourceMenuContainer.hide()
	%SourceInfoContainer.hide()
	
	%HTopSeperator.hide()
	%HBotSeperator.hide()
	
	get_window().min_size = WINDOW_MIN_SIZE * get_window().content_scale_factor

func _on_split_button_pressed() -> void:
	current_tab_state = Side.BOTH
	
	%SplitButton.disabled = true
	%SourceButton.disabled = false
	%TargetButton.disabled = false
	
	TargetEditor.show()
	%TargetMenuContainer.show()
	%TargetInfoContainer.show()
	SourceEditor.show()
	%SourceMenuContainer.show()
	%SourceInfoContainer.show()
	
	if %HorizontalContainer.visible:
		%HTopSeperator.show()
		%HBotSeperator.show()
	
	get_window().min_size = WINDOW_MIN_SIZE_SPLIT * get_window().content_scale_factor


func _on_split_button_pressed_again(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	
	if not mouse_event.pressed:
		return
	
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	if %SplitButton.disabled == false:
		return
	
	toggle_split_orientation()


func toggle_split_orientation() -> void:
	if %VerticalContainer.visible:
		# top - down
		%HorizontalContainer.show()
		SourceEditor.reparent(%HorizontalContainer, false)
		TargetEditor.reparent(%HorizontalContainer, false)
		%VerticalContainer.hide()
		%HTopSeperator.show()
		%HBotSeperator.show()
		Settings.split_horizontal = true
		
	else:
		# left - right
		%VerticalContainer.show()
		SourceEditor.reparent(%VerticalContainer, false)
		TargetEditor.reparent(%VerticalContainer, false)
		%HorizontalContainer.hide()
		%HTopSeperator.hide()
		%HBotSeperator.hide()
		Settings.split_horizontal = false


### Status Bar ###

enum StatusBarState {INFO, MESSAGE_LEFT, MESSAGE_RIGHT, MESSAGE_BOTH, SETTINGS}

var current_status_bar_state: StatusBarState = StatusBarState.INFO


func set_status_bar(state: StatusBarState) -> void:
	match state:
		StatusBarState.INFO:
			%SourceInfoContainer.show()
			%SourceStatusLabel.hide()
			%TargetInfoContainer.show()


func show_status_message(where: int, message: String, color: Color = Color.WHITE, duration: float = 5.0) -> void:
	var label: Label
	match where:
		Side.SOURCE:
			label = %SourceStatusLabel
			label.show()
			%SourceInfoLabelContainer.hide()
		
		Side.TARGET:
			label = %TargetStatusLabel
			label.show()
			%TargetInfoLabelContainer.hide()
		
		Side.BOTH:
			label = %StatusLabel
			label.show()
			%SourceInfoContainer.hide()
			%TargetInfoContainer.hide()
	
	label.text = message
	label.modulate = color
	
	if duration > 0.0:
		%ResetLabelsTimer.start(duration)


func clear_status_message(where: int) -> void:
	match where:
		Side.SOURCE:
			if %SourceStatusLabel.visible:
				%SourceStatusLabel.hide()
				%SourceInfoLabelContainer.show()
		
		Side.TARGET:
			if %TargetStatusLabel.visible:
				%TargetStatusLabel.hide()
				%TargetInfoLabelContainer.show()
		
		Side.BOTH:
			if %StatusLabel.visible:
				%StatusLabel.hide()
				match current_tab_state:
					Side.SOURCE:
						%SourceInfoContainer.show()
						
					Side.TARGET:
						%TargetInfoContainer.show()
					
					Side.BOTH:
						%SourceInfoContainer.show()
						%TargetInfoContainer.show()


func _on_reset_labels_timer_timeout() -> void:
	reset_status_bar()


func reset_status_bar() -> void:
	%StatusLabel.hide()
	%SourceStatusLabel.hide()
	%TargetStatusLabel.hide()
	%SourceInfoLabelContainer.show()
	%TargetInfoLabelContainer.show()
	
	match current_tab_state:
		Side.SOURCE:
			%SourceInfoContainer.show()
			
		Side.TARGET:
			%TargetInfoContainer.show()
		
		Side.BOTH:
			%SourceInfoContainer.show()
			%TargetInfoContainer.show()


# labels

func update_source_labels() -> void:
	# count
	var removed_sections: int = 0
	var edited_sections: int = 0
	var removed_lines: int = 0
	var edited_lines: int = 0
	
	var last_section: String = "#"
	var section_contained_edited_lines: bool = false
	var section_contained_normal_lines: bool = false
	
	for i in range(SourceEditor.get_line_count()):
		match SourceEditor.get_line_gutter_metadata(i, Gutter.LINE_TYPE):
			LineType.SECTION:
				if last_section in Data.target_section_data:
					if section_contained_edited_lines:
						if not section_contained_normal_lines:
							SourceEditor.set_line_icon(Data.source_section_data[last_section].line, Icon.REMOVED_SECTION)
							removed_sections += 1
							
						else:
							#SourceEditor.set_line_icon(Data.source_section_data[last_section].line, Icon.EDITED_SECTION)
							edited_sections += 1
						
					else:
						SourceEditor.set_line_icon(Data.source_section_data[last_section].line, Icon.NONE)
					
				else:
					SourceEditor.set_line_icon(Data.source_section_data[last_section].line, Icon.REMOVED_SECTION)
					removed_sections += 1
				
				last_section = SourceEditor.get_line(i)
				section_contained_edited_lines = false
				section_contained_normal_lines = false
			
			LineType.ORIGINAL:
				match SourceEditor.get_line_gutter_metadata(i, Gutter.ICON):
					Icon.REMOVED_LINE:
						removed_lines += 1
						section_contained_edited_lines = true
					Icon.EDITED_LINE:
						edited_lines += 1
						section_contained_edited_lines = true
					Icon.NONE:
						section_contained_normal_lines = true
	
	%SectionsRemovedLabel.text = str(removed_sections)
	%SourceSectionsEditedLabel.text = str(edited_sections)
	%LinesRemovedLabel.text = str(removed_lines)
	%SourceLinesEditedLabel.text = str(edited_lines)


func update_target_labels() -> void:
	# count
	var added_sections: int = 0
	var edited_sections: int = 0
	var added_lines: int = 0
	var edited_lines: int = 0
	var translated_parsed: int = 0
	var translated_found: int = 0
	
	var last_section: String = "#"
	var section_contained_edited_lines: bool = false
	var section_contained_normal_lines: bool = false
	
	for i in range(TargetEditor.get_line_count()):
		match TargetEditor.get_line_gutter_metadata(i, Gutter.LINE_TYPE):
			LineType.SECTION:
				if last_section in Data.source_section_data:
					if section_contained_edited_lines:
						if not section_contained_normal_lines:
							TargetEditor.set_line_icon(Data.target_section_data[last_section].line, Icon.ADDED_SECTION)
							added_sections += 1
							
						else:
							#TargetEditor.set_line_icon(Data.target_section_data[last_section].line, Icon.EDITED_SECTION)
							edited_sections += 1
						
					else:
						TargetEditor.set_line_icon(Data.target_section_data[last_section].line, Icon.NONE)
					
				else:
					TargetEditor.set_line_icon(Data.target_section_data[last_section].line, Icon.ADDED_SECTION)
					added_sections += 1
				
				last_section = TargetEditor.get_line(i)
				section_contained_edited_lines = false
				section_contained_normal_lines = false
			
			LineType.ORIGINAL:
				match TargetEditor.get_line_gutter_metadata(i, Gutter.ICON):
					Icon.ADDED_LINE:
						added_lines += 1
						section_contained_edited_lines = true
					Icon.EDITED_LINE:
						edited_lines += 1
						section_contained_edited_lines = true
					Icon.NONE:
						section_contained_normal_lines = true
			
			LineType.TRANSLATION:
				match TargetEditor.get_line_gutter_metadata(i, Gutter.ICON):
					Icon.TRANSLATED_LINE_PARSED:
						translated_parsed += 1
					Icon.TRANSLATED_LINE_FOUND:
						translated_found += 1
	
	%SectionsAddedLabel.text = str(added_sections)
	%TargetSectionsEditedLabel.text = str(edited_sections)
	%LinesAddedLabel.text = str(added_lines)
	%TargetLinesEditedLabel.text = str(edited_lines)
	%TranslationsParsedLabel.text = str(translated_parsed)
	%TranslationsFoundLabel.text = str(translated_found)



### Settings Bar ###

func ready_settings_bar() -> void:
	%ScaleSlider.value = Settings.window_content_scale


func _on_settings_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%SettingsBarContainer.show()
		%InfoBarContainer.hide()
		
	else:
		%InfoBarContainer.show()
		%SettingsBarContainer.hide()


# scale slider

func _on_scale_slider_value_changed(value: float) -> void:
	%ScaleLabel.text = str(value)


func _on_scale_slider_drag_ended(_value_changed: bool) -> void:
	var value = %ScaleSlider.value
	Settings.window_content_scale = value
	var window = get_window()
	match current_tab_state:
		Side.SOURCE, Side.TARGET:
			window.min_size = WINDOW_MIN_SIZE * value
		
		Side.BOTH:
			window.min_size = WINDOW_MIN_SIZE_SPLIT * value
	window.content_scale_factor = value


# colors

func _on_background_color_picker_button_color_changed(color: Color) -> void:
	print("background color changed")
	%BackgroundColorPickerButton.get_theme_stylebox("normal").bg_color = color
	Settings.color_background = color
	SourceEditor.add_theme_color_override("background_color", color)
	TargetEditor.add_theme_color_override("background_color", color)


func _on_font_color_picker_button_color_changed(color: Color) -> void:
	%FontColorPickerButton.get_theme_stylebox("normal").bg_color = color
	Settings.color_font = color
	SourceEditor.add_theme_color_override("font_color", color)
	TargetEditor.add_theme_color_override("font_color", color)


func _on_removed_color_picker_button_color_changed(color: Color) -> void:
	%RemovedColorPickerButton.get_theme_stylebox("normal").bg_color = color
	Settings.color_removed_line = color
	if SourceEditorOptions.popup_menu.is_item_checked(EditorOptions.LINE_COLORS):
		SourceEditorOptions.toggle_line_colors(SourceEditor, true)

func _on_edited_color_picker_button_color_changed(color: Color) -> void:
	%EditedColorPickerButton.get_theme_stylebox("normal").bg_color = color
	Settings.color_edited_line = color
	var source_editor_options := %SourceOptionMenuButton as EditorOptions
	if source_editor_options.popup_menu.is_item_checked(EditorOptions.LINE_COLORS):
		source_editor_options.toggle_line_colors(SourceEditor, true)
	if TargetEditorOptions.popup_menu.is_item_checked(EditorOptions.LINE_COLORS):
		TargetEditorOptions.toggle_line_colors(TargetEditor, true)

func _on_added_color_picker_button_color_changed(color: Color) -> void:
	%AddedColorPickerButton.get_theme_stylebox("normal").bg_color = color
	Settings.color_added_line = color
	if TargetEditorOptions.popup_menu.is_item_checked(EditorOptions.LINE_COLORS):
		TargetEditorOptions.toggle_line_colors(TargetEditor, true)

func _on_parsed_color_picker_button_color_changed(color: Color) -> void:
	%ParsedColorPickerButton.get_theme_stylebox("normal").bg_color = color
	Settings.color_translation_parsed = color
	if TargetEditorOptions.popup_menu.is_item_checked(EditorOptions.LINE_COLORS):
		TargetEditorOptions.toggle_line_colors(TargetEditor, true)

func _on_found_color_picker_button_color_changed(color: Color) -> void:
	%FoundColorPickerButton.get_theme_stylebox("normal").bg_color = color
	Settings.color_translation_found = color
	if TargetEditorOptions.popup_menu.is_item_checked(EditorOptions.LINE_COLORS):
		TargetEditorOptions.toggle_line_colors(TargetEditor, true)



### Utility ###

func editor_to_side(editor: Editor) -> int:
	if editor == SourceEditor:
		return Side.SOURCE
	return Side.TARGET


func _on_translations_found_clicked(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	
	if event.button_index == MOUSE_BUTTON_LEFT:
		TargetEditor.jump_to_next(Icon.TRANSLATED_LINE_FOUND)

#TODO: Add other labels too?
