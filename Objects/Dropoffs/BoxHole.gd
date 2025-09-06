extends StaticBody3D

class_name BoxHole

@export var destination: String = "DEN"
@export var international: bool = false
@export var is_disposal: bool = false

@onready var run_orchestrator = get_tree().get_first_node_in_group("RunOrchestrator")
@onready var money: Money = get_tree().get_first_node_in_group("Money")

@onready var rejection_sound : AudioStreamPlayer = $Rejection
@onready var acceptance_sound : AudioStreamPlayer = $Acceptance

func _ready():
	$Label3D.text = destination
	if is_disposal:
		$Label3D.text = "❌"
	if international:
		$Label3D.text += " 🌐"

func _on_deposit_zone_body_entered(body):
	if body is Box:
		var is_legit : bool = check_box_legit(body)
		if is_legit:
			acceptance_sound.pitch_scale = randf_range(0.75, 1.1)
			acceptance_sound.play()
			var total_stickers: int = body.active_qualification_icons.size() + 1
			money.make_money(body.value * total_stickers)
			Events.box_deposited.emit(body.value * total_stickers, body.destination, true)
		else:
			rejection_sound.play()
			Events.box_deposited.emit(body.value * -1, body.destination, false)
			money.make_money(body.value * -1)
		# Notify LevelManager about box processing
		
		if run_orchestrator and run_orchestrator.has_method("on_box_processed"):
			run_orchestrator.on_box_processed(is_legit)
		body.queue_free()

func check_box_legit(box: Box) -> bool:
	#print("=== BOX VALIDATION DEBUG ===")
	#print("Box: dest=", box.destination, " intl=", box.international, " disposable=", box.disposeable, " valid_dest=", box.has_valid_destination, " approval=", box.approval_state)
	#print("Hole: dest=", destination, " intl=", international, " is_disposal=", is_disposal)
	
	if box.approval_state == Box.ApprovalState.NONE:
		#print("REJECTED: Box has no approval state")
		return false
	
	if is_disposal and box.international == international:
		#print("Checking disposal hole logic...")
		if box.disposeable or not box.has_valid_destination:
			if box.approval_state == Box.ApprovalState.REJECTED:
				#print("ACCEPTED: Disposal hole - rejected box with disposable/invalid dest")
				return true
			else:
				#print("REJECTED: Disposal hole - box should be rejected but was approved")
				return false
		else:
			#print("REJECTED: Disposal hole - box is not disposable and has valid destination")
			return false
	elif box.destination == destination and box.international == international:
		#print("Checking regular hole logic...")
		if not box.disposeable:
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
