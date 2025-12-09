extends CardState
func enter() -> void:
	print("pick1")
	if card.stack_state & CardState.STACK_STATE_STACKING and card.follow_target != null:#被拿起时，断开与前一张卡的连接
		print("卡片 %s 断开与目标 %s 的连接" % [card.name, card.follow_target.name])
		card.follow_target.stop_stacking_on_you.emit()
		card.stack_state = 0
		card.follow_target = null  # 清除跟随目标
	card.z_index = 100
	# 立即更新所有子卡的z_index
	if card.children_card != null:
		card.update_children_position()
	card.drag_offset = card.get_global_mouse_position()-card.global_position
	card.drag_started.emit()
	# 通知全局事件系统
	Events.card_drag_started.emit(card)
	
func on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		print("pick2")
		transition_requested.emit(self, CardState.State.dragging)
		if card.children_card and card.children_card.card_state_machine and card.children_card.card_state_machine.current_state:
			print("%s的子卡为%s" % [card.name,card.children_card.name])
			card.children_card.card_state_machine.current_state.follow_me.emit()
			
