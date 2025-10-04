extends StaticBody3D

class_name BoxHole

@export var destination: Destination
@export var needs_inspection: bool = false
@export var is_disposal: bool = false
@export var disposable_mesh: Mesh = preload("res://Art_Assets/Models/Voxel/OBJ/Factory Bits-3-Sticker1.obj")

@onready var run_orchestrator = get_tree().get_first_node_in_group("RunOrchestrator")
@onready var money: Money = get_tree().get_first_node_in_group("Money")

@onready var rejection_sound : AudioStreamPlayer = $Rejection
@onready var acceptance_sound : AudioStreamPlayer = $Acceptance
@onready var symbol_mesh: MeshInstance3D = $SymbolMesh
@onready var inspection_mesh: MeshInstance3D = $InspectionMesh

var active: bool = false

func _ready():
	set_icon()
	
func set_icon():
	if destination != null:
		symbol_mesh.mesh = destination.symbol_mesh
	else:
		symbol_mesh.mesh = disposable_mesh
	if needs_inspection:
		inspection_mesh.visible = true
	
	if !active:
		symbol_mesh.visible = false
		inspection_mesh.visible = false


func _on_deposit_zone_body_entered(body):
	if body is Box:
		var is_legit : bool = check_box_legit(body)
		if is_legit:
			acceptance_sound.pitch_scale = randf_range(0.75, 1.1)
			acceptance_sound.play()
			var value = ProfileManager.current_profile.calculate_box_value(Economy.config.base_box_value)
			money.make_money(value)
			Events.box_deposited.emit(value, body, true)
		else:
			rejection_sound.play()
			var penalty = Economy.config.base_box_value * Economy.config.penalty_multiplier
			Events.box_deposited.emit(penalty, body, false)
			money.make_money(penalty)
		# Notify LevelManager about box processing
		
		if run_orchestrator and run_orchestrator.has_method("on_box_processed"):
			run_orchestrator.on_box_processed(is_legit)
		body.die(is_legit)

func check_box_legit(box: Box) -> bool:
	#print("=== BOX VALIDATION DEBUG ===")
	#print("Box: dest=", box.destination, " intl=", box.international, " disposable=", box.disposable, " valid_dest=", box.has_valid_destination, " approval=", box.approval_state)
	#print("Hole: dest=", destination, " intl=", international, " is_disposal=", is_disposal)
	
	if box.approval_state == Box.ApprovalState.NONE:
		#print("REJECTED: Box has no approval state")
		return false
		
	if box.cursed:
		#print("REJECTED: Box is cursed")
		return false
	
	if is_disposal and box.needs_inspection == needs_inspection:
		#print("Checking disposal hole logic...")
		if box.disposable or not box.has_valid_destination:
			if box.approval_state == Box.ApprovalState.REJECTED:
				#print("ACCEPTED: Disposal hole - rejected box with disposable/invalid dest")
				return true
			else:
				#print("REJECTED: Disposal hole - box should be rejected but was approved")
				return false
		else:
			#print("REJECTED: Disposal hole - box is not disposable and has valid destination")
			return false
	elif box.destination == destination and box.needs_inspection == needs_inspection:
		#print("Checking regular hole logic...")
		if not box.disposable:
			if box.approval_state == Box.ApprovalState.APPROVED:
				#print("ACCEPTED: Regular hole - approved non-disposable box")
				return true
			else:
				#print("REJECTED: Regular hole - non-disposable box should be approved but was rejected")
				return false
		else:
			#print("REJECTED: Regular hole - disposable box should go to disposal")
			return false
	else:
		#print("REJECTED: Box doesn't match this hole's criteria")
		#print("  - Destination match: ", box.destination == destination)
		#print("  - International match: ", box.international == international)
		return false
