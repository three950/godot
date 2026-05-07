@tool
extends MeshInstance3D

@export var sub_viewport_path: NodePath = ^"../SubViewport"


func _ready() -> void:
	call_deferred("_bind_sub_viewport_texture")


func _bind_sub_viewport_texture() -> void:
	var sub_viewport := get_node_or_null(sub_viewport_path) as SubViewport
	if sub_viewport == null:
		return

	var material := material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		material_override = material

	material.resource_local_to_scene = true
	material.resource_name = "GroundSubViewportMaterial"
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = sub_viewport.get_texture()
