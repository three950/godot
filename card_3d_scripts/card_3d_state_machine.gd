class_name Card3DStateMachine
extends Node

@export var initial_state: Card3DState
@export var debug_state_transitions: bool = true

var current_state: Card3DState
var states := {}
var _card: Card3D = null


func init(card: Card3D) -> void:
	_card = card
	states.clear()
	for child in get_children():
		var state_node := child as Card3DState
		if state_node == null:
			continue

		states[state_node.state] = state_node
		if not state_node.transition_requested.is_connected(_on_transition_requested):
			state_node.transition_requested.connect(_on_transition_requested)
		state_node.card = card

	if initial_state:
		current_state = initial_state
		_log_state_change("init", null, initial_state)
		initial_state.enter()
		initial_state.post_enter()


func on_input(event: InputEvent) -> void:
	if current_state:
		current_state.on_input(event)


func on_area_input(camera: Camera3D, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if current_state:
		current_state.on_area_input(camera, event, event_position, normal, shape_idx)


func on_mouse_entered() -> void:
	if current_state:
		current_state.on_mouse_entered()


func on_mouse_exited() -> void:
	if current_state:
		current_state.on_mouse_exited()


func _on_transition_requested(from: Card3DState, to: Card3DState.State) -> void:
	if from != current_state:
		return

	var new_state := states.get(to) as Card3DState
	if new_state == null:
		push_warning("[Card3DStateMachine] transition target missing: %s -> %s" % [_state_name(from), _state_name_by_enum(to)])
		return

	if current_state:
		current_state.exit()

	_log_state_change("transition", current_state, new_state)
	current_state = new_state
	new_state.enter()
	new_state.post_enter()


func _log_state_change(stage: String, from_state: Card3DState, to_state: Card3DState) -> void:
	if not debug_state_transitions:
		return

	var card_label := "unknown_card"
	if _card:
		card_label = _card.cardname if _card.cardname != "" else _card.name

	print("[Card3DStateMachine][%s] card=%s from=%s to=%s" % [
		stage,
		card_label,
		_state_name(from_state),
		_state_name(to_state),
	])


func _state_name(state_node: Card3DState) -> String:
	if state_node == null:
		return "null"
	return _state_name_by_enum(state_node.state)


func _state_name_by_enum(state_value: Card3DState.State) -> String:
	match state_value:
		Card3DState.State.fixed:
			return "fixed"
		Card3DState.State.pickingup:
			return "pickingup"
		Card3DState.State.dragging:
			return "dragging"
		Card3DState.State.falling:
			return "falling"
		Card3DState.State.instack:
			return "instack"
		Card3DState.State.instackdragging:
			return "instackdragging"
		_:
			return "unknown(%s)" % [str(state_value)]
