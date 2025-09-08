extends CharacterBody3D

class_name Player

@onready var neck = $Neck
@onready var camera : Camera3D = $Neck/Camera3D
@onready var tool_sys : ToolSys = $Neck/Camera3D/ToolSys
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var building_system: BuildingSystem = get_tree().get_first_node_in_group("BuildingSystem")

@onready var hud : Control = $"../../UI/HUD"

@onready var look_at_cast : RayCast3D = $Neck/Camera3D/LookAtCast
@onready var box_cast : RayCast3D = $Neck/Camera3D/BoxCast
@onready var delete_cast : RayCast3D = $Neck/Camera3D/DeleteCast
@onready var eyedropper_cast : RayCast3D = $Neck/Camera3D/EyedropperCast
@onready var item_pickup_range : Area3D = find_child("ItemPickupRange")

var SPEED = 5.0

var rng = RandomNumberGenerator.new()
@onready var pickup_sound : AudioStreamPlayer = $Audio/PickupSound
@onready var interact_sound : AudioStreamPlayer = $Audio/InteractSound
@onready var tool_sound : AudioStreamPlayer = $Audio/ToolSounder
@onready var footstep_sounds : Array[Node] = $Audio/Footsteps/Default.get_children()
@onready var jump_land_sounds : Array[Node] = $Audio/Footsteps/JumpLand.get_children()
@onready var jump_sounds : Array[Node] = $Audio/Footsteps/Jump.get_children()
@onready var skateboard_audio : AudioStreamPlayer = $Audio/Footsteps/Skateboard
@onready var skateboard_fade_audio : AudioStreamPlayer = $Audio/Footsteps/SkateboardFade
@onready var jump_splash_audio : AudioStreamPlayer = $Audio/Footsteps/JumpSplash
@onready var cant_afford : AudioStreamPlayer = $Audio/CantAfford

enum MOVE_TECH {
	NONE,
	ROLLER_SKATES,
	SKATEBOARD
}
var cur_move_tech: MOVE_TECH = MOVE_TECH.NONE

var ready_to_land : bool = true

const JUMP_VELOCITY = 5.2

var slidy: bool = false
var accelartion: float = 3
var deceleration: float = 2
var friction: float = .5

var roller_unlocked = false
var skate_unlocked = false

var mouse_sens = 1

var camera_movement_this_frame : Vector2
var sway_time : float = 0
var bob_time : float = 0
@export var sway_noise : FastNoiseLite

var footstep_cooldown = 0.4
var current_footstep_cooldown = 0

var was_just_flying : bool = false
var doing_landing_adjust : bool = false
var landing_sway_adjust_cooldown : float = 0

@onready var pipejumps : Array[Node] = get_tree().get_nodes_in_group("PipeJump")
var is_piping : bool = false
var ready_to_pipe_again : bool = false
var old_decel : float = 0
var old_speed : float = 0
@onready var halfpipe_zones : Array[Node] = get_tree().get_nodes_in_group("Pipe")
@onready var default_wall_slide_angle : float = wall_min_slide_angle
@onready var default_floor_angle : float = floor_max_angle
var is_in_halfpipe : bool = true
var pipe_landing_velocity : Vector3 = Vector3.ZERO
var plane : Plane

var moved_last_frame : bool = false
var handled_skateboard_stop : bool = false

var inventory : Array[InventoryItem] = []

var held_box: RigidBody3D = null
var box_hold_offset: Vector3 = Vector3(0, -0.25, -2)
var pickup_range: float = 3.0
var box_carry_smoothing: float = 15.0
var currently_highlighted_box: Box = null
var is_rotating_box: bool = false
var box_rotation_speed: float = 1.0  # Adjust sensitivity as needed
var box_original_rotation: Vector3  # Store original rotation for reset
var box_relative_rotation: Vector3 = Vector3.ZERO  # Store box rotation relative to camera
var default_fov: float 
var inspect_fov: float = 60.0   # Narrower FOV for inspect mode (zoomed in)
var camera_attributes: CameraAttributesPractical
var default_dof_enabled: bool = false


