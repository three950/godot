extends Card3DState


func enter() -> void:
	card.detach_from_follow_target()
	card.start_pickup_feedback()
	transition_requested.emit(self, Card3DState.State.dragging)


func on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			transition_requested.emit(self, Card3DState.State.falling)
