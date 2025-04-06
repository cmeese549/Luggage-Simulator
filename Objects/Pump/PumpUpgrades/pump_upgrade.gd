extends Resource

class_name  pump_upgrade

@export var upgrade_name: String
@export var description: String
@export var price: int
@export var effect: float
@export var icon: Texture2D
@export var model: PackedScene

enum upgrade_type {
	SPEED,
	QUALITY
}
@export var type: upgrade_type
