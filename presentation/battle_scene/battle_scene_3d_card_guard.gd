class_name BattleScene3DCardGuard
extends RefCounted

const BATTLE_META_KEY := "battle_scene_3d"
const PREV_CAN_STACK_META_KEY := "battle_3d_prev_can_stack"
const PREV_RAY_META_KEY := "battle_3d_prev_ray_interaction"
const PREV_STACK_MONITORING_META_KEY := "battle_3d_prev_stack_monitoring"
const PREV_STACK_MONITORABLE_META_KEY := "battle_3d_prev_stack_monitorable"

var non_battle_card_push_margin: float = 0.35

var _battle_area_shape: CollisionShape3D = null


func configure(battle_area_shape: CollisionShape3D, push_margin: float) -> void:
	_battle_area_shape = battle_area_shape
	non_battle_card_push_margin = push_margin


func is_battle_card(card: Card3D) -> bool:
	return card != null and (card.card_info is CharacterCard or card.card_info is EnemyCard)


func accept_battle_unit(
		card: Card3D,
		battle_scene: Node,
		characters: Array[Card3D],
		enemies: Array[Card3D]
) -> Card3D:
	var unit := _get_valid_card(card)
	if unit == null:
		return null
	if battle_scene == null or not is_instance_valid(battle_scene):
		return null
	if not is_battle_card(unit):
		return null
	if characters.has(unit) or enemies.has(unit):
		return null

	# 进入战斗的卡牌由 guard 统一接管：停止拖拽、关闭堆叠/射线交互，并挂到战斗场景下。
	lock_card_for_battle(unit, battle_scene)
	if unit.get_parent() != battle_scene:
		unit.reparent(battle_scene, true)
	return unit


func lock_card_for_battle(card: Card3D, battle_scene: Node) -> void:
	if card == null or not is_instance_valid(card):
		return

	_cancel_active_card_motion(card)
	if not card.has_meta(PREV_CAN_STACK_META_KEY):
		card.set_meta(PREV_CAN_STACK_META_KEY, card.can_stack)
	if not card.has_meta(PREV_RAY_META_KEY):
		card.set_meta(PREV_RAY_META_KEY, card.ray_interaction_enabled)
	if card.stack_detector:
		if not card.has_meta(PREV_STACK_MONITORING_META_KEY):
			card.set_meta(PREV_STACK_MONITORING_META_KEY, card.stack_detector.monitoring)
		if not card.has_meta(PREV_STACK_MONITORABLE_META_KEY):
			card.set_meta(PREV_STACK_MONITORABLE_META_KEY, card.stack_detector.monitorable)

	card.detach_from_follow_target()
	card.reset_offset()
	card.can_stack = false
	card.ray_interaction_enabled = false
	card.set_stack_detector_enabled(false)
	card.set_meta(BATTLE_META_KEY, battle_scene)
	if card.battle:
		card.battle.current_state = BattleState.Phase.BATTLE


func push_non_battle_card_from_area(card: Card3D) -> Array[Card3D]:
	if card == null or is_battle_card(card):
		return []

	var detached_battle_cards := _detach_battle_cards_from_stack(card)
	force_card_outside_battle_area(card)
	return detached_battle_cards


func restore_card_after_battle(card: Card3D) -> void:
	if card == null or not is_instance_valid(card):
		return

	if card.has_meta(PREV_CAN_STACK_META_KEY):
		card.can_stack = card.get_meta(PREV_CAN_STACK_META_KEY)
		card.remove_meta(PREV_CAN_STACK_META_KEY)
	if card.has_meta(PREV_RAY_META_KEY):
		card.ray_interaction_enabled = card.get_meta(PREV_RAY_META_KEY)
		card.remove_meta(PREV_RAY_META_KEY)
	if card.stack_detector:
		if card.has_meta(PREV_STACK_MONITORING_META_KEY):
			card.stack_detector.set_deferred("monitoring", card.get_meta(PREV_STACK_MONITORING_META_KEY))
			card.remove_meta(PREV_STACK_MONITORING_META_KEY)
		if card.has_meta(PREV_STACK_MONITORABLE_META_KEY):
			card.stack_detector.set_deferred("monitorable", card.get_meta(PREV_STACK_MONITORABLE_META_KEY))
			card.remove_meta(PREV_STACK_MONITORABLE_META_KEY)

	if card.has_meta(BATTLE_META_KEY):
		card.remove_meta(BATTLE_META_KEY)
	if card.battle:
		card.battle.current_state = BattleState.Phase.COMMON


