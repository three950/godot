extends CardState
signal stop_follow_me

func enter() -> void:
	print("%s跟着移动。。。"%card.name)
	stop_follow_me.connect(stop_follow_you)

# 移除 _process 中的位置更新逻辑，位置现在由父卡牌主动推送
# 子卡牌只需要在 instackdragging 状态等待父卡牌更新即可

func stop_follow_you():
	print('好的不跟了')
	if card.children_card!=null:#是头卡，有children就提醒，没有就不提醒，但是都回到fixed属性
		print("children_card也不跟了")
		if card.children_card and card.children_card.card_state_machine and card.children_card.card_state_machine.current_state:
			card.children_card.card_state_machine.current_state.stop_follow_me.emit()
	transition_requested.emit(self, CardState.State.instack)
