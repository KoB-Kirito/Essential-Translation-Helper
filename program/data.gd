extends Node


signal status_update(status: StringName)
signal merged(target_output: String, added_sections: Array[StringName], edited_sections: Array[StringName], added_lines: Array[int], translated_lines: Array[int],
		source_output: String, source_removed_sections: Array[StringName], source_edited_sections: Array[StringName], source_removed_lines: Array[int])

# section data
## int - index of lines in x_sections
const INDEX: StringName = "section_index"
## bool - if this section is numbered
const NUMBERED: StringName = "section_numbered"
## int - line number of this section
const LINE: StringName = "section_line"
## bool - section was found in target file
const FOUND: StringName = "section_found"
## Array[int] - lines which were found in the source file
const FOUND_LINES: StringName = "section_removed_lines"

var old_section_data: Dictionary
var old_sections: Array[PackedStringArray]
var old_line_count: int

var new_section_data: Dictionary
var new_sections: Array[PackedStringArray]
var new_line_count: int


func clear():
	old_sections.clear()
	new_sections.clear()


func parse_lines(lines: Array[String], new_intl: bool) -> String:
	var current_section_name: String = "#"
	var current_section: PackedStringArray = []
	var current_data: Dictionary = {}
	
	var first_line: bool = false
	var current_line: int = -1
	
	current_data[LINE] = 0
	current_data[FOUND] = false
	
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
	# build target output
	var target_output: String = ""
	var added_lines: Array[int] = []
	var added_sections: Array[StringName] = []
	var edited_sections: Array[StringName] = []
	var translated_lines: Array[int] = []
	
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
				target_output += line + "\n"
			
			continue
		
		# append section name
		current_line += 1
		target_output += section + "\n"
		
		# check if section is new
		var added_section: bool = not section in old_section_data
		var old_lines: PackedStringArray
		if added_section:
			added_sections.append(section)
			added_lines.append(current_line)
		else:
			old_lines = old_sections[old_section_data[section][INDEX]]
			old_section_data[section][FOUND] = true
		
		## store found positions in old to be able to check which are left
		var found_positions: Array[int] = []
		
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
					target_output += line + "\n"
					
					# set next line type
					current_line_type = 1
					
				1: # translated line
					if added_section:
						# whole section is new, no need to search
						if Globals.mark_new_lines:
							target_output += "NewLine\n"
						else:
							target_output += line + "\n"
						
					else:
						var pos = old_lines.find(line)
						if pos < 0:
							# line does not exist in source file
							if not section in edited_sections:
								edited_sections.append(section)
							
							if numbered:
								added_lines.append(current_line - 2)
							added_lines.append(current_line - 1)
							added_lines.append(current_line)
							
							if Globals.mark_new_lines:
								target_output += "NewLine\n"
							else:
								target_output += line + "\n"
							
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
							target_output += translated_line + "\n"
					
					# set next line type
					if numbered:
						current_line_type = 2
					else:
						current_line_type = 0
					
				2: # numbering line
					target_output += line + "\n"
					
					# set next line type
					current_line_type = 0
		
		if not added_section:
			# store to know removed lines in old data
			old_section_data[section][FOUND_LINES] = found_positions
	
	
	# build source
	var source_output: String
	var source_removed_sections: Array[StringName]
	var source_edited_sections: Array[StringName]
	var source_removed_lines: Array[int]
	
	current_line = -1
	
	for section in old_section_data:
		# for each section
		
		# update status
		call_deferred("emit_signal", "status_update", "Processing source " + section + " ..")
		
		# handle comment on top specially
		if section == "#":
			for line in old_sections[old_section_data[section][INDEX]]:
				# for each line in section
				current_line += 1
				source_output += line + "\n"
			
			continue
		
		# append section name
		current_line += 1
		source_output += section + "\n"
		
		var removed_section: bool = old_section_data[section][FOUND]
		if removed_section:
			source_removed_sections.append(section)
		
		var current_section_line: int = -1
		
		for line in old_sections[old_section_data[section][INDEX]]:
				# for each line in section
				current_line += 1
				current_section_line += 1
				
				source_output += line + "\n"
				
				if removed_section:
					source_removed_lines.append(current_line)
					
				elif not current_section_line in old_section_data[section][FOUND_LINES]:
					source_removed_lines.append(current_line)
					if not section in source_removed_sections:
						source_edited_sections.append(section)
	
	# free memory
	clear()
	
	# update status
	call_deferred("emit_signal", "status_update", "Building output ..")
	await get_tree().create_timer(0.5).timeout
	
	#print("merged..")
	call_deferred("emit_signal", "merged",
			target_output, added_sections, edited_sections, added_lines, translated_lines,
			source_output, source_removed_sections, source_edited_sections, source_removed_lines)
