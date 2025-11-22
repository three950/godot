extends CardState
func enter() -> void:
	print("pick1")
	if card.stack_state & CardState.STACK_STATE_STACKING and card.follow_target != null:#被拿起时，断开与前一张卡的连接
		print("卡片 %s 断开与目标 %s 的连接" % [name, card.follow_target.name])
		card.follow_target.stack_state &= ~CardState.STACK_STATE_BESTACKED
		card.follow_target = null
		card.stack_state = 0
	card.z_index = 100
	card.drag_offset = card.get_global_mouse_position()-card.global_position
		
	
func on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		print("pick2")
		transition_requested.emit(self, CardState.State.dragging)
		if card.children_card and card.children_card.card_state_machine and card.children_card.card_state_machine.current_state:
			card.children_card.card_state_machine.current_state.follow_me.emit()
			