var grinding: bool = false
var rail_grind_node = null
@export var grind_rays: Node3D
@onready var grinding_timer = $GrindingTimer

func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	data.cur_move_tech = cur_move_tech
	data.roller_unlocked = roller_unlocked
	data.skate_unlocked = skate_unlocked
	data.global_position = global_position
	data.neck_rotation = neck.rotation
	data.camera_rotation = camera.rotation
	return data

func load_save_data(data: Dictionary) -> void:
	global_position = data.global_position
	neck.rotation = data.neck_rotation
	camera.rotation = data.camera_rotation
	cur_move_tech = data.cur_move_tech
	roller_unlocked = data.roller_unlocked
	skate_unlocked = data.skate_unlocked

func _ready():
	camera.current = true
	default_fov = camera.fov
	camera_attributes = CameraAttributesPractical.new()
	camera.attributes = camera_attributes
	default_dof_enabled = false 
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	update_pipes()
	
	item_pickup_range.area_entered.connect(pickup_item)
	Events.tool_purchased.connect(unlock_new_tool)
	Events.speed_purchased.connect(apply_upgrade)
	
	for stream: Node in jump_land_sounds:
		stream.finished.connect(ready_to_land_again)
		
func update_pipes():
	pipejumps = get_tree().get_nodes_in_group("PipeJump")
	halfpipe_zones = get_tree().get_nodes_in_group("Pipe")
	for pipe: Node in halfpipe_zones:
		if pipe.body_entered.is_connected(enter_pipe):
			pipe.body_entered.disconnect(enter_pipe)
		if pipe.body_exited.is_connected(exit_pipe):
			pipe.body_exited.disconnect(exit_pipe)
		pipe.body_entered.connect(enter_pipe)
		pipe.body_exited.connect(exit_pipe)
	
	for jump: Node in pipejumps:
		if jump.body_entered.is_connected(start_pipe):
			jump.body_entered.disconnect(start_pipe)
		if jump.body_exited.is_connected(stop_pipe):
			jump.body_exited.disconnect(stop_pipe)
		jump.body_entered.connect(start_pipe.bind(jump))
		jump.body_exited.connect(stop_pipe)
	
func pickup_item(area: Area3D) -> void:
	if area.is_in_group("Pickupable"):
		pickup_sound.play()
		var new_item : InventoryItem = InventoryItem.new()
		new_item.item_name = area.get_parent().get_parent().item_name
		new_item.item_icon = area.get_parent().get_parent().item_icon
		new_item.item_description = area.get_parent().get_parent().item_description
		inventory.append(new_item)
		Events.item_pickedup.emit(new_item)
		area.get_parent().get_parent().call_deferred("queue_free")
		
func play_interact_sound() -> void:
	interact_sound.play()
	
func play_tool_sound(stream: AudioStream, volume: float) -> void:
	tool_sound.stream = stream
	tool_sound.volume_db = volume
	tool_sound.play()
	
func check_has_inventory_item(item_name: String) -> bool:
	for item: InventoryItem in inventory:
		if item.item_name == item_name:
			return true
	return false
	
func check_has_tool(tool_name: String) -> bool:
	for tool: tool in tool_sys.tools:
		if tool.tool_name == tool_name and tool.unlocked:
			return true
	if tool_name == "Rollerskates" and roller_unlocked:
		return true
	elif tool_name == "Skateboard" and skate_unlocked:
		return true
	return false
	
func unlock_new_tool(tool: ShopItem) -> void:
	tool_sys.upgrade_tool(tool.item_name)
	
