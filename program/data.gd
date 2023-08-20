extends Node


signal status_update(status: StringName)
signal merged(output: String, added_sections: Array[StringName], added_lines: Array[int], translated_lines: Array[int])

# section data
## int - index of lines in x_sections
const INDEX: StringName = "section_index"
## bool - if this section is numbered
const NUMBERED: StringName = "section_numbered"
## int - line number of this section
const LINE: StringName = "section_line"
## Array[int] - lines which were not found in the new file
const REMOVED_LINES: StringName = "section_removed_lines"

var old_section_data: Dictionary
var old_sections: Array[PackedStringArray]
var old_line_count: int

var new_section_data: Dictionary
var new_sections: Array[PackedStringArray]
var new_line_count: int

var last_directory: String
var mark_new_lines: bool = true


func parse_lines(lines: Array[String], new_intl: bool) -> String:
	var current_section_name: String = "#"
	var current_section: PackedStringArray
	var current_data: Dictionary
	
	var first_line: bool = false
	var current_line: int = -1
	
	current_data[LINE] = 0
	
	for line in lines:
		current_line += 1
		
		if first_line:
			first_line = false
			if line.is_valid_int() and lines.size() >= current_line + 3 and lines[current_line + 3].is_valid_int(): # safe enough?
				print(current_section_name, " is numbered")
				current_data[NUMBERED] = true
			else:
				current_data[NUMBERED] = false
		
		if line.begins_with("[") and line.ends_with("]"):
			# new section starts
			if new_intl:
				new_sections.append(current_section.duplicate())
				current_data[INDEX] = new_sections.size() - 1
				new_section_data[current_section_name] = current_data.duplicate()
				
			else:
				old_sections.append(current_section.duplicate())
				current_data[INDEX] = old_sections.size() - 1
				old_section_data[current_section_name] = current_data.duplicate()
			
			current_section_name = line
			current_section.clear()
			current_data.clear()
			current_data[LINE] = current_line
			first_line = true
			continue
		
		current_section.append(line)
	
	# add last section
	if new_intl:
		new_sections.append(current_section)
		current_data[INDEX] = new_sections.size() - 1
		new_section_data[current_section_name] = current_data
		new_line_count = lines.size()
		return "lines " + str(new_line_count) + ", sections " + str(new_sections.size()) #+ ", translated " + str(translated_count) + "/" + str(english_count)
		
	else:
		old_sections.append(current_section)
		current_data[INDEX] = old_sections.size() - 1
		old_section_data[current_section_name] = current_data
		old_line_count = lines.size()
		return "lines " + str(old_line_count) + ", sections " + str(old_sections.size()) #+ ", translated " + str(translated_count) + "/" + str(english_count)


var thread: Thread
func merge():
	#async_merge()
	thread = Thread.new()
	thread.start(async_merge, Thread.PRIORITY_HIGH)


func async_merge():
	var text: String = ""
	var added_lines: Array[int]
	var added_sections: Array[StringName]
	var translated_lines: Array[int]
	
	var current_line: int = -1
	
	for section in new_section_data:
		# for each section
		
		# update status
		call_deferred("emit_signal", "status_update", "Processing section " + section + " ..")
		
		# handle comment on top specially
		if section == "#":
			for line in new_sections[new_section_data[section][INDEX]]:
				# for each line in section
				current_line += 1
				text += line + "\n"
			
			continue
		
		# append section name
		current_line += 1
		text += section + "\n"
		
		# check if section is new
		var added_section: bool = not section in old_section_data
		var old_lines: PackedStringArray
		if added_section:
			added_sections.append(section)
			added_lines.append(current_line)
		else:
			old_lines = old_sections[old_section_data[section][INDEX]]
		
		## store found positions in old to be able to check which are left
		var found_positions: Array[int]
		
		# setup type of section
		var current_line_type: int = 0
		var numbered: bool = new_section_data[section][NUMBERED]
		if numbered:
			print(section, " is numbered")
			current_line_type = 2
		
		for line in new_sections[new_section_data[section][INDEX]]:
			# for each line in section
			current_line += 1
			
			if added_section:
				added_lines.append(current_line)
			
			match current_line_type:
				0: # original line
					text += line + "\n"
					
					# set next line type
					current_line_type = 1
					
				1: # translated line
					if added_section:
						# whole section is new, no need to search
						if mark_new_lines:
							text += "NewLine\n"
						else:
							text += line + "\n"
						
					else:
						var pos = old_lines.find(line)
						if pos < 0:
							# line does not exist in source file
							if numbered:
								added_lines.append(current_line - 2)
							added_lines.append(current_line - 1)
							added_lines.append(current_line)
							
							if mark_new_lines:
								text += "NewLine\n"
							else:
								text += line + "\n"
							
						else:
							# line found in source file
							var translated_line := old_lines[pos + 1]
							if translated_line != line:
								translated_lines.append(current_line)
							
							# mark as found
							if numbered:
								found_positions.append(pos - 1)
							found_positions.append(pos)
							found_positions.append(pos + 1)
							
							# use translated line
							text += translated_line + "\n"
					
					# set next line type
					if numbered:
						current_line_type = 2
					else:
						current_line_type = 0
					
				2: # numbering line
					text += line + "\n"
					
					# set next line type
					current_line_type = 0
		
		if not added_section:
			# store removed lines in old data
			var removed_lines: Array[int] = []
			for i in range(old_lines.size()):
				if not i in found_positions:
					removed_lines.append(i)
			old_section_data[section][REMOVED_LINES] = removed_lines
		
	
	# update status
	call_deferred("emit_signal", "status_update", "Building output ..")
	await get_tree().create_timer(0.5).timeout
	
	#print("merged..")
	call_deferred("emit_signal", "merged", text, added_sections, added_lines, translated_lines)
