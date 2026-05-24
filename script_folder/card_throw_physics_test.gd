extends Node

const CARD_3D_SCENE_UID: String = "uid://bntgel7ybr1bb"
const CRAFT_REVEAL_START_OFFSET: Vector3 = Vector3(-1.15, 0.08, -0.9)
const CRAFT_REVEAL_PEAK_HEIGHT: float = 3.25

enum Phase {
	IDLE,
	RISE_FLIP,
	FALL,
	BOUNCE,
	SETTLED,
}

@export_group("Nodes")
@export var card_path: NodePath = ^"../Card3d"

@export_group("Timing")
@export var auto_play_on_ready: bool = true
@export var rise_flip_duration: float = 0.3
@export var fall_duration: float = 0.28
@export var settle_delay: float = 0.12

@export_group("Motion")
@export var start_position: Vector3 = Vector3(-3.2, 0.08, 1.7)
@export var landing_position: Vector3 = Vector3(0.65, -0.88, -0.2)
@export var flight_peak_height: float = 3.25
@export var flight_peak_progress: float = 0.56
@export var back_face_up_rotation_degrees: Vector3 = Vector3(180.0, 0.0, 0.0)
@export var front_face_up_rotation_degrees: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var fall_gravity_curve: float = 1.8
@export var fall_horizontal_curve: float = 1.0
@export var fall_sideways_arc: float = 0.22

@export_group("Bounce")
@export var min_bounce_count: int = 1
@export var max_bounce_count: int = 5
@export var height_per_bounce: float = 1.4
@export var bounce_height_scale: float = 0.082
@export var bounce_height_decay: float = 0.44
@export var first_bounce_duration: float = 0.22
@export var bounce_duration_decay: float = 0.76
@export var bounce_slide_scale: float = 0.035
@export var bounce_slide_decay: float = 0.55
@export var final_snap_to_front: bool = true

@export_group("Debug")
@export var print_motion_samples: bool = true
@export var motion_sample_interval: float = 0.2

var _phase: Phase = Phase.IDLE
var _phase_time: float = 0.0
var _bounce_index: int = 0
var _next_sample_time: float = 0.0
var _front_basis: Basis
var _back_basis: Basis
var _flight_peak_position: Vector3
var _bounce_count: int = 0
var _bounce_direction: Vector3 = Vector3.ZERO
var _impact_speed: float = 0.0
var _card: Node3D


func _ready() -> void:
	_card = get_node_or_null(card_path) as Node3D
	if _card == null:
		push_error("CardRevealSpawner: card_path does not point to a Node3D.")
		return

	_front_basis = _basis_from_degrees(front_face_up_rotation_degrees)
	_back_basis = _basis_from_degrees(back_face_up_rotation_degrees)

	if auto_play_on_ready:
		await get_tree().physics_frame
		play_card_reveal()


static func spawn_revealed_card(card_info: CardInfo, spawn_position: Vector3, spawn_parent: Node) -> Card3D:
	if spawn_parent == null:
		push_error("CardRevealSpawner: spawn_parent is null.")
		return null

	var card_3d_scene := load(CARD_3D_SCENE_UID) as PackedScene
	if card_3d_scene == null:
		push_error("CardRevealSpawner: failed to load %s." % CARD_3D_SCENE_UID)
		return null

	var instance := card_3d_scene.instantiate() as Card3D
	if instance == null:
		push_error("CardRevealSpawner: card scene did not instantiate as Card3D.")
		return null

	instance.card_info = card_info
	spawn_parent.add_child(instance)
	instance.global_position = spawn_position

	var reveal: Node = load("res://script_folder/card_reveal_spawner.gd").new()
	reveal.name = "CraftRevealThrow"
	reveal.auto_play_on_ready = false
	reveal.card_path = ^".."
	reveal.start_position = spawn_position + CRAFT_REVEAL_START_OFFSET
	reveal.landing_position = spawn_position
	reveal.flight_peak_height = spawn_position.y + CRAFT_REVEAL_PEAK_HEIGHT
	reveal.print_motion_samples = false
	instance.add_child(reveal)
	reveal.play_card_reveal()

	return instance

