extends Card3DState


func on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		card.update_drag_from_mouse(mouse_motion.position)
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			card.log_state_event("transition request: dragging -> falling (left release)")
			transition_requested.emit(self, Card3DState.State.falling)
