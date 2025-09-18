extends Resource

class_name RunSaveData

@export var buildables: Array[Dictionary] = []
@export var boxes: Array[Dictionary] = []
@export var money: Dictionary = {}
@export var run_orchestrator_data: Dictionary = {}
@export var box_spawners: Array[Dictionary] = []
@export var current_day: int = 0

@export var active_multipliers: Dictionary = {}  # The between-day temporary upgrades