func remove_inventory_items(items: Array[String]) -> void:
	var items_to_remove : Array[InventoryItem] = []
	for item_name: String in items:
		for item: InventoryItem in inventory:
			if item.item_name == item_name:
				items_to_remove.append(item)
	for item: InventoryItem in items_to_remove:
		inventory.erase(item)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event.is_action_pressed("roller"):
		slidy = true
		SPEED = 10
		friction = .5
		accelartion = 3
		deceleration = 2
		roller_unlocked = true
	elif event.is_action_pressed("skate"):
		slidy = true
		SPEED = 20
		friction = .2
		accelartion = 5
		deceleration = 3 
		skate_unlocked = true

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("save_game"):
		if ProfileManager.save_current_run():
			print("Game saved successfully!")
		else:
			print("Failed to save game")
	
	if Input.is_action_just_pressed("load_game"):
		if ProfileManager.load_current_run():
			print("Game loaded successfully!")
		else:
			print("Failed to load game or no save file found")
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			var viewport_transform: Transform2D = get_tree().root.get_final_transform()
			var mouse_delta = event.xformed_by(viewport_transform).relative / 1200
			
			if is_rotating_box and held_box:
				rotate_held_box(mouse_delta)
			else:
				camera_movement_this_frame += mouse_delta
				
			
func gamepad_aim(delta: float) -> void:
	var axis_vector = Vector2.ZERO
	axis_vector.x = Input.get_action_strength("Look Right") - Input.get_action_strength("Look Left")
	axis_vector.y = Input.get_action_strength("Look Up") - Input.get_action_strength("Look Down")
	if camera_movement_this_frame == Vector2.ZERO and axis_vector != Vector2.ZERO:
		if is_rotating_box and held_box:
			rotate_held_box(axis_vector * 10 * delta * mouse_sens)
		else:
			camera_movement_this_frame = axis_vector * 10 * delta * mouse_sens
	
func handle_building_inputs() -> void:
	if Input.is_action_just_pressed("primary"):
		building_system.place_object_at_cursor()
		update_pipes()
	elif Input.is_action_just_pressed("cycle_build_forward"):
		building_system.cycle_selected_object(1)
	elif Input.is_action_just_pressed("cycle_build_backward"):
		building_system.cycle_selected_object(-1)
	elif Input.is_action_just_pressed("rotate_building"):
		building_system.rotate_object(1)
	elif Input.is_action_just_pressed("change_belt_direction"):
		building_system.reverse_belt = !building_system.reverse_belt
	elif Input.is_action_just_pressed("Pause"):
		building_system.toggle_building_mode()
		
func handle_destroy_inputs() -> void:
	if Input.is_action_just_pressed("primary"):
		building_system.destroy_object_at_cursor()
		update_pipes()
	elif Input.is_action_just_pressed("Pause"):
		building_system.toggle_destroy_mode()

func handle_hotkey_inputs() -> void:
	if Input.is_action_just_pressed("hotkey_1") and not Input.is_key_pressed(KEY_CTRL):
		building_system.pressed_hotkey(0)
	elif Input.is_action_just_pressed("hotkey_2") and not Input.is_key_pressed(KEY_CTRL):
		building_system.pressed_hotkey(1)
	elif Input.is_action_just_pressed("hotkey_3") and not Input.is_key_pressed(KEY_CTRL):
		building_system.pressed_hotkey(2)
	elif Input.is_action_just_pressed("hotkey_4") and not Input.is_key_pressed(KEY_CTRL):
		building_system.pressed_hotkey(3)
	elif Input.is_action_just_pressed("hotkey_5") and not Input.is_key_pressed(KEY_CTRL):
		building_system.pressed_hotkey(4)
	elif Input.is_action_just_pressed("hotkey_6") and not Input.is_key_pressed(KEY_CTRL):
		building_system.pressed_hotkey(5)
	elif Input.is_action_just_pressed("hotkey_7") and not Input.is_key_pressed(KEY_CTRL):
		building_system.pressed_hotkey(6)
	elif Input.is_action_just_pressed("hotkey_8") and not Input.is_key_pressed(KEY_CTRL):
		building_system.pressed_hotkey(7)
	elif Input.is_action_just_pressed("hotkey_9") and not Input.is_key_pressed(KEY_CTRL):
		building_system.pressed_hotkey(8)
	elif Input.is_action_just_pressed("hotkey_10") and not Input.is_key_pressed(KEY_CTRL):
		building_system.pressed_hotkey(9)
	elif Input.is_action_just_pressed("set_hotkey_1"):
		building_system.stored_hotkey(0)
	elif Input.is_action_just_pressed("set_hotkey_2"):
		building_system.stored_hotkey(1)
	elif Input.is_action_just_pressed("set_hotkey_3"):
		building_system.stored_hotkey(2)
	elif Input.is_action_just_pressed("set_hotkey_4"):
		building_system.stored_hotkey(3)
	elif Input.is_action_just_pressed("set_hotkey_5"):
		building_system.stored_hotkey(4)
	elif Input.is_action_just_pressed("set_hotkey_6"):
		building_system.stored_hotkey(5)
	elif Input.is_action_just_pressed("set_hotkey_7"):
		building_system.stored_hotkey(6)
	elif Input.is_action_just_pressed("set_hotkey_8"):
		building_system.stored_hotkey(7)
	elif Input.is_action_just_pressed("set_hotkey_9"):
		building_system.stored_hotkey(8)
	elif Input.is_action_just_pressed("set_hotkey_10"):
		building_system.stored_hotkey(9)
	
