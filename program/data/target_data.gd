class_name TargetData
extends RefCounted


# direct data
var output: String
#var original_added_lines_count: int
#var translations_found_count: int
#var translations_parsed_count: int
var map_names: Array[String]

# full arrays > access by line number
var section: Array[StringName]
var line_parsed_from: Array[int]
var line_icon: Array[int] # Icon

# sections > contains key
var added_sections: Array[StringName]
var edited_sections: Array[StringName]


func _init(line_count: int) -> void:
	output = ""
	section.resize(line_count)
	line_parsed_from.resize(line_count)
	line_icon.resize(line_count)
