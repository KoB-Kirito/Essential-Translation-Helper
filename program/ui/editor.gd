class_name Editor
extends TextEdit


@export var UI: UI
@export var OtherEditor: TextEdit

@export_enum("Source", "Target") var SIDE: int

@onready var double_click_timer := %DoubleClickTimer as Timer

var SECTION_DATA: Dictionary:
	get:
		if SIDE == Side.SOURCE:
			return Data.source_section_data
		else:
			return Data.target_section_data

var OTHER_SECTION_DATA: Dictionary:
	get:
		if SIDE == Side.SOURCE:
			return Data.target_section_data
		else:
			return Data.source_section_data



### Menu Bar ###

### Section Selector ###

# offset, if filler entries are added to the menu
const JUMP_INDEX_OFFSET: int = 0

@export var section_button: OptionButton

func _on_section_button_item_selected(index: int) -> void:
	print(name, ": Section selected: ", index)
	
	if index < JUMP_INDEX_OFFSET:
		section_button.select(JUMP_INDEX_OFFSET)
		return
	
	var section = SECTION_DATA.keys()[index - JUMP_INDEX_OFFSET]
	set_line_as_first_visible(SECTION_DATA[section].line)
	set_caret_line(SECTION_DATA[section].line, false)
	
	if section in OTHER_SECTION_DATA:
		OtherEditor.set_line_as_first_visible(OTHER_SECTION_DATA[section].line)
		OtherEditor.set_caret_line(OTHER_SECTION_DATA[section].line)


### Jump Back / Forward ###

@export var last_button: Button
@export var next_button: Button

var caret_current_line: int = 0
var last_jump_line: int = -1
var next_jump_line: int = -1


func update_last_next() -> void:
	#print_debug(name, ": Updating last/next")
	
	# check if there are new lines before
	last_jump_line = -1
	
	if caret_current_line > 2:
		for i in range(caret_current_line - 2, 0, -1):
			if get_line_gutter_metadata(i, Gutter.LINE_TYPE) != LineType.ORIGINAL:
				continue
			
			if get_line_gutter_metadata(i, Gutter.ICON) == Icon.ADDED_LINE or \
					get_line_gutter_metadata(i, Gutter.ICON) == Icon.EDITED_LINE or \
					get_line_gutter_metadata(i, Gutter.ICON) == Icon.REMOVED_SECTION or \
					get_line_gutter_metadata(i, Gutter.ICON) == Icon.REMOVED_LINE:
				last_jump_line = i
				break
	
	# check if there are new lines after
	next_jump_line = -1
		
	if caret_current_line < get_line_count() - 2:
		for i in range(caret_current_line + 1, get_line_count()):
			if get_line_gutter_metadata(i, Gutter.LINE_TYPE) != LineType.ORIGINAL:
				continue
			
			if get_line_gutter_metadata(i, Gutter.ICON) == Icon.ADDED_LINE or \
					get_line_gutter_metadata(i, Gutter.ICON) == Icon.EDITED_LINE or \
					get_line_gutter_metadata(i, Gutter.ICON) == Icon.REMOVED_SECTION or \
					get_line_gutter_metadata(i, Gutter.ICON) == Icon.REMOVED_LINE:
				next_jump_line = i
				break
	
	# set buttons
	
	
	if last_jump_line >= 0:
		last_button.disabled = false
	else:
		last_button.disabled = true
	
	if next_jump_line >= 0:
		next_button.disabled = false
	else:
		next_button.disabled = true


func _on_last_button_pressed() -> void:
	jump_last()

func _on_next_button_pressed() -> void:
	jump_next()


func jump_last() -> void:
	if last_button.disabled:
		return
	
	OtherEditor.center_on_line(try_find_same_line_in_other(last_jump_line), false)
	
	center_on_line(last_jump_line)

func jump_next() -> void:
	if next_button.disabled:
		return
	
	OtherEditor.center_on_line(try_find_same_line_in_other(next_jump_line), false)
	
	center_on_line(next_jump_line)


