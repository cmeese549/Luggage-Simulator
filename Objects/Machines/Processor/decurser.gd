extends Processor

func process(box: Box) -> void:
	box.cursed = false
	box.set_cursed_visual_state()
