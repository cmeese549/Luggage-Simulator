extends Node

class_name State

signal transition(new_state_name: String)

func enter(previous_state: String):
	pass

func exit():
	pass

func update(delta: float):
	pass

func physics_update(delta: float):
	pass

func handle_input(event: InputEvent):
	pass