func center_on_line(line: int, focus: bool = true) -> void:
	if line < 0 or line > get_line_count() - 2:
		push_warning("Trying to center on line out of bounds: ", line)
		return
	
	if get_caret_count() == 0:
		add_caret(line + 1, 0)
		
	else:
		set_caret_column(0)
		set_caret_line(line + 1, false)
	
	set_line_as_center_visible(line)
	
	# select translation line to mark and paste
	select(line + 1, 0, line + 1, get_line(line + 1).length())
	
	if focus:
		if SIDE == Side.TARGET:
			# copy original line, to translate
			DisplayServer.clipboard_set(get_line(line))
			#UI.show_status_message(SIDE, "Copied to clipboard", Color.GREEN, 1.0)
		
		grab_focus()


## -> line number in other editor if found, -1 if not
func try_find_same_line_in_other(line_number: int) -> int:
	# use saved reference data if present
	var ref_line: int = get_line_gutter_metadata(line_number, Gutter.LINE_NUMBER)
	if ref_line > 0:
		print("search used direct ref data")
		return ref_line
	
	var section = get_line_gutter_text(line_number, Gutter.SECTION)
	var current_line_type: int = get_line_gutter_metadata(line_number, Gutter.LINE_TYPE)
	
	# if line is section itself, just match it with other section
	if current_line_type == LineType.SECTION and section in OTHER_SECTION_DATA:
		print("search used section line")
		return OTHER_SECTION_DATA[section].line
	
	# check if block borders other section, then use that section
	var i: int = line_number
	var step: int = +1
	while true:
		# look after, then before
		i += step
		if i > get_line_count() - 1:
			i = line_number
			step = -1
			continue
		if i < 0:
			break
		
		# if section hit, return it if it exists in other editor
		if get_line_gutter_metadata(i, Gutter.LINE_TYPE) == LineType.SECTION:
			section = get_line(i)
			if section in OTHER_SECTION_DATA:
				print("search used border")
				var offset: int = i - line_number
				var t_icon: int = OtherEditor.get_line_gutter_metadata(clampi(OTHER_SECTION_DATA[section].line - offset, 0, OtherEditor.get_line_count() - 1), Gutter.ICON)
				if t_icon != Icon.ADDED_LINE and t_icon != Icon.EDITED_LINE and t_icon != Icon.REMOVED_LINE:
					offset = 0
				return clampi(OTHER_SECTION_DATA[section].line - offset, 0, OtherEditor.get_line_count() - 1)
			# if bordering section is not present, next section will find another one
			break
		
		# block ends
		if get_line_gutter_metadata(i, Gutter.ICON) == Icon.NONE or \
				get_line_gutter_metadata(i, Gutter.ICON) == Icon.TRANSLATED_LINE_FOUND or \
				get_line_gutter_metadata(i, Gutter.ICON) == Icon.TRANSLATED_LINE_PARSED:
			if step > 0:
				# try again in other direction
				i = line_number
				step = -1
				continue
			else:
				# does not border other section
				break
	
	# if not in other editor, try to get a near section and center on that
	if not section in OTHER_SECTION_DATA:
		var section_index: int = SECTION_DATA[section].index
		# get first section after
		for j in range(section_index, SECTION_DATA.size()):
			if SECTION_DATA.keys()[j] in OTHER_SECTION_DATA:
				print("search used near other section after")
				return OTHER_SECTION_DATA[SECTION_DATA.keys()[j]].line
		
		# get first before
		for j in range(section_index, 0, -1):
			if SECTION_DATA.keys()[j] in OTHER_SECTION_DATA:
				print("search used near other section before")
				return OTHER_SECTION_DATA[SECTION_DATA.keys()[j]].line
		
		# don't center if nothing is found
		print("search did not found section nor near section")
		return -1
	
	# section is also in other section data
	
	var section_data := SECTION_DATA[section] as Data.SectionData
	var other_section_data := OTHER_SECTION_DATA[section] as Data.SectionData
	
	# if section is numbered, try to get the same index or a close index
	if section_data.numbered:
		# get number of current selected entry
		var current_number: int
		var checked_line: int = line_number
		while true:
			if get_line_gutter_metadata(checked_line, Gutter.LINE_TYPE) == LineType.INDEX:
				current_number = int(get_line(checked_line))
				break
			checked_line -= 1
			if checked_line < 0:
				push_error("Could not find index in numbered section")
				return -1
		
		# find number, or a close one, in other section
		var type_offset: int = 0
		match current_line_type:
			LineType.ORIGINAL:
				type_offset = 1
			LineType.TRANSLATION:
				type_offset = 2
		var last_number_line: int = other_section_data.line # if empty
		var line: int = other_section_data.line
		while true:
			line += 1
			if line >= OtherEditor.get_line_count():
				push_error("Could not find index in numbered section")
				return -1
			
			print("search used number")
			match OtherEditor.get_line_gutter_metadata(line, Gutter.LINE_TYPE):
				LineType.INDEX:
					var number: int = int(OtherEditor.get_line(line))
					if number >= current_number:
						return line + type_offset
					
					last_number_line = line
				
				LineType.SECTION:
					return last_number_line + type_offset
	
	# look for reference data or
	# search by original line in other section
	# find reference or original line that is not marked
	var original_line: String = get_line(line_number)
	i = line_number
	step = -1
	while get_line_gutter_metadata(i, Gutter.LINE_TYPE) != LineType.ORIGINAL or \
			get_line_gutter_metadata(i, Gutter.ICON) == Icon.ADDED_LINE or \
			get_line_gutter_metadata(i, Gutter.ICON) == Icon.REMOVED_LINE:
		i += step
		if i < 0 or get_line_gutter_metadata(i, Gutter.LINE_TYPE) == LineType.SECTION:
			# search backwards, then flip direction
			i = line_number
			step = +1
			continue
		if i > get_line_count() - 1 or get_line_gutter_metadata(i, Gutter.LINE_TYPE) == LineType.SECTION:
			push_error("No original line found in section that is not marked as added/removed")
			original_line = ""
			break
		
		# use reference if found
		ref_line = get_line_gutter_metadata(i, Gutter.LINE_NUMBER)
		if ref_line > 0:
			print("search used first found ref data")
			return clampi(ref_line - (i - line_number), 0, OtherEditor.get_line_count() - 1)
		
		# save line as the search
		original_line = get_line(i)
		
	# search for original line
	var found_line: int = 0
	if not original_line.is_empty():
		found_line = OtherEditor.search(original_line, TextEdit.SEARCH_MATCH_CASE + TextEdit.SEARCH_WHOLE_WORDS, other_section_data.line, 0).y
	if found_line > 0:
		print("search used near original line: ", i)
		var offset: int = i - line_number
		return clampi(found_line - offset, 0, OtherEditor.get_line_count() - 1)
	
	# return same line number
	print("search used section line number")
	return OtherEditor.section_line_to_global(section, get_line_gutter_metadata(line_number, Gutter.SECTION))

