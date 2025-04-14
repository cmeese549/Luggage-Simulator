extends Node

class_name StateMachine

@export var initial_state: State = null
@export var current_state: State = null
var states: Dictionary[String, State] = {}

func _ready():
	if initial_state: current_state = initial_state
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.transition.connect(on_child_transition)
			if current_state == null: current_state = child
	
	current_state.enter("")

func _process(delta):
	current_state.update(delta)

func _physics_process(delta):
	current_state.physics_update(delta)

func _unhandled_input(event: InputEvent):
	current_state.handle_input(event)

func on_child_transition(new_state_name: String):
	var new_state: State = states.get(new_state_name)
	
	if new_state != null:
		if new_state != current_state:
			current_state.exit()
			new_state.enter(current_state.name)
			current_state = new_state
		else:
			push_warning("Trying to change to same state, state: "+new_state_name)
	else:
		push_error("Tring to transition to a state that doesn't exisit: "+new_state_name)
