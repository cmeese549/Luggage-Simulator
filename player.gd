extends CharacterBody3D

@onready var neck = $Neck
@onready var camera = $Neck/Camera3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var mouse_sens = 1

var camera_movement_this_frame : Vector2

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
func _input(event: InputEvent) -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			var viewport_transform: Transform2D = get_tree().root.get_final_transform()
			camera_movement_this_frame += event.xformed_by(viewport_transform).relative / 1200
			
func gamepad_aim(delta: float) -> void:
	var axis_vector = Vector2.ZERO
	axis_vector.x = Input.get_action_strength("Look Right") - Input.get_action_strength("Look Left")
	axis_vector.y = Input.get_action_strength("Look Up") - Input.get_action_strength("Look Down")
	if camera_movement_this_frame == Vector2.ZERO and axis_vector != Vector2.ZERO:
		camera_movement_this_frame = axis_vector * 10 * delta * mouse_sens
		
func _process(delta : float) -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		gamepad_aim(delta)
		neck.rotate_y(-camera_movement_this_frame.x * mouse_sens)
		camera.rotate_x(-camera_movement_this_frame.y * mouse_sens)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	
	if camera_movement_this_frame == Vector2.ZERO:
		#idle_sway_weapon(delta, bob_this_frame)
		pass
	else:
		#camera_sway_weapon(delta, bob_this_frame)
		camera_movement_this_frame = Vector2.ZERO

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

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
