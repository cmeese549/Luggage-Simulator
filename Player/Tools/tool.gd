extends Node3D

class_name tool

@onready var animation_player = $AnimationPlayer

var unlocked: bool = false
var equiped: bool = false
var tool_ready: bool = false
var tool_full: bool = false

@export var capacity: int = 1

func _ready():
	if !animation_player:
		push_error("No animation player on tool: "+name)

func use(is_there_water: bool):
	if !tool_ready:
		#TODO put some rejection noise here
		print("Tool not ready")
	
	if unlocked and equiped and tool_ready:
		tool_ready = false
		if !tool_full:
			if is_there_water:
				animation_player.play("good_fill")
				Events.remove_water.emit(capacity)
			else:
				animation_player.play("bad_fill")
		else:
			animation_player.play("empty")

func unlock():
	unlocked = true
	if "equip" not in animation_player.get_animation_list():
		push_warning(name+" doesn't have an equip animation")
	else:
		animation_player.play("equip")

func equip():
	animation_player.play("equip")
	tool_ready = false

func stow():
	animation_player.play("stow")
	tool_ready = false

func _on_animation_player_animation_finished(anim_name):
	tool_ready = true
	match anim_name:
		"equip":
			equiped = true
		"stow":
			equiped = false
		"good_fill":
			#TODO determine if near and facing water
			tool_full = true
		"empty":
			#TODO determine if near and facing reciptical
			tool_full = false

	
