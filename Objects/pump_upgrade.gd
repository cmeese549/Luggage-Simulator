extends Node

class_name  pump_upgrade

var upgrade_name: String
var description: String
var price: int
var effect: float
var icon: Texture2D

enum upgrade_type {
	SPEED,
	QUALITY
}
var type: upgrade_type
