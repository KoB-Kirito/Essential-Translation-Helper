class_name SourceData
extends RefCounted


# direct data
var output: String
#var original_removed_lines_count: int
var map_names: Array[String]

# full arrays > access by line number
var section: Array[StringName]
var line_parsed_to: Array[int]
var line_icon: Array[int] # Icon

# sections > contains key
var removed_sections: Array[StringName]
var edited_sections: Array[StringName]


func _init(line_count: int) -> void:
	section.resize(line_count)
	line_parsed_to.resize(line_count)
	line_icon.resize(line_count)
