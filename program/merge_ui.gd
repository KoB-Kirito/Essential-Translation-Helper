class_name UI
extends VBoxContainer

@export var gutter_arrow: Texture2D
@export var gutter_minus: Texture2D
@export var gutter_minus_section: Texture2D
@export var gutter_plus: Texture2D
@export var gutter_plus_section: Texture2D

@export var jump_minus: Texture2D
@export var jump_minus_section: Texture2D
@export var jump_plus: Texture2D
@export var jump_plus_section: Texture2D


func _ready() -> void:
	# hide all menus until merge is finished
	%SourceMenuContainer.visible = false
	%TargetMenuContainer.visible = false
	%TabContainer.visible = false
	%SourceTextEdit.visible = false
	
	# ToDo: Enable all corners while loading
	#%TargetTextEdit.theme_override
	
	connect_menu_button_signals()


### Menu Bar ###

### Jump Back / Forward ###

var target_current_line: int = 0
var source_current_line: int = 0
var target_last_new_line: int = -1
var target_next_new_line: int = -1
var source_last_removed_line: int = -1
var source_next_removed_line: int = -1


func _on_target_text_edit_caret_changed() -> void:
	# sync horizontal scroll
	# ToDo: Implement, refactor into two functions
	
	# update last / next
	if %TargetTextEdit.get_caret_line(0) == target_current_line:
		return
	target_current_line = %TargetTextEdit.get_caret_line(0)
	update_last_next(%TargetTextEdit, target_current_line)

func _on_source_text_edit_caret_changed() -> void:
	# sync horizontal scroll
	# ToDo: Implement, refactor into two functions
	
	# update last / next
	if %SourceTextEdit.get_caret_line(0) == source_current_line:
		return
	source_current_line = %SourceTextEdit.get_caret_line(0)
	update_last_next(%SourceTextEdit, source_current_line)


func update_last_next(text_edit: TextEdit, current_line: int) -> void:
	var skipped_lines: int = 0
	# check if there are new lines before
	if text_edit == %TargetTextEdit:
		target_last_new_line = -1
	else:
		source_last_removed_line = -1
	if current_line > 2:
		if text_edit.get_line(current_line - 1).is_valid_int():
			skipped_lines = 1
		
		for i in range(current_line - 1 - skipped_lines, -1, -1):
			if text_edit.get_line_gutter_metadata(i, ICON_GUTTER):
				if text_edit == %TargetTextEdit:
					target_last_new_line = i - 1
				else:
					source_last_removed_line = i - 1
				break
	
	# check if there are new lines after
	if text_edit == %TargetTextEdit:
		target_next_new_line = -1
	else:
		source_next_removed_line = -1
		
	if current_line < text_edit.get_line_count() - 4:
		if text_edit.get_line(current_line - 1).is_valid_int():
			skipped_lines = 2
		else:
			skipped_lines = 1
		
		for i in range(current_line + 1 + skipped_lines, text_edit.get_line_count()):
			if text_edit.get_line_gutter_metadata(i, ICON_GUTTER):
				var shifted_lines: int = 0
				if text_edit.get_line(i).is_valid_int():
					shifted_lines = 1
				if text_edit == %TargetTextEdit:
					target_next_new_line = i + shifted_lines
				else:
					source_next_removed_line = i + shifted_lines
				break
	
	# set buttons
	if text_edit == %TargetTextEdit:
		if target_last_new_line >= 0 and %TargetLastButton.disabled:
			%TargetLastButton.disabled = false
		elif target_last_new_line < 0 and not %TargetLastButton.disabled:
			%TargetLastButton.disabled = true
		
		if target_next_new_line >= 0 and %TargetNextButton.disabled:
			%TargetNextButton.disabled = false
		elif target_next_new_line < 0 and not %TargetNextButton.disabled:
			%TargetNextButton.disabled = true
		
	else:
		if source_last_removed_line >= 0 and %SourceLastButton.disabled:
			%SourceLastButton.disabled = false
		elif source_last_removed_line < 0 and not %SourceLastButton.disabled:
			%SourceLastButton.disabled = true
		
		if source_next_removed_line >= 0 and %SourceNextButton.disabled:
			%SourceNextButton.disabled = false
		elif source_next_removed_line < 0 and not %SourceNextButton.disabled:
			%SourceNextButton.disabled = true


func _on_target_last_button_pressed() -> void:
	center_on_line(%TargetTextEdit, target_last_new_line)

func _on_target_next_button_pressed() -> void:
	center_on_line(%TargetTextEdit, target_next_new_line)

func _on_source_last_button_pressed() -> void:
	center_on_line(%SourceTextEdit, source_last_removed_line)

