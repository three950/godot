extends CardState
func enter() -> void:
	print("instack状态")	
	if card.follow_target == null:
		print("没有目标兄弟")
func _process(_delta: float) -> void:
	if card.follow_target != null:
		# 当卡片有follow_target时，卡片的cardState完全按照follow_target来
		if card.stack_state & CardState.STACK_STATE_STACKING:
			var label_node = card.follow_target.get_node("Panel/Label")
			if label_node:
				var label_pos = label_node.global_position
				var label_size = label_node.size
				card.global_position = Vector2(card.follow_target.global_position.x, label_pos.y + label_size.y)
				card.z_index = card.follow_target.z_index + 1
				
func _on_control_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("LMB"):
		card.pivot_offset = card.get_global_mouse_position() - card.global_position
		transition_requested.emit(self, CardState.State.pickingup)
