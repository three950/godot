extends Card3DState

signal stop_follow_me


func enter() -> void:
	if not stop_follow_me.is_connected(stop_follow_you):
		stop_follow_me.connect(stop_follow_you)


func stop_follow_you() -> void:
	if card.children_card != null:
		if card.children_card.card_state_machine and card.children_card.card_state_machine.current_state:
			var child_state := card.children_card.card_state_machine.current_state
			if child_state.has_signal("stop_follow_me"):
				child_state.stop_follow_me.emit()
	transition_requested.emit(self, Card3DState.State.instack)
