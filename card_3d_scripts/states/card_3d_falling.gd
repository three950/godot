extends Card3DState


func enter() -> void:
	await get_tree().process_frame
	card.dropped.emit(self)
	card.end_drag()

	var closest_card := find_closest_card()
	if closest_card != null:
		card.log_state_event("falling: found stack target=%s" % [card.debug_card_name(closest_card)])
		stack_on_card(closest_card)

	if card.children_card != null:
		if card.children_card.card_state_machine and card.children_card.card_state_machine.current_state:
			card.log_state_event("falling: notify child stop follow, child=%s" % [
				card.debug_card_name(card.children_card),
			])
			var child_state := card.children_card.card_state_machine.current_state
			if child_state.has_signal("stop_follow_me"):
				child_state.stop_follow_me.emit()

	if card.stack_state & Card3DState.STACK_STATE_STACKING:
		card.log_state_event("transition request: falling -> instack")
		transition_requested.emit(self, Card3DState.State.instack)
	else:
		card.snap_to_base_plane()
		if card.children_card != null:
			card.update_children_position()
		card.log_state_event("transition request: falling -> fixed")
		transition_requested.emit(self, Card3DState.State.fixed)

	if card.fall_sound:
		SFXPlayer.play(card.fall_sound)


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


func stack_on_card(target_card: Card3D) -> void:
	var previous_target := card.follow_target
	card.stack_state = Card3DState.STACK_STATE_STACKING
	card.follow_target = target_card
	target_card.stacking_on_you.emit(card)
	card.log_state_event("stack_on_card: follow_target %s -> %s, stack_state=%d" % [
		card.debug_card_name(previous_target),
		card.debug_card_name(card.follow_target),
		card.stack_state,
	])

	var target_parent := target_card.get_parent()
	if target_parent and card.get_parent() != target_parent:
		card.reparent(target_parent, true)

	card.global_position = target_card.get_child_stack_position()
	card.update_children_position()
