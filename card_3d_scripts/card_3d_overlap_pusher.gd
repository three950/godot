class_name Card3DOverlapPusher
extends Node

@export var push_speed: float = 0.04
@export var min_separation: float = 0.01

var card: Card3D
var overlapping_push_cards := {}


func _ready() -> void:
	card = get_parent() as Card3D
	if card == null:
		push_error("Card3DOverlapPusher must be a child of a Card3D node.")
		return

	var push_detector := card.get_node_or_null("CardPushDetectorArea") as Area3D
	if push_detector:
		push_detector.area_entered.connect(_on_push_detector_area_entered)
		push_detector.area_exited.connect(_on_push_detector_area_exited)


func _physics_process(delta: float) -> void:
	if overlapping_push_cards.is_empty() or not _can_be_pushed(card):
		return

	var cards_to_remove: Array[Card3D] = []
	for other_card in overlapping_push_cards.keys():
		if other_card == null or not is_instance_valid(other_card):
			cards_to_remove.append(other_card)
			continue

		if not _can_be_pushed(other_card):
			continue

		if _is_parent_child_relation(card, other_card):
			continue

		_push_cards_apart(card, other_card, delta)

	for invalid_card in cards_to_remove:
		overlapping_push_cards.erase(invalid_card)


func _can_be_pushed(check_card: Card3D) -> bool:
	if check_card == null or check_card.card_state_machine == null or check_card.card_state_machine.current_state == null:
		return true

	var current_state := check_card.card_state_machine.current_state.state
	return current_state != Card3DState.State.dragging \
			and current_state != Card3DState.State.instackdragging \
			and current_state != Card3DState.State.pickingup


func _is_parent_child_relation(card_a: Card3D, card_b: Card3D) -> bool:
	if card_a.children_card == card_b or card_b.children_card == card_a:
		return true

	if card_a.follow_target == card_b or card_b.follow_target == card_a:
		return true

	var current := card_a.children_card
	while current:
		if current == card_b:
			return true
		current = current.children_card

	current = card_b.children_card
	while current:
		if current == card_a:
			return true
		current = current.children_card

	return false


func _push_cards_apart(card_a: Card3D, card_b: Card3D, delta: float) -> void:
	var planar_a := Vector2(card_a.global_position.x, card_a.global_position.z)
	var planar_b := Vector2(card_b.global_position.x, card_b.global_position.z)
	var direction := planar_a - planar_b

	if direction.length() < min_separation:
		direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	else:
		direction = direction.normalized()

	var half_move := push_speed * delta * 30.0
	var move := direction * half_move

	var pos_a := card_a.global_position
	var pos_b := card_b.global_position
	pos_a.x += move.x
	pos_a.z += move.y
	pos_b.x -= move.x
	pos_b.z -= move.y
	card_a.global_position = pos_a
	card_b.global_position = pos_b

	card_a.update_stack_chain_position()
	card_b.update_stack_chain_position()


func _on_push_detector_area_entered(area: Area3D) -> void:
	var other_card := area.get_parent() as Card3D
	if other_card == null or other_card == card:
		return

	if _is_parent_child_relation(card, other_card):
		return

	overlapping_push_cards[other_card] = true


func _on_push_detector_area_exited(area: Area3D) -> void:
	var other_card := area.get_parent() as Card3D
	if other_card == null:
		return

	overlapping_push_cards.erase(other_card)
