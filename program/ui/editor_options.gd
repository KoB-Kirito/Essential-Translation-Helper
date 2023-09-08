class_name EditorOptions
extends MenuButton


enum {
	MAP,
	LINE_NUMBERS,
	LINE_COLORS,
	CONTROL_CHARACTERS,
	HIGHLIGHT_LINE,
	HISTORY,
	SYNC_H_SCROLL = 7,
	SYNC = 8,
}


@export_enum("Source", "Target") var SIDE: int
@export var Editor: Editor
@export var OtherOptions: EditorOptions

@onready var popup_menu: PopupMenu = get_popup()


func _ready() -> void:
	popup_menu.index_pressed.connect(on_popup_menu_button_pressed)
	popup_menu.hide_on_checkable_item_selection = false
	#popup_menu.about_to_popup.connect(_on_popup_about_to_popup.bind(popup_menu))


func load_editor_options() -> void:
	for option in Settings.editor_options[SIDE]:
		if popup_menu.is_item_checked(option) != Settings.editor_options[SIDE][option]:
			popup_menu.set_item_checked(option, !Settings.editor_options[SIDE][option])
			on_popup_menu_button_pressed(option)


func on_popup_about_to_popup(popup: PopupMenu):
	# ToDo: Buggy. Find a fix or wait for update
	if Settings.window_content_scale > 1.0:
		popup.size *= Settings.window_content_scale
		popup.content_scale_factor = Settings.window_content_scale


func on_popup_menu_button_pressed(i: int) -> void:
	popup_menu.toggle_item_checked(i)
	
	var sync: bool = popup_menu.is_item_checked(SYNC)
	if sync or i == SYNC:
		OtherOptions.popup_menu.set_item_checked(i, popup_menu.is_item_checked(i))
	
	match i:
		LINE_NUMBERS:
			toggle_display_line_numbers(Editor, popup_menu.is_item_checked(i))
			if sync:
				toggle_display_line_numbers(Editor.OtherEditor, OtherOptions.popup_menu.is_item_checked(i))
		
		MAP:
			toggle_map(Editor, popup_menu.is_item_checked(i))
			if sync:
				toggle_map(Editor.OtherEditor, OtherOptions.popup_menu.is_item_checked(i))
		
		CONTROL_CHARACTERS:
			toggle_control_characters(Editor, popup_menu.is_item_checked(i))
			if sync:
				toggle_control_characters(Editor.OtherEditor, OtherOptions.popup_menu.is_item_checked(i))
		
		HISTORY:
			toggle_history(Editor, popup_menu.is_item_checked(i))
			if sync:
				toggle_history(Editor.OtherEditor, OtherOptions.popup_menu.is_item_checked(i))
		
		LINE_COLORS:
			toggle_line_colors(Editor, popup_menu.is_item_checked(i))
			if sync:
				toggle_line_colors(Editor.OtherEditor, OtherOptions.popup_menu.is_item_checked(i))
		
		HIGHLIGHT_LINE:
			toggle_highlight_current_line(Editor, popup_menu.is_item_checked(i))
			if sync:
				toggle_highlight_current_line(Editor.OtherEditor, OtherOptions.popup_menu.is_item_checked(i))
		
		SYNC_H_SCROLL:
			toggle_sync_horizontal_scroll(Editor, popup_menu.is_item_checked(i))
			toggle_sync_horizontal_scroll(Editor.OtherEditor, popup_menu.is_item_checked(i))
			# always sync
			OtherOptions.popup_menu.set_item_checked(i, popup_menu.is_item_checked(i))
		
		SYNC:
			# if sync was disabled already, do nothing
			if not sync:
				return
			
			# sync all settings to the other popup_menu
			if OtherOptions.popup_menu.is_item_checked(MAP) != popup_menu.is_item_checked(MAP):
				OtherOptions.popup_menu.set_item_checked(MAP, popup_menu.is_item_checked(MAP))
				toggle_map(Editor.OtherEditor, OtherOptions.popup_menu.is_item_checked(MAP))
			
			if OtherOptions.popup_menu.is_item_checked(LINE_NUMBERS) != popup_menu.is_item_checked(LINE_NUMBERS):
				OtherOptions.popup_menu.set_item_checked(LINE_NUMBERS, popup_menu.is_item_checked(LINE_NUMBERS))
				toggle_display_line_numbers(Editor.OtherEditor, OtherOptions.popup_menu.is_item_checked(LINE_NUMBERS))
			
			if OtherOptions.popup_menu.is_item_checked(LINE_COLORS) != popup_menu.is_item_checked(LINE_COLORS):
				OtherOptions.popup_menu.set_item_checked(LINE_COLORS, popup_menu.is_item_checked(LINE_COLORS))
				toggle_line_colors(Editor.OtherEditor, OtherOptions.popup_menu.is_item_checked(LINE_COLORS))
			
			if OtherOptions.popup_menu.is_item_checked(CONTROL_CHARACTERS) != popup_menu.is_item_checked(CONTROL_CHARACTERS):
				OtherOptions.popup_menu.set_item_checked(CONTROL_CHARACTERS, popup_menu.is_item_checked(CONTROL_CHARACTERS))
				toggle_control_characters(Editor.OtherEditor, OtherOptions.popup_menu.is_item_checked(CONTROL_CHARACTERS))
			
			if OtherOptions.popup_menu.is_item_checked(HISTORY) != popup_menu.is_item_checked(HISTORY):
				OtherOptions.popup_menu.set_item_checked(HISTORY, popup_menu.is_item_checked(HISTORY))
				toggle_history(Editor.OtherEditor, OtherOptions.popup_menu.is_item_checked(HISTORY))
			
			if OtherOptions.popup_menu.is_item_checked(HIGHLIGHT_LINE) != popup_menu.is_item_checked(HIGHLIGHT_LINE):
				OtherOptions.popup_menu.set_item_checked(HIGHLIGHT_LINE, popup_menu.is_item_checked(HIGHLIGHT_LINE))
				Editor.OtherEditor.highlight_current_line = OtherOptions.popup_menu.is_item_checked(HIGHLIGHT_LINE)
		
		_:
			push_error("Editor option menu button with unknown index pressed: ", i)


