extends Resource
class_name BoxHoleConfig

@export var destination: Destination
@export var needs_inspection: bool = false  
@export var is_disposal: bool = false
@export var position: Vector3 = Vector3.ZERO
@export var rotation: Vector3 = Vector3.ZERO
@export var value_multiplier: float = 1.0
@export var active: bool = false
@export var activation_day: int = 1
