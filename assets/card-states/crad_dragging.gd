extends CardState

func enter() -> void:#背包和商店的卡片可以用这个方法重新父化S1-03状态机
	print("【DRAGGING-ENTER】========================================")
	card.debug_card_info("DRAGGING-ENTER 进入拖拽状态前")
	
	var card_layer := get_tree().get_first_node_in_group("Cards")
	if card_layer:
		var old_parent = card.get_parent()
		var old_parent_name = old_parent.name if old_parent else "无"
		print("【DRAGGING-ENTER】准备reparent: 从 %s 到 %s" % [old_parent_name, card_layer.name])
		card.reparent(card_layer)
		card.debug_card_info("DRAGGING-ENTER reparent后")
	else:
		print("【DRAGGING-ENTER】警告：未找到Cards组节点！")
	
	card.z_index = 100
	card.debug_card_info("DRAGGING-ENTER 拖拽状态初始化完成")
	print("【DRAGGING-ENTER】========================================\n")

func exit() -> void:
	print("【DRAGGING-EXIT】========================================")
	card.debug_card_info("DRAGGING-EXIT 离开拖拽状态")
	print("【DRAGGING-EXIT】========================================\n")

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
	else:
		print("【DRAGGING-INPUT】警告：未找到Cards组节点进行边界限制！")
	
	# 主动更新所有子卡牌的位置
	card.update_children_position()
	
	if event.is_action_released("LMB") or event.is_action_pressed("LMB"):
		print("【DRAGGING-INPUT】鼠标释放，准备转换到falling状态")
		card.debug_card_info("DRAGGING-INPUT 鼠标释放")
		transition_requested.emit(self, CardState.State.falling)
