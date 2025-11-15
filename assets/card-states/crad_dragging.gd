extends CardState

#func enter() -> void:#背包和商店的卡片可以用这个方法重新父化
#	var ui_layer := get_tree().get_first_node_in_group("ui_layer")
#	if ui_layer:
#		card_ui.reparent(ui_layer)
#	card.z_index = 100

func on_input(event: InputEvent) -> void:
	print("drag1")
	if event.is_action_released("left_mouse"):
		print("drag2")
		transition_requested.emit(self, CardState.State.falling)
