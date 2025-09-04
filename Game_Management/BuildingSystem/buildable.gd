extends Node3D
class_name Buildable

@export var price: float = 10
@onready var money = get_tree().get_first_node_in_group("Money") as Money

var material_index = 0 : set = set_material
var valid_ghost_material : StandardMaterial3D
var invalid_ghost_material : StandardMaterial3D
@export var is_built: bool = false
@export var category: String = "Ground Conveyors"
@export var building_name: String = "4x1 Conveyor"

func get_save_data() -> Dictionary:
	return {}

func load_save_data(_data: Dictionary) -> void:
	pass
	
func die():
	money.make_money(price)
	queue_free()

func _ready():
	create_ghost_materials()
	# Apply the current material index now that we're ready
	if !is_built:
		set_material(material_index)

func create_ghost_materials():
	# Valid placement material (green)
	valid_ghost_material = StandardMaterial3D.new()
	valid_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	valid_ghost_material.albedo_color = Color(0, 1, 0, 0.5)  # Semi-transparent green
	valid_ghost_material.flags_unshaded = true
	
	# Invalid placement material (red)
	invalid_ghost_material = StandardMaterial3D.new()
	invalid_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	invalid_ghost_material.albedo_color = Color(1, 0, 0, 0.5)  # Semi-transparent red
	invalid_ghost_material.flags_unshaded = true
	
func on_object_built():
	is_built = true
	remove_material_overrides(self)

func set_material(index) -> void:	
	if not valid_ghost_material or not invalid_ghost_material:
		create_ghost_materials()
	
	material_index = index
	var material = valid_ghost_material if index == 0 else invalid_ghost_material
	apply_ghost(self, material)
	
func remove_material_overrides(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = null
	
	# Recursively apply to children
	for child in node.get_children():
		remove_material_overrides(child)

func apply_ghost(node: Node, material: StandardMaterial3D):
	if node is MeshInstance3D:
		node.material_override = material
	
	for child in node.get_children():
		apply_ghost(child, material)

func set_destroy_preview(show_preview: bool):
	if not is_built:
		return
		
	if show_preview:
		if not invalid_ghost_material:
			create_ghost_materials()  # Force creation if null
		apply_ghost(self, invalid_ghost_material)
	else:
		remove_material_overrides(self)
		if has_method("generate_visuals"):
			call("generate_visuals")

func serialize_box_queue(_queue: Array[Box]) -> Array[Dictionary]:
	var serialized_queue: Array[Dictionary] = []
	for box in _queue:
		var box_data = box.get_save_data()
		serialized_queue.append(box_data)
	return serialized_queue