## -> actual line number in editor of section line
func section_line_to_global(section: StringName, section_line: int) -> int:
	if not section in SECTION_DATA:
		return -1
	var output: int = SECTION_DATA[section].line + section_line
	# clamp at end of text
	if output > get_line_count() - 1:
		return get_line_count() - 1
	return output


func _on_done_button_pressed() -> void:
	mark_as_done()


func mark_as_done() -> void:
	if done_button.disabled:
		return
	done_button.disabled = true
	
	if SIDE == Side.SOURCE and get_line_gutter_metadata(caret_current_line, Gutter.LINE_TYPE) == LineType.SECTION:
		mark_whole_section_as_done()
		return
	
	var is_numbered: bool = SECTION_DATA[get_line_gutter_text(caret_current_line, Gutter.SECTION)].numbered
	var original_line: int = caret_current_line
	match get_line_gutter_metadata(caret_current_line, Gutter.LINE_TYPE):
		LineType.INDEX:
			original_line = caret_current_line + 1
		LineType.TRANSLATION:
			original_line = caret_current_line - 1
	
	if SIDE == Side.SOURCE:
		if is_numbered:
			set_line_icon(original_line - 1, Icon.NONE)
			set_line(original_line - 1, "# " + get_line(original_line - 1))
		set_line_icon(original_line, Icon.NONE)
		set_line_icon(original_line + 1, Icon.NONE)
		set_line(original_line, "# " + get_line(original_line))
		set_line(original_line + 1, "# " + get_line(original_line + 1))
		UI.update_source_labels()
		
	else: # Target
		# save persistent
		#if not original_line in Data.target_lines_done:
		#	Data.target_lines_done.append(original_line)
		if not original_line + 1 in Data.target_lines_done:
			Data.target_lines_done.append(original_line + 1)
		
		if is_numbered:
			set_line_icon(original_line - 1, Icon.NONE)
		set_line_icon(original_line, Icon.NONE)
		if get_line(original_line) != get_line(original_line + 1):
			set_line_icon(original_line + 1, Icon.TRANSLATED_LINE_FOUND)
		else:
			set_line_icon(original_line + 1, Icon.NONE)
		UI.update_target_labels()
	
	done_button.disabled = true