func _physics_process(delta):
	current_footstep_cooldown -= delta
	
	if is_on_floor() and is_piping and velocity.y <= 0:
		stop_pipe(self)
		
	if (is_on_floor() or is_on_wall()) and !is_piping:
		ready_to_pipe_again = true
	
	# Add the gravity.
	if not is_on_floor() and not grinding:
		if tool_sys.equipped_tool != null:
			do_jump_sway(delta)
		was_just_flying = true
		if not is_on_wall() or !is_in_halfpipe:
			skateboard_audio.stop()
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		do_jump()
		
	if Input.is_action_just_pressed("Build") and not held_box:
		building_system.toggle_building_mode()
		drop_box()
		if !building_system.building_mode_active:
			update_pipes()
	elif Input.is_action_just_pressed("Destroy"):
		building_system.toggle_destroy_mode()
		drop_box()
	
	if Input.is_action_just_pressed("Eyedropper"):
		building_system.select_buildable(building_system.find_buildable_at_position(eyedropper_cast))
	
	if Input.is_action_just_pressed("primary"):
		if !building_system.building_mode_active:
			try_pickup_box()
	elif Input.is_action_just_released("primary"):
		if held_box:
			drop_box()
			if is_rotating_box:
				stop_box_rotation()
			
	if Input.is_action_just_pressed("secondary"):
		if held_box:
			start_box_rotation()
	elif Input.is_action_just_released("secondary"):
		if is_rotating_box:
			stop_box_rotation()

	if not held_box:
		handle_hotkey_inputs()

	if building_system.building_mode_active:
		handle_building_inputs()
	elif building_system.destroy_mode_active:
		handle_destroy_inputs()
	else:
		update_box_highlighting()
		
	if held_box:
		update_held_box_position(delta)
		if Input.is_action_just_pressed("Approve"):
			held_box.set_approval_state(Box.ApprovalState.APPROVED)
		elif Input.is_action_just_pressed("Reject"):
			held_box.set_approval_state(Box.ApprovalState.REJECTED)
		
	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (neck.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if slidy and !is_piping:
		if direction:
			moved_last_frame = true
			if is_on_floor() or (is_on_wall() and is_in_halfpipe):
				handled_skateboard_stop = false
				fade_in_skateboard()
			velocity.x = lerp(velocity.x, direction.x * SPEED, accelartion * delta)
			velocity.z = lerp(velocity.z, direction.z * SPEED, accelartion * delta)
		else:
			if is_on_floor():
				fade_out_skateboard()
			moved_last_frame = false
			velocity.x = lerp(velocity.x, 0.0, deceleration * delta)
			velocity.z = lerp(velocity.z, 0.0, deceleration * delta)
	elif !is_piping:
		if direction:
			if current_footstep_cooldown <= 0 and is_on_floor():
				do_footstep_sound()
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
	#enables midair control in pipe jumps
	else:
		if direction:
			direction = plane.project(direction)
			velocity.x = direction.x * SPEED * 0.3
			velocity.z = direction.z * SPEED * 0.3
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * 0.1)
			velocity.z = move_toward(velocity.z, 0, SPEED * 0.1)
	
	move_and_slide()
	if slidy:
		rail_grinding(delta)

