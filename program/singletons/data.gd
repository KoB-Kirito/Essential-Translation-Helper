extends Node
# holds and processes data


signal status_update(status: StringName, processed_lines: int)
signal merged(source: SourceData, target: TargetData)

var working_thread: Thread

var source_file_line_count: int
var target_file_line_count: int

var map_names_translated: bool = false # ToDo: configurable


# section data

class SectionData:
	## index of lines in x_section_lines
	var index: int = 0
	
	## if this section is indexed instead of hash-based
	var numbered: bool = false
	
	## line current_number of this section
	var line: int = 0
	
	## section was found in target file
	var found: bool = false
	
	
	### temp ###
	
	## lines which were found in the source file
	var found_lines: Array[int]
	
	## not found packs
	var not_found_entries: Array[int]
	var not_found_packs: Array[Vector2i] # x = from, y = to

var source_section_data: Dictionary #[StringName, SectionData]
var target_section_data: Dictionary #[StringName, SectionData]

# save outside dictionary for way better performance
var source_section_lines: Array[PackedStringArray]
var target_section_lines: Array[PackedStringArray]


func clear_arrays():
	source_section_lines.clear()
	target_section_lines.clear()
	
	for section in source_section_data:
		source_section_data[section].found_lines.clear()
		source_section_data[section].not_found_entries.clear()
		source_section_data[section].not_found_packs.clear()
	
	for section in target_section_data:
		target_section_data[section].found_lines.clear()
		target_section_data[section].not_found_entries.clear()
		target_section_data[section].not_found_packs.clear()


func parse_lines(lines: PackedStringArray, is_target: bool) -> String:
	# clear old data
	if is_target:
		target_section_data.clear()
		target_section_lines.clear()
	else:
		source_section_data.clear()
		source_section_lines.clear()
	
	var current_section_name: String = "#"
	var current_section_lines: PackedStringArray = PackedStringArray()
	var current_section_data: SectionData = SectionData.new()
	
	var is_first_line: bool = false
	var current_line: int = -1
	
	current_section_data.line = 0
	current_section_data.found = false
	
	for raw_line in lines:
		current_line += 1
		
		# strip line end
		var line = raw_line.strip_edges(false)
		
		if is_first_line:
			is_first_line = false
			if line.is_valid_int(): # same check as compiler
				current_section_data.numbered = true
		
		if line.begins_with("[") and line.ends_with("]"):
			# new section starts
			if is_target:
				target_section_lines.append(current_section_lines.duplicate())
				current_section_data.index = target_section_lines.size() - 1
				target_section_data[current_section_name] = current_section_data
				
			else:
				source_section_lines.append(current_section_lines.duplicate())
				current_section_data.index = source_section_lines.size() - 1
				source_section_data[current_section_name] = current_section_data
			
			current_section_name = line
			current_section_lines.clear()
			current_section_data = SectionData.new()
			current_section_data.line = current_line
			is_first_line = true
			continue
		
		current_section_lines.append(line)
		
	# add last section
	if is_target:
		target_section_lines.append(current_section_lines)
		current_section_data.index = target_section_lines.size() - 1
		target_section_data[current_section_name] = current_section_data
		target_file_line_count = lines.size()
		return "lines " + str(target_file_line_count) + ", sections " + str(target_section_lines.size()) #+ ", translated " + str(translated_count) + "/" + str(english_count)
		
	else:
		source_section_lines.append(current_section_lines)
		current_section_data.index = source_section_lines.size() - 1
		source_section_data[current_section_name] = current_section_data
		source_file_line_count = lines.size()
		return "lines " + str(source_file_line_count) + ", sections " + str(source_section_lines.size()) #+ ", translated " + str(translated_count) + "/" + str(english_count)


func merge() -> void:
	#async_merge()
	working_thread = Thread.new()
	working_thread.start(async_merge, Thread.PRIORITY_HIGH)


