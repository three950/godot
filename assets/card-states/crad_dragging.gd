extends CardState

func enter() -> void:#背包和商店的卡片可以用这个方法重新父化S1-03状态机
	var card_layer := get_tree().get_first_node_in_group("Cards")
	if card_layer:
		card.reparent(card_layer)
	card.z_index = 100

func on_input(event: InputEvent) -> void:
	card.global_position = card.get_global_mouse_position() - card.drag_offset
	
	# 将卡片位置限制在 cardsArea（Cards 分组节点）矩形内
	var card_layer := get_tree().get_first_node_in_group("Cards") as Control
	if card_layer:
		var rect := card_layer.get_global_rect()
		var pos := card.global_position
		
		# 按缩放后的尺寸进行边界计算
		var scaled_size := card.size * card.scale
		
		pos.x = clamp(pos.x, rect.position.x, rect.position.x + rect.size.x - scaled_size.x)
		pos.y = clamp(pos.y, rect.position.y, rect.position.y + rect.size.y - scaled_size.y)
		
		card.global_position = pos
	
	# 主动更新所有子卡牌的位置
	card.update_children_position()
	
	if event.is_action_released("LMB") or event.is_action_pressed("LMB"):
		transition_requested.emit(self, CardState.State.falling)