func do_jump():
	velocity.y = JUMP_VELOCITY
	do_jump_sound()
	skateboard_audio.stop()
	skateboard_fade_audio.stop()
	
func start_pipe(body: Node, area: Node) -> void:
	if body != self or is_piping or !slidy or !ready_to_pipe_again:
		return
	ready_to_pipe_again = false
	is_piping = true
	pipe_landing_velocity = velocity
	velocity.y = velocity.length() * 0.675
	plane = Plane(area.global_basis.x.normalized())
	do_jump_sound()
	
func stop_pipe(body: Node) -> void:
	if body != self or !slidy:
		return
	for jump: Node in pipejumps:
		var overlaps : Array = jump.get_overlapping_bodies()
		for overlap in overlaps:
			if overlap.is_in_group("Player"):
				print("Setting new plane")
				plane = Plane(jump.global_basis.x.normalized())
				return
	is_piping = false
	
func enter_pipe(body: Node) -> void:
	if body != self or !slidy:
		return
	wall_min_slide_angle = 0
	floor_max_angle = 0
	old_decel = deceleration
	old_speed = SPEED
	SPEED = 20
	deceleration = 0
	
func exit_pipe(body: Node) -> void:
	if body != self or !slidy:
		return
	for pipe: Node in halfpipe_zones:
		if pipe == null: return
		var overlaps : Array = pipe.get_overlapping_bodies()
		for overlap in overlaps:
			if overlap.is_in_group("Player"):
				return
	wall_min_slide_angle = default_wall_slide_angle
	floor_max_angle = default_floor_angle
	deceleration = old_decel
	SPEED = old_speed

func fade_out_skateboard() -> void:
	skateboard_audio.stop()
	if !skateboard_fade_audio.playing and !handled_skateboard_stop:
		handled_skateboard_stop = true
		skateboard_fade_audio.play()
	
func fade_in_skateboard() -> void:
	if !skateboard_audio.playing:
		skateboard_fade_audio.stop()
		skateboard_audio.play()
	
func do_footstep_sound() -> void:
	var current_sounds : Array[Node] = footstep_sounds
	current_footstep_cooldown = footstep_cooldown
	rng.randomize()
	var step_index = rng.randi_range(0, current_sounds.size() - 1)
	current_sounds[step_index].play()
	

func do_landing_sound() -> void:
	rng.randomize()
	var step_index = rng.randi_range(0, jump_land_sounds.size() - 1)
	jump_land_sounds[step_index].play()
		
func do_jump_sound() -> void:
	rng.randomize()
	var step_index = rng.randi_range(0, jump_sounds.size() - 1)
	jump_sounds[step_index].play()
		
func ready_to_land_again() -> void:
	ready_to_land = true
	
func _process(delta : float) -> void:
	# Local player camera handling
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		gamepad_aim(delta)
		neck.rotate_y(-camera_movement_this_frame.x * mouse_sens)
		camera.rotate_x(-camera_movement_this_frame.y * mouse_sens)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		
	if building_system and (building_system.building_mode_active or building_system.destroy_mode_active):
		building_system.update_cursor_position(look_at_cast)
		
	# Early return if no tool equipped
	if not tool_sys or not tool_sys.equipped_tool:
		camera_movement_this_frame = Vector2.ZERO
		return
		
	var bob_this_frame : Vector2 = Vector2.ZERO
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir != Vector2.ZERO and is_on_floor():
		bob_this_frame = weapon_bob(delta)
		
	if !is_on_floor() and (!is_on_wall() and is_in_halfpipe):
		do_jump_sway(delta)
	else:
		if was_just_flying:
			if ready_to_land: 
				do_landing_sound()
				ready_to_land = false
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

