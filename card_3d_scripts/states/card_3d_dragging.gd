extends Card3DState


func on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		card.update_drag_from_mouse(mouse_motion.position)
		var next_position := card.global_position
		next_position.y = 1.0
		card.global_position = next_position
		card.update_children_position()
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			transition_requested.emit(self, Card3DState.State.falling)
