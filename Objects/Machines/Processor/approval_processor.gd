extends Processor

func process(box: Box) -> void:
	box.set_approval_state(Box.ApprovalState.APPROVED)
