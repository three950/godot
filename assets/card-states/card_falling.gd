extends CardState
# 信号：当卡片固定位置时触发（拖动结束）
signal card_fixed()
func enter() -> void:
	print("卡片 %s 处于下落状态" % name)
	card.z_index = 0
	# 延迟到下一帧再处理状态转换，确保状态机已准备好
	await get_tree().process_frame
	# 检测是否可以堆叠到其他卡片上
	var closest_card_falling = find_closest_card()
	if closest_card_falling != null:
		print("卡片 %s 找到最近的卡片 %s 进行堆叠" % [name, closest_card_falling.name])
		stack_on_card(closest_card_falling)
	if cardStackState & CardState.STACK_STATE_STACKING:
		print("卡片 %s 已堆叠到最顶部" % name)
		transition_requested.emit(self, CardState.State.instack)
	else:
		card_fixed.emit()
		print("卡片 %s 已固定" % name)
		transition_requested.emit(self, CardState.State.fixed)
func find_closest_card() -> Card:
	# 只从当前重叠的卡片中查找
	print("卡片 %s 开始查找最近的可堆叠卡片" % name)
	var closest_card: Card = null
	var closest_distance_sq: float = INF	
	for cards in card.overlapping_cards:
		var target_card = cards as Card
		if target_card == null:
			continue
		# 查找状态为fixed的卡片，或者instack状态且未被堆叠的卡片
		var target_state = target_card.card_state_machine.current_state if target_card.card_state_machine else null
		var is_bestacked = (target_state != null and target_state.state == CardState.State.instack) and \
									   (target_state != null and target_state.cardStackState & CardState.STACK_STATE_BESTACKED)
		
		if !is_bestacked:
			# 检查卡片是否未被堆叠
			var not_bestacked = target_state == null or not (target_state.cardStackState & CardState.STACK_STATE_BESTACKED)
			# 检查目标卡片不是 selling 类型
			var not_selling = target_card.card_type != Card.cardType.selling
			# 检查目标卡片是否允许堆叠
			var can_accept = target_card.can_accept_stack
			# 如果目标卡片只接受带 value 的卡片，检查当前卡片是否有 value 属性
			var value_check_passed = not target_card.accept_value_only or ("value" in card)
			
			if not_bestacked and not_selling and can_accept and value_check_passed:
				# 从重叠的卡片中找最近的一个
				var dist_sq = card.global_position.distance_squared_to(target_card.global_position)
				if dist_sq < closest_distance_sq:
					closest_distance_sq = dist_sq
					closest_card = target_card	
	return closest_card

# 堆叠到目标卡片上
func stack_on_card(target_card: Card) -> void:
	# 设置当前卡片的堆叠状态为stacking
	print("卡片 %s 开始堆叠到卡片 %s 上" % [name, target_card.name])
	cardStackState = CardState.STACK_STATE_STACKING
	# 设置跟随目标
	card.follow_target = target_card
	# 设置目标卡片的堆叠状态为bestacked（使用位或操作保留原有状态）
	if target_card.card_state_machine and target_card.card_state_machine.current_state:
		target_card.card_state_machine.current_state.cardStackState |= CardState.STACK_STATE_BESTACKED
		print("目标卡片 %s 的堆叠状态设置为bestacked" % target_card.name)
	var follower_chain: Array[Card] = get_stack_followers(card)
	# 将当前卡片的父节点设为和目标卡片相同
	var target_parent = target_card.get_parent()
	if target_parent and get_parent() != target_parent:
		var saved_global_pos = card.global_position
		var old_parent = get_parent()
		
		if old_parent:
			old_parent.remove_child(self)
		target_parent.add_child(self)
		card.global_position = saved_global_pos
		print("卡片 %s 移动到与 %s 相同的父节点" % [name, target_card.name])
	
	# 堆叠时需确保当前卡片紧跟在目标卡片堆叠链之后
	move_after_card(target_card)
	# 重新挂接跟随当前卡片的堆叠链，保持父节点一致与渲染顺序
	var previous_card: Card = card
	for follower in follower_chain:
		if follower == null:
			continue
		var follower_parent = follower.get_parent()
		if target_parent and follower_parent != target_parent:
			var follower_saved_pos = follower.global_position
			if follower_parent:
				follower_parent.remove_child(follower)
			target_parent.add_child(follower)
			follower.global_position = follower_saved_pos
		follower.move_after_card(previous_card)
		previous_card = follower
	
	# 设置初始位置：跟随目标卡片的Label节点正下方
	var label_node = target_card.get_node_or_null("ColorRect/Label")
	if label_node:
		var label_pos = label_node.global_position
		var label_size = label_node.size
		# 使用目标卡片的 x 坐标确保左右对齐，而不是 Label 的 x 坐标
		card.global_position = Vector2(target_card.global_position.x, label_pos.y + label_size.y)
	
	# 设置层级
	card.z_index = target_card.z_index + 1
	print("卡片 %s 堆叠完成")
# 将当前卡片移动到目标卡片后面（目标卡片总是在队列末尾）
func move_after_card(target_card: Card) -> void:
	var parent_node = get_parent()
	if parent_node == null:
		return

	# 目标卡片总是在队列末尾，直接移动到目标卡片后面
	var target_index = target_card.get_index()
	parent_node.move_child(self, target_index + 1)
	print("卡片 %s 移动到卡片 %s 后面（索引 %d）" % [name, target_card.name, target_index + 1])

# 获取当前卡片之上的所有跟随堆叠卡片（按堆叠顺序）
func get_stack_followers(target_card: Card) -> Array[Card]:
	var followers: Array[Card] = []
	if target_card == null:
		return followers
	var parent_node = target_card.get_parent()
	if parent_node == null:
		return followers
	for child in parent_node.get_children():
		if child is Card:
			var child_card: Card = child
			if child_card.follow_target == target_card:
				followers.append(child_card)
				followers.append_array(get_stack_followers(child_card))
	return followers