func _physics_process(delta: float) -> void:
	if _card == null or _phase == Phase.IDLE or _phase == Phase.SETTLED:
		return

	_phase_time += delta

	match _phase:
		Phase.RISE_FLIP:
			_update_rise_flip()
		Phase.FALL:
			_update_fall()
		Phase.BOUNCE:
			_update_bounce()

	if print_motion_samples and _phase_time >= _next_sample_time:
		_next_sample_time += motion_sample_interval
		print("Card reveal phase=%s t=%.2f pos=%s" % [_phase_name(), _phase_time, _card.global_position])


func play_card_reveal() -> void:
	if not _ensure_card_ready():
		return

	_reset_card_physics(false)
	_set_card_interaction_enabled(false)

	_bounce_index = 0
	_next_sample_time = 0.0
	_prepare_motion()
	_set_card_transform(start_position, _back_basis)
	_enter_phase(Phase.RISE_FLIP)


func _update_rise_flip() -> void:
	var t := _safe_progress(_phase_time, rise_flip_duration)
	var eased := smoothstep(0.0, 1.0, t)
	var position := start_position.lerp(_flight_peak_position, eased)
	var basis := _back_basis.slerp(_front_basis, eased)

	_set_card_transform(position, basis)

	if t >= 1.0:
		_enter_phase(Phase.FALL)


func _update_fall() -> void:
	var t := _safe_progress(_phase_time, fall_duration)
	var gravity_t := _curve_progress(t, fall_gravity_curve)
	var horizontal_t := _curve_progress(t, fall_horizontal_curve)
	var planar_start := Vector2(_flight_peak_position.x, _flight_peak_position.z)
	var planar_end := Vector2(landing_position.x, landing_position.z)
	var planar := planar_start.lerp(planar_end, horizontal_t)
	var travel := planar_end - planar_start

	# Give the throw a subtle lateral bow so the path does not read as a straight line.
	if absf(fall_sideways_arc) > 0.001 and travel.length_squared() > 0.000001:
		var side := Vector2(-travel.y, travel.x).normalized()
		planar += side * sin(PI * t) * fall_sideways_arc

	var y := lerpf(_flight_peak_position.y, landing_position.y, gravity_t)
	var position := Vector3(planar.x, y, planar.y)

	_set_card_transform(position, _front_basis)

	if t >= 1.0:
		_bounce_index = 0
		_enter_phase(Phase.BOUNCE)



func _update_bounce() -> void:
	if _bounce_index >= _bounce_count:
		_settle_card()
		return

	var duration := _bounce_duration(_bounce_index)
	var t := _safe_progress(_phase_time, duration)
	var height := _bounce_height(_bounce_index) * sin(PI * t)
	var start := _bounce_start_position(_bounce_index)
	var end := _bounce_end_position(_bounce_index)
	var position := start.lerp(end, smoothstep(0.0, 1.0, t)) + Vector3.UP * height

	_set_card_transform(position, _front_basis)

	if t >= 1.0:
		_bounce_index += 1
		if _bounce_index >= _bounce_count:
			_enter_phase(Phase.SETTLED)
			await get_tree().create_timer(settle_delay).timeout
			_settle_card()
		else:
			_enter_phase(Phase.BOUNCE)


func _settle_card() -> void:
	if final_snap_to_front:
		_set_card_transform(_settle_position(), _front_basis)

	_reset_card_physics(true)
	_set_card_interaction_enabled(true)
	_phase = Phase.SETTLED


func _enter_phase(next_phase: Phase) -> void:
	_phase = next_phase
	_phase_time = 0.0
	_next_sample_time = 0.0


