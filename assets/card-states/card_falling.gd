extends CardState
const CHARACTER_SCRIPT := preload("res://assets/人物与敌人/Character/character.gd")
# 信号：当卡片固定位置时触发（拖动结束）
signal card_fixed()

func enter() -> void:
	print("卡片 %s 处于下落状态" % card.name)
	card.z_index = 0
	# 延迟到下一帧再处理状态转换，确保状态机已准备好
	await get_tree().process_frame
	card.dropped.emit(self)
	# 通知全局事件系统
	Events.card_dropped.emit(card)
	
	# 先检查是否落在背包槽位内，如果是则跳过堆叠逻辑
	if _is_card_in_bag_slot():
		print("卡片 %s 落在背包槽位内，跳过堆叠检测" % card.name)
		# 清空重叠数组，避免隐形堆叠
		card.overlapping_cards.clear()
		transition_requested.emit(self, CardState.State.fixed)
		return
	
	# 检测是否可以堆叠到其他卡片上
	var closest_card_falling = find_closest_card()
	if closest_card_falling != null:
		print("卡片 %s 找到最近的卡片 %s 进行堆叠" % [card.name, closest_card_falling.name])
		stack_on_card(closest_card_falling)
	if card.children_card!=null:#是头卡，有children就提醒，没有就不提醒，但是都回到fixed属性
		print("有children_card")
		if card.children_card and card.children_card.card_state_machine and card.children_card.card_state_machine.current_state:
			card.children_card.card_state_machine.current_state.stop_follow_me.emit()
		card_fixed.emit()
	
	if card.stack_state & CardState.STACK_STATE_STACKING:#堆叠在其他卡片上，不是头卡
		print("卡片 %s 已堆叠到最顶部" % card.name)
		transition_requested.emit(self, CardState.State.instack)
	else:	
		print("卡片 %s 已固定" % card.name)
		# 进入fixed状态前，更新所有子卡牌的位置和z_index
		if card.children_card != null:
			card.update_children_position()
		transition_requested.emit(self, CardState.State.fixed)

			
	
func find_closest_card() -> Card:
	# 只从当前重叠的卡片中查找
	print("卡片 %s 开始查找最近的可堆叠卡片" % card.name)
	var closest_card: Card = null
	var closest_distance_sq: float = INF	
	for cards in card.overlapping_cards:
		var target_card = cards as Card
		if target_card == null:
			print("卡片 %s 重叠的卡片为空" % card.name)
			continue
		# 查找状态为fixed的卡片，或者instack状态且未被堆叠的卡片
		var target_state = target_card.card_state_machine.current_state if target_card.card_state_machine else null
		var is_bestacked = (target_state != null and target_state.state == CardState.State.instack) and \
									   (target_card.stack_state & CardState.STACK_STATE_BESTACKED)
		
		if !is_bestacked:
			print("卡片 %s 状态为 %s, can_stack=%s" % [target_card.name, target_state.state, target_card.can_stack])
			if target_card.can_stack:
				# 从重叠的卡片中找最近的一个
				var dist_sq = card.global_position.distance_squared_to(target_card.global_position)
				if dist_sq < closest_distance_sq:
					closest_distance_sq = dist_sq
					closest_card = target_card	
	return closest_card

# 堆叠到目标卡片上
func stack_on_card(target_card: Card) -> void:
	# 设置当前卡片的堆叠状态为stacking
	print("卡片 %s 开始堆叠到卡片 %s 上" % [card.name, target_card.name])
	card.stack_state = CardState.STACK_STATE_STACKING
	# 设置跟随目标
	card.follow_target = target_card
	target_card.stacking_on_you.emit(card)
	
	# 将当前卡片的父节点设为和目标卡片相同
	var target_parent = target_card.get_parent()
	if target_parent and get_parent() != target_parent:
		var saved_global_pos = card.global_position
		var old_parent = get_parent()
		
		if old_parent:
			old_parent.remove_child(self)
		target_parent.add_child(self)
		card.global_position = saved_global_pos
		print("卡片 %s 移动到与 %s 相同的父节点" % [card.name, target_card.name])
	
	# 设置初始位置：跟随目标卡片的Label节点正下方
	var label_node = target_card.get_node("Panel")
	if label_node:
		var label_pos = label_node.global_position
		var label_size = label_node.size
		# 使用目标卡片的 x 坐标确保左右对齐，而不是 Label 的 x 坐标
		card.global_position = Vector2(target_card.global_position.x, label_pos.y + label_size.y)
	
	# 设置层级
	card.z_index = target_card.z_index + 1
	
	# 递归更新当前卡片的所有子卡牌位置和z_index
	card.update_children_position()
	
	print("卡片 %s 堆叠完成" % card.name)

# 检查卡片是否落在背包槽位内
func _is_card_in_bag_slot() -> bool:
	var drop_position = card.get_global_mouse_position()
	# 获取所有背包区域
	var bag_areas = get_tree().get_nodes_in_group("BagArea")
	for bag in bag_areas:
		if bag is BagArea:
			var bag_area := bag as BagArea
			# 直接检查所有槽位
			for slot in bag_area.hand_slots:
				if slot.contains_global_point(drop_position):
					return true
			for slot in bag_area.backpack_slots:
				if slot.contains_global_point(drop_position):
					return true
	return false