func apply_upgrade(upgrade: ShopItem):
	match upgrade.item_name:
		"Rollerskates":
			slidy = true
			SPEED = 10
			friction = .5
			accelartion = 3
			deceleration = 2
			roller_unlocked = true
		
		"Skateboard":
			slidy = true
			SPEED = 20
			friction = .2
			accelartion = 5
			deceleration = 3 
			skate_unlocked = true

func do_jump_sway(delta: float) -> void:
	if not tool_sys.equipped_tool:
		return
	var _tool = tool_sys.equipped_tool
	_tool.position.y = lerpf(
		_tool.position.y, 
		clampf(((_tool.position.y - (velocity.y * _tool.jump_sway_amount)) * delta), -0.5, 0.5), 
		_tool.idle_sway_speed
	)
	
func reset_jump_sway(_delta: float) -> void:
	if not tool_sys.equipped_tool:
		return
	var _tool = tool_sys.equipped_tool
	var jump_reset_progress: float = remap(landing_sway_adjust_cooldown, 0, _tool.landing_sway_adjust_time, 0, 1)
	_tool.position.y = lerpf(
		_tool.position.y, 
		_tool.jump_overshoot_amount * -1, 
		_tool.idle_sway_speed * _tool.jump_reset_curve.width_curve.sample(jump_reset_progress) * _tool.recentering_force
	)

func weapon_bob(delta: float) -> Vector2:
	if not tool_sys.equipped_tool:
		return Vector2.ZERO
	var _tool = tool_sys.equipped_tool
	bob_time += delta
	if bob_time > 1000000:
		bob_time = 0
	var bob_amount : Vector2 = Vector2.ZERO
	var step_cooldown : float = footstep_cooldown
	bob_amount.x = sin(bob_time * step_cooldown * 22)
	bob_amount.y = abs(cos(bob_time * step_cooldown * 22))
	return bob_amount * _tool.bob_amount
		
func get_idle_sway(delta: float) -> Vector3:
	if not tool_sys.equipped_tool:
		return Vector3.ZERO
	var _tool = tool_sys.equipped_tool
	var idle_sway_noise : float = get_idle_sway_noise()
	var idle_sway_random_amount : float = idle_sway_noise * _tool.idle_sway_speed
	
	sway_time += delta
	if sway_time > 1000000:
		sway_time = 0
		
	var idle_sway : Vector3 = Vector3.ZERO
	idle_sway.x = sin(sway_time * 1.5 + idle_sway_random_amount) * _tool.random_sway_amount
	idle_sway.y = sin(sway_time - idle_sway_random_amount) * _tool.random_sway_amount
	idle_sway.z = sin(sway_time * 0.75 + idle_sway_random_amount) * _tool.random_sway_amount
	return idle_sway
	
func get_idle_sway_noise() -> float:
	var noise_location : float = sway_noise.get_noise_2d(self.global_position.x, self.global_position.y)
	return noise_location
	
func idle_sway_weapon(delta: float, bob_this_frame: Vector2) -> void:
	if not tool_sys.equipped_tool:
		return
	var idle_sway : Vector3 = get_idle_sway(delta)
	var _tool = tool_sys.equipped_tool
	_tool.position.x = lerpf(
		_tool.position.x, 
		(_tool.position.x - (idle_sway.x + bob_this_frame.x)) * delta,
		_tool.idle_sway_speed
	)
	_tool.position.y = lerpf(
		_tool.position.y, 
		(_tool.position.y + (idle_sway.y + bob_this_frame.y)) * delta,
		_tool.idle_sway_speed
	)
	_tool.position.z = lerpf(
		_tool.position.z, 
		(_tool.position.z + idle_sway.z) * delta, 
		_tool.idle_sway_speed
	)
	