func _prepare_motion() -> void:
	var peak_progress := clampf(flight_peak_progress, 0.0, 1.0)
	_flight_peak_position = start_position.lerp(landing_position, peak_progress)
	_flight_peak_position.y = maxf(flight_peak_height, maxf(start_position.y, landing_position.y) + 0.01)

	var planar_start := Vector2(start_position.x, start_position.z)
	var planar_landing := Vector2(landing_position.x, landing_position.z)
	var planar_travel := planar_landing - planar_start
	var total_flight_duration := maxf(rise_flip_duration + fall_duration, 0.01)

	_impact_speed = planar_travel.length() / total_flight_duration
	if planar_travel.length_squared() > 0.000001:
		_bounce_direction = Vector3(planar_travel.x, 0.0, planar_travel.y).normalized()
	else:
		_bounce_direction = Vector3.ZERO

	var drop_height := _flight_drop_height()
	var estimated_bounces := int(ceil(drop_height / maxf(height_per_bounce, 0.01)))
	var min_count := min_bounce_count
	var max_count := max_bounce_count
	if min_count < 0:
		min_count = 0
	if max_count < min_count:
		max_count = min_count
	_bounce_count = clampi(estimated_bounces, min_count, max_count)


func _set_card_transform(position: Vector3, basis: Basis) -> void:
	_card.global_transform = Transform3D(basis.orthonormalized(), position)


func _ensure_card_ready() -> bool:
	if _card == null:
		_card = get_node_or_null(card_path) as Node3D
	if _card == null:
		push_error("CardRevealSpawner: card_path does not point to a Node3D.")
		return false

	_front_basis = _basis_from_degrees(front_face_up_rotation_degrees)
	_back_basis = _basis_from_degrees(back_face_up_rotation_degrees)
	return true


func _reset_card_physics(sleeping: bool) -> void:
	var rigid_card := _card as RigidBody3D
	if rigid_card == null:
		return

	rigid_card.freeze = true
	rigid_card.sleeping = sleeping
	rigid_card.linear_velocity = Vector3.ZERO
	rigid_card.angular_velocity = Vector3.ZERO


func _set_card_interaction_enabled(enabled: bool) -> void:
	var card_3d := _card as Card3D
	if card_3d == null:
		return

	card_3d.ray_interaction_enabled = enabled
	card_3d.set_stack_detector_enabled(enabled)


func _basis_from_degrees(rotation_degrees: Vector3) -> Basis:
	return Basis.from_euler(rotation_degrees * (PI / 180.0))


func _safe_progress(time: float, duration: float) -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(time / duration, 0.0, 1.0)


func _curve_progress(t: float, curve: float) -> float:
	return pow(clampf(t, 0.0, 1.0), maxf(curve, 0.01))


func _flight_drop_height() -> float:
	return maxf(_flight_peak_position.y - landing_position.y, 0.0)


func _bounce_height(index: int) -> float:
	return _flight_drop_height() * bounce_height_scale * pow(maxf(bounce_height_decay, 0.0), index)


func _bounce_slide_distance(index: int) -> float:
	return _impact_speed * bounce_slide_scale * pow(maxf(bounce_slide_decay, 0.0), index)


func _bounce_start_position(index: int) -> Vector3:
	var position := landing_position
	for i in range(index):
		position += _bounce_direction * _bounce_slide_distance(i)
	return position


func _bounce_end_position(index: int) -> Vector3:
	return _bounce_start_position(index) + _bounce_direction * _bounce_slide_distance(index)


func _settle_position() -> Vector3:
	if _bounce_count <= 0:
		return landing_position
	return _bounce_end_position(_bounce_count - 1)


func _bounce_duration(index: int) -> float:
	return maxf(first_bounce_duration * pow(maxf(bounce_duration_decay, 0.0), index), 0.01)


func _phase_name() -> String:
	match _phase:
		Phase.RISE_FLIP:
			return "rise_flip"
		Phase.FALL:
			return "fall"
		Phase.BOUNCE:
			return "bounce_%d" % [_bounce_index + 1]
		Phase.SETTLED:
			return "settled"
		_:
			return "idle"
