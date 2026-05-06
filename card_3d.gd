@tool
extends RigidBody3D

@export var front_face_path: NodePath = ^"FrontFace"
@export var sub_viewport_path: NodePath = ^"SubViewport"


func _ready() -> void:
	call_deferred("_apply_front_viewport_texture")


func _apply_front_viewport_texture() -> void:
	var front_face := get_node_or_null(front_face_path) as MeshInstance3D
	var sub_viewport := get_node_or_null(sub_viewport_path) as SubViewport
	if front_face == null or sub_viewport == null:
		return

	var material := front_face.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		front_face.material_override = material

	material.resource_local_to_scene = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = sub_viewport.get_texture()
