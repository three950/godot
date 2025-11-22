extends CardState
signal stop_follow_me
func enter() -> void:
	print("%s跟着移动。。。"%card.name)
	stop_follow_me.connect(stop_follow_you)
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
func stop_follow_you():
	print('好的不跟了')
	if card.children_card!=null:#是头卡，有children就提醒，没有就不提醒，但是都回到fixed属性
		print("children_card也不跟了")
		if card.children_card and card.children_card.card_state_machine and card.children_card.card_state_machine.current_state:
			card.children_card.card_state_machine.current_state.stop_follow_me.emit()
	transition_requested.emit(self, CardState.State.instack)
