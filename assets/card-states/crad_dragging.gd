extends CardState

#func enter() -> void:#背包和商店的卡片可以用这个方法重新父化S1-03状态机
#	var ui_layer := get_tree().get_first_node_in_group("ui_layer")
#	if ui_layer:
#		card_ui.reparent(ui_layer)
#	card.z_index = 100

func on_input(event: InputEvent) -> void:
	card.global_position = card.get_global_mouse_position() - card.drag_offset
	card.z_index = 100
	if event.is_action_released("LMB"):
		transition_requested.emit(self, CardState.State.falling)
