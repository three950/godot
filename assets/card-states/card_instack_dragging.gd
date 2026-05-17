extends CardState
signal stop_follow_me

@export var follow_lerp_speed: float = 24.0

func enter() -> void:
	print("%s跟着移动。。。"%card.name)
	if not stop_follow_me.is_connected(stop_follow_you):
		stop_follow_me.connect(stop_follow_you)

func _physics_process(delta: float) -> void:
	if card == null or card.card_state_machine == null or card.card_state_machine.current_state != self:
		return
	if not is_instance_valid(card.follow_target):
		return
	
	var target_position := _get_follow_target_stack_position()
	var weight := 1.0 - exp(-follow_lerp_speed * delta)
	# 拖拽堆叠时子卡自行追随目标位置，避免整条队列硬同步移动。
	card.global_position = card.global_position.lerp(target_position, weight)
	card.z_index = card.follow_target.z_index + 1

func stop_follow_you():
	print('好的不跟了')
	if card.children_card!=null:#是头卡，有children就提醒，没有就不提醒，但是都回到fixed属性
		print("children_card也不跟了")
		if card.children_card and card.children_card.card_state_machine and card.children_card.card_state_machine.current_state:
			card.children_card.card_state_machine.current_state.stop_follow_me.emit()
	transition_requested.emit(self, CardState.State.instack)

func _get_follow_target_stack_position() -> Vector2:
	var label_node := card.follow_target.get_node_or_null("Panel") as Control
	if label_node == null:
		return card.follow_target.global_position
	
	var label_relative_y := label_node.position.y
	var label_size := label_node.size
	return Vector2(card.follow_target.global_position.x, card.follow_target.global_position.y + label_relative_y + label_size.y)
