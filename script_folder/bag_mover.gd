class_name BagMover
extends Node

@export var bag_area :Array[BagArea]#这是背包，不是背包中的卡槽，他没有export卡槽

func setup_card(card: Node) -> void:
	# 连接卡片的拖拽相关信号
	if card.has_signal("drag_started"):
		card.drag_started.connect(_on_card_drag_started.bind(card))
	if card.has_signal("drag_canceled"):
		card.drag_canceled.connect(_on_card_drag_canceled.bind(card))
	if card.has_signal("dropped"):
		card.dropped.connect(_on_card_dropped.bind(card))

func _get_bag_area_for_position(global: Vector2) -> int:
	"""获取指定全局位置下的背包区域索引"""
	var dropoed_bag_index:=-1
	for index in bag_area.size():
		# 使用背包节点的包围盒检查是否包含该点
		var rect = Rect2(bag_area[index].global_position, bag_area[index].size)
		if rect.has_point(global):
			dropoed_bag_index=index
	return dropoed_bag_index

func _add_card_to_slot(global:Vector2,card:Card) -> void:
	var bag_index:=_get_bag_area_for_position(global)
	if bag_index >= 0 and bag_index < bag_area.size():
		var bag = bag_area[bag_index]
		var slot = _get_slot_for_position(bag, global)
		if slot:
			slot.add_child(card)
			card.global_position = slot.get_center_global_position()
			# 4. 根据槽位大小调整卡片缩放
			var scale = slot.get_slot_size().x / card.size.x
			card.scale = Vector2(scale, scale)
			print("将卡片添加到槽位", slot)
	
func _get_slot_for_position(bag: BagArea, global: Vector2) -> BagSlot:
	"""获取背包中包含指定位置的槽位"""
	# 检查左右手槽位
	for slot in bag.hand_slots:
		if slot.contains_global_point(global):
			return slot
	# 检查背包槽位
	for slot in bag.backpack_slots:
		if slot.contains_global_point(global):
			return slot
	return null

func _reset_card_to_starting_position(starting_position: Vector2, card: Node) -> void:
	"""将卡片重置到起始位置"""
	card.global_position = starting_position

func _move_card_to_slot(card: Node, slot: BagSlot) -> void:
	"""将卡片移动到指定槽位"""
	if slot:
		card.global_position = slot.get_center_global_position() - card.size / 2.0

func _on_card_drag_started(card: Node) -> void:
	"""处理卡片拖拽开始事件"""
	# 可以在这里添加拖拽开始时的视觉效果
	pass

func _on_card_drag_canceled(starting_position: Vector2, card: Node) -> void:
	"""处理卡片拖拽取消事件"""
	_reset_card_to_starting_position(starting_position, card)

func _on_card_dropped(starting_position: Vector2, card: Node) -> void:
	"""处理卡片放置事件"""
	var drop_position = card.get_global_mouse_position()
	var target_bag = _get_bag_area_for_position(drop_position)
	var target_slot = null
	
	# 如果放置位置在某个背包内，获取对应的槽位
	if target_bag:
		target_slot = _get_slot_for_position(target_bag, drop_position)
	
	# 如果没有有效的目标槽位，重置卡片位置
	if not target_slot:
		_reset_card_to_starting_position(starting_position, card)
		return
	
	# 获取起始位置的背包和槽位
	var start_bag = _get_bag_area_for_position(starting_position)
	var start_slot = null
	if start_bag:
		start_slot = _get_slot_for_position(start_bag, starting_position)
	
	# 检查目标槽位是否已有卡片
	var existing_card = _get_card_in_slot(target_slot)
	if existing_card:
		# 如果有卡片，交换位置
		_reset_card_to_starting_position(starting_position, existing_card)
		_move_card_to_slot(card, target_slot)
		
		# 更新背包数据
		if start_slot and start_bag:
			var start_index = _get_slot_index(start_bag, start_slot)
			if start_index != -1:
				# 从起始背包中移除当前卡片
				_remove_card_from_bag(start_bag, start_index, existing_card)
				# 将现有卡片放入起始背包
				_add_card_to_bag(start_bag, start_index, existing_card)
				
		if target_bag:
			var target_index = _get_slot_index(target_bag, target_slot)
			if target_index != -1:
				# 从目标背包中移除现有卡片
				_remove_card_from_bag(target_bag, target_index, existing_card)
				# 将当前卡片放入目标背包
				_add_card_to_bag(target_bag, target_index, card)
	else:
		# 如果没有卡片，直接移动
		_move_card_to_slot(card, target_slot)
		
		# 更新背包数据
		if start_slot and start_bag:
			var start_index = _get_slot_index(start_bag, start_slot)
			if start_index != -1:
				# 从起始背包中移除当前卡片
				_remove_card_from_bag(start_bag, start_index, card)
				
		if target_bag:
			var target_index = _get_slot_index(target_bag, target_slot)
			if target_index != -1:
				# 将当前卡片放入目标背包
				_add_card_to_bag(target_bag, target_index, card)

func _get_card_in_slot(slot: BagSlot) -> Node:
	"""获取指定槽位中的卡片"""
	# 查找槽位的子节点中是否有卡片
	for child in slot.get_children():
		if child is Card or child is BaggableCard:
			return child
	return null

func _add_card_to_bag(bag: BagArea, slot_index: int, card: Node) -> void:
	"""将卡片添加到背包指定槽位并发出信号"""
	# 重新父化卡片到槽位
	card.get_parent().remove_child(card)
	# 获取对应槽位
	var slot = null
	if slot_index < bag.hand_slots.size():
		slot = bag.hand_slots[slot_index]
	else:
		slot = bag.backpack_slots[slot_index - bag.hand_slots.size()]
	
	if slot:
		slot.add_child(card)
		# 发出卡片放置信号
		bag.card_placed.emit(card, slot_index)
		# 发出背包内容变化信号
		bag.bag_item_changed.emit()

func _remove_card_from_bag(bag: BagArea, slot_index: int, card: Node) -> void:
	"""从背包指定槽位移除卡片并发出信号"""
	# 发出卡片移除信号
	bag.card_removed.emit(card, slot_index)
	# 发出背包内容变化信号
	bag.bag_item_changed.emit()
