extends Node3D

@export var vertical_step: float = 0.5
@export var drag_speed: float = 0.01
@export var vertical_smoothing: float = 12.0

@onready var camera: Camera3D = $Camera3D
@onready var ground: StaticBody3D = $Ground

var is_dragging: bool = false
var target_camera_y: float = 0.0


func _ready() -> void:
	if camera:
		camera.current = true
		target_camera_y = camera.global_position.y


func _process(delta: float) -> void:
	var camera_position: Vector3 = camera.global_position
	camera_position.y = lerp(camera_position.y, target_camera_y, 1.0 - exp(-vertical_smoothing * delta))
	camera.global_position = camera_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event

		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_camera_y += vertical_step
			get_viewport().set_input_as_handled()
			return

		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_camera_y -= vertical_step
			get_viewport().set_input_as_handled()
			return

		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				var hit: Dictionary = _raycast_ground(mouse_button.position)
				if not hit.is_empty():
					is_dragging = true
					get_viewport().set_input_as_handled()
			else:
				is_dragging = false
			return

	if event is InputEventMouseMotion and is_dragging:
		var mouse_motion: InputEventMouseMotion = event
		_pan_camera(mouse_motion.relative)
		get_viewport().set_input_as_handled()


func _raycast_ground(mouse_position: Vector2) -> Dictionary:
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_end: Vector3 = ray_origin + camera.project_ray_normal(mouse_position) * 10000.0

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 4294967295

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}

	if hit.get("collider") != ground:
		return {}

	return hit


func _pan_camera(mouse_delta: Vector2) -> void:
	var screen_right: Vector3 = camera.global_transform.basis.x
	var screen_up: Vector3 = camera.global_transform.basis.y

	screen_right.y = 0.0
	screen_up.y = 0.0

	if screen_right.length_squared() > 0.0:
		screen_right = screen_right.normalized()

	if screen_up.length_squared() > 0.0:
		screen_up = screen_up.normalized()

	var movement: Vector3 = (-screen_right * mouse_delta.x + screen_up * mouse_delta.y) * drag_speed
	camera.global_position += movement
