extends CardState
signal  follow_me
func enter() -> void:
	print("instack状态")	
	if card.follow_target == null:
		print("没有目标兄弟")
	follow_me.connect(follow_you)
	
func follow_you():
	if card.children_card:
		card.children_card.follow_me.emit()
	transition_requested.emit(self, CardState.State.instackdragging)

func _on_control_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("LMB"):
		card.pivot_offset = card.get_global_mouse_position() - card.global_position
		transition_requested.emit(self, CardState.State.pickingup)
