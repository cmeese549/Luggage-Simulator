extends Control

class_name BuildablePreview

@onready var highlight : ColorRect = $SelectedHighlight
@onready var icon: TextureRect = $Icon
@onready var name_label: Label = $Name
@onready var price_label: Label = $Price
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func setup(buildable_instance: Node3D, cached_texture: Texture2D, is_selected: bool):
	name_label.text = buildable_instance.building_name
	price_label.text = "$" + str(roundi(buildable_instance.price))
	icon.texture = cached_texture
	
	if is_selected:
		animation_player.play("fade_selected_highlight")
	else:
		highlight.modulate = Color.from_rgba8(1, 1, 1, 0)
	
