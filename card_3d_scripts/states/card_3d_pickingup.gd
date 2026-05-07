extends Card3DState


func enter() -> void:
	card.detach_from_follow_target("pickup")
	card.start_pickup_feedback()


func on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		card.log_state_event("transition request: pickingup -> dragging (mouse motion)")
		transition_requested.emit(self, Card3DState.State.dragging)
		if card.children_card and card.children_card.card_state_machine and card.children_card.card_state_machine.current_state:
			card.log_state_event("notify child to follow while dragging: child=%s" % [
				card.debug_card_name(card.children_card),
			])
			var child_state := card.children_card.card_state_machine.current_state
			if child_state.has_signal("follow_me"):
				child_state.follow_me.emit()
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			card.log_state_event("transition request: pickingup -> falling (left release)")
			transition_requested.emit(self, Card3DState.State.falling)
