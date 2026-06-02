@tool
extends Card3D
class_name CoinCard3D

const COIN_CARD_GROUP := "CoinCards3D"


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return

	add_to_group(COIN_CARD_GROUP)
	Events.coin_cards_changed.emit()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if Events != null:
		# 离树后下一帧再通知 UI 统计，避免马上计数时这张卡还在 group 列表里。
		Events.call_deferred("emit_signal", "coin_cards_changed")


func get_coin_stack_count() -> int:
	var count := 0
	var current: Card3D = self

	while current != null:
		if not (current is CoinCard3D):
			return 0
		count += 1
		current = current.children_card

	return count


func can_pay_coin_count(price: int) -> bool:
	return price > 0 and get_coin_stack_count() >= price


func spend_from_coin_stack(amount: int, remaining_position: Variant = null) -> Card3D:
	if amount <= 0:
		return self

	var remaining_head: Card3D = self
	var consumed_count := 0
	var original_parent := get_parent()

	while remaining_head != null and consumed_count < amount:
		if not (remaining_head is CoinCard3D):
			break

		var spent_card := remaining_head
		remaining_head = spent_card.children_card
		_prepare_spent_coin_for_delete(spent_card)
		consumed_count += 1

	if remaining_head != null and is_instance_valid(remaining_head):
		_detach_remaining_stack(remaining_head, original_parent, remaining_position)

	Events.call_deferred("emit_signal", "coin_cards_changed")
	return remaining_head


func _prepare_spent_coin_for_delete(spent_card: Card3D) -> void:
	# 消费金币时只断开这张卡和堆叠链的关系，不影响未被消费的上层金币。
	spent_card.children_card = null
	spent_card.follow_target = null
	spent_card.stack_state = 0
	spent_card.set_stack_detector_enabled(false)
	spent_card.end_drag()
	spent_card.queue_free()


func _detach_remaining_stack(remaining_head: Card3D, original_parent: Node, remaining_position: Variant) -> void:
	remaining_head.follow_target = null
	remaining_head.stack_state &= ~Card3DState.STACK_STATE_STACKING

	if original_parent != null and remaining_head.get_parent() != original_parent:
		remaining_head.reparent(original_parent, true)

	if remaining_position is Vector3:
		remaining_head.global_position = remaining_position

	remaining_head.snap_to_base_plane()
	remaining_head.update_stack_chain_position()
	if remaining_head.card_state_machine != null:
		remaining_head.card_state_machine.force_transition(Card3DState.State.fixed)
