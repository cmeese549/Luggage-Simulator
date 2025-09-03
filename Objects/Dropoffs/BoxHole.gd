extends Node

class_name BoxHole

@export var destination: String = "DEN"
@export var international: bool = false
@export var is_disposal: bool = false

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
		if check_box_legit(body):
			acceptance_sound.pitch_scale = randf_range(0.75, 1.1)
			acceptance_sound.play()
			%Money.make_money(body.value)
		else:
			rejection_sound.play()
			%Money.make_money(body.value * -1)
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
