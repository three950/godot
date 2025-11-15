extends CardState
func enter() -> void:
	print("pick1")
	if cardStackState & CardState.STACK_STATE_STACKING and card.follow_target != null:#被拿起时，断开与前一张卡的连接
		print("卡片 %s 断开与目标 %s 的连接" % [name, card.follow_target.name])
		if card.follow_target.card_state_machine and card.follow_target.card_state_machine.current_state:
			card.follow_target.card_state_machine.current_state.cardStackState &= ~CardState.STACK_STATE_BESTACKED
		card.follow_target = null
		cardStackState = 0
	card.z_index = 100
	card.drag_offset = card.get_global_mouse_position()-card.global_position
		
	
func on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		print("pick2")
		transition_requested.emit(self, CardState.State.dragging)