func cleanup_non_battle_cards_in_area(tree_owner: Node) -> Array[Card3D]:
	var detached_battle_cards: Array[Card3D] = []
	if tree_owner == null or not tree_owner.is_inside_tree():
		return detached_battle_cards

	var tree := tree_owner.get_tree()
	if tree == null:
		return detached_battle_cards

	for node in tree.get_nodes_in_group("Cards3D"):
		var card := node as Card3D
		if card == null or not is_instance_valid(card):
			continue
		if is_battle_card(card):
			continue
		if is_card_overlapping_battle_area(card):
			for battle_card in push_non_battle_card_from_area(card):
				if not detached_battle_cards.has(battle_card):
					detached_battle_cards.append(battle_card)

	return detached_battle_cards


func release_survivor_card(card: Card3D, release_parent: Node) -> void:
	if card == null or not is_instance_valid(card):
		return

	var preserved_transform := card.global_transform
	restore_card_after_battle(card)
	if release_parent == null or not is_instance_valid(release_parent):
		push_warning("【BattleScene3D】战斗结束时无法释放存活卡牌: %s" % card.name)
		return

	# reparent 后显式恢复全局变换，避免父节点释放时把存活单位一起带走。
	if card.get_parent() != release_parent:
		card.reparent(release_parent, false)
	card.global_transform = preserved_transform


func force_card_outside_battle_area(card: Card3D) -> void:
	if card == null or not is_instance_valid(card) or _battle_area_shape == null:
		return

	var move_card := card.get_stack_head()
	if move_card == null or not is_instance_valid(move_card):
		return

	var box_shape := _battle_area_shape.shape as BoxShape3D
	if box_shape == null:
		return

	var local_position := _battle_area_shape.to_local(card.global_position)
	var area_extents := box_shape.size * 0.5
	var card_half_size := card.face_size * 0.5
	var outside_x := area_extents.x + card_half_size.x + non_battle_card_push_margin
	var outside_z := area_extents.z + card_half_size.y + non_battle_card_push_margin
	var x_overlap := outside_x - absf(local_position.x)
	var z_overlap := outside_z - absf(local_position.z)

	# 从最近的边推出去，避免非战斗卡长期卡在战斗检测区内。
	if x_overlap < z_overlap:
		local_position.x = _signed_distance(local_position.x, outside_x)
	else:
		local_position.z = _signed_distance(local_position.z, outside_z)

	var target_position := _battle_area_shape.to_global(local_position)
	target_position.y = card.global_position.y
	move_card.global_position += target_position - card.global_position
	move_card.update_stack_chain_position()


func is_card_overlapping_battle_area(card: Card3D) -> bool:
	if card == null or _battle_area_shape == null:
		return false

	var box_shape := _battle_area_shape.shape as BoxShape3D
	if box_shape == null:
		return false

	var local_position := _battle_area_shape.to_local(card.global_position)
	var area_extents := box_shape.size * 0.5
	var card_half_size := card.face_size * 0.5
	return absf(local_position.x) <= area_extents.x + card_half_size.x \
			and absf(local_position.z) <= area_extents.z + card_half_size.y


func _signed_distance(value: float, distance: float) -> float:
	return -distance if value < 0.0 else distance


func _get_valid_card(candidate) -> Card3D:
	if candidate == null or not (candidate is Object):
		return null
	if not is_instance_valid(candidate):
		return null
	return candidate as Card3D


func _cancel_active_card_motion(card: Card3D) -> void:
	card.end_drag()
	if card.card_state_machine == null or card.card_state_machine.current_state == null:
		return

	var state := card.card_state_machine.current_state.state
	if state == Card3DState.State.pickingup \
			or state == Card3DState.State.dragging \
			or state == Card3DState.State.instack \
			or state == Card3DState.State.instackdragging:
		# 战斗接管卡牌时必须退出拖拽态，否则鼠标移动仍会改 global_position。
		card.card_state_machine.force_transition(Card3DState.State.fixed)


func _detach_battle_cards_from_stack(card: Card3D) -> Array[Card3D]:
	var battle_cards: Array[Card3D] = []
	if card == null or not is_instance_valid(card):
		return battle_cards

	var current := card.get_stack_head()
	while current != null and is_instance_valid(current):
		var next := current.children_card
		if is_battle_card(current):
			battle_cards.append(current)
		current = next

	for battle_card in battle_cards:
		# 先拆出混合堆里的战斗卡，避免推出非战斗卡时把战斗单位一起带走。
		if battle_card.follow_target != null:
			battle_card.detach_from_follow_target()
		if battle_card.children_card != null:
			battle_card.children_card.detach_from_follow_target()
		_cancel_active_card_motion(battle_card)

	return battle_cards
