extends Card3DState

signal stop_follow_me

@export var follow_lerp_speed: float = 36.0


func enter() -> void:
	if not stop_follow_me.is_connected(stop_follow_you):
		stop_follow_me.connect(stop_follow_you)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(card.follow_target):
		return
	
	var target_position := card.follow_target.get_child_stack_position()
	var weight := 1.0 - exp(-follow_lerp_speed * delta)
	# 拖拽堆叠时子卡自行追随目标位置，避免整条队列硬同步移动。
	card.global_position = card.global_position.lerp(target_position, weight)


func stop_follow_you() -> void:
	if card.children_card != null:
		if card.children_card.card_state_machine and card.children_card.card_state_machine.current_state:
			var child_state := card.children_card.card_state_machine.current_state
			if child_state.has_signal("stop_follow_me"):
				child_state.stop_follow_me.emit()
	transition_requested.emit(self, Card3DState.State.instack)
