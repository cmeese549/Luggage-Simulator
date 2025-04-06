extends Node3D

class_name tool

@onready var animation_player = $AnimationPlayer

var unlocked: bool = false
var equiped: bool = false
var tool_ready: bool = false
var tool_full: bool = false

@export var sway_min : Vector2 = Vector2(-30, -30)
@export var sway_max : Vector2 = Vector2(30, 30)
@export var sway_speed_rotation : float = 0.075
@export var sway_amount_rotation : float = 75.0

@export var random_sway_amount : float = 7
@export var idle_sway_rotation_strength : float = 35
@export var idle_sway_speed : float = 0.007

@export var jump_sway_amount : float = 35
@export var landing_sway_adjust_time : float = 0.2
@export var jump_overshoot_amount : float = 0.055
@export var bob_amount : float = 20
@export var jump_reset_curve : Line2D

@export var capacity: int = 1

func _ready():
	if !animation_player:
		push_error("No animation player on tool: "+name)

func use():
	if !tool_ready:
		#TODO put some rejection noise here
		print("Tool not ready")
	
	if unlocked and equiped and tool_ready:
		tool_ready = false
		if !tool_full:
			animation_player.play("fill")
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
		"fill":
			#TODO determine if near and facing water
			tool_full = true
		"empty":
			#TODO determine if near and facing reciptical
			tool_full = false
	