func _on_source_next_button_pressed() -> void:
	center_on_line(%SourceTextEdit, source_next_removed_line)


func center_on_line(text_edit: TextEdit, line: int) -> void:
	if line < 0 or line > text_edit.get_line_count() - 1:
		push_error("Trying to center on line ", line)
		return
	
	if text_edit.get_caret_count() == 0:
		text_edit.add_caret(line, 0)
	
	else:
		text_edit.set_caret_column(0)
		text_edit.set_caret_line(line, false)
	
	text_edit.set_line_as_center_visible(line)
	DisplayServer.clipboard_set(text_edit.get_line(line))
	show_status_message("Line " + str(line) + " copied to clipboard", Color.GREEN, 2.0)
	text_edit.select(line + 1, 0, line + 1, text_edit.get_line(line).length())
	text_edit.grab_focus()


### Jump Section ###

func _on_target_section_button_item_selected(index: int) -> void:
	if index < 3:
		%TargetSectionButton.select(3)
		return
	
	var section = %TargetSectionButton.get_item_text(index)
	%TargetTextEdit.set_line_as_first_visible(Data.new_section_data[section][Data.LINE])
	
	if section in Data.old_section_data:
		%SourceTextEdit.set_line_as_first_visible(Data.old_section_data[section][Data.LINE])


func _on_source_section_button_item_selected(index: int) -> void:
	if index < 3:
		%SourceSectionButton.select(3)
		return
		
	var section = %SourceSectionButton.get_item_text(index)
	%SourceTextEdit.set_line_as_first_visible(Data.old_section_data[section][Data.LINE])
	
	if section in Data.new_section_data:
		%TargetTextEdit.set_line_as_first_visible(Data.new_section_data[section][Data.LINE])


### Option Menu ###

enum OptionMenuEntries {LINE_NUMBERS, MAP, CONTROL_CHARACTERS}


func connect_menu_button_signals() -> void:
	%SourceOptionMenuButton.get_popup().id_pressed.connect(_on_source_option_menu_button_pressed)
	%TargetOptionMenuButton.get_popup().id_pressed.connect(_on_target_option_menu_button_pressed)


func _on_source_option_menu_button_pressed(id: int) -> void:
	var menu := %SourceOptionMenuButton.get_popup() as PopupMenu
	menu.set_item_checked(id, !menu.is_item_checked(id))
	
	match id:
		OptionMenuEntries.LINE_NUMBERS:
			toggle_display_line_numbers(%SourceTextEdit, menu.is_item_checked(id))
		
		OptionMenuEntries.MAP:
			toggle_display_map(%SourceTextEdit, menu.is_item_checked(id))
		
		OptionMenuEntries.CONTROL_CHARACTERS:
			toggle_display_control_characters(%SourceTextEdit, menu.is_item_checked(id))

func _on_target_option_menu_button_pressed(id: int) -> void:
	var menu := %TargetOptionMenuButton.get_popup() as PopupMenu
	menu.set_item_checked(id, !menu.is_item_checked(id))
	
	match id:
		OptionMenuEntries.LINE_NUMBERS:
			toggle_display_line_numbers(%TargetTextEdit, menu.is_item_checked(id))
		
		OptionMenuEntries.MAP:
			toggle_display_map(%TargetTextEdit, menu.is_item_checked(id))
		
		OptionMenuEntries.CONTROL_CHARACTERS:
			toggle_display_control_characters(%TargetTextEdit, menu.is_item_checked(id))


func toggle_display_control_characters(text_edit: TextEdit, button_pressed: bool) -> void:
	text_edit.draw_control_chars = button_pressed
	text_edit.draw_spaces = button_pressed
	text_edit.draw_tabs = button_pressed


func toggle_display_map(text_edit: TextEdit, button_pressed: bool) -> void:
	text_edit.minimap_draw = button_pressed


### Tab Modes ###

func _on_source_button_pressed() -> void:
	%SourceButton.disabled = true
	%TargetButton.disabled = false
	%SplitButton.disabled = false
	%SourceTextEdit.visible = true
	%SourceMenuContainer.visible = true
	%TargetTextEdit.visible = false
	%TargetMenuContainer.visible = false

func _on_target_button_pressed() -> void:
	%TargetButton.disabled = true
	%SourceButton.disabled = false
	%SplitButton.disabled = false
	%TargetTextEdit.visible = true
	%TargetMenuContainer.visible = true
	%SourceTextEdit.visible = false
	%SourceMenuContainer.visible = false

func _on_split_button_pressed() -> void:
	%SplitButton.disabled = true
	%SourceButton.disabled = false
	%TargetButton.disabled = false
	%TargetTextEdit.visible = true
	%TargetMenuContainer.visible = true
	%SourceTextEdit.visible = true
	%SourceMenuContainer.visible = true


