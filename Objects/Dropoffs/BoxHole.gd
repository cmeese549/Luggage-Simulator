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
	if box.approval_state == Box.ApprovalState.NONE:
		return false
	if is_disposal and box.international == international:
		if box.disposeable or not box.has_valid_destination:
			return box.approval_state == Box.ApprovalState.REJECTED
	elif box.destination == destination and box.international == international:
		if not box.disposeable:
			return box.approval_state == Box.ApprovalState.APPROVED
	return false
