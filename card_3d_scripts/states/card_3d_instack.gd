extends Card3DState

signal follow_me

var last_position: Vector3 = Vector3.ZERO


func enter() -> void:
	if not follow_me.is_connected(follow_you):
		follow_me.connect(follow_you)
	card.reset_offset()
	last_position = card.global_position


func exit() -> void:
	last_position = Vector3.ZERO


func _physics_process(_delta: float) -> void:
	if card.global_position != last_position:
		card.update_stack_chain_position()
		last_position = card.global_position


func follow_you() -> void:
	if card.children_card and card.children_card.card_state_machine and card.children_card.card_state_machine.current_state:
		var child_state := card.children_card.card_state_machine.current_state
		if child_state.has_signal("follow_me"):
			child_state.follow_me.emit()
	transition_requested.emit(self, Card3DState.State.instackdragging)


func on_area_input(camera: Camera3D, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			card.begin_drag(camera, mouse_button.position, event_position)
			transition_requested.emit(self, Card3DState.State.pickingup)