func mark_whole_section_as_done() -> void:
	var curr_line: int = caret_current_line
	while true:
		set_line_icon(curr_line, Icon.NONE)
		set_line(curr_line, "# " + get_line(curr_line))
		
		curr_line += 1
		
		if curr_line > get_line_count():
			break
		if get_line_gutter_metadata(curr_line, Gutter.LINE_TYPE) == LineType.SECTION:
			break
	UI.update_source_labels()
	update_last_next()



### Mark ToDo ###

func mark_todo() -> void:
	for line in range(get_line_count()):
		# only translation lines
		if get_line_gutter_metadata(line, Gutter.LINE_TYPE) != LineType.TRANSLATION:
			continue
		
		# only new lines
		if get_line_gutter_metadata(line, Gutter.ICON) != Icon.ADDED_LINE and \
				get_line_gutter_metadata(line, Gutter.ICON) != Icon.EDITED_LINE and \
				get_line_gutter_metadata(line, Gutter.ICON) != Icon.REMOVED_LINE:
			continue
		
		var new_line: String = Settings.mark_new_lines_text + " " + Editor.hex_to_str(line)
		
		# keep var count same
		var original_line: String = get_line(line - 1)
		var open_pos: int = original_line.find("{")
		while open_pos >= 0:
			var close_pos: int = original_line.find("}", open_pos)
			if close_pos < 0:
				break
			new_line += " " + original_line.substr(open_pos, close_pos - open_pos + 1)
			open_pos = original_line.find("{", close_pos)
		
		#TODO: Keep file paths
		
		set_line(line, new_line)


static func hex_to_str(n:int) -> String:
	var new_str := ""
	while n > 0:
		new_str = hex_digit_to_str(n&63) + new_str
		n = n>>6
	return new_str

static func hex_digit_to_str(n:int) -> String:
	match n:
		10:
			return "a"
		11:
			return "b"
		12:
			return "c"
		13:
			return "d"
		14:
			return "e"
		15:
			return "f"
		16:
			return "g"
		17:
			return "h"
		18:
			return "i"
		19:
			return "j"
		20:
			return "k"
		21:
			return "l"
		22:
			return "m"
		23:
			return "n"
		24:
			return "o"
		25:
			return "p"
		26:
			return "q"
		27:
			return "r"
		28:
			return "s"
		29:
			return "t"
		30:
			return "u"
		31:
			return "v"
		32:
			return "w"
		33:
			return "x"
		34:
			return "y"
		35:
			return "z"
		
		36:
			return "A"
		37:
			return "B"
		38:
			return "C"
		39:
			return "D"
		40:
			return "E"
		41:
			return "F"
		42:
			return "G"
		43:
			return "H"
		44:
			return "I"
		45:
			return "J"
		46:
			return "K"
		47:
			return "L"
		48:
			return "M"
		49:
			return "N"
		50:
			return "O"
		51:
			return "P"
		52:
			return "Q"
		53:
			return "R"
		54:
			return "S"
		55:
			return "T"
		56:
			return "U"
		57:
			return "V"
		58:
			return "W"
		59:
			return "X"
		61:
			return "Y"
		62:
			return "Z"
		
		63:
			return "+"
		64:
			return "-"
		65:
			return "!"
		66:
			return "."
		67:
			return ":"
		68:
			return "?"
		69:
			return "="
		70:
			return "$"
		71:
			return "<"
		72:
			return ">"
		
		_:
			return str(n)

### Synchron Scrolling ###

#TODO: get centered line in active, sync by line number of current section with other view
# get_first_visible_line()

#TODO: sync vertical scrolling


# horizontal scrolling

@onready var h_scroll_bar: HScrollBar = get_h_scroll_bar()

var sync_horizontal_scroll: bool = true

func _ready() -> void:
	h_scroll_bar.value_changed.connect(on_scrolling)