func async_merge() -> void:
	### Target ###
	
	var target: TargetData = TargetData.new(target_file_line_count)
	var source: SourceData = SourceData.new(source_file_line_count)
	
	var current_line: int = -1
	
	for section in target_section_data:
		# for each section
		
		# update status
		call_deferred("emit_signal", "status_update", "Parsing target file ...  Processing section " + section + " ..", current_line + 1)
		
		# handle comments before first section
		if section == "#":
			for line in target_section_lines[target_section_data[section].index]:
				# for each line in section
				current_line += 1
				target.section[current_line] = section
				target.output += line + "\n"
			
			continue
		
		# append section name
		current_line += 1
		target.output += section + "\n"
		
		# set section meta for this line
		target.section[current_line] = section
		
		# check if section is new or edited
		var section_is_new: bool = not section in source_section_data
		var old_lines: PackedStringArray
		if section_is_new:
			target.added_sections.append(section)
			target.line_icon[current_line] = Icon.ADDED_SECTION
			
		else:
			old_lines = source_section_lines[source_section_data[section].index]
			target_section_data[section].found = true
			source_section_data[section].found = true
		
		## store found positions in old to be able to check which are left
		var found_positions: Array[int] = []
		
		# check type of section
		var current_line_type: int = LineType.ORIGINAL
		var numbered: bool = target_section_data[section].numbered
		if numbered:
			current_line_type = LineType.INDEX
		
		# to search for the original line
		var current_number: String = ""
		var original_line: String = ""
		
		for line in target_section_lines[target_section_data[section].index]:
			# for each line in section
			current_line += 1
			
			# set section meta
			target.section[current_line] = section
			
			if line.is_empty() or line.begins_with("#"):
				# just ignore comments, they get marked later
				# also stay at current type
				# ToDo: allow custom commands?
				target.output += line + "\n"
				continue
			
			if section_is_new:
				# all lines are new if section is added
				target.line_icon[current_line] = Icon.ADDED_LINE
			
			match current_line_type:
				LineType.INDEX:
					# set next line type
					current_line_type = LineType.ORIGINAL
					
					target.output += line + "\n"
					current_number = line
				
				LineType.ORIGINAL:
					# set next line type
					current_line_type = LineType.TRANSLATION
					
					target.output += line + "\n"
					original_line = line
					
				LineType.TRANSLATION:
					# set next line type
					if numbered:
						current_line_type = LineType.INDEX
					else:
						current_line_type = LineType.ORIGINAL
					
					# handle new section > no need to search
					if section_is_new:
						# look for already added translation though
						if original_line != line and original_line != line.strip_edges().replace("  ", " ") and not Settings.mark_new_lines_text in line: #TODO: Replace through save line state system
							# line doesn't match original line and doesn't contain mark > already translated
							target.line_icon[current_line] = Icon.TRANSLATED_LINE_FOUND
							#target.translations_found_count += 1
							
						else:
							# otherwise this entry is new
							# no need to mark icons, as all lines in new sections are marked already
							#target.original_added_lines_count += 1
							pass
						
						# append line
						target.output += format_new_line(line, current_line, section)
						continue
					
					# search source for original line
					var pos: int = search(old_lines, original_line, numbered, current_number, found_positions, section)
					
					if pos < 0:
						# line does not exist in source file
						
						# check if already translated
						if original_line != line and original_line != line.strip_edges().replace("  ", " ") and not Settings.mark_new_lines_text in line:
							# line doesn't match original line and doesn't contain mark > already translated
							target.line_icon[current_line] = Icon.TRANSLATED_LINE_FOUND
							#target.translations_found_count += 1
							
							target.output += line + "\n"
							continue
						
						# add to edited sections
						if not section in target.edited_sections:
							target.edited_sections.append(section)
						
						if numbered:
							target.line_icon[current_line - 2] = Icon.ADDED_LINE
						target.line_icon[current_line - 1] = Icon.ADDED_LINE
						target.line_icon[current_line] = Icon.ADDED_LINE
						
						#target.original_added_lines_count += 1
						
						target.output += format_new_line(line, current_line, section)
						
					else:
						# line found in source file
						var translated_line := old_lines[pos + 1]
						if translated_line != line:
							target.line_icon[current_line] = Icon.TRANSLATED_LINE_PARSED
							#target.translations_parsed_count += 1
						
						# store where the line is in the source file
						var source_current_line: int = source_section_data[section].line + 1 + pos + 1
						if numbered:
							target.line_parsed_from[current_line - 2] = source_current_line - 2
						target.line_parsed_from[current_line - 1] = source_current_line - 1
						target.line_parsed_from[current_line] = source_current_line
						
						# store where the line is in the target file
						if numbered:
							source.line_parsed_to[source_current_line - 2] = current_line - 2
						source.line_parsed_to[source_current_line - 1] = current_line - 1
						source.line_parsed_to[source_current_line] = current_line
						
						# store found lines of source file
						if numbered:
							found_positions.append(pos - 1)
						found_positions.append(pos)
						found_positions.append(pos + 1)
						
						# use translated line
						target.output += translated_line + "\n"
		
		# after going through all lines in section
		
		if not section_is_new:
			# store to know removed lines in source data
			source_section_data[section].found_lines = found_positions
			
			if numbered:
				continue
			
			### Get edited sections
			# store lines left unfound in this section
			var section_line: int = -1
			var t_current_line: int = target_section_data[section].line
			
			var not_found_entries: Array[int] = []
			var not_found_packs: Array[Vector2i] = []
			var pack_start: int = -1
			
			current_line_type = LineType.ORIGINAL
			if numbered:
				current_line_type = LineType.INDEX
			
			for line in target_section_lines[target_section_data[section].index]:
				section_line += 1
				t_current_line += 1
				
				if line.is_empty() or line.begins_with("#"):
					continue
				
				match current_line_type:
					LineType.INDEX:
						current_line_type = LineType.ORIGINAL
						
					
					LineType.ORIGINAL:
						current_line_type = LineType.TRANSLATION
						if target.line_icon[t_current_line] == Icon.ADDED_LINE:
							not_found_entries.append(section_line)
					
					LineType.TRANSLATION:
						if numbered:
							current_line_type = LineType.INDEX
						else:
							current_line_type = LineType.ORIGINAL
				
				if target.line_icon[t_current_line] == Icon.ADDED_LINE:
					if pack_start < 0:
						# first line of pack
						pack_start = section_line
				elif pack_start >= 0:
					# last was the last line of pack
					# only save if larger than one entry
					if section_line - pack_start > 2:
						not_found_packs.append(Vector2i(pack_start, section_line))
					pack_start = -1
			
			# check at end of section
			if pack_start >= 0:
				# last was the last line of pack
				# only save if larger than one entry
				if section_line - pack_start > 2:
					not_found_packs.append(Vector2i(pack_start, section_line))
			
			target_section_data[section].not_found_entries = not_found_entries
			target_section_data[section].not_found_packs = not_found_packs
	
	# after going through all sections
	
	if Settings.map_name_section in target_section_data:
		target.map_names = get_map_names(target_section_lines[target_section_data[Settings.map_name_section].index], map_names_translated)
	else:
		push_warning("Map name section is missing in target file (" + Settings.map_name_section + ")")
	
	
	### Source ###
	
	current_line = -1
	
	for section in source_section_data:
		# for each section
		
		# update status
		call_deferred("emit_signal", "status_update", "Comparing section " + section + " ..", target_file_line_count + current_line + 1)
		
		# handle comment on top specially
		if section == "#":
			for line in source_section_lines[source_section_data[section].index]:
				# for each line in section
				current_line += 1
				source.section[current_line] = section
				source.output += line + "\n"
			
			continue
		
		# append section name
		current_line += 1
		source.output += section + "\n"
		source.section[current_line] = section
		
		var section_was_removed: bool = not source_section_data[section].found
		if section_was_removed:
			source.removed_sections.append(section)
		
		var current_section_line: int = -1
		
		# setup type of section
		var current_line_type: int = 0
		var numbered: bool = source_section_data[section].numbered
		if numbered:
			current_line_type = 2
		
		for line in source_section_lines[source_section_data[section].index]:
				# for each line in section
				current_line += 1
				current_section_line += 1
				
				source.section[current_line] = section
				
				source.output += line + "\n"
				
				if line.is_empty() or line.begins_with("#"):
					# just ignore comments and empty lines, they get marked later
					# also stay at current type
					# ToDo: allow custom commands?
					continue
				
				if section_was_removed:
					if not line.is_empty():
						source.line_icon[current_line] = Icon.REMOVED_LINE
					
				elif not current_section_line in source_section_data[section].found_lines:
					if not line.is_empty() and source.line_icon[current_line] != Icon.EDITED_LINE:
						source.line_icon[current_line] = Icon.REMOVED_LINE
						
						if not section in source.removed_sections and not section in source.edited_sections:
							source.edited_sections.append(section)
					
					# check if edited
					if numbered:
						match current_line_type:
							0: # original line
								current_line_type = 1
								
							1: # translated line
								current_line_type = 2
								
							2: # current_number
								current_line_type = 0
								
								if source.line_icon[current_line] == Icon.REMOVED_LINE:
									var t_line_number: int = get_number_position(int(line), target_section_lines[target_section_data[section].index])
									if t_line_number >= 0:
										source.line_icon[current_line] = Icon.EDITED_LINE
										source.line_icon[current_line + 1] = Icon.EDITED_LINE
										source.line_icon[current_line + 2] = Icon.EDITED_LINE
										
										var g_t_line_number: int = target_section_data[section].line + 1 + t_line_number
										target.line_icon[g_t_line_number] = Icon.EDITED_LINE
										target.line_icon[g_t_line_number + 1] = Icon.EDITED_LINE
										target.line_icon[g_t_line_number + 2] = Icon.EDITED_LINE
		
		# after going through all lines
		
		if not section_was_removed:
			
			# numbered sections can be aligned easily already
			if numbered:
				pass
			
			
			### Get edited sections
			# store lines left unfound in this section
			var section_line: int = -1
			var t_current_line: int = source_section_data[section].line
			
			var not_found_entries: Array[int] = []
			var not_found_packs: Array[Vector2i] = []
			var pack_start: int = -1
			
			current_line_type = LineType.ORIGINAL
			if numbered:
				current_line_type = LineType.INDEX
			
			for line in source_section_lines[source_section_data[section].index]:
				section_line += 1
				t_current_line += 1
				
				if line.is_empty() or line.begins_with("#"):
					continue
				
				match current_line_type:
					LineType.INDEX:
						current_line_type = LineType.ORIGINAL
						
					
					LineType.ORIGINAL:
						current_line_type = LineType.TRANSLATION
						if source.line_icon[t_current_line] == Icon.REMOVED_LINE:
							not_found_entries.append(section_line)
					
					LineType.TRANSLATION:
						if numbered:
							current_line_type = LineType.INDEX
						else:
							current_line_type = LineType.ORIGINAL
				
				if source.line_icon[t_current_line] == Icon.REMOVED_LINE:
					if pack_start < 0:
						# first line of pack
						pack_start = section_line
				elif pack_start >= 0:
					# last was the last line of pack
					# only save if larger than one entry
					#print(section_line - pack_start - 1)
					if section_line - pack_start > 2:
						not_found_packs.append(Vector2i(pack_start, section_line))
					pack_start = -1
			
			# check at end of section
			if pack_start >= 0:
				# last was the last line of pack
				# only save if larger than one entry
				#print(section_line - pack_start - 1)
				if section_line - pack_start > 2:
					not_found_packs.append(Vector2i(pack_start, section_line))
			
			
			#source_section_data[section].not_found_entries = not_found_entries
			#source_section_data[section].not_found_packs = not_found_packs
			
			
			### Find corresponding not found entries ###
			
			if not_found_entries.is_empty():
				continue
			
			# fit packs together
			var other_packs: Array[Vector2i] = target_section_data[section].not_found_packs
			#printt(section, not_found_packs, other_packs, current_line)
			#printt(section, not_found_entries, target_section_data[section].not_found_entries, not_found_packs, other_packs)
			for s_pack in not_found_packs:
				var matching_pack: Vector2i
				
				for t_pack in other_packs:
					#print("matching " + str(s_pack) + " with " + str(t_pack))
					if s_pack.y - s_pack.x == t_pack.y - t_pack.x:
						# pack length matches
						var j: int = 0
						for i in range(s_pack.x, s_pack.y + 1):
							source.line_parsed_to[source_section_data[section].line + 1 + i] = target_section_data[section].line + 1 + t_pack.x + j
							j += 1
							if i in not_found_entries:
								not_found_entries.erase(i)
						
						j = 0
						for i in range(t_pack.x, t_pack.y + 1):
							target.line_parsed_from[target_section_data[section].line + 1 + i] = source_section_data[section].line + 1 + s_pack.x + j
							j += 1
							if i in target_section_data[section].not_found_entries:
								target_section_data[section].not_found_entries.erase(i)
						
						matching_pack = t_pack
						break
				
				if matching_pack != null:
					other_packs.erase(matching_pack)
			
			# match single entries
			var source_entries: Array[int] = not_found_entries
			var target_entries: Array[int] = target_section_data[section].not_found_entries
			var source_section_strings: PackedStringArray = source_section_lines[source_section_data[section].index]
			var target_section_strings: PackedStringArray = target_section_lines[target_section_data[section].index]
			
			var matches: Array[Vector3i] = match_by_similarity(source_entries, target_entries, source_section_strings, target_section_strings)
			for entry in matches:
				var source_original_line = source_section_data[section].line + 1 + entry.y
				var target_original_line = target_section_data[section].line + 1 + entry.z
				
				# connect entries
				source.line_parsed_to[source_original_line] = target_original_line
				source.line_parsed_to[source_original_line + 1] = target_original_line + 1
				
				target.line_parsed_from[target_original_line] = source_original_line
				target.line_parsed_from[target_original_line + 1] = source_original_line + 1
				
				# mark as edited when quite sure that correlated
				var source_line: String = source_section_strings[entry.y]
				var target_line: String = target_section_strings[entry.z]
				if entry.x < (source_line.length() + target_line.length()) * 0.25:
					source.line_icon[source_original_line] = Icon.EDITED_LINE
					source.line_icon[source_original_line + 1] = Icon.EDITED_LINE
					
					target.line_icon[target_original_line] = Icon.EDITED_LINE
					target.line_icon[target_original_line + 1] = Icon.EDITED_LINE
	
	if Settings.map_name_section in source_section_data:
		source.map_names = get_map_names(source_section_lines[source_section_data[Settings.map_name_section].index], map_names_translated)
	else:
		push_warning("Map name section is missing in source file (" + Settings.map_name_section + ")")
	
	# free memory
	clear_arrays()
	
	# update status
	call_deferred("emit_signal", "status_update", "Building output ...", source_file_line_count + target_file_line_count)
	await get_tree().create_timer(0.5).timeout
	
	#print("merged..")
	call_deferred("emit_signal", "merged", source, target)


