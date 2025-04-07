extends CharacterBody3D

class_name Player

@onready var neck = $Neck
@onready var camera : Camera3D = $Neck/Camera3D
@onready var tool_sys : ToolSys = $Neck/Camera3D/ToolSys
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var hud : Control = $"../UI/HUD"
@onready var main_menu : Control = $"../UI/MainMenu"

@onready var item_pickup_range : Area3D = find_child("ItemPickupRange")

var SPEED = 5.0

var rng = RandomNumberGenerator.new()
@onready var pickup_sound : AudioStreamPlayer = $Audio/PickupSound
@onready var interact_sound : AudioStreamPlayer = $Audio/InteractSound
@onready var tool_sound : AudioStreamPlayer = $Audio/ToolSounder
@onready var sand_footstep_sounds : Array[Node] = $Audio/Footsteps/Sand.get_children()
@onready var water_footstep_sounds : Array[Node] = $Audio/Footsteps/Water.get_children()
@onready var jump_land_sounds : Array[Node] = $Audio/Footsteps/JumpLand.get_children()
@onready var jump_sounds : Array[Node] = $Audio/Footsteps/Jump.get_children()
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

var was_just_in_water: bool = false

var ready_to_start_game = true
var game_started = false

var inventory : Array[InventoryItem] = []

func _ready():
	if ready_to_start_game:
		start_game()
	else:
		if main_menu != null:
			main_menu.visible = true
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	item_pickup_range.area_entered.connect(pickup_item)
	Events.tool_purchased.connect(unlock_new_tool)
	Events.speed_purchased.connect(apply_upgrade)
	
	for stream: Node in jump_land_sounds:
		stream.finished.connect(ready_to_land_again)
	
func start_game() ->  void:
	if hud != null:
		hud.visible = true
		
	if main_menu != null:
		main_menu.visible = false
	game_started = true
	tool_sys.start_game()
	
func pickup_item(area: Area3D) -> void:
	if area.is_in_group("Pickupable"):
		pickup_sound.play()
		var new_item : InventoryItem = InventoryItem.new()
		new_item.item_name = area.get_parent().get_parent().item_name
		new_item.item_icon = area.get_parent().get_parent().item_icon
		new_item.item_description = area.get_parent().get_parent().item_description
		inventory.append(new_item)
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
	if ready_to_start_game and !game_started and event is not InputEventMouseMotion and event is not InputEventJoypadMotion:
		print(event)
		start_game()
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	#if ready_to_start_game and !game_started and event != InputEventMouseMotion and event != InputEventJoypadMotion:
		#start_game()
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
	current_footstep_cooldown -= delta
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if is_in_water() and !was_just_in_water:
		animation_player.play("water_bob")
		animation_player.get_animation("water_bob").loop_mode = Animation.LOOP_LINEAR
		was_just_in_water = true
	
	if !is_in_water() and was_just_in_water:
		animation_player.get_animation("water_bob").loop_mode = Animation.LOOP_NONE
		was_just_in_water = false

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		do_jump_sound()
		if tool_sys.equipped_tool != null:
			do_jump_sway(delta)
		was_just_flying = true
		
	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (neck.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if slidy and !is_in_water():
		if direction:
			#TODO skateboard sounds????
			velocity.x = lerp(velocity.x, direction.x * SPEED, accelartion * delta)
			velocity.z = lerp(velocity.z, direction.z * SPEED, accelartion * delta)
		else:
			velocity.x = lerp(velocity.x, 0.0, deceleration * delta)
			velocity.z = lerp(velocity.z, 0.0, deceleration * delta)
	else:
		if direction:
			if current_footstep_cooldown <= 0 and is_on_floor():
				do_footstep_sound()
				current_footstep_cooldown = footstep_cooldown
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
	
	move_and_slide()


	
func do_footstep_sound() -> void:
	var current_sounds : Array[Node] = sand_footstep_sounds
	if is_in_water():
		current_sounds = water_footstep_sounds
	rng.randomize()
	var step_index = rng.randi_range(0, current_sounds.size() - 1)
	current_sounds[step_index].play()

func do_landing_sound() -> void:
	if !is_in_water():
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
	var _tool = tool_sys.equipped_tool
	_tool.position.y = lerpf(
		_tool.position.y, 
		(_tool.position.y - (velocity.y * _tool.jump_sway_amount)) * delta, 
		_tool.idle_sway_speed
	)
	
func reset_jump_sway(_delta: float) -> void:
	var _tool = tool_sys.equipped_tool
	var jump_reset_progress: float = remap(landing_sway_adjust_cooldown, 0, _tool.landing_sway_adjust_time, 0, 1)
	_tool.position.y = lerpf(
		_tool.position.y, 
		_tool.jump_overshoot_amount * -1, 
		_tool.idle_sway_speed * _tool.jump_reset_curve.width_curve.sample(jump_reset_progress) * _tool.recentering_force
	)

func weapon_bob(delta: float) -> Vector2:
	var _tool = tool_sys.equipped_tool
	bob_time += delta
	if bob_time > 1000000:
		bob_time = 0
	var bob_amount : Vector2 = Vector2.ZERO
	bob_amount.x = sin(bob_time * footstep_cooldown * 22)
	bob_amount.y = abs(cos(bob_time * footstep_cooldown * 22))
	return bob_amount * _tool.bob_amount
		
func get_idle_sway(delta: float) -> Vector3:
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

func is_in_water() -> bool:
	return $WaterDetecter.is_colliding()