func on_scrolling(value: float) -> void:
	if sync_horizontal_scroll:
		OtherEditor.h_scroll_bar.value = value



### Gutter ###

var last_clicked_line: int = 0
var last_clicked_gutter: int = 0


func setup_gutters() -> void:
	# 0 - marking icon
	# icon
	# meta: enum[Icon]
	add_gutter(Gutter.ICON)
	set_gutter_type(Gutter.ICON, GUTTER_TYPE_ICON)
	
	# 1 - line number
	# string = line number
	# meta: int = line this line was parsed from, if parsed
	add_gutter(Gutter.LINE_NUMBER)
	set_gutter_type(Gutter.LINE_NUMBER, GUTTER_TYPE_STRING)
	
	
	# invisible
	
	# 2 - line type
	# string = char representation
	# meta: enum[] = line type
	add_gutter(Gutter.LINE_TYPE)
	set_gutter_type(Gutter.LINE_TYPE, GUTTER_TYPE_STRING)
	set_gutter_draw(Gutter.LINE_TYPE, false)
	
	# 3 - section
	# string = section name
	# meta: int = line number in section
	add_gutter(Gutter.SECTION)
	set_gutter_type(Gutter.SECTION, TextEdit.GUTTER_TYPE_STRING)
	set_gutter_width(Gutter.SECTION, 100)
	set_gutter_draw(Gutter.SECTION, false)
	
	# 4 - history
	# icon = reset icon
	# meta[String] = original line
	add_gutter(Gutter.HISTORY)
	set_gutter_type(Gutter.HISTORY, GUTTER_TYPE_ICON)
	set_gutter_draw(Gutter.HISTORY, false)


## Sets the icon of a line
func set_line_icon(line: int, icon: int) -> void:
	var icon_texture: Texture2D
	match icon:
		Icon.REMOVED_SECTION:
			icon_texture = UI.icon_removed_section
		Icon.EDITED_SECTION:
			icon_texture = UI.icon_edited_section
		Icon.ADDED_SECTION:
			icon_texture = UI.icon_added_section
		
		Icon.REMOVED_LINE:
			icon_texture = UI.icon_removed_line
		Icon.EDITED_LINE:
			icon_texture = UI.icon_edited_line
		Icon.ADDED_LINE:
			icon_texture = UI.icon_added_line
		
		Icon.TRANSLATED_LINE_PARSED:
			icon_texture = UI.icon_translated_line_parsed
		Icon.TRANSLATED_LINE_FOUND:
			icon_texture = UI.icon_translated_line_found
	
	set_line_gutter_icon(line, Gutter.ICON, icon_texture)
	set_line_gutter_metadata(line, Gutter.ICON, icon)
	update_line_color(line, line + 1)


func _on_gutter_clicked(line:int, gutter: int) -> void:
	# debug
	print_debug(get_line_gutter_metadata(line, gutter))
	
	# handle double click
	if line == last_clicked_line and gutter == last_clicked_gutter and not double_click_timer.is_stopped():
		var found_line: int = try_find_same_line_in_other(line)
		if found_line >= 0:
			OtherEditor.center_on_line(found_line, false)
			center_on_line(line)
		return
	double_click_timer.start()
	
	last_clicked_line = line
	last_clicked_gutter = gutter
	
	# first click
	
	match gutter:
		Gutter.ICON, Gutter.LINE_NUMBER, Gutter.LINE_TYPE:
			# select line
			select(line, 0, line, get_line(line).length())
			set_caret_column(0, false)
			set_caret_line(line, false)
		
		Gutter.SECTION:
			pass
		
		Gutter.HISTORY:
			# reset line
			if get_line_gutter_icon(line, Gutter.HISTORY) != null:
				if get_line_gutter_metadata(line, Gutter.HISTORY) != null:
					set_line(line, get_line_gutter_metadata(line, Gutter.HISTORY))
					update_line_history()
					
				else:
					# remove line
					select(line, get_line(line).length(), line - 1, get_line(line - 1).length(), 0)
					delete_selection()



### Line Numbers ###

const CHAR_WIDTH: int = 9
const LINE_NUMBER_MARGIN: int = 9