## -1 = does not exist
func get_number_position(number: int, section_lines: PackedStringArray) -> int:
	var current_line_type: int = LineType.INDEX
	var line_index: int = -1
	for line in section_lines:
		line_index += 1
		if line.is_empty() or line.begins_with("#"):
			continue
		match current_line_type:
			LineType.INDEX:
				current_line_type = LineType.ORIGINAL
				if not line.is_valid_int():
					push_error(line, " is not a number")
					return -1
				if int(line) == number:
					return line_index
				if int(line) > number:
					return -1
			
			LineType.ORIGINAL:
				current_line_type = LineType.TRANSLATION
			LineType.TRANSLATION:
				current_line_type = LineType.INDEX
	
	return -1


func match_by_similarity(string_positions_a: Array[int], string_positions_b: Array[int], strings_a: PackedStringArray, strings_b: PackedStringArray) -> Array[Vector3i]:
	var distances: Array[Vector3i] = [] # x = distance, y = pos_a, z = pos_b
	
	# match all strings
	for pos_a in string_positions_a:
		var string_a: String = strings_a[pos_a]
		
		for pos_b in string_positions_b:
			var string_b: String = strings_b[pos_b]
			var distance: int = get_string_distance(string_a, string_b)
			distances.append(Vector3i(distance, pos_a, pos_b))
	
	# sort best matches
	distances.sort_custom(func(a, b): return a.x < b.x)
	#print(distances)
	
	var matches: Array[Vector3i] = []
	while matches.size() < string_positions_a.size() and matches.size() < string_positions_b.size():
		var best_match: Vector3i = distances[0]
		matches.append(best_match)
		
		if distances.size() > 1:
			# clear remaining entries from already added values
			var to_erase: Array[int] = [0]
			for i in range(1, distances.size()):
				if distances[i].y == best_match.y or distances[i].z == best_match.z:
					to_erase.append(i)
			for i in range(0, to_erase.size(), -1):
				distances.remove_at(to_erase[i])
	
	return matches


