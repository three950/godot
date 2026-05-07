extends Card3DState


func enter() -> void:
	if card.stack_state & Card3DState.STACK_STATE_STACKING and card.follow_target != null:
		card.follow_target.stop_stacking_on_you.emit()
		card.stack_state = 0
		card.follow_target = null

	card.drag_started.emit()
	card.apply_pickup_offset()

	if card.pickup_sound:
		SFXPlayer.play(card.pickup_sound, false, 12.0)


func on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		transition_requested.emit(self, Card3DState.State.dragging)
		if card.children_card and card.children_card.card_state_machine and card.children_card.card_state_machine.current_state:
			card.children_card.card_state_machine.current_state.follow_me.emit()
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			transition_requested.emit(self, Card3DState.State.falling)
