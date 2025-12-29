extends CardState
signal  follow_me

var last_position: Vector2 = Vector2.ZERO

func enter() -> void:
	print("卡片%s instack状态"%card.name)	
	if card.follow_target == null:
		print("没有目标兄弟")
	follow_me.connect(follow_you)
	# 记录初始位置
	last_position = card.global_position

func exit() -> void:
	last_position = Vector2.ZERO

func _process(_delta: float) -> void:
	# 检查位置是否发生变化
	if card.global_position != last_position:
		# 位置发生变化，更新整个堆叠链
		card.update_stack_chain_position()
		last_position = card.global_position

func follow_you():
	if card.children_card and card.children_card.card_state_machine and card.children_card.card_state_machine.current_state:
		card.children_card.card_state_machine.current_state.follow_me.emit()
	transition_requested.emit(self, CardState.State.instackdragging)

func _on_control_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("LMB"):
		card.pivot_offset = card.get_global_mouse_position() - card.global_position
		transition_requested.emit(self, CardState.State.pickingup)
