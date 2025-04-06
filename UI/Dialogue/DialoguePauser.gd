extends Node

class_name DialoguePauser

var pauses : Array[DialoguePause] = []

var pause_pattern : String = "({pause=\\d([.]\\d+)?[}])"
var pause_regex : RegEx = RegEx.new()

signal pause_requested(duration : float)

func _ready() -> void:
	pause_regex.compile(pause_pattern)
	
func extract_pauses_from_dialogue(dialogue: String) -> String:
	pauses = []
	find_pauses(dialogue)
	return extract_tags(dialogue)

func find_pauses(dialogue: String) -> void:
	var search : Array[RegExMatch] = pause_regex.search_all(dialogue)
	for result : RegExMatch in search:
		var tag_string : String = result.get_string()
		var tag_position : int = adjust_position(result.get_start(), dialogue)
		var new_pause : DialoguePause = DialoguePause.new(tag_position, tag_string)
		pauses.append(new_pause)
	
func extract_tags(dialogue: String) -> String:
	var tag_regex : RegEx = RegEx.new()
	tag_regex.compile("({(.*?)})")
	return tag_regex.sub(dialogue, "", true)
	
func check_at_position(position: int) -> void:
	for pause : DialoguePause in pauses:
		if pause.pause_position == position:
			pause_requested.emit(pause.pause_duration)
			
func adjust_position(position: int, dialogue: String) -> int:
	var tag_regex : RegEx = RegEx.new()
	tag_regex.compile("({(.*?)})")
	var new_position : int = position
	var left_of_position : String = dialogue.left(position)
	var all_previous_tags : Array[RegExMatch] = tag_regex.search_all(left_of_position)
	for result: RegExMatch in all_previous_tags:
		new_position -= result.get_string().length()
		
	var bbcode_i_regex : RegEx = RegEx.new()
	var bbcode_e_regex : RegEx = RegEx.new()
	bbcode_i_regex.compile("\\[(?!\\/)(.*?)\\]")
	bbcode_e_regex.compile("\\[\\/(.*?)\\]")
	var all_prev_start_bbcodes : Array[RegExMatch] = bbcode_i_regex.search_all(left_of_position)
	for result : RegExMatch in all_prev_start_bbcodes:
		new_position -= result.get_string().length()
	var all_prev_end_bbcodes : Array[RegExMatch] = bbcode_e_regex.search_all(left_of_position)
	for result : RegExMatch in all_prev_end_bbcodes:
		new_position -= result.get_string().length()
		
	return new_position
