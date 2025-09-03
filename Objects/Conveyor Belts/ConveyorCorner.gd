extends Conveyor

class_name ConveyorCorner

func update_belt_direction_from_rotation(y_rotation: float):
	# Don't call parent - we'll handle directions differently
	pass

func setup_direction_and_physics():
	# Apply forces in world space, not local space
	# Input triangle (bottom right): should move North
	var input_direction = Vector3(1, 0, 0)  # North
	# Output triangle (top left): should move West  
	var output_direction = Vector3(0, 0, 1)  # West
	
	var input_belt = find_child("InputBelt")
	var output_belt = find_child("OutputBelt")
	
	if input_belt:
		var belt_body = input_belt.find_child("Belt")
		if belt_body and belt_body is StaticBody3D:
			# Reset rotation to prevent inheriting parent's rotation
			belt_body.rotation = Vector3.ZERO
			if reversed:
				belt_body.constant_linear_velocity = -input_direction * belt_speed
			else:
				belt_body.constant_linear_velocity = input_direction * belt_speed
	
	if output_belt:
		var belt_body = output_belt.find_child("Belt")
		if belt_body and belt_body is StaticBody3D:
			# Reset rotation to prevent inheriting parent's rotation
			belt_body.rotation = Vector3.ZERO
			if reversed:
				belt_body.constant_linear_velocity = -output_direction * belt_speed
			else:
				belt_body.constant_linear_velocity = output_direction * belt_speed

func apply_belt_directions(input_dir: Vector3, output_dir: Vector3):
	var input_belt = find_child("InputBelt")
	var output_belt = find_child("OutputBelt")
	
	if input_belt:
		var belt_body = input_belt.find_child("Belt")
		if belt_body and belt_body is StaticBody3D:
			belt_body.constant_linear_velocity = input_dir * belt_speed
	
	if output_belt:
		var belt_body = output_belt.find_child("Belt")
		if belt_body and belt_body is StaticBody3D:
			belt_body.constant_linear_velocity = output_dir * belt_speed
			
func set_belt_reversed(is_reversed) -> void:
	reversed = is_reversed
	if is_reversed:
		belt_direction *= -1
		$Label3D.rotation_degrees.y = 180
	else:
		# Restore original direction by making it positive again
		belt_direction = belt_direction.abs() * Vector3(belt_direction.x/abs(belt_direction.x) if belt_direction.x != 0 else 1, 1, 1)
		$Label3D.rotation_degrees.y = 0

func _process(delta):
	if is_ready:
		$Label3D.visible = false
		var uv_speed = belt_speed * delta * 0.1
		uv_offset += uv_speed
		
		# Input belt UV - scroll along its local Z axis (which is rotated in world space)
		if reversed:
			material.uv1_offset = Vector3(0, 0, -uv_offset)
		else:
			material.uv1_offset = Vector3(0, 0, uv_offset)
		
		# Output belt UV - scroll along its local Z axis (which is rotated differently)
		var output_belt = find_child("OutputBelt")
		if output_belt and output_belt.has_meta("belt_material"):
			var output_material = output_belt.get_meta("belt_material")
			if reversed:
				output_material.uv1_offset = Vector3(0, 0, -uv_offset)
			else:
				output_material.uv1_offset = Vector3(0, 0, uv_offset)
