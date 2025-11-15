extends CardState
func enter() -> void:
	if not card.is_node_ready():
		await card.ready
	print("fix状态开始")
	card.reparent_requested.emit(card)
	card.pivot_offset = Vector2.ZERO

func _on_control_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("LMB"):
		card.pivot_offset = card.get_global_mouse_position() - card.global_position
		print("fix2")
		transition_requested.emit(self, CardState.State.pickingup)
