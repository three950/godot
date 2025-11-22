extends CardState
signal  follow_me
func enter() -> void:
	print("卡片%s instack状态"%card.name)	
	if card.follow_target == null:
		print("没有目标兄弟")
	follow_me.connect(follow_you)
	
func follow_you():
	if card.children_card and card.children_card.card_state_machine and card.children_card.card_state_machine.current_state:
		card.children_card.card_state_machine.current_state.follow_me.emit()
	transition_requested.emit(self, CardState.State.instackdragging)

func _on_control_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("LMB"):
		card.pivot_offset = card.get_global_mouse_position() - card.global_position
		transition_requested.emit(self, CardState.State.pickingup)
