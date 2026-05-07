extends Card3DState


func enter() -> void:
	card.detach_from_follow_target()
	card.start_pickup_feedback()


func on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		transition_requested.emit(self, Card3DState.State.dragging)
		if card.children_card and card.children_card.card_state_machine and card.children_card.card_state_machine.current_state:
			var child_state := card.children_card.card_state_machine.current_state
			if child_state.has_signal("follow_me"):
				child_state.follow_me.emit()
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			transition_requested.emit(self, Card3DState.State.falling)