func camera_sway_weapon(delta: float, bob_this_frame: Vector2) -> void:
	if not tool_sys.equipped_tool:
		return
	var _tool = tool_sys.equipped_tool
	var movement : Vector2 = (camera_movement_this_frame * 125).clamp(_tool.sway_min, _tool.sway_max)
	var direction_modifier : float = 1
	var movement_clamp : Vector2 = Vector2(0.0, 0.1)
	var rotation_clamp: Vector2 = Vector2(-25.0, 25.0)
	bob_this_frame = bob_this_frame
	if _tool.name == "Scythe":
		if _tool.scythe_swinging_from_right:
			direction_modifier = -1
			movement_clamp.x = movement_clamp.y * -1
			movement_clamp.y = 0.0
	_tool.position.x = lerpf(
		_tool.position.x, 
		(_tool.position.x - (bob_this_frame.x)) * delta, 
		_tool.idle_sway_speed
	)
	_tool.position.y = lerpf(
		_tool.position.y, 
		(_tool.position.y + (bob_this_frame.y)) * delta, 
		_tool.idle_sway_speed
	)
	_tool.position.z = lerpf(
		_tool.position.z, 
		clamp(movement.x / _tool.horizontal_speed, _tool.horizontal_range.x, _tool.horizontal_range.y),
		_tool.idle_sway_speed
	)

func update_fov(value: float) -> void:
	camera.fov = value

func rail_grinding(delta):
	if not grinding and grinding_timer.time_left == 0:
		var grind_ray = get_valid_grind_ray()
		if grind_ray:
			start_grinding(grind_ray.get_collider().owner, delta)
	
	if grinding:
		rail_grind_node.chosen = true
		if not rail_grind_node.direction_selected:
			print("Selecting direction")
			rail_grind_node.forward = is_facing_same_direction(rail_grind_node)
			rail_grind_node.direction_selected = true
		update_grind_position(delta)
		if Input.is_action_pressed("jump"):
			detach_from_rail()

func update_grind_position(delta):
	position = lerp(position, rail_grind_node.global_position + Vector3(0,1,0), delta * 30)

func start_grinding(grind_rail, delta):
	grinding = true
	rail_grind_node = find_nearest_rail_follower(grind_rail)
	rail_grind_node.end_of_rail.connect(detach_from_rail)
	rail_grind_node.move_speed = SPEED
	update_grind_position(delta)

func get_valid_grind_ray():
	if not grind_rays:
		return null
	for grind_ray: RayCast3D in grind_rays.get_children():
		if grind_ray.is_colliding() and grind_ray.get_collider() and grind_ray.get_collider().is_in_group("Rail"):
			return grind_ray
	return null