func update_line_numbers(start_at: int = 0):
	print(name, ": Updating line_numbers")
	
	var line_count: int = get_line_count()
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
	
	set_gutter_width(Gutter.LINE_NUMBER, char_count * CHAR_WIDTH + LINE_NUMBER_MARGIN)
	
	for i in range(start_at, line_count):
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
		set_line_gutter_text(i, Gutter.LINE_NUMBER, get_padding(char_count - i_char_count) + str(i + 1))


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



### Updates ###

@export var update_timer: Timer


func _on_lines_edited(from: int, to: int) -> void:
	if from == to:
		on_line_edited(from)
		
	elif from < to:
		on_lines_added(from, to)
		
	elif from > to:
		if text.length() == 0:
			# editor now empty
			print_debug(name, ": Now empty")
			return
		
		on_lines_removed(to, from - to)


func on_line_edited(line_index: int) -> void:
	print(name, ": Line edited (" + str(line_index) + ")")
	
	#update_line_history()
	update_timer.start()
	
	var line: String = get_line(line_index)
	var was_comment: bool = get_line_gutter_metadata(line_index, Gutter.LINE_TYPE) == LineType.COMMENT
	var is_comment: bool = line.is_empty() or line.begins_with("#")
	if was_comment == is_comment:
		# comment state did not change
		return
	
	update_line_type_and_section(line_index, line_index + 1)
	if display_line_color:
		update_line_color(line_index, line_index + 1)


func on_lines_added(from: int, to: int) -> void:
	print(name, ": Lines added (from: " + str(from) + ", to: " + str(to) + ")")
	
	update_timer.stop()
	
	update_line_numbers(from)
	update_line_type_and_section(from, to + 1)
	update_line_history()
	update_last_next()
	if display_line_color:
		update_line_color(from, to + 1)


func on_lines_removed(from: int, count: int) -> void:
	print(name, ": Lines removed (from: " + str(from) + ", cound: " + str(count) + ")")
	
	update_timer.stop()
	
	update_line_numbers(from)
	update_line_type_and_section(from, from + 1)
	update_line_history()
	update_last_next()
	if display_line_color:
		update_line_color(from, from + 1)


func _on_text_set() -> void:
	print(name, ": Text set")


func _on_text_changed() -> void:
	print(name, ": Text changed")


func _on_caret_changed() -> void:
	var caret_changed_line: bool = get_caret_line() != caret_current_line
	caret_current_line = get_caret_line()
	if not caret_changed_line:
		return
	
	print(name, ": Caret changed line")
	
	var section: String = get_line_gutter_text(caret_current_line, Gutter.SECTION)
	if not section.is_empty() and section in SECTION_DATA:
		section_button.select(SECTION_DATA[section].index)
	
	update_last_next()
	
	# update done button
	if get_line_gutter_metadata(caret_current_line, Gutter.ICON) == Icon.ADDED_LINE or \
			get_line_gutter_metadata(caret_current_line, Gutter.ICON) == Icon.EDITED_LINE or \
			get_line_gutter_metadata(caret_current_line, Gutter.ICON) == Icon.REMOVED_SECTION or \
			get_line_gutter_metadata(caret_current_line, Gutter.ICON) == Icon.REMOVED_LINE:
		done_button.disabled = false
		
		#TODO: highlight diff in current entry
		# (text edit has no native function to highlight text yet)
		# find simple diff algorythm
		# get original line, get matching original line
		# compare
		# highlight (somehow)
		
	else:
		done_button.disabled = true


@export var done_button: Button