## Damerau Levenshtein
## Calculates the amount of steps of insertions, deletions, substitutions and transpositions needed to get from one string to another
## "max_length_diff": Calculation is skipped if the length difference of the strings exceeds this amount. In that case the length difference will be returned
func get_string_distance(str_1: String, str_2: String, max_length_diff: int = 0) -> int:
	if str_1.is_empty():
		if str_2.is_empty():
			return 0
		return str_2.length()
	if str_2.is_empty():
		return str_1.length()
	
	if max_length_diff > 0:
		var lengthDiff = absi(str_1.length() - str_2.length())
		if lengthDiff > max_length_diff:
			return lengthDiff
	
	if str_1 == str_2:
		return 0
	
	#TODO: 2d-arrays are quite slow in gdscript
	var matrix: Array[Array] = []
	matrix.resize(str_1.length() + 1)
	for i in range(matrix.size()):
		var inner_array: Array[int] = []
		inner_array.resize(str_2.length() + 1)
		matrix[i] = inner_array
	
	for i in range(1, str_1.length() + 1):
		matrix[i][0] = i
		
		for j in range(1, str_2.length() + 1):
			if i == 1:
				matrix[0][j] = j
			
			var pos_not_equal: int = str_2[j - 1] != str_1[i - 1]
			
			matrix[i][j] = mini(mini(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1), matrix[i - 1][j - 1] + pos_not_equal)
			
			if i > 1 and \
					j > 1 and \
					str_1[i - 1] == str_2[j - 2] and \
					str_1[i - 2] == str_2[j - 1]:
				matrix[i][j] = mini(matrix[i][j], matrix[i - 2][j - 2] + pos_not_equal)
	
	return matrix[str_1.length()][str_2.length()]


