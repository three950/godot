extends CardState
func enter() -> void:
	print("pick1")
	if cardStackState & CardState.STACK_STATE_STACKING and card.follow_target != null:#被拿起时，断开与前一张卡的连接
		print("卡片 %s 断开与目标 %s 的连接" % [name, card.follow_target.name])
		card.follow_target.cardStackState &= ~CardState.STACK_STATE_BESTACKED
		card.follow_target = null
		card.cardStackState = 0
	card.z_index = 100
		
	
func on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		print("pick2")
		transition_requested.emit(self, CardState.State.dragging)