## Parses line types and checks integrity. Parses full file if start_at is 0, else up to next section
## Also updates section line number
func update_line_type_and_section(start_at: int, to: int) -> void:
	print(name, ": Updating line type and sections")
	
	var last_line_was_translated: bool = true
	var current_section: String = "#"
	
	var current_line_type: int
	var is_first_line: bool = true
	var numbered: bool = false
	
	var integrity_error: String = ""
	
	# update section line numbers too
	var section_line_number: int = -1
	
	# get current state
	if start_at > 0:
		current_section = get_line_gutter_text(start_at - 1, Gutter.SECTION)
		if current_section in SECTION_DATA:
			numbered = SECTION_DATA[current_section].numbered
		is_first_line = false
		section_line_number = start_at - 1
		var last_non_comment_line: int = start_at - 1
		var last_non_comment_line_type: int # LineType
		while true:
			last_non_comment_line_type = get_line_gutter_metadata(last_non_comment_line, Gutter.LINE_TYPE)
			if last_non_comment_line_type != LineType.COMMENT:
				break
			if last_non_comment_line == 0:
				break
			last_non_comment_line -= 1
		match last_non_comment_line_type:
			LineType.INDEX:
				current_line_type = LineType.ORIGINAL
			LineType.ORIGINAL:
				current_line_type = LineType.TRANSLATION
			LineType.TRANSLATION:
				if numbered:
					current_line_type = LineType.INDEX
				else:
					current_line_type = LineType.ORIGINAL
			
			LineType.SECTION:
				current_line_type = LineType.ORIGINAL
				is_first_line = true
	
	for i in range(start_at, get_line_count()):
		var line = get_line(i)
		
		# set section
		section_line_number += 1
		set_line_gutter_text(i, Gutter.SECTION, current_section)
		set_line_gutter_metadata(i, Gutter.SECTION, section_line_number)
		
		# empty or comment
		if line.is_empty() or line.begins_with("#"):
			set_line_gutter_text(i, Gutter.LINE_TYPE, "C")
			set_line_gutter_metadata(i, Gutter.LINE_TYPE, LineType.COMMENT)
			continue
		
		# section
		if line.begins_with("[") and line.ends_with("]"):
			# check last section integrity
			if not last_line_was_translated:
				integrity_error = "Integrity check failed: " + current_section + " does not end with translated line"
			
			if start_at > 0 and i > to:
				# only check until new known section is hit
				break
			
			# set line type
			set_line_gutter_text(i, Gutter.LINE_TYPE, "S")
			set_line_gutter_metadata(i, Gutter.LINE_TYPE, LineType.SECTION)
			
			# set section
			section_line_number = 0
			set_line_gutter_text(i, Gutter.SECTION, line)
			set_line_gutter_metadata(i, Gutter.SECTION, section_line_number)
			
			current_section = line
			last_line_was_translated = true # allow empty sections
			
			is_first_line = true
			numbered = false
			current_line_type = LineType.ORIGINAL # next expected type
			continue
		
		last_line_was_translated = false
		
		# check first line
		if is_first_line:
			is_first_line = false
			if line.is_valid_int():
				numbered = true
				current_line_type = LineType.INDEX
		
		# iterate line type
		match current_line_type:
			LineType.INDEX:
				set_line_gutter_text(i, Gutter.LINE_TYPE, "I")
				set_line_gutter_metadata(i, Gutter.LINE_TYPE, LineType.INDEX)
				current_line_type = LineType.ORIGINAL
			
			LineType.ORIGINAL:
				set_line_gutter_text(i, Gutter.LINE_TYPE, "O")
				set_line_gutter_metadata(i, Gutter.LINE_TYPE, LineType.ORIGINAL)
				current_line_type = LineType.TRANSLATION
				
			LineType.TRANSLATION:
				set_line_gutter_text(i, Gutter.LINE_TYPE, "T")
				set_line_gutter_metadata(i, Gutter.LINE_TYPE, LineType.TRANSLATION)
				
				last_line_was_translated = true
				
				if numbered:
					current_line_type = LineType.INDEX
				else:
					current_line_type = LineType.ORIGINAL
	
	if not last_line_was_translated:
		integrity_error = "Integrity check failed: " + current_section + " does not end with translated line"
	
	if not integrity_error.is_empty():
		set_gutter_draw(Gutter.LINE_TYPE, true)
		UI.show_status_message(SIDE, integrity_error, Color.RED, 30.0)
		
	else:
		set_gutter_draw(Gutter.LINE_TYPE, false)
		UI.clear_status_message(SIDE)

var saved_line_count: int = 0

func update_line_history() -> void:
	print(name, ": Updating line_history")
	
	var found_difference: bool = false
	for line in range(get_line_count()):
		if get_line(line) == get_line_gutter_metadata(line, Gutter.HISTORY):
			set_line_gutter_icon(line, Gutter.HISTORY, null)
			
		else:
			set_line_gutter_icon(line, Gutter.HISTORY, UI.icon_reset)
			found_difference = true
	
	# also look for linecount
	if not found_difference and saved_line_count != get_line_count():
		found_difference = true
	
	if found_difference:
		has_unsaved_changes = true
		save_button.icon = UI.save_blue
		reset_button.show()
	else:
		has_unsaved_changes = false
		save_button.icon = UI.save_grey
		reset_button.hide()