func toggle_map(editor: Editor, state: bool) -> void:
	editor.minimap_draw = state


func toggle_display_line_numbers(editor: Editor, state: bool) -> void:
	if state:
		#Editor.set_gutter_draw(SPACER_GUTTER, true)
		editor.set_gutter_draw(Gutter.LINE_NUMBER, true)
		editor.update_line_numbers()
	else:
		#Editor.set_gutter_draw(SPACER_GUTTER, false)
		editor.set_gutter_draw(Gutter.LINE_NUMBER, false)


func toggle_line_colors(editor: Editor, on: bool) -> void:
	print("toggling line colors ", on)
	editor.display_line_color = on


func toggle_control_characters(editor: Editor, state: bool) -> void:
	editor.draw_control_chars = state
	editor.draw_spaces = state
	editor.draw_tabs = state


func toggle_highlight_current_line(editor: Editor, state: bool) -> void:
	editor.highlight_current_line = state


func toggle_sync_horizontal_scroll(editor: Editor, state: bool) -> void:
	editor.sync_horizontal_scroll = state


func toggle_history(editor: TextEdit, state: bool) -> void:
	editor.set_gutter_draw(Gutter.HISTORY, state)


### Focus ###



func _on_editor_focus_entered() -> void:
	#print(Editor.name,": Focus entered")
	if popup_menu.is_item_checked(HIGHLIGHT_LINE):
		Editor.highlight_current_line = true


func _on_editor_focus_exited() -> void:
	#print(Editor.name,": Focus exited")
	Editor.highlight_current_line = false
