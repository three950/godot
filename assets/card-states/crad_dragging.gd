extends CardState

func enter() -> void:#背包和商店的卡片可以用这个方法重新父化S1-03状态机
	var card_layer := get_tree().get_first_node_in_group("Cards")
	if card_layer:
		card.reparent(card_layer)
	card.z_index = 100

func on_input(event: InputEvent) -> void:
	card.global_position = card.get_global_mouse_position() - card.drag_offset
	# 主动更新所有子卡牌的位置
	card.update_children_position()
	
	if event.is_action_released("LMB") or event.is_action_pressed("LMB"):
		transition_requested.emit(self, CardState.State.falling)