### Text Editors ###

var source_last_gutter_click: int = 0
var target_last_gutter_click: int = 0


func _on_target_text_edit_gutter_clicked(line: int, gutter: int) -> void:
	handle_gutter_click(%TargetTextEdit, %SourceTextEdit, line, target_last_gutter_click)
	target_last_gutter_click = line

func _on_source_text_edit_gutter_clicked(line:int, gutter: int) -> void:
	handle_gutter_click(%SourceTextEdit, %TargetTextEdit, line, source_last_gutter_click)
	source_last_gutter_click = line


func handle_gutter_click(clicked_text_edit: TextEdit, other_text_edit: TextEdit, line: int, last_clicked_line: int) -> void:
	if line == last_clicked_line and not %DoubleClickTimer.is_stopped():
		# double click
		search_line(other_text_edit, clicked_text_edit, clicked_text_edit.get_line(line), line)
		return
	%DoubleClickTimer.start()
	
	# select line
	clicked_text_edit.select(line, 0, line, clicked_text_edit.get_line(line).length())
	clicked_text_edit.set_caret_column(0, false)
	clicked_text_edit.set_caret_line(line, false)


func search_line(text_edit: TextEdit, from_text_edit: TextEdit, line: String, current_line: int):
	var result := text_edit.search(line, TextEdit.SEARCH_MATCH_CASE + TextEdit.SEARCH_WHOLE_WORDS, 0, 0)
	var found_line = result.y
	if found_line < 0 or line.is_valid_int():
		# use line instead
		if current_line > text_edit.get_line_count() - 1:
			current_line = text_edit.get_line_count() - 1
		text_edit.set_line_as_center_visible(current_line)
		
	else:
		# line found
		text_edit.set_line_as_center_visible(found_line)
		text_edit.select(current_line, 0, current_line, text_edit.get_line(current_line).length())
	
	from_text_edit.set_line_as_center_visible(current_line)


### Line Numbers ###

# gutter order: left > right
#const SPACER_GUTTER: int = 0
const ICON_GUTTER: int = 0
const LINE_GUTTER: int = 1

const CHAR_WIDTH: int = 9
const LINE_NUMBER_MARGIN: int = 9

var source_current_line_count: int = 0
var target_current_line_count: int = 0


func toggle_display_line_numbers(text_edit: TextEdit, button_pressed: bool) -> void:
	if button_pressed:
		#text_edit.set_gutter_draw(SPACER_GUTTER, true)
		text_edit.set_gutter_draw(LINE_GUTTER, true)
		update_line_numbers(text_edit)
	else:
		#text_edit.set_gutter_draw(SPACER_GUTTER, false)
		text_edit.set_gutter_draw(LINE_GUTTER, false)


func update_line_numbers(text_edit: TextEdit):
	var line_count := text_edit.get_line_count() as int
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
	
	text_edit.set_gutter_width(LINE_GUTTER, char_count * CHAR_WIDTH + LINE_NUMBER_MARGIN)
	
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
		text_edit.set_line_gutter_text(i, LINE_GUTTER, get_padding(char_count - i_char_count) + str(i + 1))


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


func _on_source_text_edit_text_changed() -> void:
	if %SourceTextEdit.get_line_count() == source_current_line_count:
		return
	source_current_line_count = %SourceTextEdit.get_line_count()
	
	var menu := %SourceOptionMenuButton.get_popup() as PopupMenu
	if menu.is_item_checked(OptionMenuEntries.LINE_NUMBERS):
		update_line_numbers(%SourceTextEdit)

func _on_target_text_edit_text_changed() -> void:
	if %TargetTextEdit.get_line_count() == target_current_line_count:
		return
	target_current_line_count = %TargetTextEdit.get_line_count()
	
	var menu := %TargetOptionMenuButton.get_popup() as PopupMenu
	if menu.is_item_checked(OptionMenuEntries.LINE_NUMBERS):
		update_line_numbers(%TargetTextEdit)


### Status Bar ###

func show_status_message(message: String, color: Color = Color.WHITE, duration: float = 5.0) -> void:
	%StatusLabel.text = message
	%StatusLabel.modulate = color
	toggle_status_bar(false)
	if duration > 0.0:
		%ResetLabelsTimer.start(duration)


func toggle_status_bar(show_info: bool) -> void:
	%StatusLabel.visible = !show_info
	%TranslationsParsedLabel.visible = show_info
	%SectionsAddedLabel.visible = show_info
	%LinesAddedLabel.visible = show_info
	%SectionsRemovedLabel.visible = show_info
	%LinesRemovedLabel.visible = show_info


func _on_reset_labels_timer_timeout() -> void:
	toggle_status_bar(true)
