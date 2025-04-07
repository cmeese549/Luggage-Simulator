extends RichTextLabel

class_name DialogueBox

var content : RichTextLabel = self
@onready var type_timer : Timer = $"../../../../../../TypeTimer"
@onready var pause_timer : Timer = $"../../../../../../DialoguePauser/PauseTimer"
@onready var voice : AudioStreamPlayer = $"../../../../../../DialogueBloop"
@onready var pauser : DialoguePauser = $"../../../../../../DialoguePauser"

signal dialogue_finished

var test = "Welcome to my shop asshole.  I am [b]UNCLE UPGRADE[/b], the Great Sage...{pause=1.0}... of [rainbow]Upgrades.[/rainbow]"

func _ready() -> void:
	type_timer.timeout.connect(render_next_character)
	voice.finished.connect(play_bloop)
	pause_timer.timeout.connect(unpause)
	pauser.pause_requested.connect(pause)
	
func skip_dialogue() -> void:
	type_timer.stop()
	self.content.visible_characters = self.content.text.length()
	
func stop_dialogue() -> void:
	dialogue_finished.emit()
	voice.stop()
	type_timer.stop()
	pause_timer.stop()
	
func is_message_fully_visible() -> bool:
	return content.visible_characters >= content.text.length() - 1
	
func render_dialogue(dialogue: String) -> void:
	content.text = pauser.extract_pauses_from_dialogue(dialogue)
	content.visible_characters = 0
	type_timer.start()
	play_bloop()
	
func render_next_character() -> void:
	if !pause_timer.is_stopped():
		return
	pauser.check_at_position(content.visible_characters)
	if content.visible_characters < content.get_total_character_count():
		content.visible_characters += 1
		type_timer.start()
	else:
		content.visible_characters = content.text.length()
		dialogue_finished.emit()
		voice.stop()
		type_timer.stop()
		
func play_bloop() -> void:
	if content.visible_characters < content.get_total_character_count():
		voice.pitch_scale = randf_range(0.95, 1.08)
		voice.play()
		
func pause(pause_duration : float) -> void:
	type_timer.stop()
	voice.stop()
	pause_timer.wait_time = pause_duration
	pause_timer.start()

func unpause() -> void:
	play_bloop()
	type_timer.start()