func find_nearest_rail_follower(rail):
	var min_distance = INF
	var closest_follower = null
	for follower: PathFollow3D in rail.followers:
		var distance = global_position.distance_to(follower.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_follower = follower
	return closest_follower

func is_facing_same_direction(this_rail_grind_node):
	var player_forward = velocity
	var path_follow_forward = this_rail_grind_node.global_basis.z.normalized()
	var dot_result = player_forward.dot(path_follow_forward)
	var result = dot_result < 0.5
	return result

func detach_from_rail():
	print("Detatching from rail")
	grinding = false
	grinding_timer.start()
	rail_grind_node.detach = false
	rail_grind_node.chosen = false
	rail_grind_node.progress = rail_grind_node.origin_point
	if Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() < 1:
		velocity += -neck.global_basis.z.normalized() * 5
	do_jump()

func try_pickup_box():
	if not box_cast.is_colliding():
		return
		
	var collider = box_cast.get_collider()
	if not collider:
		return
		
	# Check if it's a box (RigidBody3D in "Box" group)
	var box_body = collider.owner if collider.owner is RigidBody3D else collider
	if box_body is RigidBody3D and box_body.is_in_group("Box"):
		pickup_box(box_body)

func pickup_box(box: RigidBody3D):
	held_box = box
	box_relative_rotation = box.rotation - neck.rotation
	# Switch to kinematic mode to stop physics
	box.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	held_box = box
	held_box.rotation = Vector3.ZERO
	held_box.set_freeze_enabled(true)
	
	# Disable collision with player to prevent conflicts
	box.set_collision_layer_value(1, false)
	box.set_collision_layer_value(9, false)
	box.set_collision_layer_value(11, false)
	box.set_collision_layer_value(20, false)
	box.set_collision_layer_value(21, false)
	
func drop_box():
	if not held_box:
		return
		
	# Re-enable physics (velocity is already set from camera movement)
	held_box.freeze = false
	held_box.lock_rotation = false
	# Re-enable collision
	held_box.set_collision_layer_value(1, true)
	held_box.set_collision_layer_value(9, true)
	held_box.set_collision_layer_value(11, true)
	held_box.set_collision_layer_value(20, true)
	held_box.set_collision_layer_value(21, true)
	
	held_box = null

func start_box_rotation():
	if not held_box:
		return
	
	is_rotating_box = true
	held_box.freeze = false
	box_original_rotation = held_box.rotation
	held_box.lock_rotation = true
	held_box.angular_velocity = Vector3.ZERO
	
	# Smooth FOV transition to inspect mode
	var tween = create_tween()
	tween.parallel().tween_property(camera, "fov", inspect_fov, 0.2)
	
	# Enable depth of field focused on the box
	if camera_attributes:
		var box_distance = camera.global_position.distance_to(held_box.global_position)
		camera_attributes.dof_blur_far_enabled = true
		camera_attributes.dof_blur_far_distance = box_distance + 0.2  # Blur beyond the box
		camera_attributes.dof_blur_amount = 0.15  # Adjust blur strength
		camera_attributes.dof_blur_far_transition = 1.0  # Smooth transition

func stop_box_rotation():
	is_rotating_box = false
	if held_box:
		held_box.lock_rotation = false
		held_box.freeze = true
	var tween = create_tween()
	tween.parallel().tween_property(camera, "fov", default_fov, 0.2)
	
	# Disable depth of field
	if camera_attributes:
		camera_attributes.dof_blur_far_enabled = default_dof_enabled

func rotate_held_box(mouse_delta: Vector2):
	if not held_box:
		return
	
	# Only use X mouse movement for Y-axis rotation (horizontal spinning)
	var rotation_delta = Vector3(
		0,  # No pitch (X rotation)
		mouse_delta.x * box_rotation_speed,  # Inverted yaw (Y rotation)
		0   # No roll (Z rotation)
	)
	
	# Apply rotation to the relative rotation (not absolute)
	box_relative_rotation += rotation_delta

func update_held_box_position(delta: float):
	if not held_box:
		return
		
	# Store old position to calculate velocity
	var old_position = held_box.global_position
	
	# Calculate target position in front of camera
	var target_position = camera.global_position + camera.global_basis * box_hold_offset
	
	# Always update position - box should follow player even during rotation
	held_box.global_position = held_box.global_position.lerp(target_position, box_carry_smoothing * delta)
	
	# Always make box rotate with camera + any relative rotation from inspect mode
	held_box.rotation = neck.rotation + box_relative_rotation
	
	
	# Calculate and store the velocity from camera movement
	var movement_velocity = (held_box.global_position - old_position) / delta
	var clamped_velocity = movement_velocity.normalized() * 0.005
	clamped_velocity = clamped_velocity.limit_length(1)  # Max speed of 1 unit
	held_box.linear_velocity = clamped_velocity

# Add this function:
func update_box_highlighting():
	var new_highlighted_box: Box = null
	
	# Check if looking at a box
	if box_cast.is_colliding():
		var collider = box_cast.get_collider()
		if collider:
			var box_body = collider.owner if collider.owner is Box else collider
			if box_body is Box and box_body != held_box:  # Don't highlight held box
				new_highlighted_box = box_body
	
	# Update highlighting
	if currently_highlighted_box != new_highlighted_box:
		# Remove old highlight
		if currently_highlighted_box:
			currently_highlighted_box.set_highlighted(false)
		
		# Add new highlight
		currently_highlighted_box = new_highlighted_box
		if currently_highlighted_box:
			currently_highlighted_box.set_highlighted(true)
