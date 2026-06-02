extends Node
class_name DebugCoinQuickSpawner

@export var coin_scene: PackedScene
@export var spawn_parent_path: NodePath
@export var spawn_count: int = 10
@export var spawn_position: Vector3 = Vector3(-12.0, 0.0, 2.5)
@export var batch_offset_x: float = 0.35
@export var shortcut_key: int = KEY_G

var _spawn_batch_index := 0


func _unhandled_input(event: InputEvent) -> void:
	if not _is_spawn_key_event(event):
		return

	spawn_coin_stack()
	get_viewport().set_input_as_handled()


func spawn_coin_stack() -> void:
	if coin_scene == null:
		push_warning("DebugCoinQuickSpawner: coin_scene is not assigned.")
		return

	var spawn_parent := _get_spawn_parent()
	if spawn_parent == null:
		push_warning("DebugCoinQuickSpawner: no spawn parent found.")
		return

	var base_position := spawn_position + Vector3(batch_offset_x * float(_spawn_batch_index), 0.0, 0.0)
	var previous_coin: Card3D = null
	var head_coin: Card3D = null

	for _index in range(maxi(spawn_count, 1)):
		var coin := coin_scene.instantiate() as CoinCard3D
		if coin == null:
			push_warning("DebugCoinQuickSpawner: coin_scene root is not CoinCard3D.")
			return

		spawn_parent.add_child(coin)
		if previous_coin == null:
			head_coin = coin
			coin.global_position = base_position
		else:
			_link_coin_on_top(previous_coin, coin)

		previous_coin = coin

	if head_coin != null:
		head_coin.update_stack_chain_position()

	_spawn_batch_index += 1
	Events.coin_cards_changed.emit()


func _link_coin_on_top(target_card: Card3D, stacked_coin: CoinCard3D) -> void:
	target_card.children_card = stacked_coin
	target_card.stack_state |= Card3DState.STACK_STATE_BESTACKED
	target_card.set_stack_detector_enabled(false)
	target_card.array_changed.emit()

	stacked_coin.follow_target = target_card
	stacked_coin.stack_state = Card3DState.STACK_STATE_STACKING
	stacked_coin.global_position = target_card.get_child_stack_position()
	if stacked_coin.card_state_machine != null:
		stacked_coin.card_state_machine.force_transition(Card3DState.State.instack)


func _get_spawn_parent() -> Node:
	var configured_parent := get_node_or_null(spawn_parent_path)
	if configured_parent != null:
		return configured_parent

	var existing_card := get_tree().get_first_node_in_group("Cards3D") as Card3D
	if existing_card != null:
		return existing_card.get_parent()

	return get_tree().current_scene


func _is_spawn_key_event(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	if key_event == null:
		return false
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == shortcut_key or key_event.physical_keycode == shortcut_key