func format_new_line(line: String, current_line: int, current_section: StringName) -> String:
	if Settings.mark_new_lines:
		return Settings.mark_new_lines_text.replace("{line}", str(current_line)).replace("{section}", current_section) + "\n"
	else:
		return line + "\n"


func search(lines: PackedStringArray, line: String, numbered: bool, current_number: String, found_already: Array[int], section: StringName) -> int:
	# setup type of section
	var current_line_type: int = 0
	if numbered:
		current_line_type = 2
	
	for i in range(lines.size()):
		match current_line_type:
			0: # original line
				# set next line type
				current_line_type = 1
				
				# use current_number if numbered section
				if numbered:
					continue
				
				# compare
				if lines[i] == line:
					if i in found_already:
						push_error("section ", section, ": Found an identical line in this section already: ", line,
								"\nThis means this key is not unique in this section and the importer will drop one of the translations. If you need them translated differently, talk to the devs to get the key changed.")
						continue
					
					# found
					return i
				
			1: # translated line
				# set next line type
				if numbered:
					current_line_type = 2
				else:
					current_line_type = 0
				
			2: # numbering line
				# set next line type
				current_line_type = 0
				
				# compare
				if lines[i] == current_number and lines[i + 1] == line:
					return i + 1
	
	return -1


func get_map_names(map_names_section: PackedStringArray, translated: bool) -> Array[String]:
	var output: Array[String] = ["(Shared)"]
	var current_index: int
	var current_line_type: int = LineType.INDEX
	
	for line in map_names_section:
		# ignore comments and empty lines
		if line.is_empty() or line.begins_with("#"):
			continue
		
		match current_line_type:
			LineType.INDEX:
				if not line.is_valid_int():
					call_deferred("emit_signal", "status_update", "ERROR: Map name section is not numbered (Wrong section?)", 0)
				
				current_index = int(line)
				output.resize(current_index + 1)
				current_line_type = LineType.ORIGINAL
			
			LineType.ORIGINAL:
				if not translated:
					output[current_index] = line
				current_line_type = LineType.TRANSLATION
			
			LineType.TRANSLATION:
				if translated:
					output[current_index] = line
				current_line_type = LineType.INDEX
	
	return output
