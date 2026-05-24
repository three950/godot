extends Card3DState


func enter() -> void:
	await get_tree().process_frame
	card.dropped.emit(self)
	card.end_drag()

	if _try_apply_stack_interaction():
		if _is_card_still_available():
			card.snap_to_base_plane()
			if card.children_card != null:
				card.update_children_position()
			transition_requested.emit(self, Card3DState.State.fixed)
			_play_fall_sound()
		return

	var closest_card := find_closest_card()
	if closest_card != null:
		stack_on_card(closest_card)

	if card.children_card != null:
		if card.children_card.card_state_machine and card.children_card.card_state_machine.current_state:
			var child_state := card.children_card.card_state_machine.current_state
			if child_state.has_signal("stop_follow_me"):
				child_state.stop_follow_me.emit()

	if card.stack_state & Card3DState.STACK_STATE_STACKING:
		transition_requested.emit(self, Card3DState.State.instack)
	else:
		card.snap_to_base_plane()
		if card.children_card != null:
			card.update_children_position()
		transition_requested.emit(self, Card3DState.State.fixed)

	_play_fall_sound()


func find_closest_card() -> Card3D:
	var closest_card: Card3D = null
	var closest_distance_sq := INF

	for target_card in card.overlapping_cards:
		if target_card == null or not is_instance_valid(target_card):
			continue

		var target_state := target_card.card_state_machine.current_state if target_card.card_state_machine else null
		var is_bestacked := target_state != null \
				and target_state.state == Card3DState.State.instack \
				and (target_card.stack_state & Card3DState.STACK_STATE_BESTACKED) != 0

		if is_bestacked or not target_card.can_stack:
			continue

		var distance_sq := card.global_position.distance_squared_to(target_card.global_position)
		if distance_sq < closest_distance_sq:
			closest_distance_sq = distance_sq
			closest_card = target_card

	return closest_card


func _try_apply_stack_interaction() -> bool:
	var candidates := _get_stack_interaction_candidates()

	# 特殊交互先于普通堆叠执行；按距离尝试，直到某个目标卡真正消费或处理这次落下。
	for target_card in candidates:
		if target_card.try_accept_stack_interaction(card):
			return true

	return false


func _get_stack_interaction_candidates() -> Array[Card3D]:
	var candidates: Array[Card3D] = []
	for target_card in card.overlapping_cards:
		if target_card == null or not is_instance_valid(target_card):
			continue
		if target_card == card:
			continue
		if not target_card.has_method("try_accept_stack_interaction"):
			continue
		candidates.append(target_card)

	candidates.sort_custom(func(a: Card3D, b: Card3D) -> bool:
		return card.global_position.distance_squared_to(a.global_position) \
				< card.global_position.distance_squared_to(b.global_position)
	)
	return candidates


func stack_on_card(target_card: Card3D) -> void:
	card.stack_state = Card3DState.STACK_STATE_STACKING
	card.follow_target = target_card
	target_card.stacking_on_you.emit(card)

	var target_parent := target_card.get_parent()
	if target_parent and card.get_parent() != target_parent:
		card.reparent(target_parent, true)

	card.global_position = target_card.get_child_stack_position()
	card.update_children_position()


func _is_card_still_available() -> bool:
	return card != null and is_instance_valid(card) and not card.is_queued_for_deletion()


func _play_fall_sound() -> void:
	if card.fall_sound:
		SFXPlayer.play(card.fall_sound)
