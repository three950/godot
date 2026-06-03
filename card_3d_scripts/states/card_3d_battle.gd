extends Card3DState

const BATTLE_META_KEY := "battle_scene_3d"
const PREV_CAN_STACK_META_KEY := "battle_3d_prev_can_stack"
const PREV_MOUSE_CLICK_META_KEY := "battle_3d_prev_mouse_click"
const PREV_STACK_MONITORING_META_KEY := "battle_3d_prev_stack_monitoring"
const PREV_STACK_MONITORABLE_META_KEY := "battle_3d_prev_stack_monitorable"


func enter() -> void:
	if not card.is_node_ready():
		await card.ready

	card.end_drag()
	card.reset_offset()
	_store_previous_interaction_state()

	card.can_stack = false
	card.mouse_click_enabled = false
	_set_overlap_pusher_enabled(false)

	var battle_scene := card.card_state_machine.get_battle_scene() if card.card_state_machine else null
	if battle_scene != null and is_instance_valid(battle_scene):
		card.set_meta(BATTLE_META_KEY, battle_scene)


func exit() -> void:
	_restore_previous_interaction_state()
	_set_overlap_pusher_enabled(true)

	if card.has_meta(BATTLE_META_KEY):
		card.remove_meta(BATTLE_META_KEY)


func _store_previous_interaction_state() -> void:
	if not card.has_meta(PREV_CAN_STACK_META_KEY):
		card.set_meta(PREV_CAN_STACK_META_KEY, card.can_stack)
	if not card.has_meta(PREV_MOUSE_CLICK_META_KEY):
		card.set_meta(PREV_MOUSE_CLICK_META_KEY, card.mouse_click_enabled)
	if card.stack_detector:
		if not card.has_meta(PREV_STACK_MONITORING_META_KEY):
			card.set_meta(PREV_STACK_MONITORING_META_KEY, card.stack_detector.monitoring)
		if not card.has_meta(PREV_STACK_MONITORABLE_META_KEY):
			card.set_meta(PREV_STACK_MONITORABLE_META_KEY, card.stack_detector.monitorable)


func _restore_previous_interaction_state() -> void:
	if card.has_meta(PREV_CAN_STACK_META_KEY):
		card.can_stack = card.get_meta(PREV_CAN_STACK_META_KEY)
		card.remove_meta(PREV_CAN_STACK_META_KEY)
	if card.has_meta(PREV_MOUSE_CLICK_META_KEY):
		card.mouse_click_enabled = card.get_meta(PREV_MOUSE_CLICK_META_KEY)
		card.remove_meta(PREV_MOUSE_CLICK_META_KEY)
	if card.stack_detector:
		if card.has_meta(PREV_STACK_MONITORING_META_KEY):
			card.stack_detector.set_deferred("monitoring", card.get_meta(PREV_STACK_MONITORING_META_KEY))
			card.remove_meta(PREV_STACK_MONITORING_META_KEY)
		if card.has_meta(PREV_STACK_MONITORABLE_META_KEY):
			card.stack_detector.set_deferred("monitorable", card.get_meta(PREV_STACK_MONITORABLE_META_KEY))
			card.remove_meta(PREV_STACK_MONITORABLE_META_KEY)


func _set_overlap_pusher_enabled(enabled: bool) -> void:
	var push_detector := card.get_node_or_null("CardPushDetectorArea") as Area3D
	if push_detector != null:
		push_detector.set_deferred("monitoring", enabled)
		push_detector.set_deferred("monitorable", enabled)

	var pusher := card.get_node_or_null("Card3DOverlapPusher") as Card3DOverlapPusher
	if pusher == null:
		return

	pusher.overlapping_push_cards.clear()
	pusher.set_physics_process(enabled)
