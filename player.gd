extends CharacterBody3D

class_name Player

@onready var neck = $Neck
@onready var camera = $Neck/Camera3D
@onready var tool_sys : ToolSys = $Neck/Camera3D/ToolSys

@onready var hud : Control = $"../UI/HUD"
@onready var main_menu : Control = $"../UI/MainMenu"

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var mouse_sens = 1

var camera_movement_this_frame : Vector2
var sway_time : float = 0
var bob_time : float = 0
@export var sway_noise : FastNoiseLite

var footstep_cooldown = 0.4
var current_footstep_cooldown = 0.0

var was_just_flying : bool = false
var doing_landing_adjust : bool = false
var landing_sway_adjust_cooldown : float = 0

var ready_to_start_game = true
var game_started = false

func _ready():
	if ready_to_start_game:
		start_game()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func start_game() ->  void:
	if hud != null:
		hud.visible = true
		
	if main_menu != null:
		main_menu.visible = false
	game_started = true
	tool_sys.start_game()

func _unhandled_input(event):
	if ready_to_start_game and !game_started and event is not InputEventMouseMotion:
		start_game()
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
func _input(event: InputEvent) -> void:
	if ready_to_start_game and !game_started and event is not InputEventMouseMotion:
		start_game()
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and game_started:
		if event is InputEventMouseMotion:
			var viewport_transform: Transform2D = get_tree().root.get_final_transform()
			camera_movement_this_frame += event.xformed_by(viewport_transform).relative / 1200
			
func gamepad_aim(delta: float) -> void:
	var axis_vector = Vector2.ZERO
	axis_vector.x = Input.get_action_strength("Look Right") - Input.get_action_strength("Look Left")
	axis_vector.y = Input.get_action_strength("Look Up") - Input.get_action_strength("Look Down")
	if camera_movement_this_frame == Vector2.ZERO and axis_vector != Vector2.ZERO:
		camera_movement_this_frame = axis_vector * 10 * delta * mouse_sens

func _physics_process(delta):
	if !ready_to_start_game:
		return
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		if tool_sys.equipped_tool != null:
			do_jump_sway(delta)
		was_just_flying = true


	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (neck.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
func _process(delta : float) -> void:
	if !ready_to_start_game:
		return
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		gamepad_aim(delta)
		neck.rotate_y(-camera_movement_this_frame.x * mouse_sens)
		camera.rotate_x(-camera_movement_this_frame.y * mouse_sens)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		
	if tool_sys.equipped_tool == null:
		return
		
	var bob_this_frame : Vector2 = Vector2.ZERO
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir != Vector2.ZERO and is_on_floor():
		bob_this_frame = weapon_bob(delta)
		
	if !is_on_floor():
		do_jump_sway(delta)
	else:
		if was_just_flying:
			landing_sway_adjust_cooldown += delta
			reset_jump_sway(delta)
			if landing_sway_adjust_cooldown >= tool_sys.equipped_tool.landing_sway_adjust_time:
				landing_sway_adjust_cooldown = 0
				was_just_flying = false
	
	if camera_movement_this_frame == Vector2.ZERO:
		idle_sway_weapon(delta, bob_this_frame)
	else:
		camera_sway_weapon(delta, bob_this_frame)
		camera_movement_this_frame = Vector2.ZERO
	
func do_jump_sway(delta: float) -> void:
	var tool = tool_sys.equipped_tool
	tool.position.y = lerpf(
		tool.position.y, 
		(tool.position.y - (velocity.y * tool.jump_sway_amount)) * delta, 
		tool.idle_sway_speed
	)
	
func reset_jump_sway(_delta: float) -> void:
	var tool = tool_sys.equipped_tool
	var jump_reset_progress: float = remap(landing_sway_adjust_cooldown, 0, tool.landing_sway_adjust_time, 0, 1)
	tool.position.y = lerpf(
		tool.position.y, 
		tool.jump_overshoot_amount * -1, 
		tool.idle_sway_speed * tool.jump_reset_curve.width_curve.sample(jump_reset_progress) * tool.recentering_force
	)

func weapon_bob(delta: float) -> Vector2:
	var tool = tool_sys.equipped_tool
	bob_time += delta
	if bob_time > 1000000:
		bob_time = 0
	var bob_amount : Vector2 = Vector2.ZERO
	bob_amount.x = sin(bob_time * footstep_cooldown * 22)
	bob_amount.y = abs(cos(bob_time * footstep_cooldown * 22))
	return bob_amount * tool.bob_amount
		
func get_idle_sway(delta: float) -> Vector3:
	var tool = tool_sys.equipped_tool
	var idle_sway_noise : float = get_idle_sway_noise()
	var idle_sway_random_amount : float = idle_sway_noise * tool.idle_sway_speed
	
	sway_time += delta
	if sway_time > 1000000:
		sway_time = 0
		
	var idle_sway : Vector3 = Vector3.ZERO
	idle_sway.x = sin(sway_time * 1.5 + idle_sway_random_amount) * tool.random_sway_amount
	idle_sway.y = sin(sway_time - idle_sway_random_amount) * tool.random_sway_amount
	idle_sway.z = sin(sway_time * 0.75 + idle_sway_random_amount) * tool.random_sway_amount
	return idle_sway
	
func get_idle_sway_noise() -> float:
	var noise_location : float = sway_noise.get_noise_2d(self.global_position.x, self.global_position.y)
	return noise_location
	
func idle_sway_weapon(delta: float, bob_this_frame: Vector2) -> void:
	var idle_sway : Vector3 = get_idle_sway(delta)
	var tool = tool_sys.equipped_tool
	tool.position.x = lerpf(
		tool.position.x, 
		(tool.position.x - (idle_sway.x + bob_this_frame.x)) * delta,
		tool.idle_sway_speed
	)
	tool.position.y = lerpf(
		tool.position.y, 
		(tool.position.y + (idle_sway.y + bob_this_frame.y)) * delta,
		tool.idle_sway_speed
	)
	tool.position.z = lerpf(
		tool.position.z, 
		(tool.position.z + idle_sway.z) * delta, 
		tool.idle_sway_speed
	)
	
func camera_sway_weapon(delta: float, bob_this_frame: Vector2) -> void:
	var tool = tool_sys.equipped_tool
	var movement : Vector2 = (camera_movement_this_frame * 125).clamp(tool.sway_min, tool.sway_max)
	var direction_modifier : float = 1
	var movement_clamp : Vector2 = Vector2(0.0, 0.1)
	var rotation_clamp: Vector2 = Vector2(-25.0, 25.0)
	bob_this_frame = bob_this_frame
	if tool.name == "Scythe":
		if tool.scythe_swinging_from_right:
			direction_modifier = -1
			movement_clamp.x = movement_clamp.y * -1
			movement_clamp.y = 0.0
	tool.position.x = lerpf(
		tool.position.x, 
		(tool.position.x - (bob_this_frame.x)) * delta, 
		tool.idle_sway_speed
	)
	tool.position.y = lerpf(
		tool.position.y, 
		(tool.position.y + (bob_this_frame.y)) * delta, 
		tool.idle_sway_speed
	)
	tool.position.z = lerpf(
		tool.position.z, 
		clamp(movement.x / tool.horizontal_speed, tool.horizontal_range.x, tool.horizontal_range.y),
		tool.idle_sway_speed
	)
