extends Node

var icon_cache: Dictionary = {}

func get_buildable_icon(buildable_scene: PackedScene) -> Texture2D:
	var scene_path = buildable_scene.resource_path
	
	# Return cached version if available
	if icon_cache.has(scene_path):
		return icon_cache[scene_path]
	
	# Generate new icon
	var icon_texture = generate_icon(buildable_scene)
	icon_cache[scene_path] = icon_texture
	
	return icon_texture

func generate_icon(buildable_scene: PackedScene) -> Texture2D:
	var instance = buildable_scene.instantiate()
	var packed_scene = PackedScene.new()
	packed_scene.pack(instance)
	
	var scene_texture = SceneTexture.new()
	scene_texture.scene = packed_scene
	scene_texture.camera_position = Vector3(5, 5, 5)
	var look_at_transform = Transform3D().looking_at(Vector3.ZERO - scene_texture.camera_position, Vector3.UP)
	scene_texture.camera_rotation = look_at_transform.basis.get_euler()
	scene_texture.size = Vector2(256, 256)
	
	instance.queue_free()
	return scene_texture

# Optional: Pre-generate all icons at game start for better performance
func pregenerate_all_icons(buildable_scenes: Array[PackedScene]):
	for scene in buildable_scenes:
		get_buildable_icon(scene)
