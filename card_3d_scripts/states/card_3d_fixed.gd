extends Card3DState


func enter() -> void:
	if not card.is_node_ready():
		await card.ready
	card.reset_offset()
	card.reparent_requested.emit(card)
	card.end_drag()


func on_area_input(camera: Camera3D, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			if card.card_type == Card3D.cardType.architecture:
				return
			card.begin_drag(camera, mouse_button.position, event_position)
			transition_requested.emit(self, Card3DState.State.pickingup)