@export var save_button: MenuButton
var has_unsaved_changes: bool = false

func save_line_history() -> void:
	for line in range(get_line_count()):
		set_line_gutter_metadata(line, Gutter.HISTORY, get_line(line))
		set_line_gutter_icon(line, Gutter.HISTORY, null)
	
	has_unsaved_changes = false
	save_button.icon = UI.save_grey
	reset_button.hide()
	
	saved_line_count = get_line_count()
	
	# save gutter state
	saved_gutter_icon.resize(saved_line_count)
	saved_gutter_line.resize(saved_line_count)
	saved_gutter_section.resize(saved_line_count)
	saved_gutter_section_text.resize(saved_line_count)
	
	for i in range(saved_line_count):
		saved_gutter_icon[i] = get_line_gutter_metadata(i, Gutter.ICON)
		saved_gutter_line[i] = get_line_gutter_metadata(i, Gutter.LINE_NUMBER)
		saved_gutter_section[i] = get_line_gutter_metadata(i, Gutter.SECTION)
		saved_gutter_section_text[i] = get_line_gutter_text(i, Gutter.SECTION)

var saved_gutter_icon: Array[int]
var saved_gutter_line: Array[int]
var saved_gutter_section: Array[int]
var saved_gutter_section_text: Array[String]


@export var reset_button: Button

func _on_reset_button_pressed() -> void:
	if SIDE == Side.SOURCE:
		text = FileAccess.get_file_as_string(Settings.source_path)
	else:
		text = FileAccess.get_file_as_string(Settings.target_path)
	
	# reload saved data
	for i in range(get_line_count()):
		set_line_icon(i, saved_gutter_icon[i])
		set_line_gutter_metadata(i, Gutter.LINE_NUMBER, saved_gutter_line[i])
		set_line_gutter_metadata(i, Gutter.SECTION, saved_gutter_section[i])
		set_line_gutter_text(i, Gutter.SECTION, saved_gutter_section_text[i])
	
	# save state again? (should not be neccesary if state now matches old state
	save_line_history()
	if SIDE == Side.SOURCE:
		UI.update_source_labels()
	else:
		UI.update_target_labels()


var display_line_color: bool = false:
	get:
		return display_line_color
	set (value):
		display_line_color = value
		update_line_color(0, get_line_count())

func update_line_color(from: int, to: int) -> void:
	for i in range(from, to):
		var color: Color = Color(0, 0, 0, 0)
		
		if display_line_color:
			if get_line_gutter_metadata(i, Gutter.LINE_TYPE) == LineType.COMMENT:
				color = Color.DIM_GRAY
				
			#elif get_line_gutter_metadata(i, Gutter.LINE_TYPE) == LineType.SECTION:
			#	color = Color.BLACK
				
			else:
				match get_line_gutter_metadata(i, Gutter.ICON):
					Icon.REMOVED_SECTION:
						color = Settings.color_removed_line
					Icon.EDITED_SECTION:
						color = Settings.color_edited_line
					Icon.ADDED_SECTION:
						color = Settings.color_added_line
					
					Icon.REMOVED_LINE:
						color = Settings.color_removed_line
					Icon.EDITED_LINE:
						color = Settings.color_edited_line
					Icon.ADDED_LINE:
						color = Settings.color_added_line
						
					Icon.TRANSLATED_LINE_PARSED:
						color = Settings.color_translation_parsed
					Icon.TRANSLATED_LINE_FOUND:
						color = Settings.color_translation_found
		
		set_line_background_color(i, color)


## For updates that should not occur on every edit
func _on_update_timer_timeout() -> void:
	print(name, ": Update timer timeout")

	update_line_history()


### Status Bar Jump ###

func jump_to_next(icon: int) -> void:
	for i in range(caret_current_line + 1, get_line_count()):
		if get_line_gutter_metadata(i, Gutter.ICON) == icon:
			center_on_line(i - 1, false)
			return
	
	for i in range(0, caret_current_line):
		if get_line_gutter_metadata(i, Gutter.ICON) == icon:
			center_on_line(i - 1, false)
			return
